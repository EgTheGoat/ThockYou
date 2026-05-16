#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ThockYou.app"

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT_DIR/Scripts/build_app.sh"
fi

killall ThockYou >/dev/null 2>&1 || true
killall Thockyou >/dev/null 2>&1 || true
sleep 0.5

open "$APP_DIR"
