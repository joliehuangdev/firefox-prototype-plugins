---
name: prototype
description: Coordinator skill that orchestrates the full prototype pipeline for Firefox Smart Window. Use when the user says "prototype", "build a prototype", "let's prototype", or provides a product idea they want turned into a working Smart Window prototype end-to-end. Also use with "resume prototype" to continue a stalled run.
version: 2.0.0
---

# Prototype Pipeline Coordinator

You orchestrate Firefox Smart Window prototypes end-to-end. You route the work across specialized sub-skills (PM, UX, reviewer, distiller, engineer, QA), persist all artifacts to disk for resumability, and adapt the depth of the pipeline to the **scope** of the work.

## Core Architecture

**Filesystem is the source of truth.** Every sub-skill reads inputs from a per-prototype directory and writes outputs back. The conversation is the orchestration layer; the directory is the state.

See:
- `references/artifact-convention.md` — the directory layout and `status.yaml` schema
- `references/smartwindow-design-system.md` — what every design/build agent must reference

Both files live next to this SKILL.md. When you spawn sub-skills, pass the `artifact_dir` path; they know to consult these references themselves.

---

## Step 0 — Determine if this is a new run or a resume

If the user said "resume" / "continue" / "pick up the prototype" / mentioned a feature name:
- List `~/FirefoxPrototype/_prototype/` directories sorted by mtime descending
- Read `status.yaml` of the top candidate (or the one matching their hint)
- Show them: feature name, current `phase`, `blocked_on` if any, last `updated` time
- Ask "resume this one?" — if yes, jump to the step matching `phase`

Otherwise this is a new run — proceed to Step 1.

---

## Step 1 — Capture the idea + classify scope

The user's idea comes from `$ARGUMENTS` or the prior conversation.

**Ask one question** (and only one): scope.

> Quick sizing check — is this:
>
> 1. **Tweak** — modify an existing widget/tool (e.g., "fix the weather error state", "add a unit toggle to the forecast")
> 2. **New widget** — new artifact reusing existing patterns (e.g., "add a stocks widget like weather but for tickers")
> 3. **New feature** — new tool, new artifact, possibly new actor messages (e.g., "let users save trip itineraries to a Smart Window list")
>
> Reply with the number.

Scope drives the depth of the pipeline:

| Scope | Brainstorm | Spec | Spec review | Design | Design review | Distill | Build | QA |
|---|---|---|---|---|---|---|---|---|
| tweak | skip | quick | skip | skip | skip | skip | yes | yes |
| new-widget | skip | full | yes | full | yes | yes | yes | yes |
| new-feature | yes | full | yes | full | yes | yes | yes | yes |

If the user can't pick (it's genuinely a hybrid), default to **new-widget** — you can route around steps later if it turns out smaller.

---

## Step 2 — Initialize the artifact directory

Generate a slug: `<YYYY-MM-DD>-<feature-slug-from-idea>` (kebab-case, lowercase, no special chars).

Create the directory:

```bash
mkdir -p "/Users/joliehuang/FirefoxPrototype/_prototype/<slug>/screenshots"
```

Write `idea.md` with the user's verbatim idea (no editing — this is the audit record).

Write initial `status.yaml`:

```yaml
feature: <human readable>
slug: <slug>
created: <iso>
updated: <iso>
scope: tweak | new-widget | new-feature
phase: idea
completed:
  brainstorm: false
  spec: false
  spec_review: false
  design: false
  design_review: false
  distill: false
  build: false
  qa: false
qa_cycles:
  spec: 0
  design: 0
  build: 0
  infra: 0
worktree:
  path: null
  branch: null
blocked_on: null
last_actor: prototype-coordinator
```

Tell the user the artifact dir path. They can `tail -f status.yaml` if they want to follow along.

---

## Step 3 — Brainstorm (scope=new-feature only)

Spawn the brainstorm skill via subagent. Pass the artifact_dir; the skill writes `brainstorm.md`.

```
Agent(subagent_type: "general-purpose", description: "Brainstorm new feature space")
```

Prompt:
> Use the /brainstorm skill on the idea in `<artifact_dir>/idea.md`. Write the resulting brainstorm to `<artifact_dir>/brainstorm.md`. Apply BMAD's anti-bias protocol — shift the creative domain (technical, UX, business, edge-case) every 10 ideas to avoid semantic clustering. Update `status.yaml`: `phase: brainstorm`, `completed.brainstorm: true`, `last_actor: brainstorm`.

