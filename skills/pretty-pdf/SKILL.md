---
name: pretty-pdf
disable-model-invocation: true
description: >-
  Create visually polished, professionally designed PDFs with weasyprint (HTML+CSS → PDF) —
  reports, letters, invoices, CVs — from new content or by re-typesetting a docx. Not for
  reading, merging, splitting, or form-filling existing PDFs (use the default pdf skill),
  fillable AcroForm output, or quick throwaway PDFs.
---

# Pretty PDF — Beautiful PDF Creation

## Core Approach

HTML + CSS → PDF via weasyprint:

```python
import weasyprint
weasyprint.HTML(string=html_content).write_pdf(output_path)
```

If `import weasyprint` fails, see `references/setup.md` for install instructions per
platform. For batch rendering (multiple PDFs in one session), reuse a `FontConfiguration` —
see the Weasyprint Technical Notes in `references/base-styles.md`.

## Workflow

1. **Read the source content first.** What kind of document is this — clinical summary,
   personal letter, recipe, quarterly report, CV? Tone, audience, density, and reading context
   drive every design choice that follows. Don't pick fonts or palette before you've read it.
   Also weigh the reader relationship: a known reader (doctor, colleague, friend) lets the
   document assume shared context and lean personal; an unknown reader (application, public
   report) wants more formality and self-explanation.
2. **Read `references/base-styles.md`** — the full CSS system, font pairings keyed to content
   cues, and color palettes.
3. **Read `references/templates.md`** — HTML templates for common document types.
4. **Read `references/gotchas.md` when it applies:** the source is a docx with images (`§2` —
   Word crops live in `document.xml`, not the media file; extracting the raw image loses them
   silently) or the document has long code blocks that will span pages (`§1` — a page footer
   pulled into a multi-page `<pre>` breaks copy/paste). Empirical traps with tidy fixes.
5. **Pick the five axes via the Anti-Convergence Rule below**, then copy the full `<style>`
   block from `base-styles.md` and swap the `@import` and CSS variables for your picks.
6. Choose a template from `references/templates.md`, or build from scratch.
7. Write semantic HTML — `<h1>`, `<h2>`, `<p>`, `<table>`, `<blockquote>`, etc. Set
   `<html lang="...">` so hyphenation works.
8. Test page breaks with the `.page-break` and `.no-break` utility classes.
9. **Images:** use absolute paths or base64 data URIs — relative paths don't resolve.
10. **Save the final PDF to an absolute output path** (the user's Downloads folder, or wherever
    they specify) via `weasyprint.HTML(...).write_pdf(absolute_path)`. Relative paths resolve
    from the current working directory, rarely what the user wants.

## Design Philosophy

The goal is PDFs that look typeset by someone who cares — between a well-designed book
interior and a premium consulting firm's deliverables.

### Core Principles

- **Typography IS the design.** Distinctive, characterful font choices — not safe defaults. Pair a
  display font with a body font that creates tension and interest. This alone gets you 80% of the way.
- **Whitespace is a feature.** Generous margins, breathing room between sections, no cramming.
- **Restraint over decoration.** One dominant accent with sharp contrast outperforms a timid,
  evenly-distributed palette. Commit to a cohesive aesthetic.

### Anti-Convergence Rule (critical)

The failure this guards against is **reaching for the default without reading the content** —
shipping Inter Tight + Slate on every document regardless of what it says. The cure is fit, not
novelty: choose each axis *from* the content, using the cue tables below and in `base-styles.md`.
The CSS system gives you five independent axes to fit with — if you've moved fewer than 3 off
their defaults, check whether that's genuine fit or just reflex.

#### The five axes

| Axis | Default (fallback) | Pick by content |
|------|---------|------------|
| Font pairing | Inter Tight (clean sans, single-family) | Read content first. Letter/literary → Cormorant or EB Garamond. Clinical → DM Sans. Editorial → Fraunces+Work Sans. Tech → Space Grotesk+IBM Plex. Full table in `base-styles.md`. |
| Palette | Slate | One of 8 in `base-styles.md` — each overrides 5-7 vars (chrome/borders/bg move together) |
| Header | `.header-typeset` (pure-type, quiet) | `.header-minimal`, `.header-side-rule`, `.header-centered`, `.header-large-numeral` (sparingly), `.header-bar` (sparingly, loudest) |
| Type scale | Editorial | `body class="scale-compact"` (denser) or `body class="scale-generous"` (more breathing room) |
| Edge weight | Standard | `body class="edges-hairline"` (refined, near-zero radii) or `body class="edges-chunky"` (bold, larger radii) |

A medical summary in DM Sans + Teal + `.header-minimal` + `.scale-compact` + `.edges-hairline`
naturally looks nothing like a personal letter in Cormorant + Terracotta + `.header-centered`
+ `.scale-generous` + standard edges — because the content pulled them apart, not a quota. Smoke
test: if a document came out looking like the last one, ask whether you read its content or
defaulted. If the content genuinely is similar, similar is the right answer.
