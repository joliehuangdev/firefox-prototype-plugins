# Prototype Artifact Convention

Every `/prototype` run produces a directory of artifacts on disk. Every sub-skill reads inputs from this directory and writes outputs back. The conversation is *not* the source of truth — files are.

This makes the pipeline **resumable** (a stalled prototype 3 days later picks up where it left off), **auditable** (humans can read every step), and **resilient** (a sub-agent crash doesn't lose state).

---

## 1. Directory layout

```
~/FirefoxPrototype/_prototype/<YYYY-MM-DD>-<feature-slug>/
├── status.yaml                  # phase, scope, cycle counts, blockers
├── idea.md                      # raw user idea (verbatim; scoping notes appended for new-feature)
├── demo.md                      # the 2-3 demo prompts from intake — QA's bar
├── brief-source.txt             # optional: path/URL of an existing brief (spec condenses it)
├── design-figma-source.txt      # optional: user's Figma URL (design transcribes it)
├── risk-probe.md                # new-feature with external dependency: GO / NO-GO before spec
├── spec.md                      # PM output
├── spec-review.md               # adversarial review of spec
├── design.md                    # UX output (UI spec)
├── design-figma.txt             # optional Figma URL
├── design-review.md             # adversarial review of spec+design
├── distillate.md                # condensed build context (existing patterns to follow)
├── distillate-gaps.md           # engineer-surfaced gaps; triggers distill re-run (deleted after fix)
├── reports/
│   ├── build-cycle-1.md         # one per build cycle
│   ├── build-cycle-2.md
│   ├── build-latest.md          # cp of latest build report
│   ├── qa-cycle-1.md            # one per QA run
│   ├── qa-cycle-2.md
│   └── qa-latest.md             # cp of latest QA report
├── qa-plan.md                   # test plan derived from acceptance criteria (first cycle)
├── screenshots/
│   ├── cycle-1-test-1.png
│   └── ...
├── launch.sh                    # generated launcher (chmod +x)
├── README.md                    # handover copied from <worktree>/README.md at finish
└── worktree-info.txt            # worktree path + branch (written by the coordinator at init)
```

The slug is `kebab-case` derived from the feature name. The date prefix sorts chronologically.

The directory root path is **the single argument every sub-skill receives**. Internally, sub-skills know their own filenames.

### Latest-pointer convention

For multi-cycle artifacts (build reports, QA reports), each cycle is written as `reports/<kind>-cycle-<N>.md` and **also** copied (`cp`, not symlink) to `reports/<kind>-latest.md`. Consumers always read `*-latest.md`. The `cycle-N` archive survives audits; the `latest` pointer is a read shortcut. Use `cp` because symlinks break when `_prototype/` is moved or copied (e.g., for sharing).

### Cycle counter as source of truth

The `N` in `build-cycle-N.md` and `qa-cycle-N.md` is derived from `status.yaml` counters, not by globbing the directory:

```bash
PS=/Users/joliehuang/FirefoxPrototype/bin/proto-status.sh
# Build cycle number for a fresh build
N=$(($($PS get "$DIR" cycles.build) + 1))
# QA cycle number
N=$(($($PS get "$DIR" cycles.qa_runs) + 1))
```

Sub-skills increment via `$PS set "$DIR" cycles.<layer>+=1` *after* writing the report.

---

## 2. status.yaml schema

```yaml
feature: weather-widget-improvements
slug: 2026-04-24-weather-widget-improvements
created: 2026-04-24T16:30:00Z
updated: 2026-04-24T17:45:00Z

# scope drives routing
scope: tweak | new-widget | new-feature

# pipeline phase — coordinator owns this
phase: idea | spec | design | distill | build | qa | done | blocked

# completion flags per phase — coordinator owns these
completed:
  brainstorm: false
  spec: false
  spec_review: false
  design: false
  design_review: false
  distill: false
  build: false
  demo: false         # coordinator only: every demo.md prompt passed live
  qa: false           # coordinator only, after triage

# cycle counters — sub-skills increment their own
cycles:
  spec: 0
  design: 0
  build: 0
  infra: 0
  distill: 0
  qa_runs: 0          # total QA runs (cycle-N report numbering)

# caps — coordinator enforces; user can raise via prompt
caps:
  spec: 1
  design: 2
  build: 3
  infra: 0            # 0 = unlimited
  distill: 1
  demo_fix_rounds: 2  # live-fix rounds QA may spend on a failing demo prompt

# set at init by the coordinator (worktree is created before spec so its build overlaps planning)
project_root: /Users/.../FirefoxPrototype
time_budget_min: 90
worktree:
  path: /Users/.../FirefoxPrototype/worktrees/feature-xyz
  branch: feature-xyz
  base: ai/main

# human-readable blocker if phase=blocked
blocked_on: null

# last sub-skill that ran (debugging)
last_actor: prototype-build
```

### Read/write rules (enforced via `proto-status.sh`)

- **Coordinator** writes: `phase`, all `completed.*` flags, `caps.*`, `blocked_on` (clears after user input).
- **Sub-skills** write: `last_actor`, their own `cycles.<layer>`, their own `completed.<phase>` (excluding `completed.qa`).
- **`completed.qa: true`** is exclusively the coordinator's flag — set only after triaging the latest QA report shows all PASS.
- **`updated`** is auto-stamped by `proto-status.sh set` (don't pass it explicitly unless overriding).

Use `proto-status.sh` (`<project_root>/bin/proto-status.sh`; a copy ships in the coordinator's `scripts/`). Commands: `init`, `set`, `get`, `check-cap <layer>`, `note "<text>"`. Sub-skills should not parse or write YAML by hand.

---

## 3. Sub-skill contract

Every sub-skill receives:

```
Inputs:
  artifact_dir: <absolute path to _prototype/<slug>/>

Read from artifact_dir:
  Whatever previous-phase artifacts the skill needs (declared in its own SKILL.md).

Write to artifact_dir:
  Its own output file(s) per the layout above.
  status.yaml updates ONLY via proto-status.sh.
```

Sub-skills must be **idempotent** — running them twice on the same artifact_dir overwrites their output cleanly. The coordinator decides whether to re-run. The `cp ... latest.md` pattern means the latest pointer always reflects the most recent invocation.

---

## 4. Resumability

When `/prototype` is invoked with no new idea (or with `--resume <slug>` / `--resume <date-feature>`), the coordinator:

1. Lists `_prototype/` directories sorted by `updated`.
2. Reads `status.yaml` of each candidate via `proto-status.sh get`.
3. Picks the one matching the user's hint (or shows a chooser).
4. Reads `phase` and routes to the next required step.

If `phase=blocked`, shows `blocked_on` and asks the user how to proceed.

---

## 5. Cap enforcement

Before spawning any layer's agent, the coordinator checks:

```bash
CYCLE=$($PS get "$DIR" cycles.<layer>)
CAP=$($PS get "$DIR" caps.<layer>)
if [ "$CYCLE" -ge "$CAP" ] && [ "$CAP" -gt 0 ]; then
  $PS set "$DIR" phase=blocked blocked_on="<layer> cap reached, N tests still failing"
  # surface to user; do not silently respawn
fi
```

User can raise the cap via the prompt: `caps.build=5`. The coordinator never silently exceeds.

---

## 6. Cleanup

A run is "done" when `phase: done`. The directory is preserved indefinitely as a record. `push-to-demo` (if invoked) copies the worktree's built `Nightly.app` + `profile-default` + `launch.sh` into the demos dir; the artifact dir stays put as the audit trail.
