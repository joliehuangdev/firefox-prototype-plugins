# prototype

Part of the `/prototype` family. Install all seven plugins with the two commands in the [main README](../README.md#installation), then run `/prototype setup`.

Coordinator for the Firefox Smart Window prototype pipeline.

## Setup

`/prototype setup` once per machine: creates the project folders under `~/FirefoxPrototype` (or a folder you name), installs the helper scripts into its `bin/`, writes the artifact-build mozconfig, and lists what needs you (clone, bootstrap, first build, golden profile). The scripts live in `skills/prototype/scripts/`; `bin/` gets copies, refreshed at the start of every run.

## Flow

1. **Intake**, one question at a time: scope (tweak / new widget / new feature), the 2–3 demo prompts, existing inputs (brief, Figma, branch), setup needs (where keys live), time budget.
2. **Init**: artifact dir `<project_root>/_prototype/<date>-<slug>/`, worktree via `bin/new-prototype.sh <slug> [base]`, first `./mach build` in the background.
3. **Tweak**: the coordinator edits, builds, smokes and finishes itself. No agents.
4. **Risk probe** (new feature with an external dependency): one 45-min agent tries the riskiest thing on the existing build. NO-GO stops the run.
5. **Spec** → **spec review ‖ design ‖ distill** → **design review**, each with a size limit; one trim request max.
6. **Build**: one engineer in the worktree; kept alive and messaged for fixes.
7. **QA**: smoke, then every demo prompt live, then ≤5 more. Live fix loop for `build` failures, capped per demo prompt.
8. **Triage** by class with caps, re-test only failures, then **handover**: README in the worktree, run command, offer to push the branch (and `/push-to-demo`, if you have that separate skill).

After every phase: `[phase] 9 min · 147k tokens · total 23/90 min`. At the budget, it stops and asks.

## State

`status.yaml` is mutated only through `proto-status.sh` (`init`, `set`, `get`, `check-cap <layer>`, `note`). The coordinator owns `phase`, `completed.*` (including `completed.demo`), `caps.*`; sub-skills set their own `cycles.*` and `last_actor`. See `skills/prototype/references/artifact-convention.md`.

## Resume

`/prototype resume` lists `_prototype/` by recency, reads `status.yaml`, and continues from `phase`.
