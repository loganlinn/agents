---
name: html-artifact
description: >-
  Produce a single-page, self-contained HTML report as a richer alternative to
  markdown output. Use when the user asks for a "slide-style report", "HTML
  artifact", "rich report", "HTML version of this", "one-pager", "exportable
  report", or when the content benefits from structure (cards, tables, tiered
  recommendations, diagrams) that plain markdown renders flatly. Includes
  light/dark toggle, markdown fallback view, copy-code buttons, expandable
  sections, print-to-PDF styling, and responsive layout.
argument-hint: "[filename] [--focus=...] [--theme=...] [freeform instructions]"
allowed-tools: Read, Write, Edit, Bash, Agent
---

# HTML Artifact

Generate a polished, single-page HTML report from the current conversation's content. The output is a richer alternative to markdown — readable on screen, printable to PDF, and degrades gracefully to a raw-markdown view for pasting into chat/PR/issues.

## When to use

Trigger when the user asks for:
- "output as HTML", "HTML artifact", "single-page report", "slide-style"
- "one-pager", "rich report", "exportable version"
- any output where the structure (cards, side-by-side comparisons, tiered options, tables) would be flattened by plain markdown

Prefer markdown for simple Q&A. Reach for this skill when the content has **visual structure worth preserving**.

## Process

> **IMPORTANT — context hygiene.** The template is ~18k and the generated HTML is typically 10–30k. Reading both into the main thread wastes working context. **Always delegate the generation to a subagent** via the `Agent` tool (`subagent_type: "general-purpose"`). The main thread only sees the subagent's short confirmation message.

### 1. In the main thread — decide the content and the brief

Collect the substantive points from the conversation. Default to the last analysis / recommendation / plan the main thread produced.

Organize into slide-style sections. Good section shapes:
- **Hero** — title, one-sentence thesis
- **Problem statement** — what's broken, in 2–3 cards
- **Options table** — compare alternatives in a table or tiered cards
- **Recommendation** — numbered steps
- **Blind spots / open questions** — things the user should verify

Don't pad. A 3-slide report is fine. A 12-slide one is a sign you haven't edited.

### 2. Pick an output path

Resolution order:

1. **User supplied an explicit path** (absolute or relative) → use it.
2. **Inside a git repo** → `<repo-root>/.claude/reports/<slug>.html`. This is the default.
   - Resolve repo root with `git rev-parse --show-toplevel`.
   - Create `.claude/reports/` if it doesn't exist (subagent handles this with `mkdir -p`).
   - Mention to the user once (first time per repo) that reports are written here and can be gitignored via `.claude/reports/` in `.gitignore` if they want.
3. **Not in a repo** → `/tmp/claude/<slug>.html`.

`<slug>` is a short kebab-case summary of the topic (e.g. `npm-registry-options`, `kafka-playbook-summary`). Keep it under ~40 chars.

### 2a. Parse invocation arguments

The user may pass freeform instructions along with the invocation. Recognize:

| Form | Meaning |
|---|---|
| bare filename (`migration-plan` or `migration-plan.html`) | Use as `<slug>`; apply output-path resolution above |
| absolute/relative path | Use as the exact output path |
| `--focus=<text>` or `focus on <text>` | Emphasize this theme in slide selection & ordering |
| `--theme=<name>` | Color theme override (see Custom themes below) |
| `--accent=<css-color>` | Override just the accent color |
| `--interactive=<feature>` | Add a specific interactive element (see Custom interactivity) |
| any other freeform prose | Forward to the subagent as "additional instructions" |

Parse loosely — these are hints. If you can't tell, ask the user before delegating.

### 3. Delegate generation to a subagent (in the background)

Invoke `Agent` with `subagent_type: "general-purpose"` and **`run_in_background: true`**. The main thread keeps going; the subagent completion fires a notification when done.

Why background by default:
- Generation takes 10–60 seconds. Blocking the main thread wastes that time.
- The user can continue the conversation while the report generates.
- The subagent opens the file itself (see brief below), so there's no handoff needed on completion.

When to run **foreground** instead (set `run_in_background: false`):
- User explicitly asks to see the file before continuing ("let me review it before we move on").
- Short report (≤ 2 slides) where the generation is fast and the user will look at it immediately anyway.
- The user's next request in the session depends on the report's content existing on disk.

The prompt must be **self-contained** — the subagent has no conversation context.

Include in the prompt:

1. The template path: `~/.claude/skills/html-artifact/assets/template.html` — tell it to **Read** this first.
2. The component rules (copy the relevant sections of this SKILL.md inline, or reference the skill path).
3. The full slide content — all headings, body prose, tables, cards. Spell it out. Don't say "summarize the discussion"; write the actual text.
4. The full markdown fallback content for the `<script type="text/markdown">` block.
5. The output path.
6. **Open instruction** — the subagent runs the platform-appropriate `open` command after Write succeeds (see brief). This way the file opens at completion without the main thread needing to handle it.
7. An explicit instruction to return only: `{path, bytes, slide_count, opened: true|false}`. No narration, no summary of what it did.

