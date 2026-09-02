#!/usr/bin/env bash
# =============================================================================
# THE ACCEPTANCE DRIVE — the real app, tapped as a student.
#
# The last release was called ready on a clean analyzer, passing unit tests
# and a successful build; the founder then installed it and found menus that
# would not open and buttons that did nothing. None of that was visible to
# anything being run, because none of it TAPPED anything.
#
#   ./scripts/acceptance-drive.sh [device]
#
# `linux` by default. Pass an attached phone's id to drive it on the phone.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-linux}"
# Optional: a substring of one case's name, to drive just that journey while
# diagnosing it. Empty means all twelve.
ONLY="${2:-}"
PORT="${LIP_TEST_PORT:-4601}"

# A Linux Flutter binary needs somewhere to draw. On a headless container that
# is Xvfb; without it the app never starts and the drive reports a load
# failure that has nothing to do with the app.
if [ "$DEVICE" = linux ]; then
  export DISPLAY="${DISPLAY:-:99}"
  if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    Xvfb "$DISPLAY" -screen 0 1280x1024x24 >/dev/null 2>&1 &
    sleep 2
  fi
fi

cleanup() { pkill -f "fake_backend.js $PORT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

# A stale vault or a remembered session would let steps pass without doing
# the work — the one way this drive could lie.
rm -f "$HOME/.local/share/com.lockinpoint.lockinpoint/vault.sqlite" \
      "$HOME/.local/share/com.lockinpoint.lockinpoint/shared_preferences.json" 2>/dev/null || true

node tool/fake_backend.js "$PORT" &
sleep 1

flutter test integration_test/user_journey_test.dart \
  -d "$DEVICE" \
  --dart-define=LIP_API="http://127.0.0.1:$PORT" \
  ${ONLY:+--plain-name "$ONLY"} \
  --reporter expanded
