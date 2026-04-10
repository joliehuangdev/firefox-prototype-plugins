# prototype-qa

QA agent that validates Firefox Smart Window prototypes end-to-end via Marionette browser automation.

## What it does

Launches Firefox, connects via Marionette, and runs automated tests against the spec's acceptance criteria:

1. **Test plan generation** — maps each acceptance criterion to a concrete test with selectors
2. **Environment setup** — launches Firefox with Marionette, verifies connection
3. **Test execution** — runs self-contained Python test scripts, takes screenshots at every step
4. **Fix loop** — diagnoses failures, applies targeted code fixes, rebuilds, and retests (up to 3 cycles)
5. **Structured report** — pass/fail table, screenshots, failure details with root causes

Also supports MCP Firefox DevTools for quick visual checks, console inspection, and DOM snapshots.

## Usage

```
/prototype-qa
```

Provide or reference a spec and build location in conversation. Can be used standalone or as part of the `/prototype` pipeline.

## Output

A QA report with per-test pass/fail status, screenshots at `/tmp/qa-prototype-*.png`, and detailed failure analysis with suggested fixes.

## Requirements

- Firefox build (source or demo app with `Nightly.app`)
- Marionette port 2828 available
- Python 3 with Marionette client (bundled in Firefox source tree)
