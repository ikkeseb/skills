# Motion vocabulary

Read this before changing any animation, adding a pattern, or reaching for
an optional effect. The governing sentence: **motion belongs to the
pattern, never to the deck author.** Defaults fire from a pattern's normal
markup; if an author must choose an animation, it lives here as an opt-in.

## Timing and easing tokens

All in the template's token block: `--dur-slide` 480ms, `--dur-frag` 420ms,
`--dur-hero` 560ms; auto-stagger interval 340ms (per-slide override:
`data-stagger="ms"` on the section). Easing: `--ease-out` (decisive
decelerate — the default for every entrance), `--ease-soft` (long draws:
rails, rules), `--ease-spring` (identity marks only). Never use the bare
`ease` keyword — it reads as nobody chose it.

## What fires where (engine defaults)

- **Slides** rise into place going forward, descend coming back — the
  direction-aware `fwd/back` class on the stage. Within an artifact group
  (`data-group`), transitions are fade-only with no incoming delay so the
  shared header holds still.
- **Text fragments** rise 10px and fade in.
- **Plates** (`.dplate`, `.code`, `.docmock`) are *unveiled* — a clip-path
  wipe top-to-bottom with a slight settle.
- **Ruled rows** (`.rline`, `.step`, `.cmp-row`) draw their dotted line,
  then lift the text.
- **Timeline stations** glide in along the rail; the rail itself draws with
  `--ease-soft`.
- **The one content identity mark** (`.idmark`) may spring (`--ease-spring`,
  380ms) — the ornament budget extended to motion: at most one springing
  element per slide, always the identity-colored content mark. Furniture
  (kicker brand square, rail tick) never springs; nothing else overshoots.
- **Count-up numerals**: `<span class="count" data-to="42">42</span>` tweens
  from 0 over ~900ms on reveal. Hard limits: integers or one decimal only;
  prefixes/suffixes live in sibling spans; the final value is authored in
  the markup so the slide is correct with JS off. Do not extend the format
  — thousands separators and ranges are how this feature rots.

## Opt-in effects (author's choice, costs stated)

- **Kinetic statement type**: wrap a statement's clauses in spans and give
  them `nth-child` transition-delays (cap ~8), rise ~18px, slightly longer
  duration. Cost: markup discipline at authoring time. Do not attempt
  per-line mask reveals — line-splitting breaks on reflow.
- **Hero drift** (title slide only): one Ken Burns move, `scale(1) →
  scale(1.06)` over 16–20s, linear. Costs: non-deterministic screenshots
  (`?qa=1` must disable it — verify) and it must be the only
  looping-adjacent motion in the deck. Pointer parallax is rejected
  outright: invisible on a projector, fights keyboard-only presenting.

## Hard exclusions and the ceiling

Never add: anything pointer-triggered (hover, cursor parallax,
click-to-advance); scroll-driven behavior; auto-advancing *slides*
(fragments may self-reveal, slides never do — the presenter owns the beat);
3D flips/cubes/carousels; bounce or elastic on text or panels; blur-in on
type (reads as broken focus on a projector); typewriter text and spinners;
per-letter splitting (breaks selection and screen readers); looping motion
beyond the single hero drift; anything requiring a library.

Timing ceiling: no element animates longer than 900ms except the timeline
rail (1100ms), and the last fragment of an auto slide lands within ~2.5s of
slide entry. An audience waiting to read is a defect, not a flourish.

Deliberately not adopted: the View Transitions API for shared-element
continuity — a browser-support gamble on a presenting machine the author
may not control. The fade-only group is the answer; the question is closed.
