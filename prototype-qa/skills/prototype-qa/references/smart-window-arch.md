# Smart Window — Shared Architecture Reference

Used by: `prototype-spec`, `prototype-design`, `prototype-distill`, `prototype-build`, `prototype-qa`.

This is the canonical, deduplicated description of the Smart Window feature surface. All sub-skills should reference this rather than restating it.

---

## What Smart Window is

Firefox's AI-powered window — a separate window type, ~400px wide. It hosts a conversational UI (the "Chat panel"), a primary input (the "Smartbar"), and rich UI ("Artifacts") that render alongside chat.

## Concepts

- **Smartbar** — input field at the top of the Smart Window. Submitting routes the query to the AI chat pipeline.
- **Chat panel** — conversational UI (`ai-chat-content`). Streams assistant responses, hosts artifacts inline.
- **Artifacts** — rich interactive UI rendered alongside (or instead of) chat text — weather widgets, travel planners, etc.
- **Tools** — functions the AI can call (`get_weather`, `plan_trip`, …) that produce data and (often) trigger an artifact.
- **Tab references** — the AI can read or interact with the user's open browser tabs.
- **Split layout** — chat on top/right, artifact on bottom/left.

## Constraints designers/engineers must respect

- **Width is ~400px.** Designs must work at 400px. Verify graceful degradation at 300px (Smart Window minimum).
- **Lit web components with shadow DOM.** All UI is built as Lit custom elements.
- **Dark/light mode is mandatory.** Use design tokens (`--text-color`, `--color-surface-variant`, …). Never raw hex except for documented one-offs.
- **State contract per artifact.** Every artifact component implements `loading | loaded | error | empty` per the design system doc.

## Code layout

`browser/components/aiwindow/`:

| Directory | Purpose |
|---|---|
| `ui/components/` | Lit web components (artifacts, UI elements) |
| `ui/actors/` | IPC actors (Parent/Child message passing) |
| `models/` | Backend logic, API calls, data processing |
| `ui/modules/` | Shared utilities (AIWindowUI, AIWindow, ChatConversation, …) |
| `ui/test/browser/` | Browser tests |

## Default checkout

`/Users/joliehuang/FirefoxPrototype/firefox/`

If a different layout is in use, the user will say so in `idea.md` or via Step 1 of the coordinator.

## Feature flow end-to-end

1. User types in the Smartbar → submits.
2. The chat pipeline runs. The AI may decide to call a **tool**.
3. The tool handler (in `models/`) executes (API calls, computation).
4. The tool result is returned → the relevant **artifact** component renders.
5. (If both apply) The LLM also generates conversational text alongside the widget — see `widget-llm-coexistence.md`.

## Companion references

- `smartwindow-design-system.md` — token + component inventory
- `launcher-and-profile.md` — golden profile, Marionette pref injection, port handling
- `widget-llm-coexistence.md` — convId rules, engine-failure handling, two-path data flow
