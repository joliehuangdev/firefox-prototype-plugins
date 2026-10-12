# Smart Window Design System

Sourced from `browser/components/aiwindow/ui/components/` in the FirefoxPrototype mozilla-central checkout. This is the **build-time reference** — the implementation truth that backs the design language. For visual exploration, use Figma MCP.

**Rule of thumb:** if a token, component, or pattern below exists, reuse it. Don't invent new tokens, don't fork patterns, and don't reach for raw hex/px when a token covers the case.

---

## 1. Hard Constraints

| Constraint | Value | Why it matters |
|---|---|---|
| Smart Window width | ~400px (default), 300px min, 600px expanded | Smart Window is a separate Firefox window type. All artifact layouts must fit. **No horizontal scrolling.** |
| Component model | Lit (`MozLitElement` from `chrome://global/content/lit-utils.mjs`) | Native web components with shadow DOM. Each component owns its CSS via `<link rel="stylesheet">`. |
| Style isolation | Shadow DOM per component | Tokens cascade in, but custom selectors do not. Set `:host { display: block }` to participate in flow. |
| Color modes | Dark/light auto via Firefox theme | Never use raw hex for color. Always use a token (semantic > palette). |
| CSS file pattern | `<component>.css` next to `<component>.mjs`, loaded via `chrome://browser/content/aiwindow/components/<component>.css` | Standard registration in `ui/jar.mn`. |
| Build registration | `moz.build` + `ui/jar.mn` | Adding new files requires registering in both. `./mach build faster` won't pick up new `moz.build` entries — first build needs full `./mach build`. |

---

## 2. Tokens (153 unique in use — these are the canonical set)

### 2.1 Spacing

Use spacing tokens, not raw px, for vertical rhythm and padding between sections. Raw px (4/8/12/16) is acceptable for tight intra-component layout (icon gaps, badge padding) — both patterns coexist in the codebase.

| Token | Typical use |
|---|---|
| `--space-xxsmall` | Hairline gaps between adjacent inline elements |
| `--space-xsmall` | Icon-to-label gaps, chip padding |
| `--space-small` | Default block margin (`margin-block` on `:host`), card inner padding |
| `--space-medium` | Section padding inside cards |
| `--space-large` | Spacing between major sections |
| `--space-xlarge` | Top-level layout breaks |

### 2.2 Typography

| Token | Use |
|---|---|
| `--font-size-root` | Body default |
| `--font-size-large` | Section headings |
| `--font-size-small` | Card body text, secondary copy |
| `--font-size-xsmall` | Captions, timestamps, footnotes |
| `--font-weight` | Default body weight |
| `--font-weight-semibold` | Subheadings, emphasis |
| `--font-weight-bold` | Page titles, strong emphasis |

For oversized hero numbers (e.g., the 36px temperature in weather-artifact), raw `font-size` is fine — these are one-offs, not part of the type scale.

### 2.3 Color — Semantic (prefer these over palette)

| Token | Use |
|---|---|
| `--text-color` | Primary body text |
| `--text-color-deemphasized` | Secondary text, captions, disabled labels |
| `--heading-text-color` | Headings |
| `--disclaimer-text-color` | Legal/disclaimer copy |
| `--icon-color` | Default icon fill/stroke |
| `--color-surface-variant` | Card backgrounds (used by weather-artifact) |
| `--background-color-box` | Default container background |
| `--background-color-box-info` | Info/callout containers |
| `--border-color` / `--border-color-default` | Card and divider borders |

### 2.4 Color — Palette (use only when semantic doesn't fit)

- Grayscale: `--color-gray-05/20/30/60/70/80/90/100`
- Brand violets: `--color-violet-0/10/20/30/40/50/60/70/80/90/100/110`
- Brand purples: `--color-purple-0/10/20/40/60/70`
- Accent: `--color-blue-40/50`, `--color-pink-0`
- States: `--color-red-50` (error/destructive)
- Neutrals: `--color-black`, `--color-white`, `--color-black-alpha-30`, `--color-white-alpha-20`

### 2.5 Brand & AI-Window-Specific

| Token | Use |
|---|---|
| `--smartwindow-brand-accent` | Smart Window brand accent color |
| `--smartwindow-content-max-width` | Width cap for chat content area |
| `--smartwindow-shadow` | Brand shadow for raised surfaces |
| `--smartwindow-assistant-link-color` (+ `-hover/-active/-visited`) | Links inside assistant messages |
| `--smartwindow-assistant-accent-color-focus` | Focus accent |
| `--aiwindow-text-accent` | Accent text in AI window chrome |
| `--aiwindow-border-subtle` | Low-emphasis dividers |
| `--aiwindow-callout-text-color` (+ `-hover`) | Callout text |
| `--aiwindow-callout-border-color` | Callout border |
| `--aiwindow-popover-bg` | Popover backgrounds |
| `--aiwindow-memory-item-bg` | Memory list items |

