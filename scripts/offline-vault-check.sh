#!/usr/bin/env bash
# =============================================================================
# THE OFFLINE VAULT CHECK — ON A REAL DEVICE, WITH THE NETWORK REALLY GONE.
#
# Starts a stand-in backend on 127.0.0.1, runs the app against it on the
# desktop device, and lets the test itself kill that server mid-run. What is
# exercised is the real Dio client, the real Drift schema, a real vault.sqlite
# on a real disk and the real scoring — not a mock of any of them.
#
#   ./scripts/offline-vault-check.sh [device]
#
# `linux` by default. Pass an attached phone's id to run it on the phone,
# which is the environment the feature is actually for.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-linux}"
PORT="${LIP_TEST_PORT:-4599}"

# A Linux Flutter binary needs somewhere to draw. On a headless container that
# is Xvfb; without it the app never starts and the run reports a load failure
# that has nothing to do with the vault.
export DISPLAY="${DISPLAY:-:99}"
if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
  Xvfb "$DISPLAY" -screen 0 1280x1024x24 >/dev/null 2>&1 &
  sleep 2
fi

cleanup() { pkill -f fake_backend.js >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

# A stale vault from an earlier run would let phase 1 pass without downloading
# anything, which is the one way this check could lie.
rm -f "$HOME/.local/share/com.lockinpoint.lockinpoint/vault.sqlite" \
      "$HOME/Documents/vault.sqlite" 2>/dev/null || true

node tool/fake_backend.js "$PORT" &
sleep 1

flutter test integration_test/offline_vault_real_test.dart \
  -d "$DEVICE" \
  --dart-define=LIP_API="http://127.0.0.1:$PORT" \
  --reporter expanded
