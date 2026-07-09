import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/gigs_service.dart';
import '../services/supabase_client.dart';
import '../theme/flovi_tokens.dart';
import '../widgets/booked_gig_row.dart';
import '../widgets/empty_state_panel.dart';
import '../widgets/focus_ring.dart';
import '../widgets/gig_card.dart';
import '../widgets/phone_width_layout.dart';

/// The driver's Booked list: everything currently assigned to this driver
/// (Story 3.3) — hydration plus the same shared realtime subscription Story
/// 3.2 established for Gigs (Task 1), filtered here to
/// `status == booked AND driver_id == me` — plus Story 3.4's Cancel/Mark
/// complete actions on each row.
class BookedScreen extends StatefulWidget {
  const BookedScreen({super.key});

  @override
  State<BookedScreen> createState() => _BookedScreenState();
}

class _BookedScreenState extends State<BookedScreen> {
  List<Gig> _gigs = [];
  bool _loading = true;
  late final String _driverId;

  // Story 3.4: per-gig transient state for the Cancel/Mark complete actions,
  // keyed by gig id — mirrors the `_bookingIds`/`_unavailableIds`/
  // `_removingIds` split Story 3.2 established for Gigs' own action state.
  final Set<String> _actionInFlightIds = {};
  final Map<String, String> _cancelBlockedMessages = {};
  final Set<String> _removingIds = {};

  @override
  void initState() {
    super.initState();
    _driverId = supabase.auth.currentUser!.id;
    _hydrate();
  }

  Future<void> _hydrate() async {
    var gigs = <Gig>[];
    try {
      gigs = await GigsService.instance.fetchBookedGigs(_driverId);
    } catch (_) {
      // Falls through to the zero-state rather than spinning forever — same
      // precedent Story 3.2 set for Gigs' own failed hydration.
    }
    if (!mounted) return;
    setState(() {
      _gigs = gigs;
      _loading = false;
    });
    GigsService.instance.subscribe(onChange: _handleChange);
  }

  /// This view's half of Task 1's client-side filter: `status == 'booked'
  /// AND driver_id == currentUserId`. A row that fails this predicate is
  /// removed rather than ignored — covers both a dispatcher cancelling this
  /// driver's booked gig (AC #4) and Story 3.4's "Mark complete" transitioning
  /// a row's status away from `booked`.
  void _handleChange(Map<String, dynamic> row) {
    final matchesBooked =
        row['status'] == 'booked' && row['driver_id'] == _driverId;
    if (matchesBooked) {
      _handleUpsert(Gig.fromRow(row));
    } else {
      _handleRemove(row['id'] as String);
    }
  }

  void _handleUpsert(Gig gig) {
    if (!mounted) return;
    setState(() {
      final index = _gigs.indexWhere((g) => g.id == gig.id);
      if (index == -1) {
        _gigs.insert(0, gig);
      } else {
        _gigs[index] = gig;
      }
    });
  }

  void _handleRemove(String id) {
    if (!mounted) return;
    setState(() {
      _gigs.removeWhere((g) => g.id == id);
      _removingIds.remove(id);
      _actionInFlightIds.remove(id);
      _cancelBlockedMessages.remove(id);
    });
  }

  /// Story 3.4 Task 2. Re-entrancy-guarded like Gigs' own `_bookGig`: a
  /// second tap while this gig's cancel/complete call is already in flight
  /// is ignored rather than firing a duplicate RPC round-trip.
  Future<void> _cancelGig(Gig gig) async {
    if (_actionInFlightIds.contains(gig.id)) return;
    setState(() => _actionInFlightIds.add(gig.id));

    try {
      await GigsService.instance.cancelBooking(gig.id);
    } catch (e) {
      if (!mounted) return;
      // AC #4: the server's authoritative re-check disagreed with this
      // row's own proactive cutoff read (a race between render and tap) —
      // display its exception message directly rather than a client-copy of
      // the same string (AD-3, see booked_gig_row.dart's Dev Notes).
      setState(() {
        _actionInFlightIds.remove(gig.id);
        _cancelBlockedMessages[gig.id] = _rpcErrorMessage(e);
      });
      return;
    }

    if (!mounted) return;
    // Success: optimistic removal (Task 2) — no need to wait for the
    // realtime echo, same precedent as Epic 2's dispatcher-web stories.
    setState(() {
      _actionInFlightIds.remove(gig.id);
      _removingIds.add(gig.id);
    });
  }

  /// Story 3.4 Task 3. No confirmation screen or interstitial on success
  /// (AC #6) — a failure just re-enables the row so the driver can retry;
  /// no AC specifies bespoke failure copy for this action.
  Future<void> _completeGig(Gig gig) async {
    if (_actionInFlightIds.contains(gig.id)) return;
    setState(() => _actionInFlightIds.add(gig.id));

    try {
      await GigsService.instance.completeRequest(gig.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionInFlightIds.remove(gig.id));
      return;
    }

    if (!mounted) return;
    setState(() {
      _actionInFlightIds.remove(gig.id);
      _removingIds.add(gig.id);
    });
  }

  String _rpcErrorMessage(Object error) {
    return error is PostgrestException ? error.message : error.toString();
  }

  @override
  void dispose() {
    GigsService.instance.unsubscribe(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: SafeArea(
        child: PhoneWidthLayout(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: tokens.spacing5),
                Text('Booked', style: tokens.display),
                SizedBox(height: tokens.spacing4),
                Expanded(child: _buildBody(tokens)),
                SizedBox(height: tokens.spacing5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(FloviTokens tokens) {
    if (_loading) {
      // Same skeleton treatment as Gigs during cold load (AC #2, UX-DR26).
      return ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, _) => SizedBox(height: tokens.spacing3),
        itemBuilder: (_, _) => const GigCardSkeleton(),
      );
    }

    if (_gigs.isEmpty) {
      return Center(
        child: EmptyStatePanel(
          message: "You haven't booked anything yet.",
          action: const _GoToGigsButton(),
        ),
      );
    }

    // Story 3.4 Task 4: collapses to instant/opacity-only under
    // prefers-reduced-motion — same handling already applied to Story 3.2's
    // interstitial entrance and race-lost card removal.
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return ListView.separated(
      itemCount: _gigs.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.spacing3),
      itemBuilder: (context, index) {
        final gig = _gigs[index];
        final removing = _removingIds.contains(gig.id);

        return AnimatedOpacity(
          key: ValueKey(gig.id),
          opacity: removing ? 0 : 1,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          onEnd: () {
            if (removing) _handleRemove(gig.id);
          },
          child: BookedGigRow(
            gig: gig,
            busy: _actionInFlightIds.contains(gig.id),
            cancelBlockedMessage: _cancelBlockedMessages[gig.id],
            onCancel: () => _cancelGig(gig),
            onMarkComplete: () => _completeGig(gig),
          ),
        );
      },
    );
  }
}

/// Empty-state's single ghost-button recovery action — same bordered,
/// no-fill treatment as the dispatcher app's secondary buttons (e.g.
/// "Clear filters"), never the filled accent style used for primary actions.
class _GoToGigsButton extends StatelessWidget {
  const _GoToGigsButton();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    return FocusRing(
      borderRadius: tokens.roundedFull,
      child: Semantics(
        button: true,
        label: 'Go to Gigs',
        child: GestureDetector(
          onTap: () => context.go('/gigs'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing5,
              vertical: tokens.spacing2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              border: Border.all(color: tokens.borderSubtle),
              borderRadius: BorderRadius.circular(tokens.roundedFull),
            ),
            child: Text(
              'Go to Gigs',
              style: tokens.body.copyWith(color: tokens.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
