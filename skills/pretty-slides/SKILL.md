---
name: pretty-slides
description: >-
  Build a presentation as one self-contained HTML file: a bundled slide
  engine (keyboard-only navigation, pattern-bound motion, full-frame
  artifact views) plus a build step that inlines fonts and images —
  re-skinnable through a token block, with a dark editorial default. For
  talks and decks that stand in for PowerPoint. Not for documents,
  one-pagers, or reports (pretty-html), print or PDF deliverables
  (pretty-pdf), or web-app frontends.
---

# Pretty Slides

The deliverable is **one self-contained HTML file** that double-clicks open
in any browser, offline. It comes from a template plus a tiny build script —
never from hand-editing the output.

- **Template + build step.** Edits happen in `template.html`; `build.py`
  inlines assets and writes the deliverable. Rebuilding is one command.
- **Keyboard-only navigation.** Presenters misclick; audiences see it. A
  mouse click never advances a slide.
- **Motion belongs to the pattern, never to the author.** Write a pattern's
  ordinary markup and the right choreography fires by itself. Never invent
  per-slide animation.

Copy the engine before reading any of it. Resolve this skill's directory
and copy `assets/engine-template.html` and `assets/build.py` into the deck
folder. When authoring, read only the template's slide sections (between
`<div class="stage">` and the rail) to copy pattern markup — never load the
`<style>` and `<script>` blocks into context; the patterns are documented
in `references/slide-patterns.md`, the motion vocabulary in
`references/motion.md`.

## Workflow

1. **Copy the engine.** Create `deck/` in the project workspace, copy
   `assets/engine-template.html` to `deck/template.html` and
   `assets/build.py` to `deck/build.py` (the rename is required: `build.py`
   reads `template.html`). Run the build with whatever Python launcher the
   machine has (`python`, `python3`, or `py -3`). If no Python exists:
   with no images or fonts configured the built file is byte-identical to
   the template, so copying `template.html` to `deck.html` is the same
   build — do that and say so in delivery. Done when `deck.html` exists
   via one of those paths, with zero warnings.
2. **Settle the copy.** Slides carry approved text; get the copy or a slide
   manifest settled before designing around it. Quoted material on a slide
   is reproduced verbatim — never invented or prettified. Done when the user
   has confirmed the content plan.
3. **Skin the deck.** Read `references/design-system.md` and walk its
   decision ladder: keep the shipped default as-is, swap a few tokens to
   match the project's visual identity, or adopt a fully custom direction if
   a proven one already exists. The default must remain a deliberate choice,
   not a fallback reached by skipping the step. Done when the token block
   reflects a stated decision.
4. **Taste test before full build.** Build the opening plus the strongest
   content slide and show the user. A wrong direction costs 2 slides, not
   13. Done when the user approves the direction. Unattended run: record
   the checkpoint, continue, and flag the direction as unapproved in
   delivery.
5. **Build all slides**, choosing layouts from
   `references/slide-patterns.md`: replace the example sections inside
   `<div class="stage">` with your own (delete what you don't use); keep
   everything outside it. Update the deck chrome to match your slide
   count and title: `<title>`, the `.hint` legend, the counter's `.tot`,
   and each slide's kicker count. Done when every slide carries real
   content, no example content remains, the chrome matches, and the build
   is clean.
6. **Run screenshot QA** (below) on every slide before claiming done.

## Navigation and pacing contract

- Arrows / Space / PageUp/Down navigate; digits + Enter jump to a slide by
  its `data-num`; `G` toggles the overview grid; Home/End work. Mouse click
  never advances.
- Fragments: `data-auto="1"` slides reveal their fragments themselves (a
  keypress fast-forwards the cascade). Leave slides manual only where each
  beat is rhetorical. Too many manual clicks kills pacing.
- `prefers-reduced-motion` and the `?qa=1` query flag both collapse every
  animation to instant. Any animation added to the engine must join both
  collapse selectors — a motion guarantee that rots is a defect.

## Screenshot QA (mandatory before "done")

Serve the deck over HTTP (`file://` is blocked in most browser automation)
and drive the real file with whatever browser automation the harness has —
`playwright-cli` where available:

```bash
python -m http.server 4477 --bind 127.0.0.1   # in the deck folder; any free port; localhost only; run backgrounded, stop it when done
# open http://localhost:4477/deck.html?qa=1 at 1440x810
# per slide: digits+Enter to jump, screenshot, then LOOK at the render
```

- `?qa=1` renders every fragment settled and motion-free, so screenshots
  are deterministic. Read every one: clipped labels, cropped images, and
  misaligned marks are found by looking at renders, never by re-reading
  code. Digits+Enter reaches only the first view of an artifact group
  (shared `data-num`) — step through the remaining group members with
  ArrowRight so every view is captured.
- Motion is invisible to the QA pass, so verify it separately without the
  flag by sampling: jump to an auto slide and screenshot immediately (a
  count-up caught mid-tween and a fragment at partial opacity prove the
  cascade fires), then screenshot again after ~2.5s to confirm everything
  settles at the authored values. Check the digit jump and the overview
  grid the same way.
- No browser automation available — including automation that is installed
  but cannot actually render a page (no browser binary, sandbox blocks the
  server): open the file in a desktop browser and check every slide by
  hand, or deliver with the explicit statement **built but not visually
  verified**, never described as polished.

## Hard rules

- On dark skins, images and diagrams must themselves be dark — a white
  canvas on a near-black slide reads as a mistake. Render diagrams with
  the background baked in.
- Wide artifacts get `object-fit: contain` in a full-frame view, never
  `cover` in a small card.
- The deliverable is generated — edit the template and rebuild, never the
  output file.
- One file, no external requests: never emit module scripts, external
  CSS/JS, fonts fetched at runtime, or anything else that breaks `file://`.
- Fabricated demo data is labeled as fictitious on the slide and must not
  resemble a real organization or person.
- Language follows the audience of the deck, independent of chat language.
