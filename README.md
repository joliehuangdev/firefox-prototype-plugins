# Firefox Prototype Plugins

Claude Code plugins that take a Firefox Smart Window idea to a demoable, QA'd build in a git worktree. Start with `/prototype`.

## What's included

| Plugin | Skill | Role |
| ------ | ----- | ---- |
| `prototype` | `/prototype` | Coordinator: intake, worktree + background build, routing, budget, handover |
| `prototype-spec` | `/prototype-spec` | PM: short spec with a demo script and tagged acceptance criteria |
| `prototype-review` | `/prototype-review` | Adversarial review of spec and design (≤80 lines) |
| `prototype-design` | `/prototype-design` | UX: transcribes your Figma if you have one, otherwise a ≤120-line UI spec |
| `prototype-distill` | `/prototype-distill` | Lifts the code patterns the engineer must copy, from the worktree |
| `prototype-build` | `/prototype-build` | Engineer: builds in the worktree, smokes the first demo prompt, writes the handover README |
| `prototype-qa` | `/prototype-qa` | QA: demo prompts first and live, then ≤5 more cases; live fix loop for build bugs |
| `brainstorm` | `/brainstorm` | Standalone ideation (the coordinator scopes inline) |
| `qa-extension` | `/qa-extension` | Standalone Firefox extension QA |

## Pipeline (v3.1)

```text
Intake (scope, demo prompts, inputs, keys, budget)
  → worktree + background build
  → [risk probe, new-feature with external dependency]
  → spec → [spec review ‖ design ‖ distill] → design review
  → build (one engineer, kept alive for fixes)
  → QA: smoke → demo prompts live → ≤5 more
  → triage by class (spec/design/build/infra) with caps → handover README
```

Tweaks skip all agents: the coordinator edits, builds and smokes in the worktree itself.

What changed from v3.0, and why (measured on two Oct 2026 runs: 25 agents, ~7.5 h, 127M context tokens, demo still failing):

- **Demo prompts are collected at intake and are the bar.** QA runs them first, live; `completed.demo` is set only when they pass. Offline criteria passing no longer counts as done.
- **Everything you'd otherwise be asked mid-run is asked up front**: keys, prompts, existing brief/Figma/branch, time budget.
- **Worktree and first build start at intake**, overlapping the ~10 min artifact build with planning.
- **Hard size limits**: spec ≤120/200 lines with ≤8/12 criteria, design ≤120, distillate ≤300, reviews ≤80, QA ≤8 cases. Agents re-read these on every turn, so length is cost.
- **Agents are reused** via `SendMessage` for fixes instead of respawned.
- **Progress line after every phase** (minutes, tokens, budget) and a hard stop at the budget.
- **Provided Figma is transcribed, not redesigned**; Figma generation is opt-in.
- **Distill and build read the worktree**, not the main checkout (branch bases differ).
- **Handover README** in the worktree: what it does, prompts to try, setup, limits.

## Installation

```bash
claude plugin marketplace add joliehuangdev/firefox-prototype-plugins
for p in prototype prototype-spec prototype-review prototype-design prototype-distill prototype-build prototype-qa; do
  claude plugin install $p@firefox-prototype-plugins
done
```

## Usage

```text
/prototype <idea, or a brief/Figma/branch to start from>
/prototype resume
```

Standalone: `/prototype-spec`, `/prototype-review`, `/prototype-design`, `/prototype-distill`, `/prototype-build`, `/prototype-qa` each take an `artifact_dir` or a description.

## Prerequisites

- A local Firefox checkout laid out as `<project_root>/firefox/`, `<project_root>/worktrees/`, `<project_root>/_prototype/`, with the helper scripts in `<project_root>/bin/` (`new-prototype.sh`, `launch-prototype.sh`, `seed-golden.sh`, `proto-status.sh`; a copy of the last ships in `prototype/skills/prototype/scripts/`). Default `project_root` is `~/FirefoxPrototype`; the coordinator asks if yours differs.
- Artifact-build mozconfig at `~/.firefox-prototype-mozconfig`; golden profile seeded once with `seed-golden.sh`.
- Python 3 with the Marionette client (bundled in the Firefox tree).
- Figma MCP server, only if you want designs read from or written to Figma.

## Developing these plugins

Edit under the marketplace directory, bump `plugin.json` `version`, commit and push, then `claude plugin update <plugin>@<marketplace>` and restart the session. The plugin cache is keyed by version; unbumped edits are not picked up.

## License

MIT
