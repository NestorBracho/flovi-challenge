import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/gigs_service.dart';
import '../theme/flovi_tokens.dart';
import '../widgets/focus_ring.dart';
import '../widgets/phone_width_layout.dart';
import '../widgets/raised_surface.dart';

/// Full-screen booking-confirmation interstitial (AC #5) — never a modal.
/// Reached only via a winning `book_request` call (Task 1); the single
/// primary button is the only way forward, through to the Booked tab.
class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key, required this.gig});

  final Gig gig;

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Entrance is one of EXPERIENCE.md's three named transient-motion cases
    // — collapses to instant under prefers-reduced-motion via the duration
    // passed to AnimatedOpacity below, not by skipping this fade trigger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final gig = widget.gig;

    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: PhoneWidthLayout(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: tokens.statusCompletedTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: tokens.statusCompleted,
                        size: 40,
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing5),
                  Text(
                    "You're booked.",
                    style: tokens.display,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spacing6),
                  RaisedSurface(
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
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.spacing2,
                              ),
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
                        SizedBox(height: tokens.spacing2),
                        Text(gig.formattedDate, style: tokens.meta),
                        if (gig.notes != null && gig.notes!.isNotEmpty) ...[
                          SizedBox(height: tokens.spacing2),
                          Text(
                            gig.notes!,
                            style: tokens.body.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.spacing6),
                  FocusRing(
                    borderRadius: tokens.roundedFull,
                    child: Semantics(
                      button: true,
                      label: 'View my booked gigs',
                      child: GestureDetector(
                        onTap: () => context.go('/booked'),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(
                            vertical: tokens.spacing3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            borderRadius: BorderRadius.circular(
                              tokens.roundedFull,
                            ),
                          ),
                          child: Text(
                            'View my booked gigs',
                            style: tokens.bodyStrong.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
