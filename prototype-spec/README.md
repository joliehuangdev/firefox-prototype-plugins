# prototype-spec

Part of the `/prototype` family. Install all seven plugins with the two commands in the [main README](../README.md#installation), then run `/prototype setup`.

PM agent. Writes `spec.md` from `idea.md`, `demo.md` and an optional brief.

- Opens with the **demo script** (the intake prompts, verbatim) and tags the criteria they exercise `[demo]`.
- Hard limits: new-widget ≤120 lines / 8 criteria; new-feature ≤200 / 12.
- A provided brief is condensed, never expanded.
- Complete tool definitions (name, typed params, return, LLM context), artifacts with four states, external dependencies with key locations.

Used by `/prototype`; standalone: `/prototype-spec <idea>`.
