#!/bin/bash
# Prototype pipeline setup. Runs from the prototype plugin; it is not installed into bin/.
#
# Usage:
#   setup.sh [--clone-firefox] [<project_root>]   full setup: says what it did and what needs you
#   setup.sh --preflight [<project_root>]          per-run check used by /prototype: refreshes the
#                                                  bin/ helpers and prints only problems
#
# <project_root> defaults to $HOME/FirefoxPrototype.
#
# Full setup checks, and creates where it can:
#   <project_root>/firefox          Firefox git checkout (cloned only with --clone-firefox; several GB)
#   ai remote, ai/main              github.com/Firefox-AI/firefox-prototypes, the default worktree base
#   <project_root>/worktrees, _prototype, bin   (bin/ gets the helper scripts from this plugin)
#   ~/.firefox-prototype-mozconfig  artifact-build mozconfig, from ../templates/
#   ~/.mozbuild                     Mozilla build toolchain (mach bootstrap): reported, not run
#   Marionette Python client        in-tree; tried with python3, then ./mach python
#   ~/.firefox-prototype-golden     golden profile: reported; you seed it with your own FxA sign-in
#   Figma MCP                       optional: reported
#
# It never copies an existing Firefox profile.

MODE=full
CLONE=0
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --preflight) MODE=preflight ;;
    --clone-firefox) CLONE=1 ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "setup.sh: unknown option $1" >&2; exit 2 ;;
    *) ROOT="$1" ;;
  esac
  shift
done
ROOT="${ROOT:-$HOME/FirefoxPrototype}"
ROOT="${ROOT%/}"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$(cd "$SCRIPTS_DIR/.." && pwd)/templates/firefox-prototype-mozconfig"
MOZCONFIG_PATH="$HOME/.firefox-prototype-mozconfig"
GOLDEN="$HOME/.firefox-prototype-golden"
FF="$ROOT/firefox"
BIN="$ROOT/bin"
HELPERS="new-prototype.sh launch-prototype.sh seed-golden.sh verify-golden.sh proto-status.sh"
MARKER="by the prototype plugin's setup.sh"
FIREFOX_URL="https://github.com/mozilla-firefox/firefox.git"
AI_URL="https://github.com/Firefox-AI/firefox-prototypes.git"

DONE=()      # what is fine or was just made
TODO=()      # what needs the user, in the order to do it
OPTIONAL=()
ok()   { DONE+=("ok    $*"); }
made() { DONE+=("made  $*"); }
todo() { TODO+=("$*"); }

have_ff() { [ -e "$FF/.git" ]; }

