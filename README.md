# Firefox Prototype Plugins

Claude Code plugins that orchestrate building Firefox Smart Window prototypes end-to-end — from product idea to working, tested feature.
Start with /prototype and co-create the squad agents to 10x your prototyping velocity.

## What's included

| Plugin | Skill | Role | What it does |
|--------|-------|------|-------------|
| `prototype` | `/prototype` | Coordinator | Chains all four agents below into a single pipeline |
| `prototype-spec` | `/prototype-spec` | PM Agent | Generates a structured prototype spec with user stories, acceptance criteria, and tool definitions |
| `prototype-design` | `/prototype-design` | UX Designer Agent | Produces a UI spec (component hierarchy, states, interactions) and optional Figma mockups |
| `prototype-build` | `/prototype-build` | Engineer Agent | Builds the prototype in the Firefox source tree following existing codebase patterns |
| `prototype-qa` | `/prototype-qa` | QA Agent | Validates the prototype via Marionette browser automation with screenshots and a structured report |

## Pipeline

```
User Idea -> PM Spec -> [User Review] -> UX Design -> Engineer Build -> QA Validation
                                                           ^                |
                                                           +-- fix loop ----+
```

The coordinator includes a human-in-the-loop checkpoint after the spec step and an automatic fix loop (up to 3 cycles) between build and QA.

## Installation

```bash
claude plugin marketplace add joliehuangdev/firefox-prototype-plugins
claude plugin install prototype@firefox-prototype-plugins
claude plugin install prototype-spec@firefox-prototype-plugins
claude plugin install prototype-design@firefox-prototype-plugins
claude plugin install prototype-build@firefox-prototype-plugins
claude plugin install prototype-qa@firefox-prototype-plugins
```

## Usage

Run the full pipeline:

```
/prototype build a recipe suggestion feature that reads the user's open tabs for ingredients
```

Or use individual skills standalone:

```
/prototype-spec a tab grouping assistant that organizes tabs by topic
/prototype-design
/prototype-build
/prototype-qa
```

## Prerequisites

You must have a local Firefox build before using these plugins. The build and QA skills modify and run code directly in the Firefox source tree.

Follow the setup instructions at: https://firefox-source-docs.mozilla.org/setup/index.html

## Other requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- Python 3 with Marionette client (bundled in the Firefox source tree)
- Figma MCP server (optional, for design mockups)

## License

MIT
