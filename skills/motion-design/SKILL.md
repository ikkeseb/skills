---
name: motion-design
description: "Make a short motion reel or promo for a product as a finished mp4 with sound: one concept, one musical score that drives both picture and soundtrack, canvas scenes in the product's own look, rendered frame-exact with motion blur and checked for judder. Use for a teaser, launch video, product reel or animated demo. Not for screen recordings of a live app, slide decks (html-slides) or static pages."
---

# motion-design

The deliverable is a video someone would send to a friend: 20–40 s, 1920×1080, 60 fps, sound
on, looking like the product made it. Two failures to design against: a reel that looks like a
template (generic type, no idea, motion for its own sake) and a reel that stutters (pops, jumps,
fast motion strobing at video frame rates).

The architecture is fixed and ships in `assets/`: one HTML page where `reel.js` holds the
product's look, the timeline and the score; `engine.js` is the clock, helpers, motion blur and
offline audio; each scene is a file drawing on a 2D canvas as a pure function of time; each
music candidate is a file synthesizing the score with Web Audio. Because every frame is a
function of `t`, rendering is exact on any machine, with or without a GPU.

## 1. Read the product

Find its design tokens (stylesheet variables, a design system), its fonts and their licence,
one real screenshot of its main screen, its one-sentence pitch and its signature component
(the thing a user would recognize: a waveform lane, a card, a chart, a map).

Done when you can name the palette with hex values, the type families, the signature component
and the pitch, each from a source you read.

## 2. Write the concept and the brief

One idea the whole reel enacts, not a feature list: the product doing its thing, building up
to a peak. Pick a tempo so every cut lands on a bar line (at 140 BPM a bar is 1.714 s). Write
`BRIEF.md` beside the reel: the concept in two sentences, a scene table (bars, what sound
enters, what the picture does, the exact copy), the type rules (families, sizes, tracking, at
most one headline and one small caps line per shot, margins) and the motion rules (below).
Write every word of copy yourself; scene authors render it verbatim.

Motion rules that belong in every brief: every move eases; things land on beats via
`k.env(inst)`; a slow camera drift so nothing sits still; no element jumps between consecutive
frames except on a scored hit; fast large motion is slowed or blurred, never left to strobe; a
scene's first frame is already a finished composition (it is a cut).

Done when `BRIEF.md` holds the concept, the full scene table with copy, and both rule sets.

## 3. Build the engine

Copy `assets/` into the reel's folder (scratch space, not a project's source tree). Fill in
`reel.js`: the tokens, `SCENES`, the score (layers enter as the picture builds; breaks and
risers before the peak; a last hit on the end card) and the signature component as a helper,
so every scene draws the same product. Point `index.html` at the product's font files. Serve
the folder over HTTP (`python3 -m http.server 8791 --bind 127.0.0.1`).

Write one throwaway scene and look at a still (`index.html?t=<seconds>`).

Done when the still shows the signature component in the product's look and the console is
clean.

## 4. Fan out the pieces

One author per scene file and per music candidate, in parallel if your harness can dispatch
agents; a cheaper model is fine for a piece because you hold the concept, the seams and the
assembly. Give the hero scene (the peak) two independent takes, and the music two candidates
with different flavours. Each author:

- reads `BRIEF.md`, `reel.js`, `engine.js` and the screenshot, and edits only its own file
  (`scenes/<id>.js` or `music/<x>.js`; an alternative take is `scenes/<id>b.js`, viewed with
  `?<id>=<id>b`);
- writes the file in parts, never one long write;
- for a scene: takes at least five stills across its time range, looks at each and fixes what
  is off before returning;
- for music: schedules every score event at `when + e.b * REEL.BEAT`, pure synthesis, then
  measures `REEL.renderAudio()` until the peak is below 0.95 and the per-bar RMS follows the
  arrangement (quiet open, rising layers, a dip at the break, loudest at the peak).

Done when every scene and both candidates exist and each author has reported its stills or
measurements.

## 5. Review the draft

Render a draft (`node render.mjs draft.mp4`), tile frames into contact sheets
(`ffmpeg -i draft.mp4 -vf "fps=1.2,scale=640:-1,tile=3x6" sheet-%d.png`) and judge the reel as
a whole: does each shot read in half a second, does it look like one product, is there an
empty or static frame. Pick between alternative takes. Send each weak scene back once with a
concrete note (what is wrong and what it should feel like), not a rewrite request.

Done when every scene passes your read or has had its one revision.

## 6. Polish for smoothness

Run `node judder.mjs draft.mp4 --bpm <tempo>`. It lists frames whose change from the previous
frame is far above the median and not on a cut: a short run is a pop or a discontinuity, a
long run is fast motion strobing. A run on a scored hit (a crash flash) may be intended;
everything else gets fixed. Typical fixes: replace a value that steps with one that eases; let
the camera continue across a cut instead of resetting; slow a large high-contrast element or
shrink its travel; give a pop a few frames of `outBack` instead of one frame; render with
motion blur (`--blur 8`).

This pass is where the finished look comes from. Do it yourself or give it to your strongest
model, scene by scene, with the judder report and the stills as input.

Done when judder reports no unintended runs and a live playback (`index.html`, click) shows no
stutter you can see.

## 7. Render and deliver

`node render.mjs <name>.mp4 --blur 8 --query "music=a"` per music candidate. The script
renders the audio offline, normalizes it to −14 LUFS (so candidates compare on music, not
volume) and encodes H.264 + AAC with `faststart`. Deliver the files with what differs between
them and what nobody has verified (no one has heard the audio until the user plays it).

Done when each mp4 plays, `ffprobe` shows a video and an audio stream of the reel's length,
and the render printed no page errors.
