---
name: prettier-html
description: "Art-direct a single-file HTML page with editorial ambition, designing a fresh visual concept from the content each time: launches, showcases, announcements, flagship reports. Not for plain reading documents (pretty-html), decks (pretty-slides), or web-app frontends."
---

# Prettier HTML

The deliverable is a page that looks individually designed. The reader
should believe a designer art-directed it for exactly this content. This
skill deliberately ships no template and no house palette: the skill owns
the ambition level, the quality floor, and the measured traps; the design
is yours to invent each time.

**Two pages produced by this skill must not look alike.** If swapping in
a different subject's content would leave your macro-composition intact
(same region order, same proportions, only new copy and colors), you have
templated, not designed. That is the failure mode this skill exists to
prevent.

## Design before code

Form a concept from the content and write it down in one short paragraph
before any markup. Taste signals from the user or the session (palette
likes and dislikes, motion appetite, a named mood) outrank everything in
this file except the invariants. The concept names:

- **Mood:** what the subject and audience call for, and whether you meet
  or deliberately subvert that expectation.
- **Content-shaped composition:** the concrete relationship in the
  content (a sequence, a ledger, a comparison, a single continuous
  thread…) that determines the macro-layout and reading order. If that
  relationship changed, the region order or proportions would have to
  change with it.
- **Palette:** light or dark ground, warm or cool neutrals chosen from
  the mood (cool and neutral grounds are as legitimate as warm paper;
  "editorial" is not a reflex toward brown), and a
  deliberately limited chromatic system where every color has one stated
  job, usually exactly one accent. When something else genuinely needs
  emphasis, carry it with position, scale, isolation, or weight. Never a
  second job for the accent, and never a boxed/outlined panel as the
  reflex (on dark grounds those read as a glow, not emphasis).
- **Typographic attitude:** how scale, weight, and tracking carry the
  hierarchy on this particular page. Serif, sans, or mixed is a concept
  decision, not a default.
- **One structural motif** that recurs and makes the page cohere: a
  visible grid, a rule system, offset columns, a numbering scheme, a
  margin apparatus. Invent what fits the content.

Done when: replacing the brief's content would force a different
macro-composition, not merely different copy, color, or ornament.

## The ambition level (calibration, not a look)

One measured reference page that earns this level used the ranges below.
They describe that page's complete solution, not defaults: **a new page
may reuse at most one of these concrete devices unchanged**. Derive the
rest from your concept. The measured values are the devices; the
restraint items are floor rules and never count against reuse.

- **Scale contrast**: display type in the 56–120px range with tight
  negative tracking, against 11–12px uppercase mono microlabels. The
  span between the largest and smallest type is where the drama lives.
- **Whitespace at page scale**: 80–130px between sections; hierarchy
  from space and scale, not boxes and borders.
- **Restraint**: one chromatic accent on the whole page; hairlines as
  low-alpha ink (0.05–0.22 alpha), not solid grey borders; no gradients
  or decoration that carries no information.
- **Structure made visible**: rules, dotted grids, and column edges that
  show the page's skeleton instead of hiding it.
- **Motion belongs at this ambition level**: entrance reveals, rules
  that draw themselves, staggered arrivals, numbers that count up. Be
  generous enough that the page feels alive: starving it of motion reads
  as unfinished, drowning it reads as noise. Two hard rules: reveal at
  the level of sections or clusters, never every row individually, and a
  fast scroll must outrun the choreography. Content the reader has
  passed appears settled, never queued behind animations still playing.
  Motion supports discovery, never becomes the identity: no smooth
  scrolling, nothing loops or autoplays. (Reference values: reveals rise
  12–28px, fade in around 750–900ms, short staggers.)

Distinctiveness comes from composition, structure, and palette, not from
exotic fonts. Default to the system font stack; embed a local font file
as a data URI only when the session verifiably has one that is licensed
for it.

## Invariants (the floor)

1. **One self-contained file.** Inline all CSS/JS; no CDNs, no external
   fonts, no network requests. It must render perfectly from `file://`
   offline. Give it a real `<title>`, and an inline favicon when the
   concept has a mark.
2. **Both themes, art-directed separately.** Each theme re-decides its
   surfaces and ink, never a mechanical inversion. The concept picks the
   primary edition, but the system preference wins on first load, so both
   editions must stand alone as designed. Route every theme-dependent
   color through one complete token set, redeclared in full per theme
   with `color-scheme` set: the `@media (prefers-color-scheme: dark)`
   layer guarded as `:root:not([data-theme="light"])`, then
   `:root[data-theme="dark"]` and `:root[data-theme="light"]` overrides,
   then a fixed toggle button (top-right, persists via localStorage with
   a key unique to this artifact). No component-level theme colors
   outside the tokens. Dark grounds are near-black and deliberate, not
   grey-blue washes.
3. **Responsive reflow.** Include the viewport meta tag. At 360px and at
   full desktop width, nothing overlaps, clips, or scrolls horizontally;
   display type and composition reflow deliberately (clamped/fluid
   sizes, collapsing columns). Hiding overflow is not a fix.
4. **Motion degrades safely.** `prefers-reduced-motion` collapses all
   animation to near-zero, and scroll-revealed content is visible by
   default, hidden only after the reveal machinery successfully arms
   (see the wiring below), so no failure mode can leave content blank.
