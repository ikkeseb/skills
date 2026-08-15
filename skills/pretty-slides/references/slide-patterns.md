# Slide patterns

Read this when choosing a layout for a specific slide. The engine template
ships one worked example of each pattern — copy its markup and replace the
content. Class names below are the hooks the engine's choreography binds to.

The catalog is a vocabulary, not a cage: the content decides. When a slide
genuinely fits no pattern, author a new layout inside the design invariants
(tokens, ornament budget, motion vocabulary) rather than forcing a bad fit —
and prefer bending an existing pattern before inventing from zero.

| Pattern | Hook | Reach for it when | Failure mode |
|---|---|---|---|
| Title | `.s1-body` | The opening. Kicker row, huge display title, byline; optionally a full-bleed image band when a real image exists — otherwise no band. | Decorative filler in the band: unlabeled rails/dots/pseudo-diagrams read as broken content. Also: cramming an agenda under the title — the overview grid (`G`) is the agenda. |
| Statement | `.statement` | One claim must land on its own. Optional identity-square second line and mono attribution row. | Using it for lists; a statement with three clauses is a numbered-lines slide. |
| Section divider | `.divider` | Chapter breaks in decks over ~10 slides. Giant mono numeral, title, drawn rule. | Dividing a 6-slide deck — dividers need chapters worth dividing. |
| Numbered lines | `.room` | 3–5 parallel spoken beats, each a full sentence. Closing line takes the identity square. | Bullets-in-disguise: lines that nobody would say out loud. |
| Exchange | `.work` | A real question/prompt and its condensed answer, with a source line. | Inventing or prettifying the quoted material — it must be verbatim. |
| Timeline | `.tl` | A story with stations. The "now" station takes the identity color. | More than ~6 stations; labels start colliding. |
| KPI / big number | `.kpi` | 1–3 figures that ARE the message. `.count` numerals tween on reveal. | Decorating a slide with numbers that aren't the message. |
| Comparison | `.cmp` | Two things argued row by row across a dotted spine — rows reveal as pairs, so the contrast is the beat. | Two unrelated lists side by side; if rows don't pair, use two slides. |
| Duo | `.duo` | Text column beside one dark media plate. | A light image on the dark plate; render media dark. |
| Solo | `.solo` | One diagram deserves the whole stage. `object-fit: contain`. | Shrinking a wide artifact into a card — cropped previews read as broken. |
| Artifact series | `data-group` | Several artifacts each get the full frame under one held header: same `data-num`, same `data-group`, identical header markup. | Cramming multiple previews onto one slide instead. |

## Decided against

Recorded so future sessions don't re-argue them:

- **Quote pattern** — a pull-quote is a statement with the attribution row.
- **Agenda pattern** — dead air; the `G` overview grid covers it on demand.
- **Closing/contact pattern** — the title pattern with a different kicker.
