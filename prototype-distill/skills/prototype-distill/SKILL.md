---
name: prototype-distill
description: Compresses relevant Firefox Smart Window codebase context into a focused build reference. Use when invoked by /prototype before the engineer agent runs, or when re-running to fill gaps the engineer surfaced.
version: 2.0.0
---

# Prototype Distill — Build Context Compressor

You produce `distillate.md` — a tightly compressed reference that gives the engineer agent everything it needs to write the new feature without re-exploring the codebase. Inspired by BMAD's distillator pattern.

The engineer's prompt budget is precious. Every token spent re-discovering "how does tool registration work" is a token not spent on the new code. You do that discovery once.

## Required references

- `<plugin-root>/references/smart-window-arch.md` — code layout pointer
- `<plugin-root>/references/widget-llm-coexistence.md` — only if spec needs widget+LLM coexistence
- `<plugin-root>/references/smartwindow-design-system.md` — design tokens (cite, don't inline)

`<plugin-root>` = `/Users/joliehuang/.claude/my-plugins/prototype`.

## Inputs / outputs

You receive an `artifact_dir` — absolute path to `_prototype/<slug>/`.

**Initial run (called after spec is written, in parallel with design):**

- Read `spec.md` (PM output)
- Read the Firefox checkout (default `/Users/joliehuang/FirefoxPrototype/firefox/`)
- Write `distillate.md`

**Re-run (called when engineer wrote `distillate-gaps.md`):**

- Read existing `distillate.md`
- Read `distillate-gaps.md` (engineer's surfaced gaps)
- Read the latest `reports/build-latest.md` for context on what failed
- **Update** `distillate.md` to address each gap (don't rewrite the whole thing — surgical edits)
- Increment `cycles.distill+=1`. If `cycles.distill >= caps.distill`, set `blocked_on="distill cap reached, manual review needed"`.

After writing, in either mode:

```bash
PS=/Users/joliehuang/FirefoxPrototype/bin/proto-status.sh
$PS set "$DIR" completed.distill=true last_actor=prototype-distill
# Initial run: do NOT change phase (coordinator owns it)
# Re-run: also $PS set "$DIR" cycles.distill+=1
```

Never write `status.yaml` directly.

## Workflow — initial run

### Step 1 — Plan distillation targets

Read `spec.md`. Identify what the engineer will need:

- **Tool handler pattern** — always. Source: `models/Chat.sys.mjs` and an existing tool handler.
- **Artifact component pattern** — if spec defines artifacts. Source: most-similar existing component (`weather-artifact` for data widgets, `trip-artifact` for multi-section).
- **Actor IPC pattern** — if spec implies new IPC (external API, parent-child). Source: `ui/actors/AIChatContentParent.sys.mjs` + `Child.sys.mjs`.
- **Widget+LLM coexistence** — if both widget AND LLM commentary. Pull from `widget-llm-coexistence.md` rather than re-deriving.
- **Build registration** — always. Source: `moz.build` + `ui/jar.mn`.

### Step 2 — Parallel extraction (if scope warrants)

For new-feature scope with multiple targets, dispatch parallel sub-agents — one per target — and merge. Each sub-agent gets a narrow prompt:

```
Read <file>. Extract only the <pattern> in <50 lines. No commentary, just the
canonical code snippet, file path, and a one-sentence "what to copy".
```

For tweak/new-widget scope, do extraction inline (faster, no spawn cost).

### Step 3 — Compress and structure

Sections, in this order:

```markdown
# Build Distillate: [Feature]

**Generated:** [iso]
**Source checkout:** [abs path]
**Target scope:** [tweak | new-widget | new-feature]

## Files You Will Touch

Bullet list, marked CREATE | MODIFY | REGISTER. No discussion — just the manifest.

## Pattern Snippets

### Tool registration in Chat.sys.mjs
[exact code snippet from existing — show how a tool is added to the registry]

### Tool handler shape
[exact code snippet — name, description, parameters, handler signature, return shape]

### Artifact component shape
[exact code snippet — boilerplate import, class declaration, properties, render() with state branching, customElements.define]

### Actor message pattern (only if needed)
[snippet showing parent.send + child.receive; naming `AIChatContent:Foo`]

### Widget+LLM coexistence (only if needed)
[snippets from #handleWeatherData; convId rule;
 cite widget-llm-coexistence.md for the full invariant list]

### moz.build registration
[diff style — what line, in which moz.build]

### jar.mn registration
[diff]

### HTML import (if new component)
[diff for aiChatContent.html or wherever consumed]

## Critical Invariants

5-10 bullets. The non-obvious gotchas:
- "Every conversationState entry MUST have convId or #checkConversationState wipes state."
- "browser.ml.enable defaults to false — golden profile sets it."
- "moz.build changes require full ./mach build, not faster."
- "Component CSS loads via <link> inside render(), not static styles."
- ...

## Design system pointer

Token table + component inventory:
`<plugin-root>/references/smartwindow-design-system.md`

The engineer should load that before writing CSS.

## What NOT to do

- Don't invent global tokens — use the inventory.
- Don't write actor code if no IPC needed.
- Don't refactor existing code — touch only "Files You Will Touch".
```

## Workflow — re-run (gap fix)

### Step 1 — Read the gaps

Open `distillate-gaps.md`. Each gap has form:

```markdown
- **Missing/Wrong:** <what>
- **Suggested source:** <file:line>
```

### Step 2 — Address each gap

For each: read the source the engineer pointed at (or the most-similar pattern if they didn't point at one), extract the snippet, and patch the relevant section of `distillate.md`. Be surgical — don't rewrite untouched sections.

### Step 3 — Add a "Gap fixes (cycle <N>)" section

At the bottom of `distillate.md`:

```markdown
## Gap fixes (cycle <N>)

- **Fixed:** Pattern for X — added to "Pattern Snippets" → "Tool handler shape" with snippet from `<file:line>`.
- **Fixed:** Wrong actor namespace — corrected from "Foo:" to "Bar:" in "Actor message pattern".
```

This keeps an audit trail without bloating the main sections.

## Rules

- **Stay focused.** Don't include patterns the spec doesn't need. A "tweak the error message in weather-artifact" distillate doesn't need actor or LLM coexistence sections.
- **Real code, not paraphrased.** Snippets must be lift-able. Cite the file path under each snippet.
- **Compression matters.** Skim-able in <2 minutes. Over ~500 lines = over-distilling.
- **Don't write the new feature.** Reference material, not implementation.
- **Cite, don't inline.** For shared references (widget-llm-coexistence, design system), point to the file and pull only the spec-specific snippet.
- **Re-run is surgical.** Patch what's broken; don't rewrite untouched sections.
- **Default checkout** is `/Users/joliehuang/FirefoxPrototype/firefox/`. Confirm with `ls` first.
- **Use `proto-status.sh`.** Never edit `status.yaml` directly.
