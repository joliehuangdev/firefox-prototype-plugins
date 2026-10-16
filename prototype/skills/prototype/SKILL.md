---
name: prototype
description: Coordinator skill that orchestrates the full prototype pipeline for Firefox Smart Window. Use when the user says "prototype", "build a prototype", "let's prototype", or provides a product idea they want turned into a working Smart Window prototype end-to-end. Also use with "resume prototype" to continue a stalled run, and with "prototype setup" to set up a new machine.
version: 3.2.1
---

# Prototype Pipeline Coordinator

You take a Smart Window idea to a demoable, QA'd build in a Firefox worktree. You route work to sub-skills (PM, reviewer, UX, distiller, engineer, QA), keep every artifact on disk, and adapt depth to **scope**. You are also the budget owner: you report progress after every phase and stop when the time budget is spent.

**Filesystem is the source of truth.** Sub-skills read inputs from the artifact directory and write outputs back. Never paste spec or design text into prompts.

## Paths and helpers

Set these once at intake and pass them in every sub-agent prompt:

```bash
SCRIPTS=<this skill's base directory>/scripts         # plugin copy of the helpers; the source of truth
PROJECT_ROOT=$HOME/FirefoxPrototype                   # default; ask if it doesn't exist
PS="$PROJECT_ROOT/bin/proto-status.sh"                # status.yaml helper (init/set/get/check-cap/note)
NEWWT="$PROJECT_ROOT/bin/new-prototype.sh"            # worktree creator: <name> [base-ref]
DIR="$PROJECT_ROOT/_prototype/<slug>"                 # artifact dir
```

If `$HOME/FirefoxPrototype` doesn't exist, ask the user where their prototype root is (the folder holding `firefox/`, `worktrees/`, `_prototype/`, `bin/`), or offer `/prototype setup` to create it.

Then run the preflight: `bash "$SCRIPTS/setup.sh" --preflight "$PROJECT_ROOT"`. It installs or refreshes the helper scripts in `$PROJECT_ROOT/bin/` from the plugin and prints only problems. On a non-zero exit, show its output, offer `/prototype setup` and stop. A missing golden profile is only a warning, but tell the user at intake: build smoke and QA can't launch Firefox until it is seeded. **Sub-skills must never write `status.yaml` by hand.**

References in `references/` next to this SKILL.md: `artifact-convention.md` (layout, status schema), `smart-window-arch.md`, `smartwindow-design-system.md`, `launcher-and-profile.md`, `widget-llm-coexistence.md`, `live-fix-loop.md`. Each sub-skill ships its own copy of the ones it needs.

## Progress and budget (every phase)

Each `Agent` result ends with `<usage>subagent_tokens: N tool_uses: N duration_ms: N</usage>`. After every phase print one line:

```
[spec] 9 min · 147k tokens · total 23/90 min
```

When the total passes `time_budget_min` (set at intake), finish the current agent, then **stop and ask** before spawning anything else. Record the pause with `$PS set "$DIR" phase=blocked blocked_on="time budget reached at <phase>"`.

---

## Setup (`/prototype setup`)

When `$ARGUMENTS` is `setup`, set up this machine instead of running the pipeline:

1. Resolve `PROJECT_ROOT` as above. Create a missing root only if the user agrees.
2. Run `bash "$SCRIPTS/setup.sh" "$PROJECT_ROOT"` and show its report. It creates the folders, the helper scripts in `bin/`, `~/.firefox-prototype-mozconfig` (artifact builds) and the `ai` remote, then lists what needs the user, in order.
3. Offer each "Needs you" item as its own question, in that order:
   - **Clone Firefox** (several GB): on yes, run `bash "$SCRIPTS/setup.sh" --clone-firefox "$PROJECT_ROOT"` with `run_in_background: true`.
   - **Bootstrap** asks questions, so the user runs the printed `./mach bootstrap` command in their own terminal. Wait for them.
   - **First build** (artifact build, about 12 min): on yes, run the printed command with `run_in_background: true`.
   - **Golden profile**, after the build: run `$PROJECT_ROOT/bin/seed-golden.sh` with `run_in_background: true` (it returns when Firefox quits). Firefox opens on a new, empty profile; the user signs in with their own Firefox Account, sends 3 Smart Window messages and quits with Cmd-Q. Then run `verify-golden.sh`. Never copy an existing profile into the golden one.
