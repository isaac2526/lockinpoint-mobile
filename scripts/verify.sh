#!/usr/bin/env bash
# =============================================================================
# EVERY CHECK CI RUNS, IN CI'S EXACT WORDS.
#
# This exists because a push once failed on formatting alone: the local run had
# been `dart format lib test`, while CI runs `dart format .` over the WHOLE
# repository and fails if anything changed. The commands below are copied from
# .github/workflows/check.yml verbatim, so passing here is passing there.
#
#   ./scripts/verify.sh          check only, exactly as CI does
#   ./scripts/verify.sh --fix    format in place first, then check
#
# Run it before every push.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
step() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

step "flutter pub get"
flutter pub get || fail=1

if [ "${1:-}" = "--fix" ]; then
  step "dart format (writing)"
  dart format .
fi

step "Formatting  ·  dart format --output=none --set-exit-if-changed ."
if ! dart format --output=none --set-exit-if-changed .; then
  echo "FORMATTING FAILED. Run ./scripts/verify.sh --fix and commit the result."
  fail=1
fi

step "Analyse  ·  flutter analyze --fatal-infos"
flutter analyze --fatal-infos || fail=1

step "Test  ·  flutter test"
flutter test || fail=1

if [ "$fail" -ne 0 ]; then
  printf '\n\033[31mVERIFY FAILED. Do not push.\033[0m\n'
  exit 1
fi
printf '\n\033[32mVERIFY PASSED. Safe to push.\033[0m\n'
