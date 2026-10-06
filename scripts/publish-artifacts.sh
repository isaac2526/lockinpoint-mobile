#!/usr/bin/env bash
# =============================================================================
# PUT THE APP FILES SOMEWHERE STUDENTS CAN REACH THEM.
#
#   ./scripts/publish-artifacts.sh <version> <file> [<file> ...]
#
# Uploads each file to the public `app` bucket in Supabase Storage, prints the
# permanent URL for each, and — if --register is passed — writes those URLs
# straight into app_downloads so the website updates with no further step.
#
# WHY THIS EXISTS. Both GitHub repositories are private, so a Release asset is
# a 404 for anyone not signed in. A public Storage object is a real download
# link: permanent, loginless, and free of any expiry.
#
# WHAT IT NEEDS.
#   SUPABASE_URL                 https://<project>.supabase.co
#   SUPABASE_SERVICE_ROLE_KEY    Settings → API → service_role
#
# THAT KEY BYPASSES ROW-LEVEL SECURITY ON EVERYTHING. It is the only
# credential Supabase offers that can write to Storage, so there is no smaller
# one to use — but it means: put it in GitHub Secrets, never in a file, never
# in a commit, and never echo it. Nothing below prints it, and the one place
# it could leak (curl's error output) is silenced deliberately.
#
# PLATFORM IS INFERRED FROM THE EXTENSION, because a human typing the platform
# for six files is a human who will eventually type the wrong one:
#   .apk → apk    .aab → (skipped: Play ingests it, nobody downloads it)
#   .exe/.zip → windows   .dmg → macos   .AppImage/.tar.gz/.deb → linux
#   .ipa → ios
# =============================================================================
set -euo pipefail

REGISTER=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --register) REGISTER=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]:-}"

VERSION="${1:-}"; shift || true
if [ -z "$VERSION" ] || [ $# -eq 0 ]; then
  echo "usage: $0 [--register] <version> <file> [<file> ...]" >&2
  exit 2
fi

: "${SUPABASE_URL:?SUPABASE_URL is not set}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is not set}"
BASE="${SUPABASE_URL%/}"

platform_for() {
  case "$1" in
    *.apk)                 echo apk ;;
    *.ipa)                 echo ios ;;
    *.exe|*windows*.zip)   echo windows ;;
    *.dmg)                 echo macos ;;
    *.AppImage|*.deb|*linux*.tar.gz) echo linux ;;
    *.aab)                 echo "" ;;   # Play ingests this; it is not a download
    *)                     echo "" ;;
  esac
}

declare -A URLS=()
FAILED=0

for f in "$@"; do
  [ -f "$f" ] || { echo "skip (not a file): $f"; continue; }
  name="$(basename "$f")"
  plat="$(platform_for "$name")"

  # The object key carries the version, so an old build is never overwritten by
  # a new one — a student halfway through downloading v1.0.0 keeps getting
  # v1.0.0, and the previous release stays reachable if a new one is bad.
  key="releases/$VERSION/$name"
  ctype="application/octet-stream"

  # The HTTP code decides success — a 4xx from Storage still returns a body,
  # so "the request completed" is not the same as "the file is there". stderr
  # is dropped because curl can echo the request line, key and all.
  code=$(curl -sS -o /dev/null -w "%{http_code}" -X POST \
    "$BASE/storage/v1/object/$key" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: $ctype" \
    -H "x-upsert: true" \
    --data-binary "@$f" 2>/dev/null) || code=000

  url="$BASE/storage/v1/object/public/$key"
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    echo "uploaded  $name  ->  $url"
    [ -n "$plat" ] && URLS["$plat"]="$url"
  else
    echo "FAILED    $name  (HTTP $code)" >&2
    FAILED=1
  fi
done

[ "$FAILED" = 1 ] && { echo "at least one upload failed; nothing was registered" >&2; exit 1; }

if [ "$REGISTER" = 1 ]; then
  echo
  echo "registering in app_downloads…"
  for plat in "${!URLS[@]}"; do
    # No updated_at here: 'now()' is a string to PostgREST and Postgres cannot
    # cast it to a timestamp. The column has its own default.
    body=$(printf '{"url":%s,"available":true,"version":%s}' \
             "\"${URLS[$plat]}\"" "\"$VERSION\"")
    code=$(curl -sS -o /dev/null -w "%{http_code}" -X PATCH \
      "$BASE/rest/v1/app_downloads?platform=eq.$plat" \
      -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=minimal" \
      -d "$body" 2>/dev/null) || code=000
    if [ "$code" = "204" ] || [ "$code" = "200" ]; then
      echo "  $plat is now live on the website"
    else
      echo "  $plat could NOT be registered (HTTP $code) — paste the URL in Admin instead" >&2
    fi
  done
fi

echo
echo "Paste any of these into Admin → App distribution if you did not use --register:"
for plat in "${!URLS[@]}"; do echo "  $plat  ${URLS[$plat]}"; done
