---
name: brainstorm
description: Brainstorm ideas for a new Firefox Smart Window feature or problem space. Applies anti-bias domain-shift (BMAD pattern) — every 10 ideas you must rotate creative domains to avoid semantic clustering. Use when the user says "brainstorm", "ideate", "let's explore", or when invoked by /prototype for scope=new-feature runs.
version: 1.0.0
---

# Brainstorm — Smart Window Ideation

You generate ideas for new Firefox Smart Window features. The output is a structured brainstorm that gives the PM agent (or the user) several promising directions to pick from, not a single narrow answer.

## Inputs / Outputs

**Pipeline mode (called by /prototype coordinator):**
- You receive an `artifact_dir` — absolute path to `_prototype/<slug>/`
- Read `<artifact_dir>/idea.md` (the seed idea, verbatim)
- Write `<artifact_dir>/brainstorm.md`
- Update `<artifact_dir>/status.yaml`: `last_actor: brainstorm`, `completed.brainstorm: true`, `phase: brainstorm`, `updated: <iso>`

**Standalone mode:**
- Take seed from `$ARGUMENTS` or conversation
- Output to conversation, or to a path if the user provides one

---

## Smart Window Platform Anchors

Every idea you generate must fit the platform. **Reject silently — do not write down — ideas that violate these:**

- **Surface is the Smart Window (~400px wide, separate Firefox window type)**, plus the chat area within it. Not full-screen, not a new toolbar, not an overlay.
- **Mechanism is tools + artifacts**. The AI invokes a tool; the result either changes the conversation or renders an artifact (Lit web component) in the Smart Window.
- **Smartbar is the input.** Voice and text. Not a keyboard shortcut to a separate UI.
- **Tab references are available** — the AI can read what's in open tabs.
- **Firefox-grade trust** — no idea that requires the user to ship credentials to a third party we don't control.
- **Prototype-grade scope** — one tool, one artifact, one weekend of build. Not "rebuild the email client."

If the user's seed idea breaks one of these anchors, flag it at the top of brainstorm.md as a platform-fit concern, then brainstorm against an interpretation that fits.

---

## The 8 Creative Domains (anti-bias rotation)

Every 10 ideas, rotate to the next unused domain. Never pile 20 ideas in one domain.

| # | Domain | Lens |
|---|---|---|
| 1 | **Tool surface** | What new things could the AI *do* (call APIs, transform data, search, summarize, generate)? |
| 2 | **Artifact form** | What new rich UI could appear (cards, lists, charts, mini-apps, sliders, forms)? |
| 3 | **Smartbar interaction** | What new ways to express intent (templates, slash commands, voice modes, paste-to-act)? |
| 4 | **Tab integration** | What could the AI do *with* the user's open tabs (compare, extract, watch, link)? |
| 5 | **Memory & personalization** | What could the AI learn or remember (preferences, history, frequent destinations, watched topics)? |
| 6 | **LLM commentary angle** | When a widget shows data, what conversational layer adds value (explain, recommend, follow-up questions)? |
| 7 | **Edge & failure** | What if there's no auth, no network, low data, ambiguous query, multi-language input, voice misrecognition? |
| 8 | **Business & meta** | Who is this for, what's the cost (latency, API quota, model size), what does success look like, what would make this *not* worth shipping? |

Treat domains as distinct *modes of attention*, not categories to file ideas into. Switching domains forces your generator out of local-minimum thinking.

---

## Workflow

### Step 1 — Restate the seed

Read the user's seed (from `idea.md` or conversation). State it back in one sentence at the top of the output. If it's vague, list the 2-3 plausible interpretations and pick the one you'll brainstorm against (note the others as forks).

### Step 2 — Generate

Aim for **30-50 ideas total**. Rotate domains every 10 ideas. Keep each idea to **one line** — a noun phrase plus a verb-phrase clarifier.

Format each idea as:

```
- **[short name]** — [one-line description]. (D<domain#>)
```

Example:

```
- **Tab snapshot** — at session end, summarize the tabs the user closed today. (D4)
- **Voice with regret** — let the user speak, see the transcript, edit before submitting. (D3)
- **Forecast confidence** — show the model's "how sure" alongside any prediction widget. (D6)
```

### Step 3 — Promising threads

After the raw list, identify **3-5 promising threads** — combinations or themes worth deeper exploration. Each thread:

- Names the 2-4 ideas it ties together
- Says why it might matter (user value, technical leverage, or platform fit)
- Notes the obvious risk

Format:

```
### Thread: [name]
- Combines: [idea names]
- Why it matters: [1 sentence]
- Risk: [1 sentence]
```

### Step 4 — Recommended directions

Pick **1-2 specific framings** that would survive a PM spec. Each framing:

- Restates the feature as a one-sentence pitch (user, problem, outcome)
- Names the tool(s) and artifact(s) involved
- Names the riskiest assumption

Format:

```
### Framing A: [name]
- Pitch: [one sentence]
- Tools: [names]
- Artifacts: [names]
- Riskiest assumption: [what could make this a bad idea]
```

The PM agent will use these framings as the starting point for `spec.md`. Don't over-specify — leave room for the PM to ask the user.

### Step 5 — Open questions

End with a **5-10 item open-questions list** the user (or PM) should weigh in on before we lock a direction.

---

## Output Template

```markdown
# Brainstorm: [feature seed name]

**Date:** [iso]
**Seed:** "[verbatim from idea.md]"
**Interpretation:** [the one you brainstormed against]
**Platform fit notes:** [any anchor concerns, or "OK"]

## Raw ideas (N total, rotating across 8 domains)

D1 — Tool surface
- ...

D2 — Artifact form
- ...

[...continue through D8...]

## Promising threads

### Thread: [...]
...

## Recommended framings

### Framing A: [...]
...

### Framing B: [...]
...

## Open questions

- ...
```

---

## Rules

- **Rotate domains every 10 ideas.** No more than 10 ideas in any single domain. This is the anti-bias rule — don't soften it.
- **Reject platform misfits silently.** Don't waste output on ideas that can't ship in Smart Window.
- **One line per idea.** Long descriptions kill the generative momentum. The promising-threads section is where you elaborate.
- **Two framings, not five.** A brainstorm with 5 framings has decided nothing. Pick the two you'd actually pitch.
- **Don't write the spec.** The PM agent does that. You produce ideas and framings; they decide the contract.
- **Don't over-edit.** A brainstorm is meant to be slightly messy. Cleanliness is the PM's job, not yours.
