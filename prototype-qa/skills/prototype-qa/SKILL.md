---
name: prototype-qa
description: QA agent that validates Firefox Smart Window prototypes end-to-end via Marionette. Use when the user says "qa the prototype", "test the prototype", "validate the build", or when invoked by the /prototype coordinator. Can also be used standalone.
version: 1.0.0
---

# Prototype QA — QA Agent

You autonomously validate Firefox Smart Window prototypes by launching Firefox, interacting with the feature via Marionette, taking screenshots, and reporting pass/fail results against the spec's acceptance criteria.

## Quick Reference

| Item | Detail |
|------|--------|
| Marionette client | `firefox/testing/marionette/client/marionette_driver/` |
| Browser test helpers | `firefox/browser/components/aiwindow/ui/test/browser/head.js` |
| Smart Window components | `firefox/browser/components/aiwindow/ui/components/` |
| AI Window models | `firefox/browser/components/aiwindow/models/` |
| AI Window actors | `firefox/browser/components/aiwindow/ui/actors/` |
| Demo apps | `demos/<name>/` (contain `Nightly.app` + `profile-default`) |
| Source prototypes | `assistant-<name>/` directories |
| Default Marionette port | 2828 |
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
| 1 | "Feature renders in sidebar" | Open sidebar, check for component | Element exists | `ai-window → shadowRoot → #aichat-browser → ... → feature-artifact` |
| 2 | ... | ... | ... | ... |

Print the test plan before proceeding.

---

### Phase 2 — Environment Setup

#### 2.1 Kill Stale Marionette Processes (port-scoped only)

**CRITICAL: Never use `pkill firefox`, `killall firefox`, `pkill -f Firefox`, or any broad pattern that could kill the user's regular Firefox instances (Release, Nightly, etc.). Only kill the specific process bound to the Marionette port.**

```bash
# Only kill whatever process is holding the Marionette port
lsof -i :2828 -t 2>/dev/null | xargs kill -9 2>/dev/null || true
```

#### 2.2 Launch Firefox

**Always capture the PID so cleanup can target only this instance.**

**Source builds — launch the binary directly with a persistent profile:**
```bash
cd "<build-path>/firefox"
OBJ_DIR=$(ls -d obj-* 2>/dev/null | head -1)
"$OBJ_DIR/dist/Nightly.app/Contents/MacOS/firefox" \
  -foreground -no-remote -marionette -profile "<build-path>/profile-default" &
FIREFOX_PID=$!
echo "Launched Firefox PID: $FIREFOX_PID"
```

**Never use `./mach run` for QA** — it creates a fresh temp profile on every launch, losing all prefs and auth.

If a demo app exists at `<build-path>/Nightly.app`:
```bash
"<build-path>/Nightly.app/Contents/MacOS/firefox" -foreground -no-remote -marionette -profile "<build-path>/profile-default" &
FIREFOX_PID=$!
echo "Launched Firefox PID: $FIREFOX_PID"
```

**Note:** The `-no-remote` flag prevents this instance from connecting to or interfering with existing Firefox sessions.

#### 2.3 Wait for Marionette

```bash
for i in $(seq 1 30); do
  if lsof -i :2828 >/dev/null 2>&1; then echo "Ready"; break; fi
  sleep 1
done
```

#### 2.4 Verify Connection

```python
import sys
sys.path.insert(0, "<project-root>/firefox/testing/marionette/client")
from marionette_driver.marionette import Marionette

client = Marionette(host="127.0.0.1", port=2828)
client.start_session()
print("Connected:", client.session_id)
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
client = Marionette(host="127.0.0.1", port=2828)
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

client = Marionette(host="127.0.0.1", port=2828)
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

**Wait for sidebar load:**
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

**Query inside sidebar shadow DOM:**
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

Output a structured report:

```markdown
## QA Report: [Feature Name]

**Date:** [date]
**Build:** [worktree branch or path]
**Cycles:** [N of 3]

### Results

| # | Test | Status | Notes |
|---|------|--------|-------|
| 1 | Sidebar opens with feature | PASS | |
| 2 | Core interaction works | PASS | |
| 3 | Error state displays | FAIL | Component missing error template |

### Screenshots
- `/tmp/qa-prototype-sidebar-open.png` — sidebar loaded
- `/tmp/qa-prototype-interaction.png` — after user interaction
- `/tmp/qa-prototype-error.png` — error state (FAIL)

