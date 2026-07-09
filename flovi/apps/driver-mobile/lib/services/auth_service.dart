import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Thin wrapper around supabase_flutter's auth API — the Dart-side analog of
/// the dispatcher-web app's `useAuth` composable (Story 2.1).
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => supabase.auth;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  Future<void> signInWithGoogle() {
    return _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _callbackUrl(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Calls the fixed cross-epic `claim_role(p_role)` contract pinned in
  /// Story 1.1 — exactly this parameter key, unconditionally on every
  /// successful sign-in (idempotent for a same-role reclaim; throws on a
  /// role mismatch, per AD-2).
  Future<void> claimRole(String role) {
    return supabase.rpc('claim_role', params: {'p_role': role});
  }

  /// The dedicated `/auth/callback` route on whatever origin this build is
  /// actually served from (local dev's fixed port 5000, or the Vercel
  /// production URL from Story 3.5) — never the SPA root.
  String _callbackUrl() {
    final origin = Uri.base;
    return Uri(
      scheme: origin.scheme,
      host: origin.host,
      port: origin.hasPort ? origin.port : null,
      path: '/auth/callback',
    ).toString();
  }
}
