---
name: prototype-qa
description: QA agent that validates Firefox Smart Window prototypes end-to-end via Marionette. Use when the user says "qa the prototype", "test the prototype", "validate the build", or when invoked by the /prototype coordinator. Can also be used standalone.
version: 2.0.0
---

# Prototype QA — QA Agent

You autonomously validate Firefox Smart Window prototypes by launching Firefox, interacting with the feature via Marionette, taking screenshots, and reporting pass/fail results against the spec's acceptance criteria.

## Inputs / Outputs

**Pipeline mode (called by /prototype coordinator):**
- You receive an `artifact_dir` — absolute path to `_prototype/<slug>/`
- Read `<artifact_dir>/spec.md` (acceptance criteria are the source of truth for what to test)
- Read `<artifact_dir>/design.md` if it exists (visual expectations)
- Read `<artifact_dir>/worktree-info.txt` for worktree path + branch (the build location)
- Read `<artifact_dir>/build-report-<latest>.md` for what was built
- For first cycle: write `<artifact_dir>/qa-plan.md` (the test plan)
- Each cycle: write `<artifact_dir>/qa-report-<N>.md` (N = current QA cycle, starting at 1; check the dir for existing reports)
- Save screenshots to `<artifact_dir>/screenshots/cycle-<N>-<test-name>.png`
- Update `<artifact_dir>/status.yaml`:
  - `last_actor: prototype-qa`, `updated: <iso>`
  - If all PASS: `phase: done`, `completed.qa: true`
  - For each failure, increment the appropriate `qa_cycles.<spec|design|build|infra>` counter

**Standalone mode:** detect the prototype from context, write reports inline.

## Failure Classification (CRITICAL)

Every failure in your report must include a **classification label** so the coordinator knows which layer to route the fix to. The label drives which sub-skill the coordinator re-spawns.

| Label | Use when | Examples |
|---|---|---|
| `spec` | The acceptance criterion itself is unclear, wrong, or untestable. The implementation matches the spec, but the spec doesn't match what should be tested. | "Criterion #4 says 'feature loads quickly' — no measurable threshold." "Criterion implies behavior X but no acceptance test can express it." |
| `design` | The implementation matches the spec but the visual outcome breaks the design contract: layout overflows 400px, missing state visual, wrong tokens used, interaction missing. | "Error state shows raw stack trace instead of user-readable message per design.md." "Card overflows Smart Window at 300px width." |
| `build` | Implementation bug. Spec and design are correct; the code doesn't deliver them. | "Tool handler throws on empty params." "Component shadow DOM doesn't render the icon." "convId missing — conversationState resets." |
| `infra` | Environment, profile, auth, port, or timing issue. Not a code problem. | "browser.ml.enable=false in profile." "FxA session expired." "Marionette port already bound — stale instance from prior run." "Race: artifact rendered before screenshot — needs `time.sleep(2)`." |

**You self-fix `infra` failures** (update profile prefs, kill stale port, add wait). Don't re-spawn anything for `infra` — just fix and re-test.

For `spec`/`design`/`build`, you do **not** fix the code yourself in pipeline mode. You report with the classification, and the coordinator routes to the right layer. (In standalone mode, fixing build-class issues directly is still fine — see existing rules.)

## Quick Reference

| Item | Detail |
|------|--------|
| Marionette client | `firefox/testing/marionette/client/marionette_driver/` |
| Browser test helpers | `firefox/browser/components/aiwindow/ui/test/browser/head.js` |
| Smart Window components | `firefox/browser/components/aiwindow/ui/components/` |
| AI Window models | `firefox/browser/components/aiwindow/models/` |
| AI Window actors | `firefox/browser/components/aiwindow/ui/actors/` |
| Demo apps | `demos/<name>/` (contain `Nightly.app` + `profile-default`) |
| Source prototypes | `worktrees/assistant-<name>/` directories |
| Marionette port | Read from `<worktree>/.marionette-port` (written by launch-prototype.sh) |
| Launch script (shared) | `/Users/joliehuang/FirefoxPrototype/launch-prototype.sh` |
| Screenshot output | `/tmp/qa-prototype-*.png` |
| Test scripts | `/tmp/qa-test-*.py` |

---

## Workflow

