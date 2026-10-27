---
name: html-brief
description: "Turn content into one self-contained, dark HTML document made to be read: plans, status, findings, decisions, run sheets, day sheets, prep docs, summaries, comparisons, explanations, or an existing HTML file restyled. Triggers on an ask for 'an html' or a polished HTML page of content to read. Not for an art-directed launch, showcase or landing page (html-showcase), decks (html-slides), or web-app frontends."
---

# HTML brief

One finished file the user opens locally, screen-shares or forwards. The
reader gets almost everything from the summary on the first screen and
scrolls only for depth. Every element must make the document quicker to
grasp, or it goes.

Start from `assets/template.html`. Its stylesheet is the design and stays as
it is, type sizes included; its body is a catalogue to empty and compose
from. Per document you set the accent pair and pick the pieces.

## Invariants

1. **One self-contained file.** Inline CSS, system fonts, zero network
   requests; it renders from `file://` offline.
2. **Black on screen, light in print**, handled by the stylesheet. A light
   screen theme (`<html data-theme="light">`) only when the user asks for
   one. No theme toggle, hero image, icons or emoji.
3. **One raised block: the summary.** Everything else sits on hairlines.
4. **Language follows the ask:** the language the user writes in, unless
   they name another. Technical terms keep their usual form. Set
   `<html lang>` to match.

## Compose

**Header.** A `.meta` line (project, kind of document, date, one state), an
`h1` that says the point in plain words, and one `.lede` line.

**The summary is the product.** Read alone, it gives the reader almost
everything they need, short, plain and easy to grasp:

- a bottom line in one or two sentences;
- three to five points, one line each where possible;
- the ask, when the reader must decide or do something (`.note.ask`);
- one visual, when it makes the point quicker: `.summary.split` puts the
  words in `.say` and the visual in `.see`;
- facts (ids, dates, counts) only when the reader may need them.

**Below it, less.** Two or three short sections, each `h2` a sentence that
carries the point. Don't repeat the summary. Evidence, per-item detail, ids,
file lists and reasoning the reader rarely needs are cut, or folded into
closed `details` under a last section. Prefer cutting. In prose, plain words
beat code tokens; commands the reader will run go in `pre.cmd`. Name things,
not codes: a session id, plan letter or internal label the reader may not
know becomes what it is.

**The visual follows the content.**

| The content has | Use |
|---|---|
| items compared across the same attributes | a table (`.stack` on a phone) |
| numbers to compare | `.bars` |
| parts of one total | `.dist` with `.legend` |
| order, a pipeline, a before and after | `.flow`, or `.chain` with a state per step |
| one line per item, each with a state | `.rows` |
| options to choose between | `.options`, `.pick` on the recommended one |
| steps to run | `ol.steps` with `pre.cmd`; `.two` on a long run sheet puts them in two columns on a wide screen |

No visual where words are quicker. For a missing shape (a line over time, a
timeline), build one small piece from the base variables, with inline SVG
for a chart.

**State** is a dot and a word (`.st.ok`, `.warn`, `.bad`, `.now`, `.wait`),
never colour alone. **One accent pair** per document, from the template's
list, chosen to fit the subject (a product's own colour when it has one).
Nothing else is coloured.

## Deliver and check

Save where the owning repo's rules say, else its artifacts location or the
session scratchpad; content about named people goes where the repo keeps
uncommitted files. Hand the file to the user (Claude Code: SendUserFile,
`display: render`). Publish only on explicit ask.

Done when you opened it via `file://` with no console errors and looked at a
wide window (about 2500 px) and at 390 px: the first screen carries the
point, the summary alone gives almost everything, nothing overflows, no
catalogue placeholder is left, and the user would forward it unedited.