4. Figma MCP is optional. Say whether `mcp__figma__*` tools are available in this session; if not, give the install command from the report.
5. Rerun `setup.sh` and show the final report. Don't start a prototype.

---

## Step 0 — Resume vs new

If the user says resume / continue / names a past feature:

```bash
ls -1t "$PROJECT_ROOT/_prototype/" | head -10
```

Read the candidate's `status.yaml` via `$PS get`. Show feature, `phase`, `blocked_on`, `updated`. Ask "resume this one?" and jump to the step matching `phase`. Otherwise go to Step 1.

---

## Step 1 — Intake (ask one question at a time)

The idea comes from `$ARGUMENTS` or the conversation. Ask these in order, each as its own question, skipping any the user already answered:

1. **Scope.** 1 = tweak (change an existing widget/tool), 2 = new widget (new artifact on existing patterns), 3 = new feature (new tool/actor/flow).
2. **Demo prompts.** "Give me the 2–3 exact prompts you'll type to show this off." These become `demo.md` and are what QA must make pass.
3. **Existing inputs.** Brief or PRD (path/URL), Figma URL, a branch to extend. A brief means spec *condenses* it instead of expanding. A Figma URL means design *imports* it instead of inventing. A branch means the worktree starts from it.
4. **Setup needs.** API keys, local servers, accounts. Ask where the key file lives now, not mid-build. Never ask for the key value itself.
5. **Time budget.** Default 20 min (tweak), 45 (new widget), 90 (new feature). Confirm or change.

For new-feature, also ask the 2–3 sharpening questions inline (success metric, which tabs matter, explicit non-goals). No brainstorm agent. Capture answers under `## Scoping notes` in `idea.md`.

Scope drives depth:

| Scope       | Risk probe | Spec  | Spec review   | Design | Design review | Distill | Build          | QA           |
| ----------- | ---------- | ----- | ------------- | ------ | ------------- | ------- | -------------- | ------------ |
| tweak       | –          | –     | –             | –      | –             | –       | you, inline    | you, inline  |
| new-widget  | –          | short | informational | short  | yes           | yes     | engineer agent | QA agent     |
| new-feature | if ext dep | full  | gates         | full   | yes           | yes     | engineer agent | QA agent     |

---

## Step 2 — Initialize: artifact dir, worktree, background build

```bash
SLUG=<YYYY-MM-DD>-<feature-slug>        # kebab-case
DIR="$PROJECT_ROOT/_prototype/$SLUG"
mkdir -p "$DIR/screenshots" "$DIR/reports"
printf '%s\n' "<verbatim idea>" > "$DIR/idea.md"
printf '%s\n' "<the demo prompts, one per line, numbered>" > "$DIR/demo.md"
[ -n "<figma url>" ] && echo "<figma url>" > "$DIR/design-figma-source.txt"
[ -n "<brief path or url>" ] && echo "<brief>" > "$DIR/brief-source.txt"
$PS init "$DIR" feature="<name>" slug="$SLUG" scope=<scope> project_root="$PROJECT_ROOT" time_budget_min=<N>
```

Create the worktree **now**, not at build time, and start its first build in the background so the ~10 min artifact build overlaps with spec/design:

```bash
WT_NAME=<feature-slug>                              # no date prefix
"$NEWWT" "$WT_NAME" <base-ref>                      # base: the user's branch, else ai/main
WT="$PROJECT_ROOT/worktrees/$WT_NAME"
$PS set "$DIR" worktree.path="$WT" worktree.branch="$WT_NAME" worktree.base=<base-ref>
printf 'path: %s\nbranch: %s\n' "$WT" "$WT_NAME" > "$DIR/worktree-info.txt"
```

Then run `cd "$WT" && MOZCONFIG=$HOME/.firefox-prototype-mozconfig ./mach build` with `run_in_background: true` and note the task id. If the worktree already exists (extending a branch), skip creation and just build.

Tell the user the artifact dir and worktree. Print the first progress line.

### Tweak path (no sub-agents)