### Failures (if any)
For each failure:
- **Test:** [which test]
- **Expected:** [from acceptance criteria]
- **Actual:** [what happened]
- **Root cause:** [what's wrong in the code]
- **Suggested fix:** [specific file and change needed]
- **Screenshot:** [path]

### Overall Status
[PASS — all tests green / FAIL — N tests failing, details above]
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
| AI Window | Sidebar content | `sidebarBrowser.contentDocument.querySelector("ai-window")` |
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

Many QA failures are caused by missing profile prefs or auth, not code bugs. Always verify these before testing.

### Required prefs

Before launching Firefox for QA, ensure the profile has these prefs in `user.js`:

```js
user_pref("browser.ml.enable", true);                          // CRITICAL: LLM engine won't build without this
user_pref("browser.smartwindow.enabled", true);
user_pref("browser.smartwindow.firstrun.hasCompleted", true);
user_pref("browser.smartwindow.firstrun.modelChoice", "1");
user_pref("browser.smartwindow.tos.consentTime", 1775283133);
```

Without `browser.ml.enable = true`, the engine build fails silently and no LLM response is generated.

### FxA Authentication

Check auth status early via Marionette:
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

If not signed in, tell the user to sign in interactively. Auth tokens require `signedInUser.json` + `logins.json` + `key4.db` together — copying just `signedInUser.json` is not enough.

### AI Window mode must be enabled

The Smart Window sidebar page (`smartwindow-init.mjs`) redirects to `about:newtab` unless the window has the `ai-window` attribute:

```python
client.execute_script("""
  const { AIWindow } = ChromeUtils.importESModule(
    "moz-src:///browser/components/aiwindow/ui/modules/AIWindow.sys.mjs"
  );
  if (!AIWindow.isAIWindowActive(window)) AIWindow.toggleAIWindow(window, true, "qa");
""", sandbox="system")
```

### Sidebar hidden on about:newtab

CSS rule `:root[hide-ai-sidebar]` sets `display: none` on the sidebar when on new tab pages, giving it 0x0 dimensions. Either:
- Navigate to a regular page (`https://example.com`) before opening the sidebar
- Or use the fullpage AI Window (which works on newtab) — access the tab content's `ai-window` element instead of the sidebar browser

### Never use `./mach run` for QA

`./mach run` creates a fresh temp profile on every launch, losing all prefs and auth. Always launch the Nightly.app binary directly with `-profile` pointing to a persistent profile:

```bash
"$OBJ_DIR/dist/Nightly.app/Contents/MacOS/firefox" \
  -foreground -no-remote -marionette -remote-allow-system-access \
  -profile /path/to/profile-default
```

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
| Port 2828 busy | `lsof -i :2828 -t \| xargs kill -9` then relaunch |
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
| `navigate_page` | Navigate to a URL. Use to move away from `about:newtab` before sidebar tests. |
| `hover_by_uid` | Test hover states on UI elements. |

### Recommended QA workflow

1. **After setup**: Run `list_console_messages` to check for startup errors (MLEngine, auth, etc.)
2. **After submitting a query**: Run `list_console_messages` to catch JS errors. Run `list_network_requests` to verify API calls fired.
3. **For visual verification**: Use `screenshot_page` for content area, Marionette `screenshot()` for full chrome window.
4. **When Marionette can't reach remote frames**: Use `take_snapshot` + `screenshot_page` from DevTools MCP which may access different content.
5. **For debugging failures**: Check `list_console_messages` for the specific error before attempting code fixes.

### Important limitations

- DevTools MCP sees **content pages**, not chrome UI. It can see tab content but not the sidebar browser.
- The chat content (`about:aichatcontent`) is in a remote frame that DevTools MCP also cannot access directly.
- Use DevTools MCP and Marionette together — Marionette for chrome context, DevTools for content context and console/network.

---

## Collaboration with /prototype-build

QA should not spend multiple cycles debugging the same class of issue. When tests fail:

1. **Profile/env issues** (missing prefs, auth, MLEngine disabled): Fix directly by updating `user.js` or profile setup. Don't invoke `/prototype-build`.
2. **Small code bugs** (wrong selector, missing import, CSS): Fix directly and retest. Max 3 cycles.
3. **Architectural issues** (widget + LLM coexistence, data flow, state management): Report the root cause clearly and invoke `/prototype-build` to fix. Include:
   - Which test failed and what the expected vs actual behavior was
   - The specific error from `list_console_messages` or Marionette
   - The file and line where the issue originates
   - Whether it's a race condition, missing data, or wrong rendering

Example handoff to `/prototype-build`:
> **Failing test**: Weather widget disappears when LLM responds
> **Root cause**: `#handleWeatherData` creates a standalone assistant entry without `convId`. When the LLM response arrives, `#checkConversationState` sees a convId mismatch and resets `conversationState`, wiping the widget.
> **File**: `ai-chat-content.mjs`, `#handleWeatherData` method
> **Fix needed**: Add `convId: lastUser?.convId` to the standalone entry

---

## Rules

- **NEVER kill Firefox broadly.** Do NOT use `pkill firefox`, `killall firefox`, `pkill -f Firefox`, `pkill -f Nightly`, or any pattern-based kill that could terminate the user's regular Firefox Release or Nightly browsers. Only kill via the stored `$FIREFOX_PID` or by targeting the specific Marionette port (`lsof -i :2828 -t | xargs kill`). This is the most important rule.
- **Use Firefox DevTools MCP tools actively.** Check console messages after every test action. Verify network requests for API calls. Don't rely solely on Marionette.
- **Test against acceptance criteria, not your own expectations.** The PM spec is the source of truth. In standalone mode, derive criteria from the feature code.
- **Always take screenshots.** Every test gets a screenshot, pass or fail. Use the Read tool to view them.
- **Fix code directly when possible.** Small fixes (wrong selector, missing import, CSS tweak) should be fixed and retested, not just reported.
- **Report structural failures to /prototype-build.** If the architecture is wrong (data flow, state management, race conditions), report clearly with root cause and let `/prototype-build` fix it.
- **Clean up after yourself.** Kill only the Firefox instance you launched (by PID) and remove temp scripts when done.
- **Max 3 fix cycles.** If it's not passing after 3 rounds, report and let the coordinator (or user) decide.
- **Check profile prefs and auth FIRST.** Most "silent failures" are caused by missing `browser.ml.enable`, missing FxA session, or fresh temp profiles. Verify before debugging code.
