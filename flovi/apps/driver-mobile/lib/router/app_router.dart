import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_callback_screen.dart';
import '../screens/booked_screen.dart';
import '../screens/booking_confirmation_screen.dart';
import '../screens/gigs_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/gigs_service.dart';
import '../widgets/app_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _GoRouterRefreshStream(
      AuthService.instance.onAuthStateChange,
    ),
    redirect: (context, state) {
      final signedIn = AuthService.instance.currentSession != null;
      final goingToLogin = state.matchedLocation == '/login';
      final goingToCallback = state.matchedLocation == '/auth/callback';

      if (!signedIn && !goingToLogin && !goingToCallback) return '/login';
      if (signedIn && goingToLogin) return '/gigs';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          failure: state.extra is LoginFailure
              ? state.extra as LoginFailure
              : null,
        ),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
      // Pushed outside/on top of the tab-bar shell (Story 3.2 Task 3) —
      // DESIGN.md is explicit driver-mobile never uses a centered modal,
      // full-screen interstitials only, and the tab bar must be hidden while
      // this shows (UX-DR18). A top-level route, not nested inside the Gigs
      // branch below, achieves both for free: it isn't wrapped in AppShell.
      GoRoute(
        path: '/booking-confirmation',
        builder: (context, state) =>
            BookingConfirmationScreen(gig: state.extra as Gig),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gigs',
                builder: (context, state) => const GigsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/booked',
                builder: (context, state) => const BookedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Turns Supabase's auth-state stream into a [Listenable] so GoRouter
/// re-evaluates its `redirect` whenever sign-in/sign-out happens.
///
/// Only notifies on an actual signed-in/signed-out *transition* — not on
/// every event the stream emits (tokenRefreshed fires periodically in the
/// background for as long as the app is open, and initialSession/signedIn
/// can repeat too). `redirect` only ever branches on whether the user is
/// signed in, so refiring it when that boolean hasn't changed is wasted —
/// and, worse, GoRouter recomputes its route match list from scratch on
/// every refresh, which was observed to silently drop a route just pushed
/// via `context.push` (e.g. the booking-confirmation interstitial, Story
/// 3.2) back to whatever the StatefulShellRoute branch's last location was.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<AuthState> stream) {
    _lastSignedIn = AuthService.instance.currentSession != null;
    notifyListeners();
    _subscription = stream.listen((event) {
      final signedIn = event.session != null;
      if (signedIn == _lastSignedIn) return;
      _lastSignedIn = signedIn;
      notifyListeners();
    });
  }

  late bool _lastSignedIn;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