Follow these phases in order. Phases 3-4 repeat until all tests pass (max 3 cycles per QA run).

---

### Phase 1 — Test Plan Generation

#### 1.1 Read the Inputs

You may receive inputs in two modes:

**Pipeline mode** (invoked by `/prototype` coordinator):
- **Prototype spec** — contains acceptance criteria (the source of truth for what to test)
- **Design spec** — contains visual states and interactions (the source of truth for how it should look)
- **Build location** — worktree path or project root

**Standalone mode** (invoked directly by user):
- Ask the user which prototype to test, or detect from context
- Resolve to a **demo app** (`demos/<name>/` with `Nightly.app` + `profile-default`) or **source prototype** (`assistant-<name>/` or `firefox/` requiring `./mach build`)
- Read the feature's source code to generate acceptance criteria yourself

#### 1.2 Read Feature Code

Read the implemented components to understand DOM structure and selectors:

```
Glob: <build-path>/browser/components/aiwindow/ui/components/<feature>/*
```

Look at `render()` methods for:
- Element selectors (tag names, IDs, classes)
- Shadow DOM boundaries (which elements are inside shadow roots)
- Data properties (what attributes/properties hold displayed values)

#### 1.3 Generate Test Cases

Map each acceptance criterion to a concrete test:

| # | Acceptance Criterion | Test Action | Expected Result | Selector Chain |
|---|---------------------|-------------|-----------------|----------------|
| 1 | "Feature renders in Smart Window" | Open Smart Window, check for component | Element exists | `ai-window → shadowRoot → #aichat-browser → ... → feature-artifact` |
| 2 | ... | ... | ... | ... |

Print the test plan before proceeding.

---

### Phase 2 — Environment Setup

#### 2.1 Kill Stale Marionette Processes (port-scoped only)

**CRITICAL: Never use `pkill firefox`, `killall firefox`, `pkill -f Firefox`, or any broad pattern that could kill the user's regular Firefox instances (Release, Nightly, etc.). Only kill the specific process bound to the Marionette port.**

If `<worktree>/.marionette-port` exists from a previous run, kill anything still bound to it:

```bash
WT="<worktree-path>"
if [ -f "$WT/.marionette-port" ]; then
  PORT=$(cat "$WT/.marionette-port")
  lsof -i :$PORT -t 2>/dev/null | xargs kill -9 2>/dev/null || true
fi
```

#### 2.2 Launch Firefox

**Always launch via `<worktree>/run.command`** (which delegates to `launch-prototype.sh`). This is the single source of truth — the same launcher humans and agents use. It handles golden-profile cloning, free Marionette port assignment, integrity checks, and pre-launch hooks.

```bash
WT="<worktree-path>"
"$WT/run.command" &
FIREFOX_PID=$!
echo "Launched Firefox PID: $FIREFOX_PID"
```

The launcher writes the assigned Marionette port to `$WT/.marionette-port` before exec'ing Firefox.

For a **demo app** that doesn't have a `run.command` (frozen build):
```bash
"<demo-path>/Nightly.app/Contents/MacOS/firefox" \
  -foreground -no-remote -marionette \
  -profile "<demo-path>/profile-default" &
FIREFOX_PID=$!
```
Demo Marionette uses port 2828 (default) since demos predate the per-worktree port scheme.

**Never use `./mach run` for QA** — it creates a fresh temp profile on every launch, losing all prefs and auth.

#### 2.3 Read the Port and Wait for Marionette

```bash
WT="<worktree-path>"
for i in $(seq 1 30); do
  if [ -f "$WT/.marionette-port" ]; then
    PORT=$(cat "$WT/.marionette-port")
    if lsof -i :$PORT >/dev/null 2>&1; then echo "Ready on port $PORT"; break; fi
  fi
  sleep 1
done
```

For demos, use port 2828 instead of reading the file.

#### 2.4 Verify Connection

```python
import sys, os
sys.path.insert(0, "<project-root>/firefox/testing/marionette/client")
from marionette_driver.marionette import Marionette

WT = "<worktree-path>"
PORT = int(open(os.path.join(WT, ".marionette-port")).read().strip())

client = Marionette(host="127.0.0.1", port=PORT)
client.start_session()
print(f"Connected on port {PORT}: {client.session_id}")
client.delete_session()
```

