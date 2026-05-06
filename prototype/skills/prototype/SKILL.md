---
name: prototype
description: Coordinator skill that orchestrates the full prototype pipeline for Firefox Smart Window. Use when the user says "prototype", "build a prototype", "let's prototype", or provides a product idea they want turned into a working Smart Window prototype end-to-end. Also use with "resume prototype" to continue a stalled run.
version: 3.0.0
---

# Prototype Pipeline Coordinator

You orchestrate Firefox Smart Window prototypes end-to-end. You route work across specialized sub-skills (PM, UX, reviewer, distiller, engineer, QA), persist artifacts to disk for resumability, and adapt depth to the **scope** of the work.

## Core architecture

**Filesystem is the source of truth.** Every sub-skill reads inputs from a per-prototype directory and writes outputs back. The conversation is the orchestration layer; the directory is the state.

References (next to this SKILL.md, in `../references/`):

- `artifact-convention.md` — directory layout, status.yaml schema, latest-pointer rule
- `smart-window-arch.md` — Smartbar/chat/artifacts/tools concepts (sub-skills load this)
- `smartwindow-design-system.md` — token + component inventory (designers + engineers)
- `launcher-and-profile.md` — golden profile, Marionette pref injection, port handling, `./mach build` vs `faster` auto-detect
- `widget-llm-coexistence.md` — convId rules, engine-failure handling
- `live-fix-loop.md` — QA's in-place debug protocol for `build`-class failures

The shared `proto-status.sh` helper at `/Users/joliehuang/FirefoxPrototype/bin/proto-status.sh` is the only sanctioned way to mutate `status.yaml`. Use it from every sub-skill prompt.

## State helper (use everywhere)

```bash
DIR="<artifact_dir>"
PS=/Users/joliehuang/FirefoxPrototype/bin/proto-status.sh
$PS init "$DIR" feature="X" slug="2026-..." scope=new-widget
$PS set "$DIR" phase=design completed.spec=true last_actor=prototype-spec
$PS set "$DIR" cycles.build+=1
$PS get "$DIR" cycles.build
```

The helper auto-stamps `updated`. **Sub-skills should never write status.yaml by hand.**

---

## Step 0 — Resume vs new

If the user said "resume" / "continue" / "pick up the prototype" / mentioned a feature name:

```bash
ls -1t ~/FirefoxPrototype/_prototype/ | head -10
```

