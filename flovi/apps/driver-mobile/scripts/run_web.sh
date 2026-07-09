#!/usr/bin/env bash
# Fixed dev port (5000) matches the /auth/callback URL already registered in
# Supabase's Redirect URLs allow-list per Story 1.6 — `flutter run -d chrome`
# otherwise assigns a random port per invocation, silently breaking OAuth.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter run -d chrome --web-port=5000 --dart-define-from-file=dart_defines.json "$@"
