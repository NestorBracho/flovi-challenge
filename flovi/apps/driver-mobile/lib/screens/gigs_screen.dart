import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/gigs_service.dart';
import '../theme/flovi_tokens.dart';
import '../widgets/gig_card.dart';
import '../widgets/phone_width_layout.dart';

/// The driver's Gigs browse list: hydration + realtime sync + the two-step
/// booking sequence (Story 3.2).
class GigsScreen extends StatefulWidget {
  const GigsScreen({super.key});

  @override
  State<GigsScreen> createState() => _GigsScreenState();
}

class _GigsScreenState extends State<GigsScreen> {
  List<Gig> _gigs = [];
  bool _loading = true;
  String? _errorMessage;
  final Set<String> _bookingIds = {};
  final Set<String> _unavailableIds = {};
  final Set<String> _removingIds = {};
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    var gigs = <Gig>[];
    try {
      gigs = await GigsService.instance.fetchUnbookedGigs();
    } catch (_) {
      // Falls through to the zero-state rather than spinning forever —
      // mirrors the dispatcher-web app's precedent (Story 2.2) of resolving
      // a failed initial hydration to an empty list instead of a distinct
      // error state.
    }
    if (!mounted) return;
    setState(() {
      _gigs = gigs;
      _loading = false;
    });
    _channel = GigsService.instance.subscribe(
      onUpsert: _handleUpsert,
      onRemove: _handleRemove,
    );
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
      _unavailableIds.remove(id);
      _bookingIds.remove(id);
      _removingIds.remove(id);
    });
  }

  @override
  void dispose() {
    if (_channel != null) GigsService.instance.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _bookGig(Gig gig) async {
    // Re-entrancy guard: a booking attempt for this gig is already in
    // flight (or already won and mid-navigation-away) — ignore a duplicate
    // dispatch rather than firing a second bid/RPC round-trip.
    if (_bookingIds.contains(gig.id)) return;

    setState(() {
      _errorMessage = null;
      _bookingIds.add(gig.id);
    });

    bool won;
    try {
      won = await GigsService.instance.bookGig(gig.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bookingIds.remove(gig.id);
        _errorMessage = "We couldn't reach the server — try again.";
      });
      return;
    }

    if (!mounted) return;

    if (won) {
      // Deliberately NOT clearing _bookingIds here — the card stays
      // disabled while we navigate away rather than briefly flipping back
      // to a tappable state, which otherwise leaves a narrow window where a
      // stray replayed tap could re-dispatch a second booking attempt for
      // the same gig before the confirmation screen takes over.
      //
      // Navigates outside/on top of the tab-bar shell (a top-level route,
      // not nested inside the Gigs branch) — see app_router.dart. Task 1:
      // branch directly on `book_request`'s own return value, never on a
      // subsequent realtime event.
      //
      // go(), not push(): a push here layers on top of the StatefulShellRoute
      // while leaving GoRouter's own notion of "current location" pointed at
      // the /gigs branch underneath — a subsequent redirect re-evaluation
      // (e.g. from a background token refresh on the auth stream) then
      // recomputes the route match list from that branch location and
      // silently drops the pushed confirmation page. go() makes
      // /booking-confirmation unambiguously the current location instead.
      context.go('/booking-confirmation', extra: gig);
      return;
    }

    // won === false (AC #6): in-place "No longer available" for ~2s, then
    // remove the card — no confirmation screen, no false commitment.
    setState(() {
      _bookingIds.remove(gig.id);
      _unavailableIds.add(gig.id);
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _removingIds.add(gig.id));
    });
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
                Text('Gigs', style: tokens.display),
                SizedBox(height: tokens.spacing4),
                if (_errorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(tokens.spacing3),
                      decoration: BoxDecoration(
                        color: tokens.statusCancelledTint,
                        borderRadius: BorderRadius.circular(tokens.roundedSm),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: tokens.body.copyWith(
                          color: tokens.statusCancelledText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing4),
                ],
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
      return ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, _) => SizedBox(height: tokens.spacing3),
        itemBuilder: (_, _) => const GigCardSkeleton(),
      );
    }

    if (_gigs.isEmpty) {
      return Center(
        child: Text(
          'No gigs available right now — check back soon.',
          style: tokens.body.copyWith(color: tokens.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return ListView.separated(
      itemCount: _gigs.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.spacing3),
      itemBuilder: (context, index) {
        final gig = _gigs[index];
        final status = _unavailableIds.contains(gig.id)
            ? GigCardStatus.unavailable
            : _bookingIds.contains(gig.id)
            ? GigCardStatus.booking
            : GigCardStatus.normal;
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
          child: GigCard(gig: gig, status: status, onBook: () => _bookGig(gig)),
        );
      },
    );
  }
}
