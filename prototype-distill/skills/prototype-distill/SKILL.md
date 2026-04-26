---
name: prototype-distill
description: Compresses relevant Firefox Smart Window codebase context into a focused build reference. Use when invoked by /prototype before the engineer agent runs. Reads existing similar components, actor patterns, tool registration, and produces a single distillate.md that the engineer consumes instead of re-exploring.
version: 1.0.0
---

# Prototype Distill — Build Context Compressor

You produce `distillate.md` — a tightly compressed reference that gives the engineer agent everything it needs to write the new feature without re-exploring the codebase. Inspired by BMAD's distillator pattern.

The engineer agent's prompt budget is precious. Every token spent re-discovering "how does tool registration work" is a token not spent on the new code. You do that discovery once, in parallel sub-agents if needed, and produce a focused distillate.

---

## Inputs

You receive an `artifact_dir` — an absolute path to `_prototype/<slug>/`.

Read:
- `spec.md` (PM output) — to know what tools/artifacts/actors are needed
- `design.md` (UX output) — to know what UI primitives apply
- The Firefox checkout (default: `/Users/joliehuang/FirefoxPrototype/firefox/`) — to extract patterns

Write:
- `distillate.md` to the artifact_dir
- Update `status.yaml`: `last_actor: prototype-distill`, `completed.distill: true`, `updated: <iso>`

---

## Workflow

### Step 1 — Plan distillation targets

Read `spec.md`. Identify what the engineer will need:

- **Tool handler pattern** — always needed. Source: `models/Chat.sys.mjs` and an existing tool handler.
- **Artifact component pattern** — needed if spec defines artifacts. Source: most-similar existing component (`weather-artifact` for data widgets, `trip-artifact` for multi-section, etc.).
- **Actor IPC pattern** — needed if spec implies new IPC messages (external API call, parent-child message). Source: `ui/actors/AIChatContentParent.sys.mjs` + `Child.sys.mjs`.
- **Widget+LLM coexistence** — needed if both a widget and LLM commentary should appear. Source: `ai-chat-content.mjs` (`#handleWeatherData` etc.) + `ai-window.mjs` (engine failure handling) + `ChatConversation.sys.mjs` (LLM context injection).
- **Build registration** — always needed. Source: `moz.build` files + `ui/jar.mn`.

### Step 2 — Parallel extraction (if scope warrants it)

For new-feature scope with multiple targets, **dispatch parallel sub-agents** — one per target — and merge their distillates. Each sub-agent gets a single narrow prompt:

```
Read <file>. Extract only the <pattern> in <50 lines. No commentary, just the
canonical code snippet, file path, and a one-sentence "what to copy".
```

For tweak/new-widget scope, do extraction inline (faster, no spawn cost).

### Step 3 — Compress and structure

The distillate has these sections, **in this order**:

```markdown
# Build Distillate: [Feature Name]

**Generated:** [iso timestamp]
**Source checkout:** [absolute path]
**Target scope:** [tweak | new-widget | new-feature]

## Files You Will Touch

Bullet list of files, marked CREATE | MODIFY | REGISTER. No discussion — just the manifest.

## Pattern Snippets

### Tool registration in Chat.sys.mjs
[exact code snippet from existing — show how a tool is added to the registry]

### Tool handler shape
[exact code snippet from an existing handler — show the contract: name, description, parameters, handler signature, return shape]

### Artifact component shape
[exact code snippet — boilerplate import, class declaration, properties, render() with state branching, customElements.define]

### Actor message pattern (only if needed)
[code snippet showing parent.send + child.receive with naming convention `AIChatContent:Foo`]

### Widget+LLM coexistence (only if needed)
[snippets from #handleWeatherData, conversationState invariants, convId rule]

### moz.build registration
[exact diff style — what line to add, in which moz.build]

### jar.mn registration
[exact diff — what line to add]

### HTML import (if new component)
[exact diff for aiChatContent.html or wherever the component is consumed]

## Critical Invariants

Bulleted list, ~5-10 items. The non-obvious gotchas:
- "Every conversationState entry MUST have convId or #checkConversationState wipes state."
- "browser.ml.enable defaults to false — must be in profile prefs."
- "moz.build changes require full ./mach build, not faster."
- "Component CSS loads via <link> inside render(), not static styles."
- ...

## Design System Pointer

The full token table and component inventory live at:
`/Users/joliehuang/.claude/my-plugins/prototype/references/smartwindow-design-system.md`

The engineer should load that before writing CSS.

## What NOT to Do

- Don't invent new global tokens — use the inventory.
- Don't write actor code if no IPC is needed — the spec doesn't call for it.
- Don't refactor existing code — touch only the files in "Files You Will Touch".
```

### Step 4 — Update status

```yaml
# status.yaml updates
last_actor: prototype-distill
updated: <iso timestamp>
completed:
  distill: true
```

---

## Rules

- **Stay focused.** Don't include patterns the spec doesn't need. A "tweak the error message in weather-artifact" distillate doesn't need actor or LLM coexistence sections.
- **Real code, not paraphrased.** Snippets must be lift-able from existing files. Cite the file path under each snippet.
- **Compression matters.** The distillate should be skim-able in under 2 minutes. If you're over ~500 lines, you're over-distilling.
- **Don't write the new feature.** You produce reference material, not implementation. The engineer writes the code.
- **Default checkout path** is `/Users/joliehuang/FirefoxPrototype/firefox/`. Confirm via `ls` before reading. If the path differs, ask via the spec or coordinator — don't guess.