Run via `python3 /tmp/qa-connect-test.py`. If the Marionette client fails to import, fall back to:
```bash
cd "<project-root>/firefox"
./mach python /tmp/qa-connect-test.py
```

#### 2.5 Auth Check

Take an initial screenshot and check for auth wall:

```python
client = Marionette(host="127.0.0.1", port=PORT)  # PORT from 2.4
client.start_session()
data = client.screenshot()
with open("/tmp/qa-prototype-auth-check.png", "wb") as f:
    import base64
    f.write(base64.b64decode(data))
client.delete_session()
```

Use the Read tool to view `/tmp/qa-prototype-auth-check.png`. If an auth/sign-in wall is visible and the cached profile doesn't have a session, warn the user and proceed with non-auth-gated tests only.

---

### Phase 3 — Test Execution

For each test case, write a self-contained Python script at `/tmp/qa-test-<N>.py`.

#### Boilerplate

```python
import sys, base64, json, time
sys.path.insert(0, "<project-root>/firefox/testing/marionette/client")
from marionette_driver.marionette import Marionette

client = Marionette(host="127.0.0.1", port=PORT)
client.start_session()
client.set_context(client.CONTEXT_CHROME)

try:
    # --- test logic ---
    pass
finally:
    # Screenshot on completion
    data = client.screenshot()
    with open("/tmp/qa-prototype-<N>.png", "wb") as f:
        f.write(base64.b64decode(data))
    client.delete_session()
```

#### Common Patterns

**Open Smart Window:**
```python
client.execute_script("""
  const { AIWindowUI } = ChromeUtils.importESModule(
    "moz-src:///browser/components/aiwindow/ui/modules/AIWindowUI.sys.mjs"
  );
  if (!AIWindowUI.isSidebarOpen(window)) {
    AIWindowUI.toggleSidebar(window);
  }
""", sandbox="system")
```

**Wait for Smart Window load:**
```python
client.execute_script("""
  const browser = document.getElementById("ai-window-browser");
  let tries = 0;
  while (!browser?.contentDocument?.querySelector("ai-window:defined") && tries < 50) {
    await new Promise(r => setTimeout(r, 200));
    tries++;
  }
  if (tries >= 50) throw new Error("Timeout waiting for ai-window");
""", sandbox="system")
```

**Query inside Smart Window shadow DOM:**
```python
result = client.execute_script("""
  const browser = document.getElementById("ai-window-browser");
  const aiWindow = browser.contentDocument.querySelector("ai-window");
  const component = aiWindow.shadowRoot.querySelector("<selector>");
  return { exists: !!component };
""", sandbox="system")
```

**Type and submit in Smartbar:**
```python
client.execute_script("""
  const browser = document.getElementById("ai-window-browser");
  const aiWindow = browser.contentDocument.querySelector("ai-window");
  const smartbar = aiWindow.shadowRoot.querySelector("#ai-window-smartbar");
  const input = smartbar.inputField;
  input.focus();
  input.value = arguments[0];
  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", code: "Enter", bubbles: true }));
""", script_args=["<query>"], sandbox="system")
```

**Take labeled screenshot:**
```python
data = client.screenshot()
with open(f"/tmp/qa-prototype-{step_name}.png", "wb") as f:
    f.write(base64.b64decode(data))
```

Use the Read tool to view screenshots and verify visual correctness against the design spec.

---

### Phase 4 — Analyze & Fix (if needed)

For each failing test:

#### 4.1 Capture Diagnostics

**Browser console errors:**
```python
errors = client.execute_script("""
  const consoleService = Cc["@mozilla.org/consoleservice;1"]
    .getService(Ci.nsIConsoleService);
  const messages = [];
  consoleService.getMessageArray(messages, {});
  return messages.slice(-20).map(m => m.toString());
""", sandbox="system")
```

Also take a screenshot showing the failure state.

#### 4.2 Read Source Code

Based on the failure, read the relevant source files:
- Component `.mjs` files for rendering issues
- Actor files for IPC/message issues
- Model files for data processing issues

#### 4.3 Apply Fix

Use the **Edit** tool to make targeted code changes. Prefer:
- Fixing root causes, not symptoms
- Minimal changes that address the specific failure
- Not breaking other passing tests

