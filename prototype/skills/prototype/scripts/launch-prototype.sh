#!/bin/bash
# Installed into <project_root>/bin/ by the prototype plugin's setup.sh.
# Edit the plugin copy (prototype/skills/prototype/scripts/), not the installed one.
#
# Shared launch logic for Firefox Smart Window prototypes.
#
# Each worktree's run.command calls this with $WT_DIR (its own dir).
# Responsibilities:
#   - Verify golden profile exists (or print actionable error)
#   - Clone golden into $WT_DIR/profile-default on first run (APFS COW when possible)
#   - Sound a warning if cookies look stale (>30 days old)
#   - Pick a free Marionette port and write it to $WT_DIR/.marionette-port
#   - Optionally run $WT_DIR/pre-launch.sh (for prototypes with side processes)
#   - Launch Nightly.app from the worktree's obj dir
#
# Usage:  launch-prototype.sh <worktree-dir>
#
set -e

WT_DIR="$1"
if [ -z "$WT_DIR" ] || [ ! -d "$WT_DIR" ]; then
  echo "ERROR: launch-prototype.sh requires a worktree directory argument" >&2
  exit 1
fi
WT_DIR="$(cd "$WT_DIR" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GOLDEN="$HOME/.firefox-prototype-golden"
PROFILE="$WT_DIR/profile-default"
PORT_FILE="$WT_DIR/.marionette-port"
# Resolve the objdir by glob: @CONFIG_GUESS@ changes with the macOS version
# (obj-aarch64-apple-darwin25.3.0 vs 25.6.0), so do not hardcode it.
NIGHTLY=""
for candidate in "$WT_DIR"/obj-*/dist/Nightly.app/Contents/MacOS/firefox; do
  if [ -x "$candidate" ]; then
    NIGHTLY="$candidate"
    break
  fi
done
[ -n "$NIGHTLY" ] || NIGHTLY="$WT_DIR/obj-*/dist/Nightly.app/Contents/MacOS/firefox"

if [ ! -d "$GOLDEN" ]; then
  cat <<EOF >&2
ERROR: Golden profile not found at $GOLDEN

Run the seed script first:
  $SCRIPT_DIR/seed-golden.sh

EOF
  exit 1
fi

if ! "$SCRIPT_DIR/verify-golden.sh" --quiet; then
  echo "ERROR: Golden profile failed integrity check. Run verify-golden.sh for details." >&2
  exit 1
fi

if [ ! -d "$PROFILE" ]; then
  echo "First run for $(basename "$WT_DIR") — cloning golden profile..."
  if cp -cR "$GOLDEN" "$PROFILE" 2>/dev/null; then
    echo "  Cloned with APFS COW (shared blocks)."
  else
    echo "  APFS clone unavailable (different volume?) — falling back to plain copy..."
    cp -R "$GOLDEN" "$PROFILE"
  fi
fi

COOKIES="$PROFILE/cookies.sqlite"
if [ -f "$COOKIES" ]; then
  COOKIE_AGE_DAYS=$(( ( $(date +%s) - $(stat -f %m "$COOKIES") ) / 86400 ))
  if [ "$COOKIE_AGE_DAYS" -gt 30 ]; then
    echo ""
    echo "  ⚠  WARNING: cookies.sqlite is $COOKIE_AGE_DAYS days old."
    echo "     FxA tokens may be expired. If the LLM fails to load:"
    echo "     1) refresh golden ($HOME/.firefox-prototype-golden) by signing in there"
    echo "     2) delete $PROFILE and rerun this command"
    echo ""
  fi
fi

PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
echo "$PORT" > "$PORT_FILE"
echo "Marionette port: $PORT (written to .marionette-port)"

# Set the marionette.port pref in user.js so Firefox uses our chosen port
# instead of the default 2828. Drop any prior line first so the pref reflects
# this launch only.
#
# Also gate Marionette's RecommendedPreferences module by setting
# remote.prefs.recommended=false. With -marionette enabled, that module
# (remote/shared/RecommendedPreferences.sys.mjs) injects ~112 hermetic-test
# prefs every startup, including identity.fxaccounts.auth.uri="https://{server}/dummy/fxa".
# That kills FxA auth (NS_ERROR_UNKNOWN_HOST) which manifests as the
# Smart Window sign-in wall. The pref must be in user.js so it's read before
# applyPreferences() runs.
USER_JS="$PROFILE/user.js"
if [ -f "$USER_JS" ]; then
  grep -v -E 'marionette\.port|remote\.prefs\.recommended' "$USER_JS" > "$USER_JS.tmp"
else
  : > "$USER_JS.tmp"
fi
echo "user_pref(\"remote.prefs.recommended\", false);" >> "$USER_JS.tmp"
echo "user_pref(\"marionette.port\", $PORT);" >> "$USER_JS.tmp"
mv "$USER_JS.tmp" "$USER_JS"

# Strip any Marionette dummy-pref pollution from a prior run that didn't
# shut down cleanly. These get serialized to prefs.js as user_prefs and
# persist across launches, so without this scrub the gate above doesn't
# help — the values stay in prefs.js until something deletes them.
PREFS_JS="$PROFILE/prefs.js"
if [ -f "$PREFS_JS" ]; then
  sed -i '' -E '/\{server\}|%\(server\)s|remote-settings-dummy|"network\.connectivity-service\.enabled"|"network\.manage-offline-status"|"network\.sntp\.pools"|"remote\.prefs\.recommended\.applied"|"services\.settings\.server"/d' "$PREFS_JS"
fi

if [ -x "$WT_DIR/pre-launch.sh" ]; then
  echo "Running pre-launch.sh..."
  ( cd "$WT_DIR" && "$WT_DIR/pre-launch.sh" ) || {
    echo "ERROR: pre-launch.sh failed" >&2
    exit 1
  }
fi

if [ ! -x "$NIGHTLY" ]; then
  cat <<EOF >&2
ERROR: Nightly.app not found at $NIGHTLY

Build first:
  cd "$WT_DIR" && ./mach build

EOF
  exit 1
fi

echo "Launching Firefox..."
# Chrome-context Marionette (QA/engineer smoke checks) needs system access.
export MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1
exec "$NIGHTLY" \
  -foreground \
  -no-remote \
  -profile "$PROFILE" \
  -marionette \
  -remote-allow-system-access
