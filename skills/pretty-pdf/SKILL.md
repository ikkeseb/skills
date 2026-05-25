---
name: pretty-pdf
description: >
  Create visually polished, professionally designed PDF documents using weasyprint (HTML+CSS → PDF).
  Use whenever creating a NEW PDF from scratch where the output should look designed — reports,
  letters, summaries, medical documents, personal letters, invoices, proposals, cover letters, recipes,
  travel itineraries, one-pagers, CVs, or any other document that will be read or shared and benefits
  from typographic care. Applies across all domains — work, personal, medical, legal, creative. Also
  use when the source content lives in a docx that should be re-typeset into a polished PDF. Adapt
  the design (typography, color palette, layout density) to match content and context. Do NOT use
  for: reading, extracting, merging, splitting, rotating, or form-filling existing PDFs (use the
  default pdf skill); generating fillable AcroForm PDFs (weasyprint produces flat PDFs only); or
  throwaway/quick-dump PDFs where the user signals they want output fast, not polished.
---

# Pretty PDF — Beautiful PDF Creation

## Setup

`pip install weasyprint`. Platform notes:

- **Windows:** weasyprint also needs the GTK3 runtime (Pango/Cairo/GLib DLLs). Install with
  `winget install tschoonj.GTKForWindows` (one-time, ~50MB, UAC prompt) or download from
  github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases.
  Without GTK3, `import weasyprint` fails at load time with a `cannot load library 'libgobject-2.0-0'` error.
- **macOS:** `brew install pango` first, then `pip install weasyprint`.
- **Linux:** `pip install weasyprint` usually suffices (Pango/Cairo come from system libs;
  on Debian/Ubuntu: `apt install libpango-1.0-0 libpangoft2-1.0-0`).

Verify: `python -c "import weasyprint; print(weasyprint.__version__)"`.

## Core Approach

**HTML + CSS → PDF via weasyprint.** Write semantic HTML with a carefully designed stylesheet,
then convert to PDF. This gives full control over typography, layout, colors, and spacing.

```python
import weasyprint
weasyprint.HTML(string=html_content).write_pdf(output_path)
```

## Performance

A cold render costs ~0.5–1s wall time and ~600KB of Google Fonts download per PDF — there
is **no caching by default**, not even across renders inside the same Python process. If
you're generating multiple PDFs in one session, reuse a single `FontConfiguration` to skip
re-downloading fonts each time. Measured: render 2+ drops from ~1.6s → ~0.27s.

```python
from weasyprint import HTML
from weasyprint.text.fonts import FontConfiguration
fc = FontConfiguration()
for spec in jobs:
    HTML(string=spec.html).write_pdf(spec.path, font_config=fc)
```

Offline / firewalled environments will silently fall back to system fonts — the PDF still
renders but looks visibly different. For deterministic offline builds, self-host the fonts
and reference via `@font-face { src: url('./fonts/...') }`.

## Before You Start

1. **Read the source content first** — what kind of document is this actually? A clinical
   summary, a personal letter, a recipe, a quarterly report, a CV? Tone, audience, density,
   and reading context drive every design choice that follows. **Don't pick fonts or palette
   before you've read the content** — the design should serve what's being communicated,
   not be selected upfront from a default.
2. **Read `references/base-styles.md`** — contains the full CSS system, font pairings keyed
   to content cues, and color palettes.
3. **Read `references/templates.md`** — HTML templates for common document types and design
   guidance.
4. **Read `references/gotchas.md` when any of these apply:** the document contains long code
   blocks that will span pages, or the source content is a docx with images. These are empirical
   traps with tidy fixes — skim it so you don't rediscover them the hard way.

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
specific content and context — not stamped from a template. The CSS system is built around five
independent variation axes; pick a **non-default value on at least 3 of 5** for every document,
or you've shipped a re-skin, not a design.

#### The five axes

