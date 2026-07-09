import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/flovi_tokens.dart';
import 'login_screen.dart';

/// The dedicated `/auth/callback` route (AC #3) — never the SPA root, since
/// Flutter web's default hash-router collides with an implicit-flow OAuth
/// redirect. supabase_flutter detects the PKCE code in this page's own URL
/// automatically once `Supabase.initialize` has run; this screen just waits
/// for the resulting auth-state change and then calls `claim_role('driver')`.
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  StreamSubscription<AuthState>? _subscription;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Future<void> _handle() async {
    // OAuth-failure copy is verbatim-fixed (AC #4, EXPERIENCE.md State Patterns).
    final oauthError = Uri.base.queryParameters['error'];
    if (oauthError != null) {
      _returnToLogin(
        const LoginFailure("We couldn't sign you in — try again."),
      );
      return;
    }

    if (AuthService.instance.currentSession != null) {
      await _claimAndContinue();
      return;
    }

    _subscription = AuthService.instance.onAuthStateChange.listen((state) {
      if (_handled) return;
      if (state.event == AuthChangeEvent.signedIn && state.session != null) {
        _handled = true;
        unawaited(_subscription?.cancel());
        unawaited(_claimAndContinue());
      }
    });
  }

  Future<void> _claimAndContinue() async {
    try {
      // Called on every successful OAuth completion, not just a detected
      // "first-time" one — claim_role is idempotent for a same-role reclaim
      // (Story 1.1), so no first-time-detection logic is needed here.
      await AuthService.instance.claimRole('driver');
      if (!mounted) return;
      context.go('/gigs');
    } catch (_) {
      // The signed-in Google account already holds the `dispatcher` role —
      // claim_role throws by design (AD-2). Sign back out rather than
      // leaving the user in a half-authenticated state.
      await AuthService.instance.signOut();
      _returnToLogin(
        const LoginFailure(
          'This Google account is already registered as a dispatcher — '
          'sign in through the dispatcher app instead.',
        ),
      );
    }
  }

  void _returnToLogin(LoginFailure failure) {
    if (!mounted) return;
    context.go('/login', extra: failure);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: Center(child: CircularProgressIndicator(color: tokens.accent)),
    );
  }
}