### 2.6 Borders, Radii, Shadows

| Token | Use |
|---|---|
| `--border-radius-xsmall` | Small chips, inputs |
| `--border-radius-small` | Buttons, tags |
| `--border-radius-medium` | Cards (default for artifacts) |
| `--border-radius-large` | Modals, large containers |
| `--border-radius-circle` | Avatars, icon-only buttons |
| `--border-width` | Default 1px |
| `--box-shadow-level-1/2/3` | Elevation scale (1 = subtle, 3 = prominent) |
| `--box-shadow-color-lighter-layer-1` | Composable shadow color |
| `--focus-outline` + `--focus-outline-offset` | **Required on all interactive elements** for accessibility |

### 2.7 Sizing

| Token | Use |
|---|---|
| `--icon-size-small` / `--icon-size-medium` | Standard icon sizing |
| `--size-image-small` | Inline image size |
| `--size-item-small/medium/large/xlarge` | Generic item sizing |
| `--smartbar-height` / `--smartbar-width` | Smartbar chrome — don't override |
| `--panel-max-width` | Popover panel width cap |

### 2.8 Component-scoped tokens (don't reinvent)

These are specific to existing components — only relevant if you're modifying them. **Don't create new component-scoped tokens for new artifacts unless absolutely necessary** — prefer the semantic tokens above.

- Smartbar: `--smartbar-button-background-color`, `--smartbar-button-border-color`, `--smartbar-button-text-color`, `--smartbar-cta-icon-fill`
- Chips: `--chip-border-color`, `--chip-hover-*`, `--chip-selected-*`, `--chip-text-color*`, `--chip-label-mask-size`
- Context chips: `--context-chip-*`
- Buttons: `--button-background`, `--button-background-dark`, `--button-border-*`, `--button-padding-block`, `--button-font-*`, `--button-box-shadow`, `--button-separator-color`
- Chat assistant: `--chat-assistant-footer-button-*`, `--chat-assistant-loader-*`, `--chat-bubble-inset-color`, `--assistant-box-shadow`, `--assistant-error-color`
- Panels: `--panel-icon-fill-color`, `--panel-icon-stroke-color`, `--panel-item-icon-size`, `--panel-item-icon-url`, `--panel-item-padding`, `--panel-section-header-color`, `--panel-section-header-font-size`
- Voice: `--voice-button-active-bg`, `--voice-button-active-fill`
- Memories: `--memories-accent-bg-active`, `--memories-accent-bg-hover`, `--memories-accent-border`

---

## 3. Component Inventory

All paths relative to `browser/components/aiwindow/ui/components/`.

### 3.1 Core chrome (don't touch)

| Component | Purpose |
|---|---|
| `ai-window/` | Root Smart Window shell. Hosts smartbar + chat content. |
| `ai-chat-content/` | Chat conversation container (lives in remote `#aichat-browser`). |
| `ai-chat-message/` | Individual chat bubble. Storybook variants: `UserMessage`, `AssistantMessage`, `AssistantMessageWithMarkdown`. |
| `smartwindow-heading/` | Section heading primitive. |
| `smartwindow-footer/` | Footer chrome. |
| `smartwindow-prompts/` | Suggested prompt buttons. |
| `smartwindow-panel-list/` | Panel list primitive. |

### 3.2 Smartbar input area

| Component | Purpose |
|---|---|
| `input-cta/` | Smartbar input call-to-action wrapper. |
| `voice-input-button/` | Voice input toggle. |
| `context-icon-button/` | Context chip icon button. |
| `memories-icon-button/` | Memories shortcut button. |
| `ai-search-button/` | Search trigger button. |
| `ai-website-chip/` | Website context chip in input. |
| `website-chip-container/` | Container for chips. |

### 3.3 Artifacts (canonical examples — copy these patterns)

| Component | Purpose | Lines | Read first if you're building... |
|---|---|---|---|
| `weather-artifact/` | Weather card (current + forecast). Two API sources (Merino + Open-Meteo) branched in render. | ~325 | Any data-display widget with multiple API sources, hero numbers, horizontal forecast strip. |
| `trip-artifact/` | Travel planner with multi-section layout. | ~436 | Anything with sections, lists of items, expand/collapse, multi-day itineraries. |

> **Read at least one of these end-to-end before writing a new artifact.** They demonstrate the real Lit patterns, the real state handling, and the real CSS organization used in production.

---

## 4. The Artifact State Contract

