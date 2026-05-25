---
name: pretty-pdf
description: >
  Create visually polished, professionally designed PDF documents using weasyprint (HTML+CSS → PDF).
  Use this skill whenever creating NEW PDFs from scratch — reports, letters, summaries, medical documents,
  personal letters, invoices, proposals, cover letters, recipes, travel itineraries, one-pagers, CVs,
  or any other document where the output should look like it was designed by a professional.
  This skill applies to ALL PDF creation regardless of topic or domain — work, personal, medical, legal,
  creative. Trigger on any "create/generate/write/make a PDF" request, including when the source
  content lives in a docx that should be re-typeset into a polished PDF. Adapt the design (typography,
  color palette, layout density) to match the content and context. Do NOT use for reading, extracting,
  merging, splitting, or form-filling existing PDFs — use the default pdf skill for those operations.
---

# Pretty PDF — Beautiful PDF Creation

## Core Approach

**HTML + CSS → PDF via weasyprint.** Write semantic HTML with a carefully designed stylesheet,
then convert to PDF. This gives full control over typography, layout, colors, and spacing.

```python
import weasyprint
weasyprint.HTML(string=html_content).write_pdf(output_path)
```

## Before You Start

1. **Read `references/base-styles.md`** — contains the full CSS system, font stack, and color palettes.
2. **Read `references/templates.md`** — contains HTML templates for common document types and design guidance.
3. **Read `references/gotchas.md` when any of these apply:** the document contains long code blocks
   that will span pages, or the source content is a docx with images. These are empirical traps
   with tidy fixes — skim it so you don't rediscover them the hard way.

## Design Philosophy

The goal is PDFs that look like they were typeset by someone who cares. Not "default LaTeX" and
not "PowerPoint exported to PDF" — somewhere between a well-designed book interior and a premium
consulting firm's deliverables.

### Core Principles

- **Typography IS the design.** Distinctive, characterful font choices — not safe defaults. Pair a
  display font with a body font that creates tension and interest. This alone gets you 80% of the way.
- **Whitespace is a feature.** Generous margins, breathing room between sections, no cramming.
- **Restraint over decoration.** One dominant accent with sharp contrast outperforms a timid,
  evenly-distributed palette. Commit to a cohesive aesthetic.
- **Adapt to context.** A medical summary needs clinical scannability. A travel log can be warm
  and expressive. A business proposal should feel authoritative but not cold. Read the room.

### Anti-Convergence Rule (critical)

NEVER produce the same visual design twice. Each PDF should feel like it was designed for its
specific content and context — not stamped from a template. This means:

- **Vary fonts between documents.** Don't always reach for Source Sans/Serif. The base stylesheet
  is a starting point — swap the `@import` URL and CSS variables to use different Google Fonts
  for different documents. See `base-styles.md` for proven font pairings.
- **Vary palettes.** Don't default to the same blue/slate every time. A letter to a doctor and
  a quarterly report should not share a color scheme.
- **Vary layout patterns.** Not every document needs a header-bar. Some documents are better with
  a minimal rule, a centered title, or no header decoration at all.
- **Match complexity to vision.** A formal letter needs precision and restraint — not fewer elements,
  but every element placed with care. A creative brief can be bolder and more expressive.

Avoid generic AI-generated aesthetics: overused font families (Inter, Arial, system fonts), clichéd
color schemes (purple gradients, corporate blue-on-white), and predictable safe layouts. If the
design wouldn't stand out printed and handed to someone, push harder.

## Choosing a Design Direction

Before writing HTML, decide on the design direction based on what's being created:

| Context | Palette | Typography feel | Density |
|---------|---------|-----------------|---------|
| Business/corporate | Slate, navy, or steel | Clean sans-serif headings, serif body | Medium |
| Medical/clinical | Muted teal or warm gray | Clear sans-serif throughout | High — scannable |
| Personal letter | Warm earthy tones or soft palette | Elegant serif throughout | Low — spacious |
| Creative/portfolio | Bold accent, dark bg option | Distinctive display font | Varies |
| Legal/formal | Conservative dark palette | Traditional serif | High |
| Invoice/financial | Clean minimal | Tabular sans-serif | Medium-high |

These are starting points, not rules. The CSS system in `base-styles.md` uses CSS custom properties
so you can swap the entire palette by changing 6 variables.

## Implementation Checklist

1. **Choose a design direction first** — before touching any code, decide: what aesthetic fits
   this content? What fonts, palette, and layout density? Refer to the context table below and
   the palettes/fonts in `references/base-styles.md`.
2. Read `references/base-styles.md` — copy the full `<style>` block as your starting point
3. **Customize the design** — swap CSS variables for fonts, palette, and spacing. Don't use the
   defaults unchanged unless they genuinely fit this specific document.
4. Choose the right template from `references/templates.md` or build from scratch
5. Write semantic HTML — `<h1>`, `<h2>`, `<p>`, `<table>`, `<blockquote>`, etc.
6. Test page breaks — use `.page-break` and `.no-break` utility classes
7. **Images:** use absolute paths or base64-encoded data URIs. **If the source is a docx with
   images, read `references/gotchas.md §2` first** — Word crops live in `document.xml`, not in
   the media file, and extracting the raw image loses them silently.
8. **Long code blocks:** if a `<pre>` will span page breaks, read `references/gotchas.md §1`.
   Shipping multi-page code with a page footer will break copy/paste for users. The fix is
   either (a) shrink the code to fit on one page, or (b) use a named `@page` to suppress the
   footer on code pages. Do not reflex-split into a sidecar file.
9. Save final PDF to `/mnt/user-data/outputs/`

## Relationship to Other Skills

- **Default `pdf` skill:** Reading, merging, splitting, form-filling, rotating — all manipulation of existing PDFs
- **`docx` skill:** When the user explicitly wants a Word document
- **This skill:** When creating any new PDF where visual quality matters
