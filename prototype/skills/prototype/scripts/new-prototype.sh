#!/bin/bash
# Installed into <project_root>/bin/ by the prototype plugin's setup.sh.
# Edit the plugin copy (prototype/skills/prototype/scripts/), not the installed one.
#
# Create a new Firefox Smart Window prototype worktree.
#
# Usage: new-prototype.sh <prototype-name> [base-ref]
# Example: new-prototype.sh assistant-tab-grouper            # branches from ai/main
#          new-prototype.sh my-feature-v2 my-feature        # branches from an existing branch
#
# What this does:
#   1. Creates a new branch from <base-ref> (default ai/main)
#   2. Sets up a worktree in <project_root>/worktrees/<prototype-name>/
#   3. Drops a run.command that delegates to launch-prototype.sh
#      (which handles golden-profile cloning, free Marionette port, etc.)
#
# <project_root> is the parent of the bin/ directory this script lives in.
#
# Prereqs:
#   - Artifact-build mozconfig at ~/.firefox-prototype-mozconfig
#   - Golden profile seeded once via seed-golden.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAIN_REPO="$PROJECT_DIR/firefox"
WORKTREE_DIR="$PROJECT_DIR/worktrees"

if [ -z "$1" ]; then
  echo "Usage: new-prototype.sh <prototype-name> [base-ref]"
  echo "Example: new-prototype.sh assistant-tab-grouper"
  exit 1
fi

NAME="$1"
BASE="${2:-ai/main}"
WORKTREE_PATH="$WORKTREE_DIR/$NAME"

if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: $WORKTREE_PATH already exists"
  exit 1
fi

if [ ! -d "$MAIN_REPO/.git" ]; then
  echo "Error: no Firefox git checkout at $MAIN_REPO. Run /prototype setup." >&2
  exit 1
fi

if [ -z "$MOZCONFIG" ]; then
  echo "WARNING: \$MOZCONFIG is not set."
  echo "  For artifact builds (recommended), add to your shell rc:"
  echo "    export MOZCONFIG=\$HOME/.firefox-prototype-mozconfig"
  echo ""
fi

if [ ! -d "$HOME/.firefox-prototype-golden" ]; then
  echo "WARNING: golden profile not seeded yet."
  echo "  Run $SCRIPT_DIR/seed-golden.sh once before launching the new prototype."
  echo ""
fi

echo "Creating prototype: $NAME"
echo "  Branch: $NAME (from $BASE)"
echo "  Path:   $WORKTREE_PATH"
echo ""

if ! git -C "$MAIN_REPO" rev-parse --verify -q "$BASE" >/dev/null; then
  echo "Error: base ref '$BASE' not found in $MAIN_REPO" >&2
  exit 1
fi
mkdir -p "$WORKTREE_DIR"
git -C "$MAIN_REPO" worktree add -b "$NAME" "$WORKTREE_PATH" "$BASE"

cat > "$WORKTREE_PATH/run.command" <<SCRIPT
#!/bin/bash
# Thin wrapper. All launch logic lives in launch-prototype.sh
# so updates only need to be made once.
exec "$SCRIPT_DIR/launch-prototype.sh" "\$(dirname "\$0")"
SCRIPT
chmod +x "$WORKTREE_PATH/run.command"

echo ""
echo "Done. Next steps:"
echo "  cd $WORKTREE_PATH"
echo "  MOZCONFIG=\$HOME/.firefox-prototype-mozconfig ./mach build   # artifact build, ~12 min the first time"
echo "  open run.command     # double-click to launch (or ./run.command)"
echo ""
echo "First launch will clone the golden profile into profile-default/."
echo "Marionette port will be auto-assigned and written to .marionette-port."
