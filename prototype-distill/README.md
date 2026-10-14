# prototype-distill

Writes `distillate.md` (≤300 lines): the exact code patterns the engineer must copy, lifted from the **worktree** recorded in `status.yaml` (not the main checkout, whose branch base may differ).

Sections: files to touch, pattern snippets (tool registration/handler, artifact component, actor IPC if needed, widget+LLM coexistence if needed, moz.build/jar.mn/HTML registration), critical invariants, tokens verified to exist, do-nots. Re-runs patch only the gaps the engineer reported.
