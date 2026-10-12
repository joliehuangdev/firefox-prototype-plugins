# Launcher, Profile, and Marionette — Shared Reference

Used by: `prototype-build`, `prototype-qa`.

The single source of truth for how prototype Firefox instances are launched, what's in their profiles, and how Marionette connects.

---

## Launch entry point

Always launch via the worktree's `run.command`, which is a thin wrapper around the shared launcher:

```bash
#!/bin/bash
exec /Users/joliehuang/FirefoxPrototype/bin/launch-prototype.sh "$(dirname "$0")"
```

`bin/launch-prototype.sh` handles: golden-profile clone, free Marionette port assignment, integrity check, pre-launch hook.

**`./mach run` is forbidden.** It creates a fresh temp profile every launch — losing prefs, FxA auth, and the MLPA model cache.

## Golden profile

Lives at `~/.firefox-prototype-golden/`, seeded once via `seed-golden.sh`. The launcher clones it (APFS COW when same volume) into `<worktree>/profile-default/` on first run, so each prototype starts pre-authed and pre-warmed.

### Required prefs in golden's `user.js`

```js
user_pref("browser.ml.enable", true);                          // CRITICAL: defaults to false; LLM engine won't build without it
user_pref("browser.smartwindow.enabled", true);
user_pref("browser.smartwindow.firstrun.hasCompleted", true);
user_pref("browser.smartwindow.firstrun.modelChoice", "1");
user_pref("browser.smartwindow.tos.consentTime", 1775283133);  // any past timestamp
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("remote.prefs.recommended", false);                  // CRITICAL with -marionette: see "Sign-in loop" below
```

### Other golden contents

- **FxA auth bundle** — `signedInUser.json`, `logins.json`, `key4.db`, `cert9.db`, `cookies.sqlite` (all together; alone they don't authenticate).
- **MLPA model cache** in `storage/` — populated by exercising Smart Window features once during seed.

If golden is missing or stale, the launcher prints an actionable error pointing at `seed-golden.sh`. Without `browser.ml.enable=true`, the engine build silently fails.

### Do NOT write per-worktree `user.js`

Golden is the single source of truth for prefs. `launch-prototype.sh` clones; never patch the per-worktree profile by hand.

## Marionette port

The launcher picks a free port and writes it to `<worktree>/.marionette-port`. Read that file — never hardcode 2828.

```bash
WT="<worktree-path>"
PORT=$(cat "$WT/.marionette-port")
```

Demos (frozen builds, no `run.command`) use port 2828 by historical convention.

## Sign-in loop / `NS_ERROR_UNKNOWN_HOST` on FxA

**Symptom:** repeated `error POSTing /oauth/token: NS_ERROR_UNKNOWN_HOST`, MLEngine 401s, auth wall in the chat. Looks like an FxA / OAuth / network problem.

**Cause:** `launch-prototype.sh` passes `-marionette`, which activates `remote/shared/RecommendedPreferences.sys.mjs`. That module injects ~112 hermetic-test prefs at startup, including:

```
identity.fxaccounts.auth.uri = "https://{server}/dummy/fxa"
services.settings.server     = "data:,#remote-settings-dummy/v1"
network.connectivity-service.enabled = false
network.manage-offline-status        = false
toolkit.telemetry.server, network.sntp.pools, extensions.update.url, ...
```

Literal `{server}` is unresolvable; everything FxA-touching fails. Marionette serializes these to `prefs.js` on shutdown, so the values persist across launches.

**The gate:** `user_pref("remote.prefs.recommended", false);` in `user.js` — read before `applyPreferences()` runs, short-circuits the injection. `launch-prototype.sh` re-asserts it on every launch and scrubs prior pollution from `prefs.js`. Both halves matter.

**If you hit this:** classify as `infra`, do NOT redo OAuth or re-seed. Self-fix:

1. Confirm `<worktree>/profile-default/user.js` contains `user_pref("remote.prefs.recommended", false);` (launcher should have written it; if missing, the launcher is broken — flag).
2. `grep -E '\{server\}|%\(server\)s|remote-settings-dummy' <worktree>/profile-default/prefs.js` should be empty.
3. If polluted: quit Firefox, then strip:
   ```bash
   sed -i '' -E '/\{server\}|%\(server\)s|remote-settings-dummy|"network\.connectivity-service\.enabled"|"network\.manage-offline-status"|"network\.sntp\.pools"|"remote\.prefs\.recommended\.applied"|"services\.settings\.server"/d' prefs.js
   ```
4. Relaunch via `run.command` and re-test.

## Building from a worktree

Each worktree has its own `obj-*` and builds independently. With `MOZCONFIG=$HOME/.firefox-prototype-mozconfig` (artifact builds), obj stays ~1.5 GB.

| Change shape | Build command |
|---|---|
| JS / CSS only | `./mach build faster` |
| New `moz.build` entries (added files, new component dirs) | `./mach build` (full, once after the registration) |
| C++ / Rust | `./mach build` (full) |

**Rule of thumb (engineer auto-detects):** if the diff touches any `moz.build`, `jar.mn`, or adds a new file under `ui/components/`, run full `./mach build` instead of `faster`. Otherwise `faster` is fine.

## Killing Firefox safely

**NEVER use** `pkill firefox`, `killall firefox`, `pkill -f Firefox`, `pkill -f Nightly`, or any pattern-based kill — that can take down the user's regular Firefox Release/Nightly.

Only kill via:
- The stored `$FIREFOX_PID` from your launch
- `lsof -i :$(cat <worktree>/.marionette-port) -t | xargs kill` to free a stuck port

## Demo apps (frozen)

Pre-compiled `Nightly.app` in `demos/<name>/`. Cannot be patched in place. If a fix is needed, switch to source mode (worktree) or rebuild the demo via `push-to-demo` after fixing in source.
