# prototype-review

Part of the `/prototype` family. Install all seven plugins with the two commands in the [main README](../README.md#installation), then run `/prototype setup`.

Adversarial reviewer for `spec.md` and `design.md`. Reads only the artifact files, never the conversation.

- Spec review: testability, tool completeness, artifact/tool alignment, scope leaks, integration realism, hidden assumptions.
- Design review adds: 400px fitness, state completeness, token discipline, pattern reuse, interaction specificity, accessibility floor.
- Scope-aware: informational for new widgets, gating (≥3 findings, HALT / PASS WITH FIXES / PASS) for new features.
- ≤80 lines. Findings with quote, problem and fix; no essays.
