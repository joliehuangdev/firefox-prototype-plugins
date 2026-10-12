# Live Fix Loop — Shared Reference

Used by: `prototype-qa` (orchestrator), `prototype-build` (engineer in fix mode).

## Why

The default coordinator round-trip for QA-classified `build` failures is:

QA report → coordinator reads → spawn fresh engineer → engineer reads spec/design/distillate/qa-report from disk → edit → `./mach build faster` → coordinator spawns fresh QA → QA relaunches Firefox → re-tests.

That's 2 fresh subagents and a Firefox restart per fix attempt. The engineer never sees the live DOM, console errors, or network traces — only what QA serialized to disk.

The **live fix loop** collapses this. When QA classifies a failure as `build`, instead of writing a report and exiting, QA dispatches **one** "fix-and-verify" engineer subagent that owns the running Marionette session. The engineer edits, rebuilds, re-tests in-place, screenshots, and either succeeds or escalates. Only on escalation does the coordinator round-trip happen.

## Trigger condition

In `prototype-qa`, after Phase 4 classification:

- If failure(s) are exclusively `build`-class **and** `cycles.build < caps.build`: enter live fix loop.
- If `infra` only: self-fix in-place (no new agent), as today.
- If any `spec` or `design` failures: write report, exit, let coordinator route to upstream layers (those need design/PM judgement; live loop won't help).
- If mixed (e.g., 1 design + 2 build): write report with all failures, exit, let coordinator route — design fix may invalidate the build classification anyway.

## Loop protocol

```
Phase 4.live (QA) — Live Fix Loop
  Marionette session: KEEP OPEN
  Firefox process: KEEP RUNNING

  For each `build`-class failure (max 2 attempts per failure):
    1. QA captures: console messages, failed network requests, screenshot, the
       failing element's outerHTML if reachable.
    2. QA dispatches a "live-fix" engineer subagent with:
       - artifact_dir
       - the specific failure (one at a time)
       - the diagnostics bundle from step 1
       - worktree path
       - explicit instruction: "DO NOT re-explore the codebase or run QA. Edit,
         build, return."
    3. Engineer subagent: reads relevant file(s), edits, runs `./mach build
       faster` (or full per launcher-and-profile.md auto-detect rule), returns
       a one-line verdict ("BUILT" or "BUILD_FAILED: <reason>").
    4. If BUILT: QA re-tests just this failing case via the still-open
       Marionette session. If pass → mark fixed, continue. If still fail and
       attempts < 2 → loop. If still fail at attempt 2 → escalate.
    5. If BUILD_FAILED: escalate.
  Increment `cycles.build` by 1 (whole live-fix invocation = 1 cycle, regardless
  of internal attempts).
```

## Escalation

If the live loop exhausts its attempts without fixing all `build` failures:

- Write `qa-report-<N>.md` covering remaining failures with classification still as `build`, plus the diagnostics that were collected.
- Exit. Coordinator routes to a fresh `prototype-build` engineer for the harder fix (with full context, distillate gap check, etc.).

## Why this is safer than collapsing build+QA into one role

The engineer sub-agent inside the live loop has narrow scope: one failure, one edit, one rebuild. It does **not** decide whether the test should pass or change classifications — QA still owns that. Keeps blast radius small.

## Engineer's "live-fix" prompt template

```
You are in LIVE FIX MODE. The QA agent has the Marionette session open. Your job
is one tight cycle.

Artifact dir: <abs path>
Worktree: <abs path>
Failure: <verbatim from QA report>
Diagnostics:
  Console (last 20): <embedded>
  Network failures: <embedded>
  Screenshot: <abs path>
  Element outerHTML (if available): <embedded>

Read only the file(s) directly implicated. Edit. Rebuild via launcher-and-profile.md
auto-detect rule. Return one of:

  BUILT
  BUILD_FAILED: <one-line reason>

Do NOT run QA. Do NOT explore unrelated code. Do NOT update status.yaml.
QA owns verification and counter increments.
```

## Counter accounting

- `cycles.build` increments by 1 per live-fix loop *invocation*, not per internal attempt. A loop that fixes 3 failures in 2 attempts = +1.
- If the loop escalates and the coordinator then spawns a full engineer: the coordinator increments `cycles.build` again (+1 more). This is intentional — escalation is a real cycle.
