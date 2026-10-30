---
name: motion-design
description: "Make a motion design piece as a finished video in its subject's own look. Use for a product reel, promo, teaser, title sequence, logo sting, animated explainer or loop. Not for screen recordings of a live app, slide decks (html-slides) or static pages."
---

# motion-design

The deliverable is a video someone would send to a friend, looking like its subject made it.
Where it plays sets the length, frame and sound: a reel is often 20–40 s at 1920×1080, 60 fps,
sound on; a sting or a loop is shorter and may be silent. Two failures to design against: a reel that looks like a
template (generic type, no idea, motion for its own sake) and a reel that stutters (pops, jumps,
fast motion strobing at video frame rates).

`assets/` ships one way to build it, a starting point to adapt or replace when the piece asks
for something else: one HTML page where `reel.js` holds the product's look, the timeline and the
score; `engine.js` is the clock, helpers, scene seams, motion blur and offline audio; each scene
is a file drawing on a 2D canvas as a pure function of time; each music candidate is a file
synthesizing the score with Web Audio. Because every frame is a function of `t`, rendering is
exact on any machine, with or without a GPU.

## 1. Read the subject

The subject is what the piece is about: a product, a brand, an event, an idea. Find its design
tokens (stylesheet variables, a design system, brand guidelines), its fonts and their licence,
one real image of it (for a product, a screenshot of its main screen), its one-sentence pitch
and its signature component (the thing a viewer would recognize: a waveform lane, a card, a
chart, a map, a logo mark).

Done when you can name the palette with hex values, the type families, the signature component
and the pitch, each from a source you read.

## 2. Write the concept and the brief

One idea the whole piece enacts, not a feature list: the subject doing its thing, building up
to a peak. Pick a tempo so every cut lands on a bar line (at 140 BPM a bar is 1.714 s). Write
`BRIEF.md` beside the reel: the concept in two sentences, a scene table (bars, what sound
enters, what the picture does, the exact copy), the type rules (families, sizes, tracking, at
most one headline and one small caps line per shot, margins) and the motion and score rules
(below). Write every word of copy yourself; scene authors render it verbatim.

Before the scene table, set the art direction: the one idea, how scale changes across the
reel, where light and texture come from, how shots hand over to each other, and what to avoid.
A reference the user names sharpens it; write the result into the brief.

Motion rules that belong in every brief: every move eases; things land on beats via
`k.env(inst)`; a slow camera drift so nothing sits still; no element jumps between consecutive
frames except on a scored hit; fast large motion is slowed or blurred, never left to strobe; a
scene's first frame is already a finished composition. A hit-driven value needs a short attack
(an envelope that jumps to full on the hit moves in one frame), and a landing that starts fast
or overshoots reads as a pop. Sync with meaning: an element moves with the sound it stands for
and the rest holds or drifts; when everything pulses on every subdivision, the frame reads busy.
Hand-overs between shots read smoother as a continuous seam (the next shot starts on the last
frame's geometry) or a wipe behind a moving edge that leaves the frame on the hit (`SEAMS` in
`reel.js`) than as hard cuts; viewers asked for clean transitions still expect the sync.

Score rules that belong in every brief: layers enter as the picture builds. Breaks and risers
come before the peak, with the pulse kept on the break's downbeat so the listener keeps the
one. A looped part's harmony repeats with its loop, coloured later by extensions in the other
voices over its own roots before the bass moves under it, since a slash bass under an open
triad can read off-key. Harmony checked on paper is unheard. A last hit lands on the end card.

Every landing the scene table names cites an event that exists in the score, by instrument and
beat. Before the pieces fan out, have a reader check the brief against the evaluated score: a
direction that promises a landing the score never plays is the costliest rework.

Done when `BRIEF.md` holds the concept, the full scene table with copy, and the type, motion
and score rules.

## 3. Build the engine

The engine needs Node, Playwright (`playwright` or `playwright-core`, or `PW_MODULE`) for
`still.mjs` and `render.mjs`, and `ffmpeg` and `ffprobe` on PATH for the steps below.
Resolve `<skill-root>` from this `SKILL.md`; never assume the session working directory. Copy
the files in `<skill-root>/assets/` into the reel's folder (scratch space, not a project's
source tree) and run the commands below from there. Fill in
`reel.js`: the tokens, `SCENES`, the score (by the brief's score rules) and the signature
component as a helper, so every scene draws the same product. It often fills the frame at the
peak, so give it detail that holds up at that size, not a thin outline. The engine adds grain
and a vignette after the motion blur (`LOOK` in `reel.js`). Point `index.html` at the product's
font files. Serve the folder over HTTP (`python3 -m http.server 8791 --bind 127.0.0.1`).

Write one throwaway scene and look at a still (`index.html?t=<seconds>`, or
`node still.mjs <dir> <seconds…>` over `file://` without the server).

Done when the still shows the signature component in the product's look and the console is
clean.

## 4. Fan out the pieces

When the direction is still open, build the peak first as a proof segment in one or two
directions (`node render.mjs proof.mp4 --from <s> --to <s>`) and let the user choose before the
rest fans out. Tell the user up front that a proof is a segment, not the reel; written on the
reel's own timeline, it goes straight into the final cut.

One author per scene file and per music candidate, in parallel if your harness can dispatch
agents. A scene author needs a browser to render its stills. Give the hero scene (the peak) two
independent takes, and the music two candidates with different flavours, sent to the user
loudness-matched to choose by ear. Each author:

- reads `BRIEF.md`, `reel.js`, `engine.js` and the screenshot, and edits only its own file
  (`scenes/<id>.js` or `music/<x>.js`; an alternative take is `scenes/<id>b.js`, viewed with
  `?<id>=<id>b`);
- for a scene: takes at least five stills across its time range, looks at each and fixes what
  is off before returning;
- for music: schedules every score event at `when + e.b * REEL.BEAT`, pure synthesis, then
  measures `REEL.renderAudio()` until the peak is below 0.95 and the per-bar RMS follows the
  arrangement (quiet open, rising layers, a build at the break, loudest at the peak).

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

This pass is where the finished look comes from: work scene by scene from the judder report
and the stills.

Done when judder reports no unintended runs and a live playback (`index.html`, click) shows no
stutter you can see.

## 7. Render and deliver

`node render.mjs <name>.mp4 --blur 8 --query "music=a"` per music candidate. The script renders
the audio offline, normalizes it to −14 LUFS (so candidates compare on music, not volume) and
encodes H.264 + AAC with `faststart`. A blurred render splits well: parallel `--from`/`--to`
chunks at whole seconds, concatenated as video only, with one chunk's full-length audio muxed
once at −14 LUFS. A change that touches only the audio, and no data a scene reads, is a remux
onto the rendered video, not a new render. Deliver the files with what differs between them and
what nobody has verified (no one has heard the audio until the user plays it).

Grain makes the master large (about 6 MB per second at CRF 18): send a share copy,
`ffmpeg -i <name>.mp4 -c:v libx264 -preset slow -crf 22 -c:a copy -movflags +faststart
<name>-share.mp4`, about a tenth of the size.

Done when each mp4 plays, `ffprobe` shows a video and an audio stream of the reel's length,
and the render printed no page errors.
