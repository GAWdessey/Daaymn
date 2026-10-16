#!/usr/bin/env bash
# Demo-data mode: builds the Flutter web demo (lib/demo/demo_main.dart) and serves it
# at http://localhost:8099. No Supabase/Firebase login, made-up AI-photo profiles.
# Usage: tool/run_demo.sh [port]
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${1:-8099}"
exec flutter run -d web-server -t lib/demo/demo_main.dart \
  --web-hostname 127.0.0.1 --web-port "$PORT" --release
