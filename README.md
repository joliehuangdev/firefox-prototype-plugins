# Firefox Prototype Plugins

Claude Code plugins that orchestrate building Firefox Smart Window prototypes end-to-end — from product idea to working, tested feature.
Start with `/prototype` and co-create the squad agents to 10x your prototyping velocity.

## What's included

| Plugin | Skill | Role | What it does |
| ------ | ----- | ---- | ------------ |
| `prototype` | `/prototype` | Coordinator | Routes work across all agents below; adapts pipeline depth to scope; persists state for resumability |
| `prototype-spec` | `/prototype-spec` | PM Agent | Generates a structured prototype spec with user stories, acceptance criteria, and tool definitions |
| `prototype-review` | `/prototype-review` | Reviewer | Adversarial review of spec and design — forces findings before the engineer wastes a build cycle |
| `prototype-design` | `/prototype-design` | UX Designer Agent | Produces a UI spec (component hierarchy, states, interactions) and optional Figma mockups |
| `prototype-distill` | `/prototype-distill` | Distillator | Compresses relevant Firefox codebase context into a focused `distillate.md` for the engineer |
| `prototype-build` | `/prototype-build` | Engineer Agent | Builds the prototype in an isolated worktree following existing codebase patterns |
| `prototype-qa` | `/prototype-qa` | QA Agent | Validates via Marionette with screenshots; classifies failures by layer for triaged retries |
| `brainstorm` | `/brainstorm` | Ideation | Anti-bias domain-shift ideation for new features. Standalone — the coordinator does brainstorm inline, so this is for exploring a problem space on its own |
| `qa-extension` | `/qa-extension` | Extension QA | Standalone utility to test, debug, and fix Firefox browser extensions — independent of the prototype pipeline |

## Pipeline

```text
Idea -> Spec -> [Spec review + Design + Distill in parallel] -> Design review -> Build -> QA
                       ^                                                            |
                       +-- classified retry loop (spec / design / build) -----------+
```

The coordinator asks a single sizing question up front (tweak / new widget / new feature) and adapts the pipeline accordingly — a tweak skips review and design and runs a quick distill; new features run the full chain, with brainstorm handled inline in the coordinator. After the spec, spec review, design, and distill fan out in parallel. QA failures are classified (`spec | design | build | infra`) and routed back to the responsible agent with per-layer retry caps (`infra` is self-fixed by QA rather than re-spawned).

All artifacts live in `~/FirefoxPrototype/_prototype/<slug>/` so any run can be resumed with `/prototype resume`.

## Installation

```bash
claude plugin marketplace add joliehuangdev/firefox-prototype-plugins
claude plugin install prototype@firefox-prototype-plugins
claude plugin install prototype-spec@firefox-prototype-plugins
claude plugin install prototype-review@firefox-prototype-plugins
claude plugin install prototype-design@firefox-prototype-plugins
claude plugin install prototype-distill@firefox-prototype-plugins
claude plugin install prototype-build@firefox-prototype-plugins
claude plugin install prototype-qa@firefox-prototype-plugins
claude plugin install brainstorm@firefox-prototype-plugins
claude plugin install qa-extension@firefox-prototype-plugins
```

## Usage

Run the full pipeline:

```text
/prototype build a recipe suggestion feature that reads the user's open tabs for ingredients
```

Resume a stalled run:

```text
/prototype resume
```

Or use individual skills standalone:

```text
/prototype-spec a tab grouping assistant that organizes tabs by topic
/prototype-review
/prototype-design
/prototype-distill
/prototype-build
/prototype-qa
```

## Prerequisites

You must have a local Firefox build before using these plugins. The build and QA skills modify and run code directly in the Firefox source tree.

Follow the setup instructions at: <https://firefox-source-docs.mozilla.org/setup/index.html>

## Other requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- Python 3 with Marionette client (bundled in the Firefox source tree)
- Figma MCP server (optional, for design mockups)

## License

MIT
