#!/bin/bash
# Installed into <project_root>/bin/ by the prototype plugin's setup.sh.
# Edit the plugin copy (prototype/skills/prototype/scripts/), not the installed one.
#
# Pre-clone integrity check for the golden profile.
#
# Returns 0 if golden looks healthy, non-zero otherwise.
# In quiet mode (--quiet) only prints on failure (used by launch-prototype.sh).
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN="$HOME/.firefox-prototype-golden"
QUIET=0
if [ "$1" = "--quiet" ]; then
  QUIET=1
fi

say() { if [ "$QUIET" -eq 0 ]; then echo "$@"; fi; }
fail() { echo "FAIL: $1" >&2; exit 1; }

if [ -L "$GOLDEN" ]; then
  fail "$GOLDEN is a symlink. Golden must be a fresh profile made by seed-golden.sh, never a link to an existing one."
fi

if [ ! -d "$GOLDEN" ]; then
  fail "$GOLDEN does not exist. Run $SCRIPT_DIR/seed-golden.sh"
fi

REQUIRED_FILES=(
  "user.js"
  "prefs.js"
  "signedInUser.json"
  "key4.db"
  "cert9.db"
  "logins.json"
  "cookies.sqlite"
)

MISSING=()
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$GOLDEN/$f" ]; then
    MISSING+=("$f")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "FAIL: Golden profile is missing required files:" >&2
  for f in "${MISSING[@]}"; do
    echo "  - $f" >&2
  done
  echo "" >&2
  echo "Likely cause: you didn't complete the seed checklist (sign in to FxA)." >&2
  echo "Re-run: $SCRIPT_DIR/seed-golden.sh --force" >&2
  exit 1
fi

if [ ! -d "$GOLDEN/storage" ]; then
  fail "Golden profile has no storage/ directory. MLPA models not downloaded. Re-run seed checklist."
fi

STORAGE_SIZE_MB=$(du -sm "$GOLDEN/storage" 2>/dev/null | awk '{print $1}')
if [ -z "$STORAGE_SIZE_MB" ] || [ "$STORAGE_SIZE_MB" -lt 100 ]; then
  echo "FAIL: storage/ is only ${STORAGE_SIZE_MB}MB — MLPA models likely not downloaded." >&2
  echo "Open Smart Window in golden and exercise ML features, then re-verify." >&2
  exit 1
fi

GOLDEN_LOCK="$GOLDEN/lock"
if [ -e "$GOLDEN_LOCK" ] || [ -L "$GOLDEN_LOCK" ]; then
  fail "Profile lock present — Firefox is still running with golden, or didn't quit cleanly. Cmd-Q golden's Firefox first."
fi

COOKIES="$GOLDEN/cookies.sqlite"
COOKIE_AGE_DAYS=$(( ( $(date +%s) - $(stat -f %m "$COOKIES") ) / 86400 ))

say ""
say "Golden profile OK"
say "  Path:    $GOLDEN"
say "  Storage: ${STORAGE_SIZE_MB} MB (MLPA model cache)"
say "  Cookies: ${COOKIE_AGE_DAYS} days old"
if [ "$COOKIE_AGE_DAYS" -gt 30 ]; then
  say "  WARNING: cookies >30 days old. FxA may have expired."
  say "           If clones start failing auth, run $SCRIPT_DIR/seed-golden.sh --force"
fi

exit 0