Update `status.yaml` `phase: spec`, then proceed.

---

## Step 4 — Spec (PM)

Spawn the PM agent. The spec skill reads `idea.md` (and `brainstorm.md` if it exists), writes `spec.md`.

```
Agent(subagent_type: "general-purpose", description: "PM spec generation")
```

Prompt:
> Use the /prototype-spec skill. Artifact dir: `<artifact_dir>`. For scope=tweak, focus only on what changes from the existing implementation; skip full user-stories ceremony. Otherwise produce the full spec. Read `idea.md` (and `brainstorm.md` if present). Write `spec.md`. Update `status.yaml`: `phase: spec`, `completed.spec: true`, `last_actor: prototype-spec`.

---

## Step 5 — Parallel: spec review + design (skips for tweak)

For scope=tweak: skip to Step 7 (Distill).

For new-widget and new-feature: spawn **two subagents in parallel** in a single message:

1. **prototype-review** on the spec
2. **prototype-design** on the spec

```
Agent(subagent_type: "general-purpose", description: "Adversarial spec review")
Agent(subagent_type: "general-purpose", description: "UX design")
```

This is a Party Mode-style parallelization: the reviewer and designer don't depend on each other's output, and serializing them wastes a round-trip.

Reviewer prompt:
> Use the /prototype-review skill. Artifact dir: `<artifact_dir>`. Mode: spec-review. Read `idea.md`, `spec.md`. Write `spec-review.md`. Force at least 3 findings across at least 2 dimensions. Update `status.yaml`: `completed.spec_review: true`, `last_actor: prototype-review`. If verdict=HALT, set `phase: blocked` and `blocked_on`.

Designer prompt:
> Use the /prototype-design skill. Artifact dir: `<artifact_dir>`. Read `spec.md`. Reference `/Users/joliehuang/.claude/my-plugins/prototype/references/smartwindow-design-system.md` before proposing tokens or layouts. Write `design.md` (and `design-figma.txt` if Figma MCP available). Update `status.yaml`: `phase: design`, `completed.design: true`, `last_actor: prototype-design`.

After both complete, **read `spec-review.md`**:
- If verdict is HALT or has BLOCKER findings → present them to the user, ask whether to fix the spec (re-run spec) or override and proceed. Set `phase: blocked` until they decide.
- If PASS WITH FIXES → show the user the major findings and proceed (designer already worked off the unfixed spec, but the engineer will see the review too).
- If PASS → proceed silently.

---

## Step 6 — Design review (gate before build)

For new-widget and new-feature only. Spawn one reviewer subagent over spec + design:

```
Agent(subagent_type: "general-purpose", description: "Adversarial design review")
```

Prompt:
> Use the /prototype-review skill. Artifact dir: `<artifact_dir>`. Mode: design-review (because `design.md` exists and `design-review.md` does not). Read `spec.md`, `design.md`. Write `design-review.md`. Force at least 3 findings. Update `status.yaml`: `completed.design_review: true`, `last_actor: prototype-review`.

Same verdict handling as Step 5: HALT/BLOCKER → user gate; otherwise proceed.

---

## Step 7 — Distill build context

Spawn the distillator:

```
Agent(subagent_type: "general-purpose", description: "Distill build context")
```

Prompt:
> Use the /prototype-distill skill. Artifact dir: `<artifact_dir>`. Read `spec.md` (and `design.md` if exists). Read the Firefox checkout at `/Users/joliehuang/FirefoxPrototype/firefox/`. Produce `distillate.md`. Update `status.yaml`: `phase: distill`, `completed.distill: true`, `last_actor: prototype-distill`.

For scope=tweak the distillate is small (just the file to modify + the immediate pattern). For new-feature the distillator may dispatch its own internal parallel sub-agents per pattern target.

---

## Step 8 — Build (engineer, in worktree)

Spawn the engineer with worktree isolation:

```
Agent(subagent_type: "general-purpose", description: "Prototype build", isolation: "worktree")
```

Prompt:
> Use the /prototype-build skill. Artifact dir: `<artifact_dir>`. Read `spec.md`, `design.md` (if exists), `distillate.md`. Reference `/Users/joliehuang/.claude/my-plugins/prototype/references/smartwindow-design-system.md` before writing CSS. Build the prototype. Write `build-report-<N>.md` (N = current build cycle, starting at 1). Generate `launch.sh` in the artifact dir. Update `status.yaml`: `phase: build`, `completed.build: true`, `last_actor: prototype-build`, and set `worktree.path` and `worktree.branch` from your isolation context.

