import 'package:supabase_flutter/supabase_flutter.dart';

// Flutter web has no runtime .env equivalent (compiled/AOT output, not a
// Node server reading process env at request time) — both values are baked
// in at build time via `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
// (see .vscode/launch.json and scripts/run_web.sh for the fixed invocation).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> initSupabase() {
  return Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
