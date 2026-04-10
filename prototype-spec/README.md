# prototype-spec

PM agent that produces a structured, implementation-ready prototype spec for Firefox Smart Window features.

## What it does

Takes a product idea and generates a complete spec covering:

- Problem statement and target user
- User stories (3-6 covering core flow + edge cases)
- Testable acceptance criteria (GIVEN/WHEN/THEN format)
- Smart Window integration: tool definitions, artifact components, tab references
- Scope boundaries (in/out) and assumptions

The output is structured so downstream agents (designer, engineer, QA) can consume it directly without ambiguity.

## Usage

```
/prototype-spec [product idea]
```

Can be used standalone or as part of the `/prototype` pipeline.

## Output

A markdown spec document with every section required. Tool definitions include names, parameters, and return types. Acceptance criteria are written to be directly automatable by the QA agent.
