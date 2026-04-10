# prototype

Coordinator that orchestrates the full prototype pipeline for Firefox Smart Window features.

## What it does

Chains four specialized agents in sequence to go from a product idea to a working, tested prototype:

1. **PM Agent** (`/prototype-spec`) — generates a structured spec
2. **UX Designer Agent** (`/prototype-design`) — generates UI spec and optional Figma designs
3. **Engineer Agent** (`/prototype-build`) — builds the prototype in a worktree
4. **QA Agent** (`/prototype-qa`) — validates via Marionette automation

The pipeline includes a human-in-the-loop checkpoint after the spec step, and an automatic fix loop (up to 3 cycles) between build and QA.

## Usage

```
/prototype [your product idea]
```

Or describe your idea in conversation and invoke `/prototype`.

## Pipeline flow

```
User Idea -> PM Spec -> [User Review] -> UX Design -> Engineer Build -> QA Validation
                                                           ^                |
                                                           +-- fix loop ----+
```

## Requirements

- Firefox source tree (for `./mach build`)
- Marionette-capable Firefox build (for QA)
- Figma MCP server (optional, for design mockups)
