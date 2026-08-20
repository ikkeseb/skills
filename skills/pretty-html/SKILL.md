---
name: pretty-html
description: "Produce a polished, self-contained HTML reading document with light and dark themes: briefs, reports, meeting notes, prep docs, or restyling an existing HTML file. Not for showcase pages (prettier-html), decks (pretty-slides), or web-app frontends."
---

# Pretty HTML

The deliverable is a clean, finished artifact the user can open locally,
keep, screen-share, or send onward. It is not a draft and not a web project.
The bar is "immediately useful and good-looking with zero follow-up fixes".

Start from `assets/template.html` (copy, then adapt). It carries the
theming, toggle, and baseline rhythm already correct. Deviate freely on
layout and components. Do not deviate on the invariants below.

## Invariants

1. **One self-contained file.** Inline all CSS/JS. No CDNs, no external
   fonts, no network requests. It must render perfectly from `file://`
   offline. System font stack.
2. **Both themes, plus a toggle.** CSS custom properties define every color.
   Wire three layers so all combinations work: `@media
   (prefers-color-scheme: dark)`, then `:root[data-theme="dark"]` and
   `:root[data-theme="light"]` overrides, then a fixed toggle button
   (top-right, ◐, persists via localStorage). Give each artifact its own
   localStorage key so documents don't fight over theme state. Dark mode
   means a near-black background (`#0b0b0d`-family), not grey-blue washes.
3. **Air.** The recurring defect is dense, cramped sections. Body
   line-height ≥ 1.6, content max-width 760–860px, section gaps around
   56–64px, card padding at the template's rhythm or airier, real margins
   between list items and table rows. If the page feels long, cut or
   collapse content. Never compress the spacing to fit more in.
4. **Selective content.** "Almost too long" is a defect. Every section earns
   its place. Prefer hierarchy over volume: supporting detail goes in muted
   small-print or gets cut.
5. **Print survives.** `@media print`: white background, hide the toggle,
   `break-inside: avoid` on cards/tiles. These documents get rendered to
   PDF.
6. **Language follows the audience** of the artifact, independent of chat
   language.

## Component vocabulary

These shapes are the house style. Reuse them before inventing new ones:

- **Header:** small uppercase kicker line, large `h1`, muted lede paragraph.
- **Fact tiles:** grid of small cards, one big number/word + a caption each.
- **Numbered ladder:** stacked cards with a circled step number, for
  capability levels, phased plans, ranked lists.
- **Callout:** accent-tinted box with a left border for the one paragraph
  that must not be skimmed past.
- **Quiet tables:** hairline row borders only, no zebra stripes, uppercase
  muted headers, tall cells, no border under the last row.
- **Timeline list:** left rule with dot markers, for day-in-the-life or
  chronological narratives.
- **Tag/pill:** tiny uppercase badge for status ("in use", "emerging",
  "draft").

Accent color: one per document, used sparingly (numbers, borders, kicker).
Pick it to fit the subject. The default family is a muted blue for
neutral/work docs and warm rust for personal docs. No gradients, no emoji,
no decoration that carries no information.

## Routing and delivery

- **Where to save:** follow the owning repo's rules first, otherwise the
  repo's natural artifacts location, or the session scratchpad for
  throwaways. Content about named people or otherwise sensitive material
  goes wherever the repo keeps uncommitted/private files, never somewhere
  that auto-publishes.
- **Deliver** the rendered file directly to the user (in Claude Code:
  SendUserFile with `display: render` so it opens in the panel
  immediately).
- **Never publish** (Artifact tool / external hosting) unless the user
  explicitly asks. These documents are often private or work-sensitive.

## Done when

Every invariant above has been exercised, not assumed: the file was opened
from `file://` (no console errors), the toggle was flipped both ways, print
preview was checked, and the content survives the "would the user forward
this without edits?" test.
