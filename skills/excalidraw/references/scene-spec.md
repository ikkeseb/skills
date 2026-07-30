# Scene specification

Use the scene specification for new diagrams. It is a compact, inspectable
layout contract; `scripts/excalidraw.mjs build` expands it into native
Excalidraw elements with reciprocal bindings.

## Minimal example

```json
{
  "title": "Review loop",
  "subtitle": "Validity is necessary; inspected pixels are the release gate.",
  "roughness": 1,
  "nodes": [
    {
      "id": "draft",
      "text": "Draft scene",
      "shape": "rectangle",
      "x": 80,
      "y": 180,
      "width": 200,
      "height": 100,
      "tone": "primary"
    },
    {
      "id": "inspect",
      "text": "Inspect pixels",
      "shape": "diamond",
      "x": 420,
      "y": 165,
      "width": 220,
      "height": 130,
      "tone": "decision"
    }
  ],
  "edges": [
    {
      "id": "draft-to-inspect",
      "from": "draft",
      "to": "inspect",
      "label": "render"
    }
  ]
}
```

Build it:

```bash
node <skill-root>/scripts/excalidraw.mjs build review-loop.scene.json review-loop.excalidraw
```

## Root fields

| Field | Meaning |
|---|---|
| `title`, `subtitle` | Optional free-floating heading and explanatory line. |
| `titleX`, `titleY` | Heading origin; defaults to `60`, `40`. |
| `theme` | `dark` (default) or `light`. |
| `canvasBackground` | Optional exact canvas color; defaults to `#000000`. |
| `roughness` | `0` clean or `1` hand-drawn; defaults to `1`. |
| `sections` | Optional visual regions behind nodes. |
| `nodes` | Meaning-bearing shapes with optional bound labels. |
| `edges` | Bound arrows between nodes. |
| `lines` | Unbound structural lines or arrows. |
| `texts` | Free-floating labels, notes, and evidence. |

Every element needs a stable, descriptive `id`. Coordinates are absolute
canvas pixels. The specification is intentionally layout-only: it does not
guess placement or hide routing decisions.

## Sections

```json
{
  "id": "validation-zone",
  "title": "Mechanical checks",
  "x": 40,
  "y": 130,
  "width": 700,
  "height": 360,
  "tone": "tertiary"
}
```

Sections are light background rectangles, not semantic containers. Keep them
few and large. They do not automatically move or bind their contents.

## Nodes

```json
{
  "id": "artifact",
  "text": "Native .excalidraw",
  "shape": "rectangle",
  "x": 80,
  "y": 180,
  "width": 220,
  "height": 96,
  "tone": "success",
  "fontSize": 20
}
```

`shape` accepts `rectangle`, `ellipse`, or `diamond`. Labels wrap to the node
width and are bound reciprocally. Set `code: true` for monospace evidence.

## Edges

```json
{
  "id": "artifact-to-check",
  "from": "artifact",
  "to": "check",
  "label": "validate",
  "strokeStyle": "solid",
  "route": [
    { "x": 350, "y": 228 },
    { "x": 350, "y": 420 }
  ]
}
```

Without `route`, the builder connects the nearest dominant sides with one
straight segment. Route points are absolute coordinates between the generated
start and end anchors. Set `curved: true` to smooth a multi-point route into a
native Excalidraw curve. Prefer moving nodes over adding route points.

Optional arrow fields: `strokeColor`, `strokeWidth`, `strokeStyle`,
`roughness`, `curved`, `startArrowhead`, `endArrowhead`, `labelDx`, and
`labelDy`.

## Lines

```json
{
  "id": "feedback",
  "arrow": true,
  "curved": true,
  "points": [[800, 420], [800, 560], [220, 560], [220, 300]],
  "strokeStyle": "dashed"
}
```

Lines are deliberately unbound. Use them for dividers, timelines, arcs, and
feedback paths where a bound edge would be misleading. `curved: true` smooths
routes with three or more points.

## Free text

```json
{
  "id": "evidence",
  "text": "node scripts/excalidraw.mjs check diagram.excalidraw",
  "x": 80,
  "y": 340,
  "width": 520,
  "fontSize": 16,
  "code": true
}
```

Free text wraps by default. Set `wrap: false` only when the available width is
known. Use `color`, `textAlign`, and `verticalAlign` sparingly.

## Semantic tones

`primary`, `secondary`, `tertiary`, `start`, `success`, `warning`,
`decision`, `ai`, `external`, `data`, `human`, and `inactive`.

The semantic dark palette is the default. Read `color-palette.md` when custom
colors or light mode are needed.

## Escape hatch

The scene specification covers the common diagram vocabulary. For a shape it
cannot express, build the nearest scene, then edit the native `.excalidraw`
JSON. Run `validate` and `check` again after every manual edit.