Extract the worktree path and branch from the Agent result and confirm they match what the engineer wrote into status.yaml.

If the build fails (compile error, not test failure): re-spawn the engineer with the build error and the unchanged artifact dir. Loop max 3 build cycles. After that, surface the error to the user.

---

## Step 9 — QA

Spawn the QA agent:

```
Agent(subagent_type: "general-purpose", description: "Prototype QA")
```

Prompt:
> Use the /prototype-qa skill. Artifact dir: `<artifact_dir>`. Read `spec.md` (acceptance criteria), `design.md` (visual expectations if exists), `worktree-info.txt`. Launch the prototype via the worktree's `run.command` (which writes `<worktree>/.marionette-port` for you to read). Run the full QA cycle. Write `qa-plan.md` (first cycle only) and `qa-report-<N>.md` (N = current QA cycle). Save screenshots to `<artifact_dir>/screenshots/`. **Classify each failure** as `spec | design | build | infra`. Update `status.yaml`: `phase: qa`, `completed.qa: true` (only if PASS), `last_actor: prototype-qa`, increment the appropriate `qa_cycles.*` counter for any failures.

---

## Step 10 — QA failure triage and routing

Read the latest `qa-report-<N>.md`. For each failure, look at its **classification label**:

| Classification | Route to | Notes |
|---|---|---|
| `spec` | `/prototype-spec` (re-run with QA failure context) | Acceptance criterion was unclear or wrong; spec edit needed |
| `design` | `/prototype-design` (re-run with QA failure context) | Layout broke / state missing / tokens wrong |
| `build` | `/prototype-build` (re-run with QA failure context) | Implementation bug |
| `infra` | Fix in-place (profile prefs, FxA, port) — no re-spawn | QA usually self-fixes these per its own skill |

Group failures by classification. **If multiple classifications, run the highest-leverage layer first** (spec → design → build). Re-spawn the appropriate skill with:

- The artifact_dir
- The specific failures from the QA report
- Instruction to update its own artifact file (spec.md, design.md, or generate build-report-2.md)

After re-running, **always go back through QA** (Step 9) to verify.

**Caps per layer** (read from `status.yaml.qa_cycles`):
- spec: 1 (re-spec is heavy; one round only)
- design: 2
- build: 3
- infra: unlimited (these are environment fixes, not code)

If any cap is hit and tests still fail, set `phase: blocked`, `blocked_on: "<layer> hit cycle cap with N tests still failing"`, and surface to the user.

---

## Step 11 — Final report

When QA passes:

- Set `status.yaml`: `phase: done`, `completed.qa: true`, `updated: <iso>`
- Summarize for the user:
  - Feature name + scope
  - Where artifacts live (`_prototype/<slug>/`)
  - Where the worktree + branch lives
  - How to run (`<artifact_dir>/launch.sh` or `worktree/<path>` + `./mach run`)
  - Total cycles by layer (from `qa_cycles`)
  - Any deferred items from spec-review / design-review that the user explicitly waved through
- Ask if they want to push to demo (`/push-to-demo`).

---

## Rules

- **Filesystem is the source of truth.** Always pass `artifact_dir` to sub-skills, never paste the spec body into a prompt. Sub-skills read it from disk.
- **Parallelize independent work.** Spec-review and design in Step 5 are independent — fire them in a single message with two Agent calls.
- **One human gate by default**, after spec is reviewed (Step 5). Add gates only when reviews surface BLOCKERs.
- **Adapt depth to scope.** Don't run brainstorm + spec-review + design-review for a 3-line CSS tweak. Don't skip them for a new feature.
- **QA failure triage matters more than retry count.** A "build" failure that's actually a "spec" failure burns a build cycle. Honor the classification.
- **Never read sub-skill outputs from the conversation.** Always read from disk. The conversation's copy may be stale or truncated.
- **Resumability is non-negotiable.** Every sub-skill must update `status.yaml` so the next invocation knows where to pick up.
- **Worktree isolation only on build.** Other sub-skills work against the persistent artifact_dir directly.
- **Default checkout path** is `/Users/joliehuang/FirefoxPrototype/firefox/`. If the user has a different layout, they'll tell you in idea.md or via Step 1.
