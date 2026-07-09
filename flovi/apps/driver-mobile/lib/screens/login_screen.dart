import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/flovi_tokens.dart';
import '../widgets/focus_ring.dart';
import '../widgets/phone_width_layout.dart';

/// A failure to show on Login after bouncing back from `/auth/callback` —
/// either the OAuth-failure copy (AC #4, verbatim-fixed) or the role-mismatch
/// copy (Task 5's unnamed gap: a dispatcher-role account signing into this
/// app). Passed via GoRouter's `extra` rather than a URL query param.
class LoginFailure {
  const LoginFailure(this.message);

  final String message;
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.failure});

  final LoginFailure? failure;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing5),
            child: PhoneWidthLayout(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Flovi', style: tokens.display),
                  SizedBox(height: tokens.spacing3),
                  Text(
                    'Sign up here as a driver.',
                    style: tokens.body.copyWith(color: tokens.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spacing6),
                  if (failure != null) ...[
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
                          failure!.message,
                          style: tokens.body.copyWith(
                            color: tokens.statusCancelledText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacing5),
                  ],
                  FocusRing(
                    borderRadius: tokens.roundedFull,
                    child: Semantics(
                      button: true,
                      label: 'Sign in with Google',
                      child: GestureDetector(
                        onTap: () => AuthService.instance.signInWithGoogle(),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: 44,
                            minWidth: 44,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing6,
                            vertical: tokens.spacing3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            borderRadius: BorderRadius.circular(
                              tokens.roundedFull,
                            ),
                          ),
                          child: Text(
                            'Sign in with Google',
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
