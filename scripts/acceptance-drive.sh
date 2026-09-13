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

# A HARD CEILING, BECAUSE A FAILURE HERE USED TO COST TWENTY-TWO MINUTES.
#
# The first time this drive ever ran, case 2 failed and the process then sat
# there until the job's own 25 minute timeout killed it — the app under test
# keeps live timers and streams, so `flutter test -d linux` never got its exit.
# The whole job was reported as "cancelled", which reads like an infrastructure
# blip rather than a failing test, and the failure that caused it was twenty
# minutes up the log.
#
# 900s is generous for a walk that takes about ninety seconds when it passes.
# Exit 124 is timeout's own code and says so plainly.
set +e
timeout --signal=TERM --kill-after=30s 900 \
  flutter test integration_test/user_journey_test.dart \
    -d "$DEVICE" \
    --dart-define=LIP_API="http://127.0.0.1:$PORT" \
    ${ONLY:+--plain-name "$ONLY"} \
    --reporter expanded
rc=$?
set -e
if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
  echo "the drive did not finish within 900s — it hung rather than failed." >&2
fi
exit "$rc"