The `/prototype-design` skill prescribes **loading / loaded / error / empty** as required states. The codebase reality is slightly looser — `weather-artifact` uses:

```js
render() {
  const cssLink = html`<link rel="stylesheet" href="...">`;
  if (!this.weatherData)            return loading;
  if (this.weatherData.error)        return error;
  if (!forecasts?.length)            return nothing;   // empty
  return loaded;
}
```

**Recommended pattern for new artifacts:**

```js
render() {
  const cssLink = html`<link rel="stylesheet" href="chrome://browser/content/aiwindow/components/<name>.css">`;

  if (!this.data) return html`${cssLink}${this.#renderLoading()}`;
  if (this.data.error) return html`${cssLink}${this.#renderError()}`;
  if (this.#isEmpty()) return html`${cssLink}${this.#renderEmpty()}`;
  return html`${cssLink}${this.#renderLoaded()}`;
}
```

**Each state must:**

- **Loading** — Skeleton or text. Match the loaded layout's bounding box where possible to avoid jank. Existing pattern is a small text label (`"Loading weather..."`); a skeleton is fine for richer artifacts.
- **Error** — User-readable message + retry affordance if the operation is retriable. Use `--color-red-50` or `--assistant-error-color` for emphasis. Never expose raw error JSON.
- **Empty** — Helpful message explaining why there's no data and what the user can do. `return nothing` is acceptable only when the empty state is intentionally invisible.
- **Loaded** — Full content. Use cards (`var(--color-surface-variant)` background, `var(--border-radius-medium)` radius, `var(--border-color-default)` border) as the default container.

---

## 5. Layout Primitives for the 400px Smart Window

| Pattern | When | How |
|---|---|---|
| **Single card** | Default for one-shot data (weather now, single trip). | `:host { display: block; margin-block: var(--space-small); }` + `.card { background, border, radius }` |
| **Card with header strip** | Most artifacts. | Header row uses `display: flex; justify-content: space-between; padding: 12px 16px; gap: 8px` (raw px is the existing pattern) |
| **Horizontal scroll-strip** | Forecast hours, day chips. | `display: flex; overflow-x: auto;` — but only for *short* horizontal lists. Vertical scrolling is preferred. |
| **Stacked sections** | Multi-part data (trip days, multiple metrics). | Vertical flex with `--space-medium` between sections. |
| **Hero number** | Headline metric (temperature, count, score). | Raw `font-size: 36px; font-weight: 300; line-height: 1` — large + light is the existing pattern. |

**Forbidden:**
- Horizontal layout that requires the user to scroll the entire artifact horizontally
- Fixed pixel widths greater than ~360px (leaves room for Smart Window gutter)
- Any layout that breaks below 300px Smart Window width

---

## 6. Common Imports and Boilerplate

Top of every Lit component:

```js
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
import { html, nothing } from "chrome://global/content/vendor/lit.all.mjs";
import { MozLitElement } from "chrome://global/content/lit-utils.mjs";

export class FeatureArtifact extends MozLitElement {
  static properties = {
    data: { type: Object, attribute: false },
  };

  constructor() {
    super();
    this.data = null;
  }

  render() { /* ... */ }
}

customElements.define("feature-artifact", FeatureArtifact);
```

CSS file (`feature-artifact.css`):

```css
/* MPL header */
:host {
  display: block;
  margin-block: var(--space-small);
}

.feature-card {
  background: var(--color-surface-variant);
  border: 1px solid var(--border-color-default);
  border-radius: var(--border-radius-medium);
  overflow: hidden;
  font-size: var(--font-size-small);
}
```

Loaded via `<link rel="stylesheet" href="chrome://browser/content/aiwindow/components/feature-artifact.css">` from inside `render()`.

---

## 7. Accessibility Floor

- **Focus rings on every interactive element** — use `--focus-outline` + `--focus-outline-offset`. Don't `outline: none` without a replacement.
- **Alt text on `<img>`** — even decorative weather icons get `alt={condition}`.
- **Semantic HTML inside the shadow root** — `<button>` for clicks, `<a>` for navigation, headings nested correctly.
- **Color is not the only signal** — error states need an icon or text label, not just `--color-red-50`.

---

## 8. When to Diverge

This document is a contract for *prototype-grade* work. Diverge when:

1. The user explicitly asks for an exception (e.g., "use a custom color, this is a launch-day demo").
2. The existing artifact you're modeling on already diverges (cite it).
3. A token genuinely doesn't exist for what you need — then add the value as a raw `px` or named color *inside the component* (not as a new global token), and flag it in the build report so it can be promoted later.

Never silently invent global tokens. Never silently break the 400px constraint.