For scope=tweak you do the work yourself in `$WT`: write a 10-line `plan.md` (files, change, how you'll verify), make the edit, `./mach build faster`, launch via `"$WT/run.command"`, run the demo prompt through Marionette (patterns in the QA skill), screenshot to `screenshots/`, write `reports/build-cycle-1.md`. Set `phase=done completed.build=true completed.demo=true completed.qa=true`. Go to Step 9. Spawn the QA agent only if the user asks for a full pass.

---

## Step 3 — Risk probe (new-feature with an external dependency)

If the feature depends on something you cannot control (third-party API, agent service, a specific live site), run one time-boxed probe **before** spec. Budget: 60 min, counted against the total.

```
Agent(general-purpose, "Risk probe: <dependency>")
```

> On the existing build in `<WT>` (wait for the background build task `<id>` if it has not finished), try the single riskiest thing the feature needs: `<one sentence, e.g. "drive Google Flights' From/To dialog with typed text via the existing /browse loop">`. Use the demo prompt in `<DIR>/demo.md` as the goal. Time box 45 minutes. Write `<DIR>/risk-probe.md`: what you tried, what happened, verdict `GO | NO-GO | GO-WITH-CHANGES` and the one change if any. Do not build the feature. Do not update status.yaml.

Read `risk-probe.md`. `NO-GO` → stop, show the user, ask whether to re-scope. `GO-WITH-CHANGES` → append the change to `idea.md` scoping notes. Then `$PS note "$DIR" "risk probe: <verdict>"`.

---

## Step 4 — Spec (PM)

```
Agent(general-purpose, "PM spec")
```

> Use the /prototype-spec skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Read `idea.md`, `demo.md`, `status.yaml`, and `brief-source.txt` if present (fetch the brief and condense it; do not re-derive). Scope is `<scope>`: short spec for new-widget (≤120 lines, ≤8 acceptance criteria), full for new-feature (≤200 lines, ≤12 criteria). Mark the criteria that the demo prompts exercise with `[demo]`. Write `spec.md`, then `$PS set "$DIR" phase=spec completed.spec=true last_actor=prototype-spec`.

Check `wc -l spec.md` and the AC count. If over the limit, send one `SendMessage` to the same agent: "Trim to the limit; cut non-demo criteria first." Do not loop.

---

## Step 5 — Parallel: spec review + design + distill

Spawn all three in **one message**. Distill needs only `spec.md`.

```
Agent(general-purpose, "Spec review")
Agent(general-purpose, "UX design")
Agent(general-purpose, "Distill build context")
```

Reviewer:

> Use the /prototype-review skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Mode: spec-review. Scope `<scope>`: new-widget findings are informational; new-feature gates (≥3 findings, verdict). Keep the report under 80 lines — findings, not essays. Write `spec-review.md`, then `$PS set "$DIR" completed.spec_review=true last_actor=prototype-review`; on HALT also `phase=blocked blocked_on="spec review: N blockers"`.

Designer:

> Use the /prototype-design skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Read `spec.md`. If `design-figma-source.txt` exists, import that Figma (get_design_context / get_screenshot) and write `design.md` from it; do not invent a second design. Generate new Figma frames **only** if `status.yaml` has `design_figma: generate`. Limit: ≤120 lines. Write `design.md`, then `$PS set "$DIR" phase=design completed.design=true last_actor=prototype-design`.

Distiller:

> Use the /prototype-distill skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Read `spec.md`. Read code from the **worktree** at `<WT>` (not the main checkout). Limit: ≤300 lines. Write `distillate.md`, then `$PS set "$DIR" completed.distill=true last_actor=prototype-distill`.

When all three finish, read `spec-review.md`:

- **HALT** (new-feature) → show the blockers, ask: fix via `SendMessage` to the spec agent, or override. After a respec, `SendMessage` the designer and distiller to reconcile (do not respawn).
- **PASS WITH FIXES** → list the majors in one line each, continue.
- **PASS / informational** → continue.

---

## Step 6 — Design review

```
Agent(general-purpose, "Design review")
```

> Use the /prototype-review skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Mode: design-review. Under 80 lines. Write `design-review.md`, then `$PS set "$DIR" completed.design_review=true last_actor=prototype-review`; on HALT also set `phase=blocked`.

HALT → `SendMessage` the designer with the blockers, re-run review once. Otherwise continue.

---

## Step 7 — Build (engineer)

```bash
$PS check-cap "$DIR" build || { surface; stop; }
```

Confirm the background build task finished (it should have by now). Then:

```
Agent(general-purpose, "Build")
```

> Use the /prototype-build skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Worktree: `<WT>` on branch `<branch>` — `cd` there first and verify with `git branch --show-current`. Read `spec.md`, `design.md`, `distillate.md`, `demo.md`, and the review files. Build the feature. The objdir is already built; use `./mach build faster` unless you touch `moz.build`/`jar.mn`. Cycle N = `$PS get "$DIR" cycles.build` + 1 → `reports/build-cycle-N.md` and `cp` to `reports/build-latest.md`. Write `launch.sh`, update `worktree-info.txt`, and write `<WT>/README.md` (handover: what it does, what it does not do, the demo prompts, setup, how to run). On success: `$PS set "$DIR" phase=build completed.build=true last_actor=prototype-build cycles.build+=1`. If the distillate was wrong or missing something, write `distillate-gaps.md` and stop without incrementing.

Keep the agent id. Later fixes go to it with `SendMessage`, not a new agent, while it exists.

**Build failed:** if `distillate-gaps.md` exists → `SendMessage` the distiller to patch (`cycles.distill+=1`), then `SendMessage` the engineer to retry. Otherwise `SendMessage` the engineer with the error. Check the cap before each retry.

---

## Step 8 — QA (demo first)

```
Agent(general-purpose, "QA")
```

> Use the /prototype-qa skill. `artifact_dir`: `<DIR>`. `PS`: `<PS>`. Worktree `<WT>`. Order: (1) smoke — Firefox launches, Smart Window opens, no console errors; (2) **every prompt in `demo.md`, live**, exactly as written; (3) at most 5 more criteria from `spec.md`, highest risk first. Total test cases ≤ 8. For a demo failure classified `build` you may run the live fix loop, at most `caps.demo_fix_rounds` rounds; then report the result either way. Cycle N = `$PS get "$DIR" cycles.qa_runs` + 1 → `reports/qa-cycle-N.md`, `cp` to `reports/qa-latest.md`, screenshots in `screenshots/cycle-N-<test>.png`. Classify every failure `spec | design | build | infra`. Increment counters via `$PS`. Do **not** set `completed.qa` or `completed.demo`.

---

## Step 9 — Triage, route, finish

Read `reports/qa-latest.md`.

- All demo prompts pass → `$PS set "$DIR" completed.demo=true`. All tests pass → also `completed.qa=true phase=done`.
- Otherwise group failures by class and route, highest layer first: `spec` → spec agent, `design` → designer, `build` → engineer (all via `SendMessage` to the existing agent; respawn only if it is gone). `$PS check-cap` before each. Then re-run QA (`SendMessage` the QA agent: "re-test only the failed cases").
- A cap reached with the **demo** still failing → `phase=blocked`, tell the user exactly which demo prompt fails and why, and offer: raise the cap, change the demo prompt, or accept as partial (`completed.demo=false`, `phase=done`). Never mark the demo passing because offline tests pass.

**Handover.** Copy `<WT>/README.md` to `<DIR>/README.md`. Report in this order: the demo prompts and whether each passed; how to run (`<WT>/run.command`); artifact dir and branch; cycles by layer; anything deferred. Then offer, as separate questions: push the branch to `ai` (`git -C <WT> push ai <branch>`; needs write access to Firefox-AI/firefox-prototypes), and `/push-to-demo` only if that skill is installed (it is not part of these plugins).

---

## Rules

- **Ask at intake, not mid-run.** Keys, prompts, inputs and budget are collected before any agent spawns.
- **Demo prompts are the bar.** QA runs them first; `completed.demo` is set only by you, only when they pass live.
- **Reuse agents.** Fixes and reconciliations go by `SendMessage` to the agent that wrote the artifact.
- **Report after every phase** with time and tokens. Stop at the budget.
- **Caps gate.** `$PS check-cap` before every retry. Hitting a cap halts and surfaces.
- **Coordinator owns `phase` and `completed.*`.** Sub-skills set their own counters and `last_actor`.
- **Soft size limits**, not rewrites: one trim request per artifact, then move on.
- **Default checkout** for distill and build is the worktree, never `$PROJECT_ROOT/firefox/`.
