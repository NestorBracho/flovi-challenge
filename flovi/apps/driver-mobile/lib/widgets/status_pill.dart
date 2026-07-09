import 'package:flutter/material.dart';

import '../theme/flovi_tokens.dart';

/// Dot + label + tint background — three redundant cues, never color-only
/// (DESIGN.md, UX-DR5). Same visual recipe as the dispatcher-web app's
/// `StatusPill.vue`, independently implemented here per AD-1: no shared code
/// between the two apps, just the same recipe against this app's own
/// `ThemeExtension` status tokens (Story 3.1).
///
/// Built generically for all 4 `relocation_requests` lifecycle states even
/// though Booked's own client-side filter (Story 3.3 Task 1) means it will
/// only ever actually render `booked` in practice — Story 3.4 continues to
/// rely on this same component.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  /// One of: unbooked, booked, completed, cancelled.
  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    final meta = _metaFor(tokens, status);

    return Semantics(
      label: meta.label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing3,
          vertical: tokens.spacing1,
        ),
        decoration: BoxDecoration(
          color: meta.tint,
          borderRadius: BorderRadius.circular(tokens.roundedFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: meta.dot, shape: BoxShape.circle),
            ),
            SizedBox(width: tokens.spacing2),
            Text(meta.label, style: tokens.meta.copyWith(color: meta.text)),
          ],
        ),
      ),
    );
  }
}

class _StatusMeta {
  const _StatusMeta({
    required this.label,
    required this.dot,
    required this.text,
    required this.tint,
  });

  final String label;
  final Color dot;
  final Color text;
  final Color tint;
}

_StatusMeta _metaFor(FloviTokens tokens, String status) {
  switch (status) {
    case 'unbooked':
      return _StatusMeta(
        label: 'Unbooked',
        dot: tokens.statusUnbooked,
        text: tokens.statusUnbookedText,
        tint: tokens.statusUnbookedTint,
      );
    case 'booked':
      return _StatusMeta(
        label: 'Booked',
        dot: tokens.statusBooked,
        text: tokens.statusBookedText,
        tint: tokens.statusBookedTint,
      );
    case 'completed':
      return _StatusMeta(
        label: 'Completed',
        dot: tokens.statusCompleted,
        text: tokens.statusCompletedText,
        tint: tokens.statusCompletedTint,
      );
    case 'cancelled':
      return _StatusMeta(
        label: 'Cancelled',
        dot: tokens.statusCancelled,
        text: tokens.statusCancelledText,
        tint: tokens.statusCancelledTint,
      );
    default:
      throw ArgumentError.value(status, 'status', 'Unknown request status');
  }
}
