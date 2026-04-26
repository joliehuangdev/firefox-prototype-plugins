# Prototype Artifact Convention

Every `/prototype` run produces a directory of artifacts on disk. Every sub-skill reads inputs from this directory and writes outputs back. The conversation is *not* the source of truth — files are.

This makes the pipeline **resumable** (a stalled prototype 3 days later picks up exactly where it left off), **auditable** (humans can read every step), and **resilient** (a sub-agent crash doesn't lose state).

---

## 1. Directory Layout

```
~/FirefoxPrototype/_prototype/<YYYY-MM-DD>-<feature-slug>/
├── status.yaml              # phase, scope, cycle counts, blockers
├── idea.md                  # raw user idea (verbatim, never edited)
├── brainstorm.md            # only for scope=new-feature; output of brainstorm step
├── spec.md                  # PM output
├── spec-review.md           # adversarial review of spec (forced findings)
├── design.md                # UX output (UI spec)
├── design-figma.txt         # optional Figma URL
├── design-review.md         # adversarial review of spec+design (forced findings)
├── distillate.md            # condensed build context (existing patterns to follow)
├── build-report-1.md        # engineer report, cycle 1
├── build-report-2.md        # cycle 2 (if QA failed and looped)
├── qa-plan.md               # test plan derived from acceptance criteria
├── qa-report-1.md           # QA report, cycle 1 (includes screenshots inline by ref)
├── qa-report-2.md           # cycle 2
├── screenshots/
│   ├── cycle-1-test-1.png
│   └── ...
├── launch.sh                # generated launcher (chmod +x)
└── worktree-info.txt        # worktree path + branch (extracted from Agent result)
```

The slug is `kebab-case` derived from the feature name. The date prefix sorts chronologically.

The directory root path is **the single argument every sub-skill receives**. Internally, sub-skills know their own filenames.

---

## 2. status.yaml Schema

```yaml
feature: weather-widget-improvements
slug: 2026-04-24-weather-widget-improvements
created: 2026-04-24T16:30:00Z
updated: 2026-04-24T17:45:00Z

# scope drives routing in the coordinator
scope: tweak | new-widget | new-feature

# pipeline phase — coordinator reads this on resume
phase: idea | brainstorm | spec | spec-review | design | design-review | distill | build | qa | done | blocked

# completion flags per phase (true once the artifact exists and was approved)
completed:
  brainstorm: false
  spec: false
  spec_review: false
  design: false
  design_review: false
  distill: false
  build: false
  qa: false

# QA cycle counter (caps at 3 per fix-loop layer)
qa_cycles:
  spec: 0      # times QA bounced back to spec layer
  design: 0    # times QA bounced back to design layer
  build: 0     # times QA bounced back to build layer
  infra: 0    # times QA had to fix profile/env

# worktree info (set by build phase)
worktree:
  path: /Users/.../FirefoxPrototype/worktrees/feature-xyz
  branch: prototype/feature-xyz

# human-readable blocker if phase=blocked
blocked_on: null      # e.g. "spec review surfaced 5 issues, awaiting user resolution"

# last sub-skill that ran (for debugging)
last_actor: prototype-build
```

**Read/write rules:**

- The coordinator is the only writer of `phase`, `scope`, and `completed.*`.
- Sub-skills update `last_actor`, `updated`, and their own counters (e.g., QA increments `qa_cycles.*`).
- `blocked_on` is set by whichever skill found the blocker; cleared by the coordinator after user input.

---

## 3. Sub-skill Contract

Every sub-skill receives:

```
Inputs:
  artifact_dir: <absolute path to _prototype/<slug>/>

Read from artifact_dir:
  Whatever previous-phase artifacts the skill needs (declared in its own SKILL.md).

Write to artifact_dir:
  Its own output file(s) per the layout above.
  status.yaml updates: last_actor, updated, own counters.
```

Sub-skills must be **idempotent** — running them twice on the same artifact_dir overwrites their output cleanly. The coordinator decides whether to re-run.

---

## 4. Resumability

When `/prototype` is invoked with no new idea (or with `--resume <slug>` / `--resume <date-feature>`), the coordinator:

1. Lists `_prototype/` directories sorted by `updated`.
2. Reads `status.yaml` of each candidate.
3. Picks the one matching the user's hint (or shows a chooser).
4. Reads `phase` and routes to the next required step.

If `phase=blocked`, shows `blocked_on` and asks the user how to proceed.

---

## 5. Cleanup

A prototype run is "done" when `phase: done`. The directory is preserved indefinitely as a record. `push-to-demo` (if invoked) copies the worktree's built `Nightly.app` + `profile-default` + `launch.sh` into the demos dir; the artifact dir stays put as the audit trail.
