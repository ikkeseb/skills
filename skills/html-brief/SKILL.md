---
name: html-brief
description: "Turn content into one self-contained, dark, editorial HTML document: plans, summaries, breakdowns, explanations, decisions, run sheets, day sheets, prep docs, status, comparisons, multi-part packs, or an existing HTML file restyled. Triggers on any ask for a polished HTML page or 'an html'. Not for showcase pages (html-showcase), decks (html-slides), or web-app frontends."
---

# HTML brief

One finished file the user opens locally, screen-shares or forwards. "Brief"
is loose: a plan, a day sheet, a status, a decision, an explanation, a
breakdown, a multi-part pack. The reader gets the point from the first screen
and scrolls only for depth. Least noise, fastest overview: every element must
make the document quicker to grasp, or it goes.

Start from `assets/template.html`. Its stylesheet is the design and stays as
it is, type sizes included; its body is a catalogue to empty and compose from.

## Invariants

1. **One self-contained file.** Inline CSS, zero network requests, renders
   from `file://` offline. Fonts: Build, step 2.
2. **Dark on screen, light in print** (ready for PDF), handled by the
   stylesheet. No theme toggle, hero image, icons or emoji. A light screen
   theme only when the user asks for one.
3. **One box: the glance.** It holds what the reader must not miss.
   Everything else sits on hairlines, with the left rail carrying the spine
   (`.row` > `.rail`).
4. **Every section earns its place.** Long? Cut, or fold into `details`;
   never shrink type or spacing. **Language follows the audience** of the
   document, not the chat.

## Compose

**The spine.** Pick what the rail carries from this content:

| Document | Rail carries | Body shapes |
|---|---|---|
| Meeting prep | act numerals I II III + minutes | `.act` rows, `.list` with say-lines, one `.quote` |
| Day / run sheet | times | `.slot` rows, `.cols` for the week |
| Plan | phase numbers or dates | `.act` rows 01.., `.cols` for options |
| Status / summary | area or workstream | `.row.tagged` entries, `table` with `.tag` states |
| Decision / comparison | option or criterion | `.cols` with `.now` on the pick, `table` |
| Explanation | part numbers 01.. | `.act` rows, `.quote` for the key line |
| Breakdown | category | `table`, `.bar` for shares |
| Pack with many segments | one tab per segment | `.tabs`, each panel with its own spine |

**The glance.** After the `header` (mono `.label`, an `h1` that is a
sentence, a one-line `.lede`): the `.verdict` in one sentence with `em` on
the phrase that matters, then three to five `.figs` when numbers or dates
carry the answer, such as the total, the gap or the next step. A run sheet may
open with its anchor slot instead.

**The body.** One `.block` per section: a `.row` head (rail label, `h2`
sentence, `.sub`), then `.act` rows (parts, phases) or `.slot` rows (times,
dates). Rail content is a time, a numeral or one or two words, never a
sentence. Two or three shapes carry a document; prose is a shape too
(`.wrap.narrow`).

- **Headings are sentences from the content.** "Agenda" is the `.label`;
  the `h2` says "Three parts, in your order." `.say[data-tag]` holds words
  to say verbatim.
- **One accent** in `--accent`: amber `#E9B44C` for personal and prep work,
  teal `#3E8A85` for product and project work. `.now` marks the anchor
  (today, the pick, the ask); `.tag.good/.warn/.bad` mark state. Nothing
  else is coloured.
- **Bars only when relative size is the point**: shares of a total, budget
  used, one option against another. Never on a single number or as decoration.
- **A table holds short cells**: numbers, single words, a state. Entries
  that each carry a sentence go in `.row.tagged` rows, which stack on a
  phone where a table of sentences overflows.
- **Tabs only for four or more distinct segments.** Panels are `.tab` with
  `data-tab`; the first is the overview. No-JS and print show every panel.
- **Missing shape?** Build it from the template's variables. The footer
  names sources, date and what was not read.

## Build

1. Copy the template, keep the `/* FONTS */` line, write the document.
2. Splice the fonts (Archivo + IBM Plex Mono, about 180 KB) without reading
   them. `$p` is the document and `$fonts` is this skill's `assets/fonts.css`,
   both as full paths:
   bash: `awk 'NR==FNR{f=f $0 RS;next} /\/\* FONTS \*\//{printf "%s",f;next}1' "$fonts" "$p" > "$p.tmp" && mv "$p.tmp" "$p"`
   PowerShell: `[IO.File]::WriteAllText($p,[IO.File]::ReadAllText($p).Replace('/* FONTS */',[IO.File]::ReadAllText($fonts)))`
3. Read the result without the font data, never raw: bash
   `grep -v base64 "$p"`, PowerShell
   `Select-String -Path $p -Pattern base64 -NotMatch`.

The fonts are under the SIL Open Font License; `assets/OFL.txt` and the
notice at the top of `assets/fonts.css` travel with them.

## Deliver and check

Save where the owning repo's rules say, else its artifacts location or the
session scratchpad; content about named people goes where the repo keeps
uncommitted files. Hand the file to the user (Claude Code: SendUserFile,
`display: render`). Publish only on explicit ask.

Done when you opened it via `file://` with no console errors and looked: the
glance alone carries the point, no catalogue placeholder is left, the fonts
are embedded, nothing overflows at a narrow width, and the user would forward
it unedited.