5. **Accessibility floor.** Real heading order and a `lang` attribute.
   All text meets WCAG AA contrast in both themes (4.5:1 normal, 3:1
   large), measured for every text style, not eyeballed; the smallest
   and faintest styles are the likeliest failures. Boundaries that
   convey state or affordance, and focus indicators, reach 3:1;
   hairlines that only convey grouping may stay low-alpha. The toggle is
   a native `<button>` with an accessible name.
6. **Print survives at legible grade.** `@media print`: white
   background, dark ink, toggle hidden, all reveal states forced
   visible, no clipped content, viewport-height and sticky/fixed layouts
   neutralized. Full print art direction is out of scope; legibility is
   not.
7. **Language follows the audience** of the artifact, independent of
   chat language.

## Wiring, not design

Bug-prone plumbing. Take it as given and spend your effort on the
design. The snippets expect these exact hooks: a `<button
class="theme-toggle">`, reveal targets carrying class `.reveal` (a
section or cluster, never every row), your CSS hiding them only under
`.reveal-armed .reveal` (the `.reveal` element itself carries the
hidden state, not its children) and showing them again via `.on`. Both
scripts go at the end of `<body>`; only the theme boot script goes in
`<head>` so first paint is correct.

```html
<!-- in <head> -->
<script>
  (function () {
    var k = 'theme-UNIQUE-SUFFIX', t = null;
    try { t = localStorage.getItem(k); } catch (e) {}
    if (t === 'dark' || t === 'light') document.documentElement.dataset.theme = t;
  })();
</script>
<!-- end of <body> -->
<script>
  document.querySelector('.theme-toggle').addEventListener('click', function () {
    var k = 'theme-UNIQUE-SUFFIX', root = document.documentElement;
    var dark = root.dataset.theme
      ? root.dataset.theme === 'dark'
      : matchMedia('(prefers-color-scheme: dark)').matches;
    root.dataset.theme = dark ? 'light' : 'dark';
    try { localStorage.setItem(k, root.dataset.theme); } catch (e) {}
  });
</script>
```

Reveals: armed only when safe, watchdog only for a dead observer, and
*reveal-through*: when any target intersects, everything before it in
document order reveals too, which is what makes jump scrolls, anchor
links, and full-page screenshot tools safe (measured failure without
it):

```html
<script>
  (function () {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches
        || !('IntersectionObserver' in window)) return;
    document.documentElement.classList.add('reveal-armed');
    var targets = Array.prototype.slice.call(document.querySelectorAll('.reveal'));
    var fired = false;
    var io = new IntersectionObserver(function (es) {
      fired = true;
      es.forEach(function (e) {
        if (!e.isIntersecting) return;
        for (var j = 0; j <= targets.indexOf(e.target); j++) {
          targets[j].classList.add('on');
          io.unobserve(targets[j]);
        }
      });
    }, { threshold: 0.15 });
    targets.forEach(function (el) { io.observe(el); });
    setTimeout(function () {
      if (!fired) targets.forEach(function (el) { el.classList.add('on'); });
    }, 1400);
  })();
</script>
```

## Measured traps

- **Print rules lose the specificity fight against theme selectors**
  (bit two independent builders): a plain `@media print { :root {…} }`
  is outranked by `:root[data-theme="dark"]`, printing dark panels and
  invisible ink while the body background still looks right. Write print
  token overrides with at least the explicit theme selectors' specificity
  (e.g. `:root, :root[data-theme="dark"] {…}` inside the print block).
- **Decorative filler must never mimic data visualization**: no rails
  with dots, no unlabeled axes, no fake charts as ornament. Readers parse
  them as broken content, and any example that carries them gets cloned
  into real pages.
- **Settled screenshots hide motion bugs.** A page can look perfect
  after animations finish while a cascade defect breaks the transition
  itself; QA must catch at least one frame mid-reveal.
- **Display-scale system-stack bold turns clunky.** At 60px+ the system
  sans's default heavy weight reads as unstyled boldness (measured on a
  build that shipped without visual QA). The largest type on the page
  needs the most deliberate styling: tune weight, tracking, and
  line-height on purpose, or take a serif/mono attitude instead.
- **Auto-inverted themes read as broken.** A palette flipped
  mechanically produces washed-out surfaces and wrong shadow directions;
  re-decide each theme's surfaces deliberately (invariant 2).

## Routing and delivery

- **Where to save:** follow the owning repo's rules first, otherwise the
  repo's natural artifacts location, or the session scratchpad for
  throwaways. Content about named people or otherwise sensitive material
  goes wherever the repo keeps uncommitted/private files, never somewhere
  that auto-publishes. QA artifacts (screenshots, PDFs) are session
  working files for the scratchpad; the deliverable stays one file.
- **Deliver** the rendered file directly to the user (in Claude Code:
  SendUserFile with `display: render`).
- **Never publish** (Artifact tool / external hosting) unless the user
  explicitly asks.

## Done when

QA runs through a scripted browser (e.g. Playwright against `file://`);
if the session has no browser tooling, deliver with an honest list of
the checks you could not perform, never claiming them.

- The file was opened from `file://` with no console errors.
- Themes: with the storage key cleared, loaded under system light and
  system dark; then each explicit theme forced opposite the system
  scheme, with a reload proving persistence and a correct first paint.
  Both editions read as designed, not inverted.
- Contrast was measured, not eyeballed, in both themes (invariant 5).
- Motion was checked with reduced-motion emulated and with at least one
  mid-reveal frame sampled.
- The page was checked at 360–390px wide with zero horizontal overflow.
- Print preview shows a legible page from both explicit themes.
- You can state in one line why this design could only belong to this
  content, and swapping the content would break the composition.
