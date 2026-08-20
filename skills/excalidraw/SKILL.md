---
name: excalidraw
description: "Create an editable .excalidraw diagram for flows, relationships, and system structure, with structural validation and visual review. Not for draw.io files (drawio) or numerical charts."
disable-model-invocation: true
---

# Excalidraw diagram creator

Produce a native `.excalidraw` file that explains a relationship, plus an
inspection of the native canvas. The workflow is the same in Claude Code and
Codex.

## Quality contract

A diagram moves through four distinct states:

1. **Structurally valid.** JSON, numbers, IDs, files, and reciprocal bindings
   pass the validator.
2. **Layout previewed.** The lightweight renderer exposes obvious geometry
   defects but does not prove native rendering.
3. **Visually approved.** Inspect pixels from an official Excalidraw surface
   and correct clipping, overlap, weak hierarchy, ambiguous flow, and edge
   crowding.
4. **Handed off.** The editable artifact and its verification state are clear
   to the user.

Never collapse these states into "done." Native inspection is required before
normal delivery. If the environment cannot render the official canvas,
deliver only when useful and say `structurally valid, native visually
unverified`.

## Tooling

The dependency-free Node CLI lives at `scripts/excalidraw.mjs`. Resolve
`<skill-root>` from this `SKILL.md`; never assume the session working
directory or a particular install shape.

```bash
node <skill-root>/scripts/excalidraw.mjs build diagram.scene.json diagram.excalidraw
node <skill-root>/scripts/excalidraw.mjs validate diagram.excalidraw
node <skill-root>/scripts/excalidraw.mjs check diagram.excalidraw diagram.layout.png
```

`check` writes lightweight SVG and PNG layout diagnostics without network or
third-party packages. It deliberately exits `2`: these pixels are not native.
Set `EXCALIDRAW_BROWSER_PATH` only when the local browser is outside standard
install locations and `PATH`. Step 5 covers how to reach an official surface
from there.

For a new diagram, read `references/scene-spec.md` before writing the compact
scene JSON. Read `references/color-palette.md` for custom colors or rebranding,
then inspect its single source `references/palette.json` for exact tokens.

## Workflow

### 1. Write the visual brief

State, in two or three lines:

- the claim the diagram should make;
- the intended reading order;
- the evidence or detail that makes the claim credible.

Choose one dominant flow: left-to-right, top-to-bottom, radial, or cyclic.
Done when the intended eye path can be described without naming coordinates.

### 2. Choose the depth

Use the simple path when the diagram has roughly 12 or fewer nodes, one flow
direction, and few cross-region edges. Use the complex path for dense text,
multiple regions, cross-region relationships, or more than roughly 12 nodes.

- **Simple:** one scene specification, one build, one native overview.
- **Complex:** sketch regions first, add one region at a time, validate after
  each addition, then inspect both the overview and local crops near 100%.
  Prefer an overview plus focused companion diagrams over a canvas wider than
  3600px or taller than 2600px.

Done when every planned region and cross-region edge has a reason to exist.

### 3. Lay out the scene specification

Write explicit coordinates in a `.scene.json` file. This file is the
inspectable layout contract: keep IDs semantic, whitespace visible, and routes
intentional. Do not jump straight to verbose native elements.

Use:

- position and scale for hierarchy;
- free text for titles, annotations, and supporting detail;
- containers only for real entities, decisions, or grouping;
- evidence artifacts such as actual commands, payloads, method names, or
  miniature UI where technical specificity teaches something.

If most text is boxed or most nodes look like uniform cards, the diagram is
probably displaying an inventory rather than making an argument. Different
shapes must encode different meanings, not decorative variety.

Done when the specification itself makes overlap, crowded margins, and
tortured routes easy to spot.

### 4. Build and validate

Run `build`, then `validate`. Treat validator errors as blockers. Treat
geometry warnings as review prompts: fix real overlap or crossings, but do not
distort a clear layout merely to silence a false positive.

The builder creates native Excalidraw JSON with:

- a black canvas and Excalifont by default (`"font": "sans"` in the scene spec
  switches all non-code text to a normal sans face; hand-drawn stays the
  default, switch only when the audience or deliverable clearly calls for it);
- Cascadia only when a text item is explicitly code;
- wrapped, reciprocally bound node labels;
- reciprocally bound arrows;
- straight or curved routed arrows and structural lines;
- deterministic IDs, seeds, and element order;
- semantic palette defaults.

If the scene specification cannot express one necessary element, edit the
native JSON after building. This escape hatch preserves the full Excalidraw
vocabulary: frames, freedraw, images, unusual boxes, and advanced line
geometry. Validate again. Done when validation reports `STRUCTURALLY VALID`
and every warning is either fixed or visibly harmless.

### 5. Render and inspect

Run `check` for early geometry feedback, then import the native file into an
official Excalidraw surface, in this order:

1. any Playwright-based browser automation available in the session, driving
   `excalidraw.com` (headed when the user is present, headless when not);
2. manual import by the user in an ordinary browser;
3. neither available: stop at the degraded status, which is an honest end
   state rather than a failure.

Read `references/native-inspection.md` for the import recipe, the confirmation
step that separates a rendered canvas from an imported scene, and what to ask
before sending a diagram to excalidraw.com.

Inspect that canvas at full size. For complex diagrams also inspect crops
containing dense text, edge junctions, curved segments, and canvas boundaries.

Inspection means pixels actually reached you. If a read or screenshot tool
returns no visible image, the inspection did not happen: treat it as a failed
check and report the honest degraded status, never a pass.

Ask these adversarial questions:

- Is any text clipped, stacked, too small, or visually detached from its
  subject?
- Do labels collide with arrows or shapes?
- Does any arrow cross an unrelated node, point ambiguously, or exit the
  canvas?
- Is the reading order obvious within three seconds?
- Is the most important relationship visually dominant?
- Are margins balanced, including the right and bottom edges?
- Does the diagram still communicate when skimmed without reading every word?

Correct the scene specification, rebuild, and re-import until the answers hold.
For high-impact diagrams or a repeat failure, ask an independent reviewer to
critique the native pixels, not the source JSON. Done only after inspecting
the final native canvas.

### 6. Deliver safely

Deliver the `.excalidraw` file and the approved native screenshot or export.
Name the exact status: `structurally valid and natively visually approved`, or
the truthful degraded status.

To continue editing, use Excalidraw's **File → Open** or drag the file onto a
fresh canvas. Never put a full scene on the clipboard for paste into an
existing canvas: Excalidraw merges pasted elements with cached content, so the
result is not deterministic.

Done when the user has a native editable artifact, a preview, and an honest
verification statement.

## Visual grammar

| Meaning | Default representation |
|---|---|
| Start, trigger, actor | Ellipse |
| Process, system, concrete thing | Rectangle |
| Decision or condition | Diamond |
| End, result, output | Ellipse |
| Region or phase | One light background section |
| Relationship or sequence | Bound arrow |
| Detail, annotation, section title | Free text |
| Code, command, payload | Monospace free text or one dark evidence block |

Prefer moving nodes over adding route points. Straight or gently routed edges
show that the spatial story works; arrow gymnastics usually expose a layout
problem.
