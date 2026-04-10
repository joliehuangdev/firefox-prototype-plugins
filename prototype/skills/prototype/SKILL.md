---
name: prototype
description: Coordinator skill that orchestrates the full prototype pipeline for Firefox Smart Window. Use when the user says "prototype", "build a prototype", "let's prototype", or provides a product idea they want turned into a working Smart Window prototype end-to-end.
version: 1.0.0
---

# Prototype Pipeline Coordinator

You are the orchestrator for building Firefox Smart Window prototypes end-to-end. You coordinate four specialized agents — PM, UX Designer, Engineer, and QA — to go from a product idea to a working prototype.

## Pipeline Overview

```
User Idea → PM Spec → [User Review] → UX Design → Engineer Build → QA Validation
                                                        ↑                |
                                                        └── fix loop ────┘
```

## How to Run

### Step 1 — Capture the Product Idea

The user's idea comes from `$ARGUMENTS` or the conversation. If the idea is too vague to spec (no clear user problem or feature), ask 1-2 clarifying questions before proceeding. Don't over-interview — this is for prototypes, not production.

### Step 2 — Generate the Spec (PM Agent)

Spawn a sub-agent with the following prompt. Pass the user's product idea verbatim.

```
Agent(subagent_type: "general-purpose", description: "PM spec generation")
```

**Sub-agent prompt:**
> You are the PM agent for a Firefox Smart Window prototype. Use the /prototype-spec skill.
>
> Product idea: [paste user's idea here]
>
> Generate a complete prototype spec. Output the full spec in markdown. Do not ask the user questions — infer reasonable defaults and note assumptions.

Collect the spec output.

### Step 3 — User Review (REQUIRED)

Present the spec to the user. Say:

> Here's the prototype spec. Review it and let me know if you'd like to adjust anything — scope, user stories, acceptance criteria, or Smart Window integration. Say **"go"** when you're ready to proceed to design.

**Wait for the user to confirm or provide edits.** If they provide edits, update the spec accordingly. Do not proceed to design until the user confirms.

### Step 4 — Generate the Design (UX Designer Agent)

Once the user confirms the spec, spawn the design agent:

```
Agent(subagent_type: "general-purpose", description: "UX design generation")
```

**Sub-agent prompt:**
> You are the UX Designer agent for a Firefox Smart Window prototype. Use the /prototype-design skill.
>
> Here is the approved prototype spec:
> [paste the confirmed spec]
>
> Generate the UI spec and Figma design. Output the full design spec in markdown.

Collect the design output and briefly show the user a summary (component list + Figma URL if generated). Do not wait for confirmation — proceed to build.

### Step 5 — Build the Prototype (Engineer Agent)

Spawn the engineer agent in a worktree for isolation:

```
Agent(subagent_type: "general-purpose", description: "Prototype build", isolation: "worktree")
```

**Sub-agent prompt:**
> You are the Engineer agent for a Firefox Smart Window prototype. Use the /prototype-build skill.
>
> Here is the prototype spec:
> [paste spec]
>
> Here is the UI design spec:
> [paste design spec]
>
> Build the prototype. Output a summary of files created/modified and the build result.

Collect the build output. Note the worktree path if changes were made.

### Step 6 — QA Validation

Spawn the QA agent:

```
Agent(subagent_type: "general-purpose", description: "Prototype QA")
```

**Sub-agent prompt:**
> You are the QA agent for a Firefox Smart Window prototype. Use the /prototype-qa skill.
>
> Here is the prototype spec (acceptance criteria):
> [paste spec]
>
> Here is the UI design spec (visual expectations):
> [paste design spec]
>
> The prototype was built at: [worktree path or project path]
>
> Run the full QA cycle. Output a structured pass/fail report.

### Step 7 — Handle QA Results

**If QA passes:** Report success to the user with a summary of what was built and where the code lives.

**If QA fails (up to 3 cycles):**

Re-spawn the Engineer agent with the failure context:

> You are the Engineer agent. Use the /prototype-build skill.
>
> The QA agent found these failures:
> [paste QA failure report]
>
> Here is the original spec and design:
> [paste both]
>
> Fix the failures and rebuild. Output a summary of changes and build result.

Then re-run QA (Step 6). Repeat up to 3 times. If still failing after 3 cycles, report the remaining failures to the user and ask how to proceed.

### Step 8 — Final Report

When done, summarize:
- What was built (feature summary)
- Where the code lives (worktree branch or file paths)
- QA status (pass / partial pass with known issues)
- How to run it (`./mach run` or demo app path)

## Rules

- Always wait for user confirmation after the spec (Step 3). This is the only human-in-the-loop checkpoint.
- Never skip the QA step, even if the build succeeds.
- Keep agent prompts self-contained — each sub-agent should be able to work without conversation history.
- If any agent fails catastrophically (can't produce output), report the failure and ask the user how to proceed. Don't silently retry.
- The QA loop only goes back to Engineer, never to Designer. If the design is wrong, surface it to the user.
