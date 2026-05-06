---
name: qa-extension
description: Use this skill when the user wants to test, debug, or fix a Firefox browser extension. Triggers on phrases like "test my extension", "debug extension", "fix extension", "qa extension", "run extension tests", or any request to load, validate, or iterate on a Firefox extension until tests pass.
version: 1.0.0
---

# QA Extension

Automates the loop of loading a Firefox extension, running tests, debugging failures, fixing the code, and repeating until all tests pass.

## Workflow

Follow these steps in order. Repeat from step 2 until all tests pass.

### Step 1 — Setup (first run only)

1. Ask the user for:
   - Path to the extension directory (if not already known)
   - How tests are run (e.g., `web-ext run`, Playwright, Jest, custom script)
   - Where test output / error logs appear
2. Verify `web-ext` is available: `web-ext --version`
   - If missing, suggest: `npm install -g web-ext`
3. Confirm the extension loads without errors: `web-ext lint --source-dir <ext-dir>`

### Step 2 — Load & Run Tests

Run the test command provided by the user. Common patterns:

```bash
# Lint the extension
web-ext lint --source-dir <ext-dir>

# Run unit tests (if configured)
npm test

# Run e2e tests with Playwright/Selenium
npx playwright test

# Launch Firefox with extension loaded
web-ext run --source-dir <ext-dir>
```

Capture the full output — both stdout and stderr.

### Step 3 — Analyze Failures

For each failing test or error:
1. Read the relevant source files implicated in the error
2. Identify the root cause (logic error, missing permission, API mismatch, manifest issue, etc.)
3. Note which files need to change

### Step 4 — Fix

Apply the minimal fix needed to address each failure. Prefer:
- Targeted edits over rewrites
- Fixing root causes, not symptoms
- Not breaking passing tests

### Step 5 — Verify & Repeat

Re-run tests (Step 2). If failures remain, go back to Step 3.

When all tests pass, report:
- What was fixed and why
- Any follow-up recommendations (e.g., edge cases, permissions to review)

## Common Firefox Extension Issues

| Symptom | Likely Cause | Fix |
|---|---|---|
| Permission denied | Missing permission in `manifest.json` | Add to `permissions` array |
| Content script not injecting | Wrong `matches` pattern | Fix URL pattern in manifest |
| Background script crash | Manifest V3 service worker issue | Check `background.service_worker` |
| CSP violation | Inline script or unsafe eval | Remove inline JS, use external files |
| `browser` API undefined | Running outside extension context | Use `typeof browser !== 'undefined'` guard |
| Extension not reloading | Cached old version | `web-ext run` auto-reloads; hard reload with `Ctrl+Shift+R` |

## Manifest Checklist

Before running tests, verify `manifest.json`:
- `manifest_version`: use `2` or `3` (check compatibility)
- `permissions`: includes all APIs the extension uses
- `content_scripts.matches`: correct URL patterns
- `background`: correct key for MV2 (`scripts`) vs MV3 (`service_worker`)
- `web_accessible_resources`: lists any files injected into pages

## Tips

- Use `web-ext lint` to catch manifest and code issues before running full tests
- Check the Firefox Browser Console (`Ctrl+Shift+J`) and extension DevTools for runtime errors
- `about:debugging#/runtime/this-firefox` shows loaded extensions and lets you inspect background scripts
- For Playwright tests against a real browser with extension: use `firefox` channel with `--load-extension` flag
