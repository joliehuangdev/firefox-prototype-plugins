---
name: prototype-distill
description: Compresses relevant Firefox Smart Window codebase context into a focused build reference. Use when invoked by /prototype before the engineer agent runs, or when re-running to fill gaps the engineer surfaced.
version: 3.1.0
---

# Prototype Distill — Build Context Compressor

You produce `distillate.md`: the code patterns the engineer must copy, lifted verbatim from the **worktree the feature will be built in**, so the engineer never re-explores. Every line you write is read by the engineer on every turn; keep it to what the spec needs.

## Required references

- `references/smart-window-arch.md` — code layout pointer
- `references/widget-llm-coexistence.md` — only if the spec needs widget + LLM coexistence
- `references/smartwindow-design-system.md` — tokens (cite, don't inline; it is a snapshot — verify token names in the worktree)

## Inputs / outputs

`artifact_dir` and `PS` come from the coordinator.

**Initial run** (parallel with design):

- Read `spec.md`
- Source tree: `worktree.path` from `status.yaml` (`$PS get "$DIR" worktree.path`). Fall back to `<project_root>/firefox/` only if that is empty, and say so in the header.
- Write `distillate.md`, then `$PS set "$DIR" completed.distill=true last_actor=prototype-distill`

**Re-run** (engineer wrote `distillate-gaps.md`, or the coordinator sent you a message):

- Read `distillate.md`, `distillate-gaps.md`, `reports/build-latest.md`
- Patch only the affected sections; add a `## Gap fixes (cycle N)` list at the bottom
- `$PS set "$DIR" cycles.distill+=1 last_actor=prototype-distill`; if `$PS check-cap "$DIR" distill` fails, set `blocked_on="distill cap reached"`

Never write `status.yaml` directly.

## Size limit (hard)

≤ 300 lines. If you are over, drop whole sections the spec does not need before trimming snippets.

## Workflow — initial run

### 1. Decide targets from the spec

- **Tool registration + handler shape** — always. Source: `browser/components/aiwindow/models/Chat.sys.mjs` plus one existing tool handler.
- **Artifact component shape** — if the spec defines artifacts. Source: `ls browser/components/aiwindow/ui/components/` in the worktree and pick the most similar existing component by shape (data card, list, multi-section). Name the one you chose. Do not assume a component exists because an older doc names it.
- **Actor IPC** — only if the spec implies new parent/child messaging. Source: `ui/actors/AIChatContentParent.sys.mjs` + `Child.sys.mjs`.
- **Widget + LLM coexistence** — only if both. Pull from `widget-llm-coexistence.md`.
- **Registration** — always: `moz.build`, `ui/jar.mn`, the HTML that imports the component.

### 2. Extract

For new-feature with 3+ targets you may fan out `Explore` sub-agents, one per target, each with a narrow prompt: "Read `<file>`. Return only the `<pattern>` as a liftable snippet (<50 lines) with the path and one sentence on what to copy." Otherwise extract inline.

### 3. Write

```markdown
# Build Distillate: [Feature]

**Generated:** [iso]  **Source tree:** [worktree path @ short commit]  **Scope:** [...]

## Files you will touch
CREATE | MODIFY | REGISTER, one per line. Nothing else.

## Pattern snippets
### Tool registration (Chat.sys.mjs)
### Tool handler shape
### Artifact component shape (copied from `<component you chose>`)
### Actor message pattern (only if needed)
### Widget + LLM coexistence (only if needed)
### moz.build / jar.mn / HTML import — as diffs

Each snippet: real code, path cited beneath it.

## Critical invariants
5–10 bullets of non-obvious gotchas (convId rule, `browser.ml.enable`, moz.build ⇒ full build, CSS via <link> in render(), ...).

## Design tokens
Point to `references/smartwindow-design-system.md`; list only the tokens this feature will use, verified to exist in the worktree's CSS.

## Do not
- invent tokens · write actor code without IPC need · refactor outside "Files you will touch"
```

## Rules

- **Worktree, not main checkout.** Branch bases differ; the main checkout may not have the files the engineer will edit.
- **Real code, lift-able, cited.**
- **Only what the spec needs.**
- **Re-runs are surgical.**
- **Use `$PS`.** Never edit `status.yaml` directly.
