#!/bin/bash
# Installed into <project_root>/bin/ by the prototype plugin's setup.sh.
# Edit the plugin copy (prototype/skills/prototype/scripts/), not the installed one.
#
# One-time setup of the golden Firefox profile.
#
# Creates an EMPTY ~/.firefox-prototype-golden, writes the canonical user.js
# prefs, launches a locally built Nightly with that profile, and prints a
# checklist for the manual steps (sign in to your own FxA account, exercise
# Smart Window features so MLPA models download).
#
# This script never copies an existing Firefox profile (yours or anyone
# else's). Profiles hold live FxA credentials; the golden profile must be
# created fresh and signed in by the person who will use it.
#
# Re-running this script is safe: it won't clobber an existing golden profile
# unless --force is passed.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GOLDEN="$HOME/.firefox-prototype-golden"
NOTES="$GOLDEN/SEED-NOTES.md"

usage() {
  cat <<EOF
Usage: seed-golden.sh [--force] [<built-checkout-or-worktree-dir>]

Creates ~/.firefox-prototype-golden, writes the canonical user.js prefs,
and launches Firefox to let you sign in to FxA + warm the MLPA model cache.

The Nightly used is the first one built under:
  $PROJECT_DIR/firefox/obj-*
  $PROJECT_DIR/worktrees/*/obj-*
unless you name a checkout or worktree directory.

Options:
  --force    Delete and recreate an existing golden profile
  -h, --help Show this message
EOF
}

FORCE=0
SRC_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
    *) SRC_DIR="$1" ;;
  esac
  shift
done

if [ -L "$GOLDEN" ]; then
  echo "ERROR: $GOLDEN is a symlink. The golden profile must be a fresh directory," >&2
  echo "not a link to an existing Firefox profile. Remove the link and re-run." >&2
  exit 1
fi

if [ -d "$GOLDEN" ] && [ "$FORCE" -eq 0 ]; then
  echo "Golden profile already exists at $GOLDEN"
  echo "  - To refresh, pass --force (this will delete and recreate it)"
  echo "  - To verify integrity, run: $SCRIPT_DIR/verify-golden.sh"
  exit 0
fi

# Find a built Nightly. The objdir name varies with arch and macOS version
# (obj-aarch64-apple-darwin25.3.0, obj-x86_64-apple-darwin24.6.0, ...).
NIGHTLY=""
if [ -n "$SRC_DIR" ]; then
  CANDIDATES=("$SRC_DIR"/obj-*/dist/Nightly.app/Contents/MacOS/firefox)
else
  CANDIDATES=("$PROJECT_DIR"/firefox/obj-*/dist/Nightly.app/Contents/MacOS/firefox
              "$PROJECT_DIR"/worktrees/*/obj-*/dist/Nightly.app/Contents/MacOS/firefox)
fi
for candidate in "${CANDIDATES[@]}"; do
  if [ -x "$candidate" ]; then
    NIGHTLY="$candidate"
    break
  fi
done

if [ -z "$NIGHTLY" ]; then
  cat <<EOF >&2
ERROR: no built Nightly.app found under ${SRC_DIR:-$PROJECT_DIR/firefox or $PROJECT_DIR/worktrees/*}

Build once first (artifact build, ~12 min the first time):
  cd ${SRC_DIR:-$PROJECT_DIR/firefox} && MOZCONFIG=\$HOME/.firefox-prototype-mozconfig ./mach build

EOF
  exit 1
fi

if [ "$FORCE" -eq 1 ] && [ -d "$GOLDEN" ]; then
  echo "Removing existing golden profile..."
  rm -rf "$GOLDEN"
fi

mkdir -p "$GOLDEN"

# Canonical pref set for Smart Window prototypes.
cat > "$GOLDEN/user.js" <<'EOF'
// Smart Window prototype prefs — canonical seed.
// Keep in sync with prototype-build SKILL.md.

user_pref("browser.ml.enable", true);
user_pref("browser.smartwindow.enabled", true);
user_pref("browser.smartwindow.firstrun.hasCompleted", true);
user_pref("browser.smartwindow.firstrun.modelChoice", "1");
user_pref("browser.smartwindow.tos.consentTime", 1775283133);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
EOF

cat > "$NOTES" <<EOF
# Golden Profile — Seed Notes

This profile is the seed for all Firefox Smart Window prototype testing.
Each worktree clones it on first launch; the clone inherits FxA login,
MLPA model cache, and the canonical pref set.

It belongs to whoever signed in to it. Never copy it to another person
or commit any profile directory: it holds live FxA credentials.

## What's seeded

- \`user.js\`              Smart Window prefs (browser.ml.enable, smartwindow.*)
- FxA sign-in            Stored across signedInUser.json, logins.json,
                         key4.db, cert9.db, cookies.sqlite
- MLPA model cache       Inside \`storage/\` (IndexedDB + OPFS)

## Refresh procedure

When FxA tokens expire (~weeks to months) or models update:

1. Delete clones (or accept they will lazily re-download):
     find "$PROJECT_DIR/worktrees" -maxdepth 2 \\
       -name profile-default -exec rm -rf {} +
2. Re-seed golden:
     "$SCRIPT_DIR/seed-golden.sh" --force
3. Walk through the manual checklist again.
4. Next launch of any worktree's run.command will re-clone fresh.

## Known limitations

- Each cloned profile is independent after creation — no live sync.
- COW dedup applies to model blob files (write-once); SQLite databases
  (cookies, places) drift quickly and stop sharing blocks.
- \`cp -c\` only works within a single APFS volume. Cross-volume falls
  back to a regular copy (still correct, no dedup).

## Verification

Run:  "$SCRIPT_DIR/verify-golden.sh"
EOF

echo ""
echo "================================================================"
echo "Golden profile created at: $GOLDEN"
echo "Using Nightly: $NIGHTLY"
echo "================================================================"
echo ""
echo "Launching Firefox now with the golden profile."
echo "Complete this checklist before quitting Firefox:"
echo ""
echo "  [ ] 1. Sign in to your own FxA account."
echo ""
echo "  [ ] 2. Open Smart Window. Send 3 chat messages. Wait for the"
echo "         LLM to respond (this triggers MLPA model download)."
echo ""
echo "  [ ] 3. If your prototypes use other ML features (translations,"
echo "         smart tab grouping, etc.), exercise each once now."
echo ""
echo "  [ ] 4. Quit Firefox cleanly (Cmd-Q, NOT force quit)."
echo ""
echo "Then run:  $SCRIPT_DIR/verify-golden.sh"
echo ""
echo "If the verifier complains, repeat the checklist or run"
echo "  $SCRIPT_DIR/seed-golden.sh --force  to start over."
echo ""

exec "$NIGHTLY" -foreground -no-remote -profile "$GOLDEN"
