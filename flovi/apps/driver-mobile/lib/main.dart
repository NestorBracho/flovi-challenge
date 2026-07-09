import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'services/supabase_client.dart';
import 'theme/flovi_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path-based URLs (not Flutter web's default hash routing) are required
  // for a real `/auth/callback` route to work with the OAuth redirect (AC #3).
  usePathUrlStrategy();
  await initSupabase();
  runApp(const FloviDriverApp());
}

class FloviDriverApp extends StatelessWidget {
  const FloviDriverApp({super.key});

  // Built once at the class level, not inside build() — GoRouter must be a
  // single, stable instance for the app's lifetime. Calling buildRouter()
  // from within build() would construct a brand-new GoRouter (and a brand-new
  // _GoRouterRefreshStream subscribing to onAuthStateChange all over again,
  // which immediately replays an extra AuthChangeEvent.initialSession to
  // that new listener) on every rebuild of this widget — go_router's own
  // docs call this out as the standard footgun.
  static final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flovi Driver',
      debugShowCheckedModeBanner: false,
      // Pinned explicitly — MaterialApp's default themeMode is
      // ThemeMode.system, which would resolve Flutter's own generic dark
      // Material theme (not DESIGN.md's palette) if the OS/browser is in
      // dark mode, since no darkTheme is supplied (AC #1, light mode only).
      themeMode: ThemeMode.light,
      theme: buildFloviTheme(),
      routerConfig: _router,
    );
  }
}
