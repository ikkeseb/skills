---
name: excalidraw
description: Generate `.excalidraw` JSON diagrams for relationships, flows, architectures, or system structure. Invoke ONLY when the user explicitly asks for a diagram or types `/excalidraw` — do NOT auto-invoke from soft cues like "show me" or "walk me through". Do NOT use for numerical charts (use a charting tool), UI mockups (use frontend-design), or text documentation.
---

# Excalidraw Diagram Creator

Generate `.excalidraw` JSON files that **argue visually**, not just display information.

## Environment Detection

This skill works in both Claude Code and Claude Chat.

**Claude Code** (`~/.claude/skills/excalidraw/` or `<project>/.claude/skills/excalidraw/`): Generate the `.excalidraw` JSON and deliver it. Don't auto-render — get the diagram right by following the methodology. After delivery, offer two opt-in follow-ups: render to PNG (`references/render_excalidraw.py`) and open in Excalidraw via clipboard (`references/open_in_excalidraw.py`).

**Claude Chat** (`/mnt/skills/user/excalidraw/`): Create the `.excalidraw` JSON file and save to `/mnt/user-data/outputs/`. The user opens it in [excalidraw.com](https://excalidraw.com) or the Excalidraw desktop app. No render loop — get it right by following the methodology carefully.

## Customization

All colors live in `references/color-palette.md`. Edit that file to rebrand — everything else is universal methodology.

---

## Core Philosophy

**Diagrams should ARGUE, not DISPLAY.**

A diagram is a visual argument showing relationships, causality, and flow that words alone can't express. The shape should BE the meaning.

**The Isomorphism Test**: Remove all text. Does the structure alone communicate the concept? If not, redesign.

**The Education Test**: Could someone learn something concrete, or does it just label boxes? Good diagrams teach.

---

## Depth Assessment (Do This First)

### Simple / Conceptual
Use abstract shapes when explaining mental models, the audience doesn't need technical specifics, or the concept IS the abstraction.

### Comprehensive / Technical
Use concrete examples when diagramming a real system, the diagram will teach or explain, the audience needs to understand what things actually look like, or you're showing how technologies integrate.

**For technical diagrams, include evidence artifacts** — real code snippets, actual JSON payloads, real event/method names from specs. See the Evidence Artifacts section.

---

## Design Process

### Step 0: Assess Depth
Simple/conceptual or comprehensive/technical? If comprehensive — research actual specs, formats, and terminology first.

### Step 1: Understand Deeply
For each concept, ask: What does it DO? What relationships exist? What's the core transformation? What would someone need to SEE?

### Step 2: Map Concepts to Patterns

| If the concept...              | Use this pattern                                    |
|-------------------------------|-----------------------------------------------------|
| Spawns multiple outputs        | **Fan-out** — radial arrows from center              |
| Combines inputs into one       | **Convergence** — funnel, arrows merging             |
| Has hierarchy/nesting          | **Tree** — lines + free-floating text                |
| Is a sequence of steps         | **Timeline** — line + dots + labels                  |
| Loops or improves continuously | **Spiral/Cycle** — arrow returning to start          |
| Is an abstract state/context   | **Cloud** — overlapping ellipses                     |
| Transforms input to output     | **Assembly line** — before → process → after         |
| Compares two things            | **Side-by-side** — parallel with contrast            |
| Separates into phases          | **Gap/Break** — visual separation between sections   |

### Step 3: Ensure Variety
Each major concept uses a different visual pattern. No uniform cards or grids.

### Step 4: Sketch the Flow
Mentally trace how the eye moves. There should be a clear visual story.

### Step 5: Generate JSON
Only now create the Excalidraw elements. For large diagrams, build section-by-section (see below).

### Step 6: Deliver
Save the `.excalidraw` file and tell the user where it lives. The methodology is the verification — do **not** auto-render. Rendering is an opt-in follow-up the user requests.

### Step 7: Offer Follow-Ups (Claude Code only)
After delivery, offer two opt-in actions in a single short prompt:
- **Render to PNG** — useful for docs, sharing, or visual sanity-check on complex diagrams
- **Open in Excalidraw** — copy JSON to clipboard, open excalidraw.com for editing

See "After Delivery" below for the exact wording and commands.

---

## Evidence Artifacts

Concrete examples that prove accuracy and help viewers learn. Include in technical diagrams.

| Artifact Type        | When to Use                       | How to Render                                       |
|---------------------|-----------------------------------|-----------------------------------------------------|
| Code snippets        | APIs, integrations, implementation | Dark rect + syntax-colored text                     |
| Data/JSON examples   | Schemas, payloads, formats         | Dark rect + green text                              |
| Event sequences      | Protocols, workflows, lifecycles   | Timeline (line + dots + labels)                     |
| UI mockups           | Showing actual output              | Nested rectangles mimicking real UI                 |
| API/method names     | Real function calls, endpoints     | Use actual names from docs, not placeholders         |

**Key principle**: Show what things actually look like, not just what they're called.

---

## Multi-Zoom Architecture

Comprehensive diagrams operate at multiple zoom levels:

**Level 1 — Summary Flow**: Simplified overview of the full pipeline. Often at top or bottom.

**Level 2 — Section Boundaries**: Labeled regions grouping related components. Visual "rooms".

**Level 3 — Detail Inside Sections**: Evidence artifacts, code snippets, concrete examples. Where educational value lives.

For comprehensive diagrams, include all three levels.

---

## Container vs. Free-Floating Text

Default to free-floating text. Add containers only when they serve a purpose.

| Use a Container When...                    | Use Free-Floating Text When...            |
|-------------------------------------------|-------------------------------------------|
| It's the focal point of a section          | It's a label or description               |
| It needs visual grouping with other elements | It's supporting detail or metadata        |
| Arrows need to connect to it               | It describes something nearby             |
| The shape itself carries meaning            | Typography alone creates sufficient hierarchy |
| It represents a distinct "thing"            | It's a section title or annotation        |

**The container test**: For each boxed element, ask "Would this work as free-floating text?" If yes, remove the container. Aim for <30% of text elements inside containers.

---

## Large Diagram Strategy

For diagrams with ~50+ elements, build section-by-section to stay under output limits and
preserve layout quality. See `references/large-diagrams.md` for the phased workflow and ID
namespacing convention.

---

## Shape Meaning

| Concept Type                  | Shape                          | Why                        |
|------------------------------|--------------------------------|----------------------------|
| Labels, descriptions, details | **none** (free-floating text)  | Typography creates hierarchy|
| Section titles, annotations   | **none** (free-floating text)  | Font size/weight is enough  |
| Markers on a timeline          | small `ellipse` (10-20px)      | Visual anchor, not container|
| Start, trigger, input          | `ellipse`                      | Soft, origin-like           |
| End, output, result            | `ellipse`                      | Completion, destination     |
| Decision, condition            | `diamond`                      | Classic decision symbol     |
| Process, action, step          | `rectangle`                    | Contained action            |
| Abstract state, context        | overlapping `ellipse`          | Fuzzy, cloud-like           |
| Hierarchy node                 | lines + text (no boxes)        | Structure through lines     |

---

## Layer Order (Z-Index)

In Excalidraw, **array position is z-index**. Earlier elements render behind, later elements render on top. There's no separate `zIndex` field — order in the `elements` array IS the layering.

Build elements in this order so layering stays correct without post-hoc reshuffling:

1. **Background structure** — section dividers, region rectangles, large grouping shapes
2. **Primary shapes** — rectangles, ellipses, diamonds for main concepts
3. **Arrows and lines** — connections between shapes
4. **Free-floating text** — labels, annotations, captions on top

When labels look clipped by arrows, or arrows pass behind shapes that should sit in front, the fix is array reordering — not coordinates.

---

## Color, Aesthetics & Layout

**Colors**: Read `references/color-palette.md` before generating any diagram. Every color choice comes from there.

**Roughness**: `0` for clean/modern (default), `1` for hand-drawn/informal.

**Stroke width**: `1` thin/elegant, `2` standard (default), `3` bold emphasis (sparingly).

**Opacity**: Always `100`. Use color, size, and stroke width for hierarchy instead.

**Hierarchy through scale**: Hero 300×150, Primary 180×90, Secondary 120×60, Small 60×40.

**Whitespace = importance**: Most important element gets 200px+ of empty space around it.

**Flow direction**: Left→right or top→bottom for sequences, radial for hub-and-spoke.

**Connections**: Position alone doesn't show relationships. If A relates to B, there must be an arrow.

**Layout fixes beat arrow gymnastics**: If an arrow needs a tortured curve or hand-placed waypoints to clear an obstacle, the layout is wrong, not the arrow. Move the box. Straight or gently curved arrows mean the spatial story is clear; bezier acrobatics mean it isn't.

---

## Text Rules

The JSON `text` property contains ONLY readable words. No formatting codes.

```json
{ "id": "myElement1", "text": "Start", "originalText": "Start" }
```

Settings: `fontSize: 16`, `fontFamily: 3`, `textAlign: "center"`, `verticalAlign: "middle"`

---

## JSON Structure

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [...],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": 20 },
  "files": {}
}
```

See `references/element-templates.md` for copy-paste JSON templates per element type.
See `references/json-schema.md` for the full schema reference.

---

## After Delivery: Opt-In Follow-Ups (Claude Code only)

After saving the `.excalidraw` file in Claude Code, offer two opt-in actions in one short
prompt: render to PNG, or open in Excalidraw via clipboard. Do **not** auto-render — get
the diagram right by following the methodology; rendering is opt-in verification, and
Chromium cold-start (~6–10s) is rude to spend without permission. **Skip in Claude Chat** —
the user already has the file via the chat UI.

For the exact wording, commands, flags, and first-time setup, see
`references/follow-ups.md`.

---

## Quality Checklist

### Depth & Evidence (Technical Diagrams)
- [ ] Research done — actual specs, formats, event names
- [ ] Evidence artifacts — code snippets, JSON examples, real data
- [ ] Multi-zoom — summary + sections + detail
- [ ] Concrete over abstract — real content, not labeled boxes

### Conceptual
- [ ] Isomorphism — visual structure mirrors concept behavior
- [ ] Argument — shows something text alone couldn't
- [ ] Variety — each concept uses a different visual pattern
- [ ] No uniform containers — no card grids or equal boxes

### Container Discipline
- [ ] Minimal containers — <30% of text in boxes
- [ ] Lines as structure — timelines/trees use lines + text, not boxes
- [ ] Typography hierarchy — font size and color create hierarchy

### Structural
- [ ] Connections — every relationship has an arrow/line
- [ ] Flow — clear visual path for the eye
- [ ] Hierarchy — important elements larger/more isolated

### Technical
- [ ] `fontFamily: 3`, `roughness: 0`, `opacity: 100`
- [ ] `text` contains only readable words
- [ ] All `containerId`, `boundElements`, and arrow `startBinding`/`endBinding` references point at existing element IDs
- [ ] Layer order in the array goes background → primary shapes → arrows → free-floating text