#### 4.4 Rebuild

**Source builds:**
```bash
cd "<prototype-dir>/firefox"
./mach build faster
```

**Demo builds:** Pre-compiled `Nightly.app` cannot be patched. If a fix is needed, inform the user they need to switch to source mode or rebuild the demo.

#### 4.5 Re-run Failing Tests

After fixing and rebuilding:
1. If Firefox needs to restart (rebuild case), kill **only the stored `$FIREFOX_PID`** and relaunch per 2.2 (capturing the new PID). **Never use broad kill commands.**
2. Re-run only the failing test cases
3. If still failing, loop back to 4.1

Repeat Phase 3-4 up to 3 cycles.

---

### Phase 5 — Report

In pipeline mode, write to `<artifact_dir>/qa-report-<N>.md` (N = current QA cycle). Save screenshots to `<artifact_dir>/screenshots/cycle-<N>-<name>.png`. In standalone mode, output to conversation and `/tmp/`.

```markdown
## QA Report: [Feature Name]

**Date:** [date]
**Build:** [worktree branch or path]
**Cycle:** [N]

### Results

| # | Test | Status | Classification | Notes |
|---|------|--------|----------------|-------|
| 1 | Sidebar opens with feature | PASS | — | |
| 2 | Core interaction works | PASS | — | |
| 3 | Error state displays | FAIL | design | Component missing error template per design.md state contract |
| 4 | Forecast loads in 5s | FAIL | spec | Criterion has no measurable threshold for "loads" — needs LCP/load-event definition |

### Screenshots
- `screenshots/cycle-<N>-window-open.png` — Smart Window loaded
- `screenshots/cycle-<N>-interaction.png` — after user interaction
- `screenshots/cycle-<N>-error.png` — error state (FAIL)

### Failures (if any)

For each failure:
- **Test:** [which test]
- **Classification:** `spec | design | build | infra` (REQUIRED)
- **Expected:** [from acceptance criteria]
- **Actual:** [what happened]
- **Root cause:** [what's wrong, in the layer named by classification]
- **Suggested fix:** [specific file/section/change needed at the right layer]
- **Screenshot:** [path]

### Cycle Counter Updates

Report the increments you applied to `status.yaml.qa_cycles`:
- spec: +N
- design: +N
- build: +N
- infra: +N (self-fixed inline)

### Overall Status

[PASS — all tests green / FAIL — N tests failing across <layers>, details above]
```

### Phase 6 — Cleanup

```python
# Disconnect Marionette
client.delete_session()
```

```bash
# Terminate ONLY the Firefox instance we launched (by stored PID)
kill $FIREFOX_PID 2>/dev/null || true
# Clean up temp scripts
rm -f /tmp/qa-test-*.py /tmp/qa-connect-test.py
```

**IMPORTANT:** Do NOT use `pkill`, `killall`, or any pattern-based kill during cleanup. Only kill the specific `$FIREFOX_PID` we launched.

---

## Selector Reference

These selectors are verified from `head.js` browser test helpers:

| Element | Context | Selector |
|---------|---------|----------|
| Sidebar browser | Chrome | `document.getElementById("ai-window-browser")` |
| AI Window | AI Window content | `sidebarBrowser.contentDocument.querySelector("ai-window")` |
| Smartbar | AI Window shadow | `aiWindow.shadowRoot.querySelector("#ai-window-smartbar")` |
| Smartbar input | Smartbar | `smartbar.inputField` |
| Chat browser | AI Window shadow | `aiWindow.shadowRoot.querySelector("#aichat-browser")` |
| Chat content | Chat browser content | `chatBrowser.contentDocument.querySelector("ai-chat-content")` |
| Chat messages | Chat content shadow | `chatContent.shadowRoot.querySelectorAll("ai-chat-message")` |
| Prompts | AI Window shadow | `aiWindow.shadowRoot.querySelector("smartwindow-prompts")` |
| Prompt buttons | Prompts shadow | `prompts.shadowRoot.querySelectorAll(".sw-prompt-button")` |
| Weather widget | Chat content shadow | `chatContent.shadowRoot.querySelector("weather-artifact")` |
| Context chips | Smartbar | `smartbar.querySelector(".smartbar-context-chips-header")` |
| Context button | Smartbar | `smartbar.querySelector("context-icon-button")` |
| Panel list | Smartbar | `smartbar.querySelector("smartwindow-panel-list")` |
| Input CTA | AI Window shadow | `aiWindow.shadowRoot.querySelector("input-cta")` |
| Footer | AI Window shadow | `aiWindow.shadowRoot.querySelector("smartwindow-footer")` |
| Editor | Smartbar | `smartbar.querySelector("moz-multiline-editor")` |
| Website chips | Editor shadow | `editor.shadowRoot.querySelector("ai-website-chip")` |

