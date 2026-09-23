# Design

Read this before writing a document's HTML. `assets/base.css` is the design:
paper, ink, type scale, rules and spacing are fixed so every document reads
as set by the same careful hand. A document decides only what its content
decides, in a small override stylesheet.

## What the document decides

| Choice | Default | Set it when |
|---|---|---|
| Voice | Serif text, sans headings and tables | Add `class="sans"` to `<body>` for documents read by scanning, not reading: invoices, CVs, clinical summaries, forms |
| Density | Reading density | Add `class="compact"` to `<body>` when the content must fit a page or is dense by nature: CVs, invoices, one-pagers |
| Accent | `#1d4f7c` ink blue | Set `--accent` and `--accent-wash` for the subject (below) |
| Opener | `.doc-head` | Add `ruled` for a formal front (reports, specs), `cover` for a title page |

One accent per document. It marks the kicker, links, the callout edge and the
raised initial; it never tints the page, fills table headers or carries
state. State uses `.ok`, `.warn` and `.bad`, and only where the content has
state.

Accents that hold up in print (text-grade contrast on white):

| Subject | `--accent` | `--accent-wash` |
|---|---|---|
| Neutral work, reports | `#1d4f7c` | `#eef2f6` |
| Money, health, nature | `#2e6a4c` | `#edf3ef` |
| Personal, warm | `#8f3b1b` | `#f7efe9` |
| Formal, legal | `#22252a` | `#f1f1ef` |
| Creative | `#5a2f6b` | `#f3eef5` |

Pick another hue when the subject has one (a brand colour, an institution's
colour), keeping the accent dark enough to read as text.

## Vocabulary

- **Opener:** `<header class="doc-head">` with an optional `p.kicker` (the
  document type and date), `h1`, optional `p.subtitle` (one sentence on what
  this is), optional `p.meta` (who, when, reference).
- **Headings:** `h2` for sections, `h3` for items within them. Headings name
  the content ("Month-end reporting"), never the genre ("Overview").
- **Figures:** `div.figures` of up to four `div`s, each a `b` number and a
  `span` label, for numbers that are the message. Numbers that are merely
  data go in a table.
- **Callout:** `div.callout` for the one passage a reader must not skim
  past; `callout-warn` and `callout-ok` when it carries state. One per page
  at most.
- **Facts:** `dl.facts` for labelled details: parties, dates, references,
  patient or project data.
- **Pair:** `div.pair` puts two blocks side by side: sender and date,
  billed-to and payment details.
- **Tables:** plain `table` with `thead`; `td.num`/`th.num` right-align
  numbers; `tr.total` closes a column of amounts.
- **Text:** `.lede` gives the first paragraph a raised initial, for essays
  and personal letters only; `.muted`, `.small`, `.num` (tabular figures),
  `blockquote`, `.two-col`.
- **Code:** `pre` and `code`; a listing that may span pages goes in a
  `section.code-block` together with its heading (`gotchas.md` §1).
- **Closing:** `div.signature` with `p.name` and `p.role`.
- **Pagination:** `.page-break` before a major section, `.no-break` around
  anything that must stay together.

When the content needs a shape the vocabulary lacks, build it from the base
variables (`--ink`, `--rule`, `--gap`, the faces) so it belongs.

## Fonts

The base stacks use installed fonts only, so rendering needs no network:
a serif (Charter or Iowan Old Style on macOS, Cambria on Windows, DejaVu
Serif on Linux), a sans (Avenir Next, Segoe UI, Helvetica Neue) and a mono.
The PDF embeds whichever face the machine resolved; the same source can
render in different faces on different machines.

For one specific face, add an `@font-face` rule in the override pointing at a
local font file whose licence permits embedding (the OFL faces do), then set
`--serif` or `--sans`. Never fetch fonts from a web service: an offline
render silently falls back to another face.

## Running section header

For a long multi-section document, a running header helps navigation:

```css
h2 { string-set: section content; }
@page { @top-right { content: string(section); font-family: var(--sans);
  font-size: 7.5pt; color: var(--ink-3); } }
@page :first { @top-right { content: none; } }
@page code-page { @top-right { content: none; } }
```

Skip it for letters, one-pagers and anything under four pages.

## Technical notes

- WeasyPrint renders static HTML and CSS, no JavaScript. Grid and flex both
  work for simple layouts; keep them one level deep.
- A4 is the default; override `@page { size: letter; }` when needed.
- Set `lang` on `<html>` for hyphenation. Use `<sub>` and `<sup>`, not
  Unicode substitutes whose glyph coverage varies by font.
