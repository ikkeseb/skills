---
name: html-brief
description: "Turn content into a dark, self-contained HTML brief that reads at a glance: summaries, status reports, decision briefs, meeting notes, prep docs, comparisons. Not for showcase pages (html-showcase), decks (html-slides), or web-app frontends."
---

# HTML brief

A brief is one finished file the user opens locally, screen-shares or sends
onward. Its reader gets the point from the first screen and scrolls only for
depth. The bar: useful and good-looking with zero follow-up fixes.

Start from a copy of `assets/template.html`. Its stylesheet is the design:
surfaces, ink, the sans type and the spacing are fixed, so the result stays
clean whoever builds it. Its body is a catalogue of shapes. Empty it, then
compose the brief from the shapes this content calls for.

## Invariants

1. **One self-contained file.** All CSS inline, system fonts, zero network
   requests. It renders from `file://` offline.
2. **Dark, in the template's type.** Keep its surfaces, ink and sans stack.
   Set another typeface only when the user asks for one.
3. **The glance answers.** The brief opens with a `.glance` block: the
   verdict, status or recommendation in one sentence, then the few facts
   behind it. A reader who stops there has the brief. Background, method and
   caveats follow it, or fold into `details`.
4. **Every section earns its place.** When the brief runs long, cut content
   or fold it into `details`; the template's spacing stays as it is.
5. **Language follows the audience** of the document, whatever the chat uses.

## Compose

Two briefs on different subjects look different, because each is composed
from its own material:

- **The glance.** A decision leads with the verdict, a status with figures or
  a short board, a comparison with the pick, a plan with the next date and
  step.
- **The shapes.** Match shape to data: `figures` for a few numbers, `board`
  for items with a state, `cols` for options or parties, `steps` for order,
  `timeline` for time, `meter` for a share, `table` for three or more
  attributes, `callout` for the one warning. Two or three shapes carry most
  briefs, and prose is a shape: a short brief may be a glance and four
  paragraphs. A board shows what differs, so items sharing a state with
  nothing to add collapse into one row. Headings name the content.
- **`--hue`.** One accent per document, chosen for the subject: 150 green
  for money or health, 25 rust for personal, 235 blue for neutral work, 300
  violet for creative, or your own. `good`, `warn` and `bad` mark state only.
- **Width.** Add `wide` to `.wrap` when boards, columns or tables carry the
  brief.

When the content has a shape the catalogue lacks, build it from the
template's variables and spacing so it belongs. Everything on the page
carries information: text, numbers, hairlines and flat surfaces, with emoji
and icons left out.

## Routing and delivery

- **Save** where the owning repo's rules say, otherwise in its natural
  artifacts location, or the session scratchpad for throwaways. Content about
  named people or otherwise sensitive material goes where the repo keeps
  uncommitted files.
- **Deliver** the rendered file directly to the user (in Claude Code:
  SendUserFile with `display: render`).
- **Publish** (Artifact tool, external hosting) only on the user's explicit
  ask.

## Done when

You opened the file from `file://`, saw no console errors, and looked at it:
the glance alone carries the point, every catalogue placeholder is gone,
nothing overflows at a narrow width, and the user would forward it unedited.