---

## Prototype Registry

| Prototype | Directory | Launch | Key Feature |
|-----------|-----------|--------|-------------|
| weather-widget | `demos/weather-widget/` | Demo (Nightly.app) | Weather artifact in chat |
| open-meteo-forecast | `demos/open-meteo-forecast/` | Demo (Nightly.app) | Weather forecast widget |
| assistant-weather-widget | `assistant-weather-widget/` | Source build | Weather artifact (dev) |
| assistant-travel-planner | `assistant-travel-planner/` | Source build | Travel planning assistant |
| assistant-open-meteo-forecast | `assistant-open-meteo-forecast/` | Source build | Forecast widget (dev) |

---

## Profile & Environment Setup (CRITICAL)

Many QA failures are caused by missing profile prefs or auth, not code bugs. The reliable mechanism is the **golden profile** at `~/.firefox-prototype-golden/`, cloned into `<worktree>/profile-default/` on first launch by `launch-prototype.sh`. The clone inherits all prefs, FxA auth, and MLPA model cache.

### What's in golden

- **Required prefs** in `user.js`:
  ```js
  user_pref("browser.ml.enable", true);                          // CRITICAL: LLM engine won't build without this
  user_pref("browser.smartwindow.enabled", true);
  user_pref("browser.smartwindow.firstrun.hasCompleted", true);
  user_pref("browser.smartwindow.firstrun.modelChoice", "1");
  user_pref("browser.smartwindow.tos.consentTime", 1775283133);
  ```
- **FxA auth** (signedInUser.json + logins.json + key4.db + cert9.db + cookies.sqlite — together).
- **MLPA model cache** in `storage/`.

The launcher verifies golden integrity (`verify-golden.sh`) before cloning. If golden is missing or stale, the launch fails with an actionable error.

Without `browser.ml.enable = true`, the engine build fails silently and no LLM response is generated. If you see this symptom, the golden seed is incomplete — re-run `seed-golden.sh --force`.

### FxA Authentication

If golden was seeded correctly, every cloned profile starts signed in. Verify via Marionette:
```python
r = client.execute_async_script("""
  const resolve = arguments[arguments.length - 1];
  (async () => {
    const { getFxAccountsSingleton } = ChromeUtils.importESModule(
      "resource://gre/modules/FxAccounts.sys.mjs"
    );
    const fxa = getFxAccountsSingleton();
    resolve({ signedIn: await fxa.hasLocalSession() });
  })();
""", sandbox="system")
```

If not signed in despite golden being present, FxA tokens may have expired. Re-seed golden (`seed-golden.sh --force`) and delete the worktree's `profile-default/` so it re-clones.

### AI Window mode must be enabled

The Smart Window page (`smartwindow-init.mjs`) redirects to `about:newtab` unless the window has the `ai-window` attribute:

```python
client.execute_script("""
  const { AIWindow } = ChromeUtils.importESModule(
    "moz-src:///browser/components/aiwindow/ui/modules/AIWindow.sys.mjs"
  );
  if (!AIWindow.isAIWindowActive(window)) AIWindow.toggleAIWindow(window, true, "qa");
""", sandbox="system")
```

### Sidebar hidden on about:newtab

CSS rule `:root[hide-ai-sidebar]` (legacy attribute name from when AI Window was sidebar-only) sets `display: none` on the Smart Window browser when on new tab pages, giving it 0x0 dimensions. Either:
- Navigate to a regular page (`https://example.com`) before opening the Smart Window
- Or use the fullpage AI Window (which works on newtab) — access the tab content's `ai-window` element instead of the Smart Window browser

### Never use `./mach run` for QA

