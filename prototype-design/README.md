# prototype-design

UX Designer agent that produces UI specs and Figma designs for Firefox Smart Window prototypes.

## What it does

Takes a prototype spec and generates:

- **Component hierarchy** — tree of Lit web components with names matching the spec
- **Layout spec** — flex/grid structure, spacing, overflow behavior for the ~400px Smart Window
- **Visual states** — loading, loaded, error, and empty states for every component
- **Interactions** — specific triggers, targets, results, and animations
- **Typography and colors** — using Firefox design tokens, not hard-coded values
- **Responsive behavior** — Smart Window at 300px, 400px, and 600px widths

Optionally generates Figma mockups via the Figma MCP server when available.

## Usage

```
/prototype-design
```

Provide or reference a prototype spec in conversation. Can be used standalone or as part of the `/prototype` pipeline.

## Output

A markdown UI spec document. If Figma tools are available, also a Figma file URL with frames for each major state.
