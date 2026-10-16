# prototype-design

Part of the `/prototype` family. Install all seven plugins with the two commands in the [main README](../README.md#installation), then run `/prototype setup`.

UX agent. Writes `design.md` (≤120 lines) for the engineer and QA.

- If the user provided a Figma (`design-figma-source.txt`), it **transcribes** it: frames → components, spacing, token mapping, missing states. It does not design a second version.
- Otherwise it designs from the spec, modeled on the closest existing component in the worktree.
- Figma generation only when `status.yaml` has `design_figma: generate`.
- Four states, 400px-first with 300px degradation, tokens by name, deviations flagged.