# --- tools -------------------------------------------------------------------
# After an Xcode update, git exits 69 until the license is accepted. The
# Command Line Tools git still works, so use it for this run and say so.
git --version >/dev/null 2>&1
if [ $? -eq 69 ] && [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  todo "Accept the Xcode license so git works outside this script: sudo xcodebuild -license accept"
fi
if ! git --version >/dev/null 2>&1; then
  todo "git doesn't run. Install the Xcode Command Line Tools: xcode-select --install"
fi
if ! command -v python3 >/dev/null 2>&1; then
  todo "python3 not found. The helper scripts need it (xcode-select --install provides one)."
fi

# --- project root and dirs ---------------------------------------------------
if [ ! -d "$ROOT" ]; then
  if [ "$MODE" = preflight ]; then
    echo "Project root $ROOT does not exist. Run: /prototype setup"
    exit 2
  fi
  mkdir -p "$ROOT" && made "$ROOT"
fi
for d in worktrees _prototype bin; do
  if [ ! -d "$ROOT/$d" ]; then
    mkdir -p "$ROOT/$d" && made "$ROOT/$d/"
  fi
done

# --- helper scripts ----------------------------------------------------------
# The plugin copy is the source of truth. A hand-made script already in bin/
# (no install marker) is kept once as <name>.pre-plugin-<timestamp>.
CHANGED=()
BACKUPS=()
for name in $HELPERS; do
  src="$SCRIPTS_DIR/$name"
  dst="$BIN/$name"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    continue
  fi
  if [ -f "$dst" ] && ! grep -q "$MARKER" "$dst"; then
    bak="$dst.pre-plugin-$(date +%Y%m%d%H%M%S)"
    cp -p "$dst" "$bak" && BACKUPS+=("$bak")
  fi
  cp "$src" "$dst" && chmod +x "$dst" && CHANGED+=("$name")
done
if [ ${#CHANGED[@]} -gt 0 ]; then
  made "$BIN/: ${CHANGED[*]}"
else
  ok "$BIN/ helper scripts (current)"
fi
for b in "${BACKUPS[@]}"; do
  DONE+=("kept  your previous script as $b")
done

# --- mozconfig ---------------------------------------------------------------
if [ ! -f "$MOZCONFIG_PATH" ]; then
  cp "$TEMPLATE" "$MOZCONFIG_PATH" && made "$MOZCONFIG_PATH (artifact builds)"
elif cmp -s "$TEMPLATE" "$MOZCONFIG_PATH"; then
  ok "$MOZCONFIG_PATH"
elif grep -q -- "--enable-artifact-builds" "$MOZCONFIG_PATH"; then
  ok "$MOZCONFIG_PATH (yours, kept; artifact builds on)"
else
  todo "$MOZCONFIG_PATH exists but doesn't enable artifact builds, so the first build would be a full compile (hours). Compare it with $TEMPLATE."
fi

# --- preflight stops here ----------------------------------------------------
if [ "$MODE" = preflight ]; then
  status=0
  [ ${#CHANGED[@]} -gt 0 ] && echo "Updated $BIN/: ${CHANGED[*]}"
  for b in "${BACKUPS[@]}"; do echo "Kept your previous script as $b"; done
  if ! have_ff; then
    echo "No Firefox git checkout at $FF. Run: /prototype setup"
    status=1
  fi
  if [ -L "$GOLDEN" ]; then
    echo "$GOLDEN is a symlink; it must be a fresh profile. Remove it and run $BIN/seed-golden.sh"
  elif [ ! -d "$GOLDEN" ]; then
    echo "No golden profile yet: build smoke and QA can't launch Firefox until you run $BIN/seed-golden.sh (after a first build)."
  fi
  for t in "${TODO[@]}"; do echo "$t"; done
  exit $status
fi

# --- Firefox checkout --------------------------------------------------------
if have_ff; then
  ok "Firefox checkout at $FF"
elif [ -e "$FF" ]; then
  todo "$FF exists but isn't a git checkout. The pipeline needs git (it creates git worktrees). Move it aside, then rerun /prototype setup."
elif [ "$CLONE" -eq 1 ]; then
  echo "Cloning Firefox into $FF (several GB; this takes a while)..."
  if git clone "$FIREFOX_URL" "$FF"; then
    made "Firefox checkout at $FF"
  else
    todo "Cloning Firefox failed. Retry: git clone $FIREFOX_URL \"$FF\""
  fi
else
  todo "Clone Firefox (several GB): git clone $FIREFOX_URL \"$FF\"   (or rerun setup with --clone-firefox)"
fi

# --- ai remote: default worktree base ----------------------------------------
if have_ff; then
  if ! git -C "$FF" remote get-url ai >/dev/null 2>&1; then
    git -C "$FF" remote add ai "$AI_URL" && made "git remote ai -> $AI_URL"
  fi
  if git -C "$FF" rev-parse --verify -q refs/remotes/ai/main >/dev/null; then
    ok "ai/main (default base for new worktrees)"
  else
    echo "Fetching ai/main from $(git -C "$FF" remote get-url ai)..."
    if git -C "$FF" fetch ai main; then
      made "ai/main fetched"
    else
      todo "Couldn't fetch ai/main from $(git -C "$FF" remote get-url ai). Retry: git -C \"$FF\" fetch ai main. Until then, give /prototype a base branch you have, such as origin/main."
    fi
  fi
fi

# --- build toolchain ---------------------------------------------------------
if [ -d "$HOME/.mozbuild" ]; then
  ok "Mozilla build toolchain (~/.mozbuild)"
else
  todo "Install the Mozilla build toolchain, in your own terminal (it asks questions): cd \"$FF\" && ./mach bootstrap --application-choice browser_artifact_mode"
fi

# --- Marionette client -------------------------------------------------------
if have_ff; then
  if FF="$FF" python3 -c 'import os, sys; sys.path.insert(0, os.environ["FF"] + "/testing/marionette/client"); from marionette_driver.marionette import Marionette' >/dev/null 2>&1; then
    ok "Marionette client (python3)"
  elif [ -x "$FF/mach" ] && (cd "$FF" && ./mach --no-interactive python -c "from marionette_driver.marionette import Marionette" </dev/null >/dev/null 2>&1); then
    ok "Marionette client (via ./mach python, which QA falls back to)"
  else
    todo "The Marionette client doesn't import yet (QA needs it). After bootstrap, check: cd \"$FF\" && ./mach python -c 'from marionette_driver.marionette import Marionette'"
  fi
fi

# --- first build and golden profile ------------------------------------------
NIGHTLY=""
for c in "$FF"/obj-*/dist/Nightly.app "$ROOT"/worktrees/*/obj-*/dist/Nightly.app; do
  if [ -d "$c" ]; then NIGHTLY="$c"; break; fi
done

if [ -L "$GOLDEN" ]; then
  todo "$GOLDEN is a symlink. It must be a fresh profile, never a link to an existing one. Remove the link, then run $BIN/seed-golden.sh"
elif [ -d "$GOLDEN" ]; then
  if verr=$("$BIN/verify-golden.sh" --quiet 2>&1); then
    ok "golden profile at $GOLDEN"
  else
    todo "Golden profile fails its check ($(printf '%s' "$verr" | head -1)). Re-seed: $BIN/seed-golden.sh --force"
  fi
else
  if [ -z "$NIGHTLY" ]; then
    todo "Build Firefox once (artifact build, about 12 min the first time): cd \"$FF\" && MOZCONFIG=$MOZCONFIG_PATH ./mach build"
  fi
  todo "Seed the golden profile: $BIN/seed-golden.sh. Firefox opens on a new, empty profile: sign in with your own Firefox Account, send 3 Smart Window messages, then Cmd-Q. Check with $BIN/verify-golden.sh"
fi

# --- Figma MCP (optional) ----------------------------------------------------
if grep -qis '"figma' "$HOME/.claude.json" "$HOME/.claude/settings.json" "$HOME/.claude/plugins/installed_plugins.json"; then
  ok "Figma MCP configured (optional)"
else
  OPTIONAL+=("Figma MCP not found. Without it, design works from text only and can't read your Figma links. To add it: claude plugin install figma@claude-plugins-official")
fi

# --- report ------------------------------------------------------------------
echo ""
echo "Prototype setup: $ROOT"
for l in "${DONE[@]}"; do echo "  $l"; done
if [ ${#TODO[@]} -gt 0 ]; then
  echo ""
  echo "Needs you, in order:"
  i=1
  for t in "${TODO[@]}"; do echo "  $i. $t"; i=$((i + 1)); done
fi
if [ ${#OPTIONAL[@]} -gt 0 ]; then
  echo ""
  echo "Optional:"
  for t in "${OPTIONAL[@]}"; do echo "  - $t"; done
fi
echo ""
if [ ${#TODO[@]} -eq 0 ]; then
  echo "Ready. Start with: /prototype <idea>"
  exit 0
fi
exit 1
