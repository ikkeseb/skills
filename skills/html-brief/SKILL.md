---
name: html-brief
description: "Turn content into a dark, self-contained HTML brief that reads at a glance: summaries, status reports, decision briefs, meeting notes, prep docs, comparisons. Not for showcase pages (prettier-html), decks (pretty-slides), or web-app frontends."
---

# HTML brief

The deliverable is one finished file the user opens locally, screen-shares or
sends onward. The reader gets the point from the first screen and scrolls only
for depth. The bar is "useful and good-looking with zero follow-up fixes".

Copy `assets/template.html`. Its stylesheet is the design: surfaces, ink,
fonts and rhythm are fixed so the result stays clean whoever builds it. Its
body is a catalogue of shapes, not a layout: delete it, then compose.

## Invariants

1. **One self-contained file.** Inline CSS, no CDNs, no external fonts, no
   network requests. It renders from `file://` offline.
2. **Dark only.** Keep the template's surfaces and ink. No light theme, no
   toggle, no print rules.
3. **The first screen answers.** Open with a `.glance` block: the verdict,
   status or recommendation in one sentence, then the few facts behind it.
   A reader who stops there has the brief. Background, method and caveats
   come after, or inside `details`.
4. **Selective content.** Every section earns its place. Cut before you
   shrink: supporting detail goes in `details`, muted small print, or out.
   Never tighten the template's spacing to fit more in.
5. **Language follows the audience** of the document, not the chat.

## Compose from the content

Two briefs on different subjects should not look alike. Decide these from
the material, not from habit:

- **What the glance holds.** A decision leads with the verdict. A status
  leads with figures or a short board. A comparison leads with the pick.
  A plan leads with the next date and step.
- **Which shapes appear.** Match shape to data: `figures` for a few numbers,
  `board` for items with a state, `cols` for options or parties, `steps` for
  order, `timeline` for time, `meter` for a share, `table` for anything with
  three or more attributes, `callout` for the one warning. Most briefs need
  two or three shapes. Prose is a shape too; a short brief may be a glance
  and four paragraphs. A board shows what differs: items that share a state
  and need no note collapse into one row. Headings name the content, never
  the shape.
- **`--hue`.** One accent per document, chosen for the subject (for example
  150 green for money or health, 25 rust for personal, 235 blue for neutral
  work, 300 violet for creative). State colors (`good`, `warn`, `bad`) mean
  state only.
- **Voice.** `class="editorial"` on `body` gives serif headings for
  reflective or narrative subjects. Default sans for operational ones.
- **Width.** `wide` on `.wrap` when boards, columns or tables carry it.

A new shape is welcome when the content has one the catalogue lacks. Build it
from the template's variables and spacing so it belongs. No gradients beyond
the template's, no emoji, no icons, no decoration that carries no
information.

## Routing and delivery

- **Where to save:** the owning repo's rules first, otherwise its natural
  artifacts location, or the session scratchpad for throwaways. Content about
  named people or otherwise sensitive material goes wherever the repo keeps
  uncommitted files, never somewhere that auto-publishes.
- **Deliver** the rendered file directly to the user (in Claude Code:
  SendUserFile with `display: render`).
- **Never publish** (Artifact tool, external hosting) unless the user
  explicitly asks.

## Done when

The file was opened from `file://` with no console errors and looked at: the
first screen alone carries the point, no catalogue placeholder text remains,
nothing overflows at a narrow width, and the user would forward it without
edits.
