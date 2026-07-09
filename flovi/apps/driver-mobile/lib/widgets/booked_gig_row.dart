import 'package:flutter/material.dart';

import '../services/gigs_service.dart';
import '../theme/flovi_tokens.dart';
import 'focus_ring.dart';
import 'raised_surface.dart';
import 'status_pill.dart';

/// The driver Booked list row: origin/destination/date/notes plus a
/// [StatusPill] (AC #1) and Story 3.4's two ghost-button actions — Cancel
/// (gated by the 24h cutoff) and Mark complete (available any time the gig
/// is `booked`). Purely presentational: all RPC calls, busy tracking, and
/// row removal live in [BookedScreen] (same split [GigCard] established for
/// Gigs), so this widget only renders whatever state it's handed and fires
/// the two callbacks.
class BookedGigRow extends StatelessWidget {
  const BookedGigRow({
    super.key,
    required this.gig,
    required this.busy,
    required this.cancelBlockedMessage,
    required this.onCancel,
    required this.onMarkComplete,
  });

  final Gig gig;

  /// True while a cancel or mark-complete RPC is in flight for this row —
  /// mutes both actions to guard against a double-tap firing a second
  /// concurrent call for the same gig.
  final bool busy;

  /// Set only after a cancel attempt is rejected server-side (AC #4's race
  /// case — cutoff passed between render and tap). When present, this is
  /// `cancel_request_driver`'s own exception message, displayed verbatim
  /// instead of this row re-deriving the "too close to cancel" copy itself
  /// (AD-3) — see Dev Notes on the story for why that distinction matters.
  final String? cancelBlockedMessage;

  final VoidCallback onCancel;
  final VoidCallback onMarkComplete;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    // A server-side rejection always wins over the client's own proactive
    // check — the server already told us this gig can't be cancelled, so
    // there's no reason to re-derive that from the (now almost certainly
    // also-expired, but not necessarily worded identically) client cutoff.
    final cancellable = cancelBlockedMessage == null && gig.isCancellable;
    final blockedText =
        cancelBlockedMessage ?? 'Too close to the ride to cancel (within 24h).';

    return RaisedSurface(
      padding: EdgeInsets.all(tokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gig.origin,
                  style: tokens.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing2),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: tokens.accent,
                ),
              ),
              Expanded(
                child: Text(
                  gig.destination,
                  style: tokens.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing1),
          Text(gig.formattedDate, style: tokens.meta),
          if (gig.notes != null && gig.notes!.isNotEmpty) ...[
            SizedBox(height: tokens.spacing2),
            Text(
              gig.notes!,
              style: tokens.body.copyWith(color: tokens.textSecondary),
            ),
          ],
          SizedBox(height: tokens.spacing3),
          StatusPill(status: gig.status),
          SizedBox(height: tokens.spacing3),
          Row(
            children: [
              Expanded(
                child: _GhostActionButton(
                  label: 'Cancel',
                  enabled: cancellable && !busy,
                  onTap: onCancel,
                ),
              ),
              SizedBox(width: tokens.spacing3),
              Expanded(
                child: _GhostActionButton(
                  label: 'Mark complete',
                  enabled: !busy,
                  onTap: onMarkComplete,
                ),
              ),
            ],
          ),
          if (!cancellable) ...[
            SizedBox(height: tokens.spacing2),
            Text(
              blockedText,
              style: tokens.meta.copyWith(color: tokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bordered, no-fill treatment (AC #1, #5) — the same "ghost" recipe
/// [BookedScreen]'s own empty-state recovery button already established:
/// [FloviTokens.surfaceCard] fill, [FloviTokens.borderSubtle] border, never
/// the filled-accent style reserved for primary actions like "Book this
/// gig". Muted/non-interactive (AC #2) when [enabled] is false — no
/// [FocusRing]/[GestureDetector] in that state, since a disabled control has
/// nothing to focus or tap.
class _GhostActionButton extends StatelessWidget {
  const _GhostActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    final button = Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: tokens.spacing2),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        border: Border.all(
          color: enabled ? tokens.borderSubtle : tokens.borderHairline,
        ),
        borderRadius: BorderRadius.circular(tokens.roundedFull),
      ),
      child: Text(
        label,
        style: tokens.bodyStrong.copyWith(
          color: enabled ? tokens.textSecondary : tokens.textTertiary,
        ),
      ),
    );

    if (!enabled) {
      return Semantics(button: true, enabled: false, label: label, child: button);
    }

    return FocusRing(
      borderRadius: tokens.roundedFull,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(onTap: onTap, child: button),
      ),
    );
  }
}