| Axis | Default (fallback) | Pick by content |
|------|---------|------------|
| Font pairing | Inter Tight (clean sans, single-family) | Read content first. Letter/literary → Cormorant or EB Garamond. Clinical → DM Sans. Editorial → Fraunces+Work Sans. Tech → Space Grotesk+IBM Plex. Full table in `base-styles.md`. |
| Palette | Slate | One of 8 in `base-styles.md` — each overrides 5-7 vars (chrome/borders/bg move together) |
| Header | `.header-typeset` (pure-type, quiet) | `.header-minimal`, `.header-side-rule`, `.header-centered`, `.header-large-numeral` (sparingly), `.header-bar` (sparingly, loudest) |
| Type scale | Editorial | `body class="scale-compact"` (denser) or `body class="scale-generous"` (more breathing room) |
| Edge weight | Standard | `body class="edges-hairline"` (refined, near-zero radii) or `body class="edges-chunky"` (bold, larger radii) |

A medical summary in DM Sans + Teal + `.header-minimal` + `.scale-compact` + `.edges-hairline`
should be unrecognizable from a personal letter in Cormorant + Terracotta + `.header-centered`
+ `.scale-generous` + standard edges. If two of your recent PDFs share more than 2 axes, you're
converging — stop and re-pick.

#### Specific things to avoid

- **Don't pick fonts before reading content.** The default Inter Tight is for "I genuinely
  don't know what this is" — every document where you DO know the tone should override it.
  A clinical summary and a personal letter sharing a typeface is the failure mode.
- **Vary palettes.** A letter to a doctor and a quarterly report should not share a color
  scheme. Slate is the safe pick; pick differently when you can.
- **Don't reach for `.header-bar` by default.** It's the loudest chrome element in the system
  — every doc using it looks like every other doc using it. `.header-typeset` or
  `.header-minimal` carries most documents better.
- **Match complexity to vision.** A formal letter needs precision and restraint — not fewer
  elements, but every element placed with care. A creative brief can be bolder and more expressive.

Avoid generic AI-generated aesthetics: overused font families (Inter classic, Arial, plain
system fonts), clichéd color schemes (purple gradients, corporate blue-on-white), zebra-striped
tables, rounded corners on printed images, and predictable safe layouts. If the design wouldn't
stand out printed and handed to someone, push harder.

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

1. **Read the source content first.** What document type? Who reads it? What tone? Until you've
   answered this, you don't know what to design.
2. **Pick fonts + palette + header to match the content** — use the cue tables in
   `references/base-styles.md` (Font Loading) and the palette guidance. Defaults exist as
   fallback only; using them on a document where you know the type is the convergence failure.
3. Read `references/base-styles.md` — copy the full `<style>` block as your starting point.
4. **Customize the design** — replace the `@import` URL if you picked a non-default pairing,
   swap CSS variables for palette, set body class for scale/edge if appropriate. Don't ship
   defaults unchanged unless they genuinely fit.
5. Choose the right template from `references/templates.md` or build from scratch.
6. Write semantic HTML — `<h1>`, `<h2>`, `<p>`, `<table>`, `<blockquote>`, etc. Set
   `<html lang="...">` so hyphenation works.
7. Test page breaks — use `.page-break` and `.no-break` utility classes.
8. **Images:** use absolute paths or base64-encoded data URIs. **If the source is a docx with
   images, read `references/gotchas.md §2` first** — Word crops live in `document.xml`, not in
   the media file, and extracting the raw image loses them silently.
9. **Long code blocks:** if a `<pre>` will span page breaks, read `references/gotchas.md §1`.
   Shipping multi-page code with a page footer will break copy/paste for users. The fix is
   either (a) shrink the code to fit on one page, or (b) use a named `@page` to suppress the
   footer on code pages. Do not reflex-split into a sidecar file.
10. Save the final PDF to an absolute local path (e.g., the user's Downloads folder, or wherever
    they specify). Use `weasyprint.HTML(...).write_pdf(absolute_path)`. Relative paths are resolved
    from the current working directory, which is rarely what the user wants — be explicit.

## Relationship to Other Skills

- **Default `pdf` skill:** Reading, merging, splitting, form-filling, rotating — all manipulation of existing PDFs
- **`docx` skill:** When the user explicitly wants a Word document
- **This skill:** When creating any new PDF where visual quality matters
