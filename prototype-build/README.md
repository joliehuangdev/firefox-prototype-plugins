# prototype-build

Engineer agent that builds Firefox Smart Window prototypes from a spec and design.

## What it does

Takes a PM spec and UI design spec and produces a working implementation:

- **Tool handler** — registered in `Chat.sys.mjs`, processes AI tool calls
- **Artifact component** — Lit web component with all 4 states (loading, loaded, error, empty)
- **Actor updates** — IPC message handlers if needed
- **Build registration** — `moz.build` entries and component imports

Follows existing codebase patterns exactly. Reads the most similar existing feature before creating new files.

## Usage

```
/prototype-build
```

Provide or reference a spec and design in conversation. Can be used standalone or as part of the `/prototype` pipeline.

## Output

A build report listing files created/modified, tool definitions, artifact components, build status, and known limitations. Always verifies with `./mach build faster` before reporting success.

## Requirements

- Firefox source tree at the expected path
- Prior `./mach build` (full build) completed at least once
