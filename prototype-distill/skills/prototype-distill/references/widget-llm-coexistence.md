# Widget + LLM Coexistence — Shared Reference

Used by: `prototype-spec` (LLM context disposition), `prototype-distill` (canonical pattern), `prototype-build` (implementation), `prototype-qa` (failure diagnosis).

When an artifact shows BOTH a data widget (weather card, map, etc.) AND an LLM text response, both paths must coexist without one wiping the other.

---

## Two parallel data paths

1. **Widget path (fast)** — query detection in `ai-chat-content` → event to `AIChatContentParent` → external API fetch → IPC back → artifact renders.
2. **LLM path (slow)** — `submitChatMessage` → `generatePrompt` injects API context → `Chat.fetchWithHistory` → LLM streams text into the same bubble.

## Critical invariants (every one of these has caused a real bug)

1. **Every `conversationState` entry MUST have `convId`.**
   `#checkConversationState()` compares the convId of incoming messages against the last entry. Missing convId → full state reset → all messages wiped, including the widget that just rendered.

2. **Merge standalone widget entries when LLM responds.**
   If you create a temporary assistant entry for widget data before the LLM responds, `handleAIResponseEvent` must find it, take the widget data, delete the standalone entry, and put the widget data on the real assistant entry.

3. **Handle engine build failure gracefully.**
   Wrap `openAIEngine.build()` in a nested try-catch. If it fails, still create user message + assistant placeholder so widget detection fires. Re-throw for the outer catch.

4. **Suppress errors only for engine failure, not LLM failure.**
   Track `engineBuildFailed`. Only suppress error display when the engine specifically failed AND the widget provides the answer.

5. **Clear loading state when widget data arrives standalone.**
   Set `assistantIsLoading = false` and `errorObj = null` so the user sees the widget instead of a spinner.

6. **Start API context fetch early.**
   Widget API calls don't depend on the engine. Fire them before sequential engine-dependent context (realTimeInfo, memories) and await later.

## File locations for widget features

| Layer | File | Purpose |
|---|---|---|
| Widget component | `ui/components/<name>/<name>.mjs` | Lit component rendering the card |
| Query detection | `ui/components/ai-chat-content/ai-chat-content.mjs` | Pattern matching, widget data binding |
| Submission | `ui/components/ai-window/ai-window.mjs` | Query detection at submit, engine-failure handling |
| API fetch (widget) | `ui/actors/AIChatContentParent.sys.mjs` | External API calls |
| IPC routing | `ui/actors/AIChatContentChild.sys.mjs` | Parent ↔ child message passing |
| LLM context inject | `ui/modules/ChatConversation.sys.mjs` | Inject API data into LLM prompt |
| Actor registration | `browser/components/DesktopActorRegistry.sys.mjs` | Register new actor events |
| Chrome manifest | `ui/jar.mn` | Register new component files |
| HTML import | `ui/content/aiChatContent.html` | Script tag for new component |
