import 'package:flutter/material.dart';

import '../services/gigs_service.dart';
import '../theme/flovi_tokens.dart';
import 'focus_ring.dart';
import 'raised_surface.dart';

enum GigCardStatus { normal, booking, unavailable }

/// The driver Gigs browse card: origin/destination/date/notes, one primary
/// action ("Book this gig"), no secondary actions on the card itself
/// (DESIGN.md, CAP-6/UX-DR15). [status] drives the action area: normal shows
/// the Book button, booking disables it mid-request, unavailable replaces it
/// with the race-lost "No longer available" text (AC #6).
class GigCard extends StatelessWidget {
  const GigCard({
    super.key,
    required this.gig,
    required this.status,
    required this.onBook,
  });

  final Gig gig;
  final GigCardStatus status;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

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
          SizedBox(height: tokens.spacing4),
          _ActionArea(status: status, onBook: onBook),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.status, required this.onBook});

  final GigCardStatus status;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    if (status == GigCardStatus.unavailable) {
      // Announced the moment it appears, not just visually shown — a
      // screen-reader user needs to learn the attempt failed without
      // watching the screen (AC #6).
      return Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Text(
            'No longer available',
            style: tokens.bodyStrong.copyWith(color: tokens.textSecondary),
          ),
        ),
      );
    }

    final busy = status == GigCardStatus.booking;

    return FocusRing(
      borderRadius: tokens.roundedFull,
      child: Semantics(
        button: true,
        label: 'Book this gig',
        child: GestureDetector(
          onTap: busy ? null : onBook,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: tokens.spacing3),
            decoration: BoxDecoration(
              color: busy
                  ? tokens.accent.withValues(alpha: 0.6)
                  : tokens.accent,
              borderRadius: BorderRadius.circular(tokens.roundedFull),
            ),
            child: busy
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Book this gig',
                    style: tokens.bodyStrong.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton row: the shape of a [GigCard], no content — shown only during
/// the initial load (AC #1).
class GigCardSkeleton extends StatelessWidget {
  const GigCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    return RaisedSurface(
      padding: EdgeInsets.all(tokens.spacing4),
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceTint,
            borderRadius: BorderRadius.circular(tokens.roundedSm),
          ),
        ),
      ),
    );
  }
}