Read `status.yaml` of the top candidate (or one matching the user's hint) via `proto-status.sh get`. Show: feature, current `phase`, `blocked_on`, `updated`. Ask "resume this one?" — if yes, jump to the step matching `phase`.

Otherwise this is a new run — proceed to Step 1.

---

## Step 1 — Capture idea + scope (one question only)

The user's idea comes from `$ARGUMENTS` or the prior conversation.

Ask:

> Quick sizing — is this:
>
> 1. **Tweak** — modify an existing widget/tool ("fix the weather error state")
> 2. **New widget** — new artifact reusing existing patterns ("add a stocks widget like weather")
> 3. **New feature** — new tool/artifact/actor messages ("save trip itineraries to a list")
>
> Reply with the number.

Scope drives pipeline depth:

| Scope        | Brainstorm | Spec  | Spec review     | Design | Design review | Distill | Build | QA  |
| ------------ | ---------- | ----- | --------------- | ------ | ------------- | ------- | ----- | --- |
| tweak        | skip       | quick | skip            | skip   | skip          | quick   | yes   | yes |
| new-widget   | skip       | full  | informational   | full   | yes           | yes     | yes   | yes |
| new-feature  | inline (1) | full  | yes             | full   | yes           | yes     | yes   | yes |

(1) Brainstorm for new-feature is **inline in the coordinator** — ask 2-3 sharpening questions ("what is the success metric?", "which tab references matter?", "what's explicitly out of scope?"), capture answers in `idea.md` as a `## Scoping notes` section. No subagent spawn. If the idea is already a complete brief (PRD, multi-paragraph product brief, linked design ref), skip — note "brainstorm: skipped — idea is a complete brief" in status notes.

For new-widget, spec-review is **informational** (findings shown, but no HALT/PASS gate; designer can read them as they work). For new-feature, spec-review still gates.

---

## Step 2 — Initialize artifact directory

Generate slug: `<YYYY-MM-DD>-<feature-slug>` (kebab-case, lowercase).

```bash
DIR=~/FirefoxPrototype/_prototype/<slug>
mkdir -p "$DIR/screenshots" "$DIR/reports"
echo "<verbatim user idea>" > "$DIR/idea.md"
$PS init "$DIR" feature="<human readable>" slug="<slug>" scope=<scope>
```

Tell the user the path. They can `tail -f $DIR/status.yaml` to follow along.

---

## Step 3 — Spec (PM)

Spawn the PM agent.

```
Agent(subagent_type: "general-purpose", description: "PM spec generation")
```

Prompt:

> Use the /prototype-spec skill. `artifact_dir`: `<path>`. Read `idea.md` and `status.yaml`. For scope=tweak produce a focused diff-style spec (~30-60 lines). Otherwise produce the full spec. Write `spec.md`. After writing, run `/Users/joliehuang/FirefoxPrototype/bin/proto-status.sh set "$artifact_dir" phase=spec completed.spec=true last_actor=prototype-spec`.

---

## Step 4 — Three-way parallel: spec-review + design + distill

For scope=tweak: skip review and design; go straight to distill (Step 5) then build.

For new-widget and new-feature: spawn **three subagents in parallel** in a single message — spec-review, design, AND distill. Distill only needs `spec.md`, so it can fan out alongside design instead of waiting.

```
Agent(general-purpose, "Adversarial spec review")
Agent(general-purpose, "UX design")
Agent(general-purpose, "Distill build context")
```

Reviewer prompt:

> Use the /prototype-review skill. `artifact_dir`: `<path>`. Mode: spec-review. Read `idea.md`, `spec.md`. Write `spec-review.md`. Scope is `<scope>` — for new-widget treat findings as informational (no HALT). For new-feature, force ≥3 findings and gate with verdict. After writing, `proto-status.sh set "$artifact_dir" completed.spec_review=true last_actor=prototype-review`. If verdict is HALT, also `set phase=blocked blocked_on="spec review found N blockers"`.

Designer prompt:

> Use the /prototype-design skill. `artifact_dir`: `<path>`. Read `spec.md`. Reference `<plugin-root>/references/smart-window-arch.md` and `<plugin-root>/references/smartwindow-design-system.md` before proposing tokens or layouts. Write `design.md` (and `design-figma.txt` if Figma MCP available). After writing, `proto-status.sh set "$artifact_dir" phase=design completed.design=true last_actor=prototype-design`.

Distill prompt:

> Use the /prototype-distill skill. `artifact_dir`: `<path>`. Read `spec.md`. Read the Firefox checkout at `/Users/joliehuang/FirefoxPrototype/firefox/`. Produce `distillate.md`. After writing, `proto-status.sh set "$artifact_dir" completed.distill=true last_actor=prototype-distill`.

After all three complete, **read `spec-review.md`** from disk:

- HALT or BLOCKER (new-feature only) → present findings to user, ask to fix-and-respec or override. If respec: re-run Step 3 with the review attached. Then re-run distill (it may need updating).
- PASS WITH FIXES → show major findings, proceed.
- PASS / informational-only → proceed silently.

For `<plugin-root>` substitute `/Users/joliehuang/.claude/my-plugins/prototype`.

---

## Step 5 — Design review (gate before build)

For new-widget and new-feature only.

```
Agent(general-purpose, "Adversarial design review")
```

Prompt:

> Use the /prototype-review skill. `artifact_dir`: `<path>`. Mode: design-review. Read `spec.md`, `design.md`. Write `design-review.md`. Force ≥3 findings. After writing, `proto-status.sh set "$artifact_dir" completed.design_review=true last_actor=prototype-review`. If HALT, set `phase=blocked blocked_on=...`.

HALT/BLOCKER → user gate. Otherwise proceed.

---

## Step 6 — Build (engineer, in worktree)

Read caps before spawning. If `cycles.build >= caps.build`, halt with `blocked_on: "build cap reached"` — never silently exceed.

```
Agent(general-purpose, "Prototype build", isolation: "worktree")
```

Prompt:

> Use the /prototype-build skill. `artifact_dir`: `<path>`. Read `spec.md`, `design.md` (if exists), `distillate.md`, `spec-review.md` and `design-review.md` (if exist). Reference `<plugin-root>/references/smart-window-arch.md`, `smartwindow-design-system.md`, `launcher-and-profile.md`. Build the prototype.
>
> Cycle number: read with `proto-status.sh get "$artifact_dir" cycles.build` (your output goes to `reports/build-cycle-<N+1>.md`; also write `reports/build-latest.md` as a copy or symlink).
>
> Generate `launch.sh`. Write `worktree-info.txt` with worktree path + branch. After successful build: `proto-status.sh set "$artifact_dir" phase=build completed.build=true last_actor=prototype-build worktree.path=<path> worktree.branch=<branch> cycles.build+=1`. If build fails, see "distillate gaps" below.

Extract worktree path/branch from the Agent result and verify.

### Build failure handling (NEW)

If `./mach build faster` fails (compile error, not test failure):

1. The engineer should write `distillate-gaps.md` if the failure stems from missing/wrong distillate guidance (missing imports, wrong actor IPC pattern, missing moz.build entry, etc.).
2. If `distillate-gaps.md` was written, **re-run distill first** (cheap, narrow):
   ```
   Agent(general-purpose, "Distill update")
   ```
   Prompt:
   > Use the /prototype-distill skill. `artifact_dir`: `<path>`. Read existing `distillate.md` and `distillate-gaps.md`. Update `distillate.md` to address the gaps. Increment `cycles.distill+=1`.

   Then re-spawn the engineer with the updated distillate.
3. If no distillate gap (engineer's own bug), re-spawn the engineer directly.
4. **Cap on build retries:** `cycles.build < caps.build`. If at cap → `phase=blocked blocked_on="build cap reached"`, surface to user with the latest build error.

---

## Step 7 — QA

```
Agent(general-purpose, "Prototype QA")
```

Prompt:

> Use the /prototype-qa skill. `artifact_dir`: `<path>`. Read `spec.md`, `design.md` (if exists), `worktree-info.txt`, `reports/build-latest.md`. Reference `<plugin-root>/references/launcher-and-profile.md`.
>
> Cycle number: read with `proto-status.sh get "$artifact_dir" cycles.qa_runs` then increment. Write to `reports/qa-cycle-<N+1>.md` (also `reports/qa-latest.md`).
>
> Save screenshots to `screenshots/cycle-<N+1>-<test-name>.png`. **Classify each failure** as `spec | design | build | infra`.
>
> **If failures are exclusively `build`-class AND `cycles.build < caps.build`**, you MAY enter the live fix loop per `<plugin-root>/references/live-fix-loop.md`. Otherwise write the report and exit; the coordinator will route.
>
> Update status.yaml with the appropriate cycle counters via `proto-status.sh`. **Do NOT set `completed.qa: true`** — the coordinator owns that flag.

---

## Step 8 — Triage and route

Read `reports/qa-latest.md`. For each failure, check classification. If all PASS:

```bash
$PS set "$DIR" phase=done completed.qa=true last_actor=prototype-coordinator
```

→ Step 9.

Otherwise, group failures by classification. Run highest-leverage layer first (spec → design → build). Check caps before each respawn.

| Class    | Route to            | Cap (default) | Notes                                               |
| -------- | ------------------- | ------------- | --------------------------------------------------- |
| `spec`   | `/prototype-spec`   | 1             | Acceptance criterion was unclear/wrong              |
| `design` | `/prototype-design` | 2             | Layout/state/tokens broken                          |
| `build`  | `/prototype-build`  | 3             | Implementation bug; may have been live-fix-tried    |
| `infra`  | (QA self-fixed)     | unlimited     | Profile, port, FxA — no respawn                     |

For each layer that needs a respawn, prompt includes:
- `artifact_dir`
- "Read `reports/qa-latest.md` for failures classified as `<your-layer>`"
- "Read your existing artifact (spec.md / design.md / latest build report) and revise"
- "Increment your own `cycles.<layer>+=1`"

After respawn(s), **always loop back to Step 7 (QA)** to verify.

If any cap is reached and tests still fail:

```bash
$PS set "$DIR" phase=blocked blocked_on="<layer> cap reached, N tests still failing"
```

Surface to the user with: failing tests, classifications, and last fix attempts. Ask whether to raise the cap (`caps.<layer>` adjustment), pivot strategy, or accept partial.

---

## Step 9 — Final report

When QA passes:

```bash
$PS set "$DIR" phase=done completed.qa=true last_actor=prototype-coordinator
```

Summarize for the user:

- Feature + scope
- Artifact dir path
- Worktree + branch
- Run command (`<DIR>/launch.sh` or `<worktree>/run.command`)
- Total cycles by layer (read from `cycles.*`)
- Any deferred items from spec/design reviews the user waved through

Ask if they want to push to demo (`/push-to-demo`).

---

## Rules

- **Filesystem is the source of truth.** Always pass `artifact_dir`. Never paste spec/design content into prompts.
- **Use `proto-status.sh`.** Sub-skills must not write `status.yaml` directly.
- **Coordinator owns `phase` and `completed.*` transitions** (per `artifact-convention.md`). Sub-skills set their own counters and `last_actor`. The qa skill is forbidden from writing `completed.qa: true` — only the coordinator does after triage.
- **Parallelize.** Spec-review + design + distill are independent — fire all three in one message after spec is written.
- **Adapt depth to scope.** Don't run brainstorm + reviews for a CSS tweak. Don't skip them for a new feature.
- **Caps gate, don't drift.** Every spawn checks `cycles.X < caps.X`. Hitting a cap halts and surfaces; never silently retries.
- **Distillate gaps trigger distill re-run.** Engineer's reported gaps update the distillate before another build attempt — don't burn build cycles on the same missing pattern.
- **Live fix loop is QA's choice.** QA decides whether to enter the in-place fix loop based on failure classification + remaining build budget. The coordinator only routes when QA exits.
- **Default checkout** is `/Users/joliehuang/FirefoxPrototype/firefox/`. Otherwise the user says so in `idea.md`.