Template prompt skeleton:

```
Generate an HTML artifact using the template at ~/.claude/skills/html-artifact/assets/template.html.

Output path: <absolute-path>.html
(Create parent directories if missing: `mkdir -p $(dirname <path>)`)

Title: <title>
Eyebrow: <eyebrow>
Subtitle: <subtitle>

Slides:
<full HTML-ready content for each slide>

Markdown fallback (embed verbatim in <script type="text/markdown" id="md-source">):
<full markdown mirror>

Footer: <footer>

Focus (optional): <user's focus instructions — shape slide selection & emphasis around this>

Theme override (optional):
  Inject <style>:root { --accent: <color>; ... }</style> AFTER the template's <style> block.
  Only override the CSS variables listed in the Custom themes section of SKILL.md.

Custom interactivity (optional): <description of extra interactive elements to add>
  Implement as a single inline <script> block at the end of <body>. No external deps.

Rules:
- Read the template. Substitute {{TITLE}}, {{EYEBROW}}, {{SUBTITLE}}, {{SLIDES}}, {{MARKDOWN}}, {{FOOTER}}.
- Use Write (not Edit) since this is a new file.
- Do NOT modify the template's core CSS or JS — only append overrides.
- Do NOT add external links (CDN, fonts, libs).
- Keep the page self-contained.
- After Write succeeds, open the file in the default browser:
    macOS:         open "<path>"
    Linux:         xdg-open "<path>" 2>/dev/null
    WSL/Windows:   cmd.exe /c start "" "<path>"  or  explorer.exe "<path>"
    If $BROWSER is set, prefer: "$BROWSER" "<path>"
  If the open command fails or returns non-zero, set opened=false and continue — do not retry.
- Respond with only: {path, bytes, slide_count, opened}. Nothing else.
```

Skip the open step only if the user's original request included "just write it", "don't open", or "save only" — propagate that flag into the brief.

### 4. Handle the handoff

**If you ran the subagent in the background:**

- Immediately tell the user: "Generating report in the background at `<path>`. I'll let you know when it's ready." — then carry on with whatever the user asks next.
- When the completion notification fires, relay the subagent's result in one line: path, size, and whether the browser opened. Example: `Report ready at <path> (12 KB, opened in browser)`.
- If `opened: false`, surface the path with a one-line suggestion to open manually (`open <path>` on macOS).
- If the subagent errored, show the error and ask whether to retry.

**If you ran the subagent in the foreground:**

- Same handoff, just inline rather than async.
- Do **not** re-read or summarize the generated HTML — trust the subagent's confirmation. If the user wants changes, delegate those to a new subagent.

## Component library

All components live in the template. Use them as-is; customize content only.

### Slide container
```html
<section class="slide">
  <h2><span class="n">1</span> Section title</h2>
  <p class="lede">Optional one-line summary.</p>
  <!-- body -->
</section>
```

Hero variant: add `class="slide hero"` for the first slide.

### Cards (single, 2-col, 3-col)
```html
<div class="grid-2">
  <div class="card accent-green">
    <h3>Left title</h3>
    <p>…</p>
  </div>
  <div class="card accent-red">…</div>
</div>
```
Accent classes: `accent-green`, `accent-blue`, `accent-yellow`, `accent-red`, `accent-purple`.

### Tags / pills
```html
<span class="tag green">fork</span>
<span class="tag blue">internal</span>
<span class="tag yellow">deprecated</span>
<span class="tag red">blocker</span>
```

### Tables
Standard `<table>` — the template styles them. Use `<thead>` / `<tbody>`. Keep columns ≤ 4 for readability.

### Code blocks
```html
<pre><code class="language-bash">aws codeartifact login --tool npm</code></pre>
```
The template auto-adds a **Copy** button to every `<pre>`. No extra markup needed.

For inline code: `<code>value</code>`.

### Expandable sections
```html
<details>
  <summary>Click to expand details</summary>
  <p>Hidden content…</p>
</details>
```
Native `<details>` — prints expanded in PDF export, survives the markdown-view toggle.

### ASCII/monospace diagrams
```html
<div class="flow">BEFORE
  $ command here
AFTER
  $ different command</div>
```

### Mermaid diagrams
The template does **not** bundle Mermaid (keeps it dependency-free). If a diagram is essential, render it as an SVG inline, or fall back to the `.flow` monospace block.

## Required features (already in template — do not remove)

1. **Light/dark toggle** — `<button class="tb-btn" data-action="theme">`. Persists in `localStorage` under `html-artifact-theme`. Respects `prefers-color-scheme` by default.
2. **Markdown view** — `<button class="tb-btn" data-action="markdown">` or URL fragment `#md` / query `?view=md`. Replaces page content with a `<pre>` of the markdown source. Back button / removing the fragment restores HTML view.
3. **Copy code** — every `<pre>` gets a Copy button, positioned top-right. Hidden in print and markdown views.
4. **Print** — `<button class="tb-btn" data-action="print">` calls `window.print()`. `@media print` rules: white background, black text, no toolbar, no copy buttons, details expanded.
5. **Responsive** — grids collapse to single column < 720px. Toolbar stays reachable.