`./mach run` creates a fresh temp profile on every launch, losing all prefs and auth. Use the worktree's `run.command` instead — it delegates to `launch-prototype.sh`, which launches the Nightly.app binary directly with the persistent (golden-cloned) profile and a free Marionette port.

### Remote chat frame (`#aichat-browser`)

The chat content (`about:aichatcontent`) runs in a remote content process (`<browser remote="true">`). Marionette's `CONTEXT_CONTENT` and `CONTEXT_CHROME` cannot access its DOM. Neither can `drawWindow()` or Firefox DevTools MCP.

For widget verification, use:
- **Programmatic checks**: `conversationMessageCount`, `showStarters`, `conversationId` on the `ai-window` element (accessible from chrome context)
- **Screenshot verification**: Marionette `screenshot()` captures the chrome window including composited remote frames (the widget/text IS visible in screenshots even though DOM isn't accessible)
- **LLM response timing**: Allow 30-45 seconds for weather/widget queries — the API context fetch + LLM streaming takes time

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Marionette import fails | Use `./mach python /tmp/qa-test.py` instead of system `python3` |
| Marionette port busy | `lsof -i :$(cat <worktree>/.marionette-port) -t \| xargs kill -9` then relaunch via `run.command` |
| Firefox won't start | Check if another instance is using the same profile; use `-no-remote` flag. **Never kill other Firefox instances to free the profile.** |
| Shadow DOM selector returns null | Add wait/poll loop; Lit components render async after `updateComplete` |
| Auth wall blocks testing | Use demo `profile-default` which may have cached FxA session |
| `execute_script` timeout | Increase Marionette script timeout: `client.timeout.script = 60` |
| Cannot patch demo app | Demo `Nightly.app` is pre-compiled; switch to source build for code fixes |
| `./mach build faster` fails | Ensure `./mach build` was run at least once first; check for C++/Rust changes |
| Screenshot is blank/black | Firefox may not have finished rendering; add `time.sleep(2)` before screenshot |
| No LLM response (msgCount stays 2) | Check `browser.ml.enable` pref is `true`; check FxA `hasLocalSession()`; allow 30-45s for response |
| Sidebar has 0x0 dimensions | Navigate away from `about:newtab` first, or use fullpage mode |
| `CONTEXT_CONTENT` shows wrong page | Chat content is in remote `#aichat-browser`; use chrome context + `conversationMessageCount` for programmatic checks, screenshots for visual verification |
| "Something went wrong" error | Check browser console: "MLEngine is disabled" means `browser.ml.enable=false`; auth errors mean FxA not signed in |
| `conversationState` resets unexpectedly | Standalone entries (e.g., widget-only) must include `convId` from the user message, otherwise `#checkConversationState` wipes everything |

---

## Using Firefox DevTools MCP for Testing & Debugging

The `mcp__firefox-devtools` MCP server provides tools to interact with the running Firefox instance beyond what Marionette offers. **Use these tools actively throughout QA** — they complement Marionette and help diagnose issues faster.

### Debugging tools

| Tool | When to use |
|------|-------------|
| `list_console_messages` | Check for JS errors, warnings, and logs after every test action. Look for "MLEngine is disabled", auth errors, fetch failures, weather/widget errors. |
| `list_network_requests` | Verify external API calls fired (Open-Meteo, Geoapify, etc.). Check for failed requests, timeouts, or missing calls. |
| `get_network_request` | Inspect specific API response payloads to verify data correctness. |
| `get_firefox_output` | Get stdout/stderr from the Firefox process for crash diagnostics. |
| `get_firefox_info` | Check Firefox version and configuration. |

### Visual verification tools

| Tool | When to use |
|------|-------------|
| `screenshot_page` | Capture the current page content. Use alongside Marionette `screenshot()` which captures chrome. |
| `screenshot_by_uid` | Capture a specific element by UID from a snapshot. |
| `take_snapshot` | Get a DOM snapshot with stable UIDs. Use to find elements, verify structure, check text content. |
| `list_pages` | See all open tabs/pages. Check if the right page is selected. |
| `select_page` | Switch to a specific tab by index, URL, or title. |

### Interaction tools

| Tool | When to use |
|------|-------------|
| `click_by_uid` | Click UI elements (buttons, links) found via `take_snapshot`. |
| `fill_by_uid` | Type text into input fields. Alternative to Marionette smartbar interaction. |
| `navigate_page` | Navigate to a URL. Use to move away from `about:newtab` before Smart Window tests. |
| `hover_by_uid` | Test hover states on UI elements. |

### Recommended QA workflow

1. **After setup**: Run `list_console_messages` to check for startup errors (MLEngine, auth, etc.)
2. **After submitting a query**: Run `list_console_messages` to catch JS errors. Run `list_network_requests` to verify API calls fired.
3. **For visual verification**: Use `screenshot_page` for content area, Marionette `screenshot()` for full chrome window.
4. **When Marionette can't reach remote frames**: Use `take_snapshot` + `screenshot_page` from DevTools MCP which may access different content.
5. **For debugging failures**: Check `list_console_messages` for the specific error before attempting code fixes.

### Important limitations

- DevTools MCP sees **content pages**, not chrome UI. It can see tab content but not the Smart Window browser.
- The chat content (`about:aichatcontent`) is in a remote frame that DevTools MCP also cannot access directly.
- Use DevTools MCP and Marionette together — Marionette for chrome context, DevTools for content context and console/network.

---

## Collaboration with the Coordinator

In **pipeline mode**, the coordinator does the routing — your job is to classify failures correctly. Behavior by classification:

1. **`infra`** — Fix in-place (update `user.js` for missing prefs, kill stale port, add wait, re-auth). Don't write a "needs fix from another skill" report. Re-test in the same cycle.
2. **`spec`** — Report only. The coordinator re-spawns `/prototype-spec` with your failure report attached.
3. **`design`** — Report only. The coordinator re-spawns `/prototype-design`.
4. **`build`** — Report only. The coordinator re-spawns `/prototype-build`.

In **standalone mode**, `build`-class small bugs you may fix directly (selector, import, CSS) — historical behavior. For larger issues, surface to the user.

Example failure entry for the coordinator:
> **Test:** Weather widget disappears when LLM responds
> **Classification:** `build`
> **Root cause:** `#handleWeatherData` creates a standalone assistant entry without `convId`. When the LLM response arrives, `#checkConversationState` sees a convId mismatch and resets `conversationState`, wiping the widget.
> **File:** `ai-chat-content.mjs`, `#handleWeatherData` method
> **Suggested fix:** Add `convId: lastUser?.convId` to the standalone entry

---

## Rules

- **NEVER kill Firefox broadly.** Do NOT use `pkill firefox`, `killall firefox`, `pkill -f Firefox`, `pkill -f Nightly`, or any pattern-based kill that could terminate the user's regular Firefox Release or Nightly browsers. Only kill via the stored `$FIREFOX_PID` or by targeting the worktree-specific Marionette port (`lsof -i :$(cat <worktree>/.marionette-port) -t | xargs kill`). This is the most important rule.
- **Classify every failure.** Every failure entry must have `spec | design | build | infra`. The coordinator routes based on this; an unlabeled or wrong label burns a cycle in the wrong layer.
- **Use Firefox DevTools MCP tools actively.** Check console messages after every test action. Verify network requests for API calls. Don't rely solely on Marionette.
- **Test against acceptance criteria, not your own expectations.** The PM spec is the source of truth. In standalone mode, derive criteria from the feature code.
- **Always take screenshots.** Every test gets a screenshot, pass or fail. Use the Read tool to view them. In pipeline mode, save to `<artifact_dir>/screenshots/cycle-<N>-<name>.png`.
- **Self-fix `infra` only.** In pipeline mode, do not patch source code for `spec`/`design`/`build` failures — classify and report; the coordinator routes. (In standalone mode, fixing small `build`-class bugs in-place is still allowed.)
- **Clean up after yourself.** Kill only the Firefox instance you launched (by PID) and remove temp scripts when done.
- **Cycle caps differ by layer.** `qa_cycles.spec: max 1`, `qa_cycles.design: max 2`, `qa_cycles.build: max 3`, `qa_cycles.infra: unlimited`. Increment honestly so the coordinator can enforce.
- **Check profile prefs and auth FIRST.** Most "silent failures" are caused by missing `browser.ml.enable`, missing FxA session, or fresh temp profiles. Verify before debugging code.