## Custom themes

The template is unopinionated about color — everything keys off CSS variables on `:root`. Override by appending a `<style>` block after the template's existing `<style>` (subagent does this, not a template modification).

**Named themes** — recognize these and translate to variable overrides:

| Theme | Accent | Notes |
|---|---|---|
| `default` | `#0969da` (blue) | Template default, GitHub-like |
| `sunset` | `#e06c3f` (warm orange) | Warm palette, accent green → amber |
| `forest` | `#1a7f37` (green) | Nature palette, cooler greens |
| `plum` | `#8250df` (purple) | Editorial / literary |
| `terminal` | `#3fb950` on black | Mono-heavy, high contrast |
| `paper` | `#333` on cream | Light-only, print-optimized |

**Override-able variables** (both `:root` and `:root[data-theme="dark"]`):
- Surfaces: `--bg`, `--panel`, `--panel-2`, `--line`
- Text: `--text`, `--text-strong`, `--muted`
- Semantic: `--accent`, `--green`, `--yellow`, `--red`, `--purple`
- Fonts: `--sans`, `--mono` (stick to system fonts — no web font requests)

**Do NOT override** the component structure (padding, radii, grid layouts). Theme overrides are colors only.

Example theme override block:
```html
<style>
  :root {
    --accent: #e06c3f;
    --green: #d29922;
  }
  :root[data-theme="dark"] {
    --accent: #ff8a5b;
    --green: #eac54f;
  }
</style>
```

## Custom interactivity

The user can request extra interactive elements. Common requests and sanctioned patterns:

| Request | Implementation |
|---|---|
| Tabs | `<div role="tablist">` with buttons toggling `.active` on content panes. ~30 lines of JS. |
| Filter / search bar | Plain `<input>`; filter by hiding `.slide` elements that don't match `textContent`. |
| Checklist state persistence | `<input type="checkbox">` with `localStorage` keyed by an explicit `data-id`. |
| Progress tracker | `<progress>` element updated from checklist state. |
| Table sort | Click handler on `<th>` that re-sorts sibling `<tr>` by column. |
| Anchor TOC | `<aside>` fixed to the side, JS builds from `h2` elements. |

**Constraints for all custom interactivity:**
- Single inline `<script>` at the end of `<body>`. No external deps, no CDN.
- Wrap in IIFE. Don't leak globals.
- Must work in the markdown view too, OR be cleanly disabled there (no console errors).
- Print-friendly: custom UI chrome hides under `@media print`.
- Keyboard accessible: tab order, Enter/Space activation, `aria-*` where relevant.

If the request doesn't fit the template's aesthetic (e.g., "add a game"), push back — this skill is for reports, not apps. Use the `playground` skill for that.

## Writing the markdown fallback

The skill produces both views from one source. Rules for the `<script type="text/markdown">` block:

- Mirror the structure of the HTML, flattened: `## Slide title` per section.
- Replace `.card` groupings with bolded sub-heads (`**Title**`).
- Replace tables with markdown tables.
- Replace `.flow` blocks with fenced code blocks.
- Preserve `<details>` as GitHub-flavored `<details>` blocks — GitHub renders them natively.
- Keep it paste-ready: the output should look good pasted into a PR description, Linear comment, or Slack.

## Example invocations

```
User: "output as an html artifact"
→ Build from the last substantive turn. Write to <repo>/.claude/reports/<slug>.html.

User: "save as html, focus on the CI side of this"
→ Build with slides re-ordered to prioritize CI content. Default path.

User: "/html-artifact migration-plan --theme=sunset"
→ Slug migration-plan, sunset theme override, default path.

User: "html artifact with a TOC sidebar and a filter box, plum theme"
→ Default path. Plum theme. Add a custom <script> for TOC + filter.

User: "render that to docs/proposals/registry.html"
→ Explicit path wins; skip default resolution.

User: "/html-artifact inf-113-playbook focus on Kafka failure modes and add
       a checklist that persists state"
→ Slug inf-113-playbook, Kafka-centric slides, custom interactivity for
  a localStorage-backed checklist.
```

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| Output dir | Where to write reports | `<repo>/.claude/reports/` in a git repo, else `/tmp/claude/` |
| Filename | Report filename | `<slug>.html` (slug derived from topic) |
| Theme | Color palette | `default` (see Custom themes) |
| Focus | Content emphasis | None — uses the last substantive turn verbatim |

## Anti-patterns

- **Don't link to external CSS frameworks** (Tailwind CDN, Bootstrap). Self-contained means self-contained.
- **Don't bundle JS libraries** (React, Alpine, Mermaid) unless the user explicitly asks. The template is vanilla.
- **Don't skip the markdown fallback.** It's the paste-ready escape hatch; a report without it is half-built.
- **Don't omit the viewport meta tag** (already in template). Mobile users will see broken layouts.
- **Don't over-decorate.** Three accent colors per slide is the max. Six tags in one paragraph is noise.
