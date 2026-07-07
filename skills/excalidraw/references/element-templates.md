# Element Templates

Copy-paste JSON templates for each Excalidraw element type. Replace color placeholders with actual values from `color-palette.md` based on the element's semantic purpose.

## Common Defaults

Every template implicitly includes these fields. **Always include them in the output JSON**, even though they're omitted from the per-shape blocks below:

```json
{
  "fillStyle": "solid",
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "angle": 0,
  "version": 1,
  "isDeleted": false,
  "groupIds": [],
  "link": null,
  "locked": false
}
```

For each new element, also generate:
- `id`: descriptive string (e.g., `"rect_trigger"`, `"arrow_fan_left"`)
- `seed`: any integer; Excalidraw reassigns on load. Namespace by section (see SKILL.md → Large Diagram Strategy)
- `versionNonce`: any integer; Excalidraw reassigns on load

`strokeWidth` is `1` (thin), `2` (bold/standard), or `4` (extra bold) — Excalidraw's UI presets.

---

## Free-Floating Text (no container)
```json
{
  "type": "text",
  "id": "label_descriptive_name",
  "x": 100, "y": 100,
  "width": 200, "height": 25,
  "text": "Section Title",
  "originalText": "Section Title",
  "fontSize": 20,
  "fontFamily": 3,
  "textAlign": "left",
  "verticalAlign": "top",
  "strokeColor": "<title color from palette>",
  "backgroundColor": "transparent",
  "strokeWidth": 1,
  "boundElements": null,
  "containerId": null,
  "lineHeight": 1.25
}
```

## Line (structural, not arrow)
```json
{
  "type": "line",
  "id": "line_descriptive_name",
  "x": 100, "y": 100,
  "width": 0, "height": 200,
  "strokeColor": "<structural line color from palette>",
  "backgroundColor": "transparent",
  "strokeWidth": 2,
  "boundElements": null,
  "points": [[0, 0], [0, 200]]
}
```

## Small Marker Dot
```json
{
  "type": "ellipse",
  "id": "dot_descriptive_name",
  "x": 94, "y": 94,
  "width": 12, "height": 12,
  "strokeColor": "<marker dot color from palette>",
  "backgroundColor": "<marker dot color from palette>",
  "strokeWidth": 1,
  "boundElements": null
}
```

## Rectangle
```json
{
  "type": "rectangle",
  "id": "rect_descriptive_name",
  "x": 100, "y": 100, "width": 180, "height": 90,
  "strokeColor": "<stroke from palette>",
  "backgroundColor": "<fill from palette>",
  "strokeWidth": 2,
  "boundElements": [{"id": "text_descriptive_name", "type": "text"}],
  "roundness": {"type": 3}
}
```

## Text (centered in shape)
```json
{
  "type": "text",
  "id": "text_descriptive_name",
  "x": 130, "y": 132,
  "width": 120, "height": 25,
  "text": "Process",
  "originalText": "Process",
  "fontSize": 16,
  "fontFamily": 3,
  "textAlign": "center",
  "verticalAlign": "middle",
  "strokeColor": "<text color from palette>",
  "backgroundColor": "transparent",
  "strokeWidth": 1,
  "boundElements": null,
  "containerId": "rect_descriptive_name",
  "lineHeight": 1.25
}
```

## Arrow
```json
{
  "type": "arrow",
  "id": "arrow_descriptive_name",
  "x": 282, "y": 145, "width": 118, "height": 0,
  "strokeColor": "<arrow color — source element's stroke>",
  "backgroundColor": "transparent",
  "strokeWidth": 2,
  "boundElements": null,
  "points": [[0, 0], [118, 0]],
  "startBinding": {"elementId": "rect_source", "focus": 0, "gap": 2},
  "endBinding": {"elementId": "rect_target", "focus": 0, "gap": 2},
  "startArrowhead": null,
  "endArrowhead": "arrow"
}
```

For curved arrows: use 3+ points in the `points` array. Arrowhead values (both `startArrowhead` and `endArrowhead`): `null`, `"arrow"`, `"bar"`, `"dot"`, `"triangle"`.

## Diamond (Decision)
```json
{
  "type": "diamond",
  "id": "decision_descriptive_name",
  "x": 100, "y": 100, "width": 120, "height": 90,
  "strokeColor": "<Decision stroke from palette>",
  "backgroundColor": "<Decision fill from palette>",
  "strokeWidth": 2,
  "boundElements": [{"id": "text_decision", "type": "text"}]
}
```

## Ellipse (Start/End)
```json
{
  "type": "ellipse",
  "id": "ellipse_descriptive_name",
  "x": 100, "y": 100, "width": 140, "height": 70,
  "strokeColor": "<stroke from palette>",
  "backgroundColor": "<fill from palette>",
  "strokeWidth": 2,
  "boundElements": [{"id": "text_ellipse", "type": "text"}]
}
```

## Frame (Grouping Container)
```json
{
  "type": "frame",
  "id": "frame_descriptive_name",
  "x": 50, "y": 50, "width": 400, "height": 300,
  "name": "Section Name",
  "strokeColor": "<structural line color from palette>",
  "backgroundColor": "transparent",
  "strokeWidth": 1,
  "boundElements": null
}
```

---

## Binding Rules

When a text element is inside a shape:
- The shape's `boundElements` array must include `{"id": "<text-id>", "type": "text"}`
- The text's `containerId` must reference the shape's ID

When an arrow connects two shapes:
- The arrow's `startBinding.elementId` = source shape ID
- The arrow's `endBinding.elementId` = target shape ID
- Both shapes' `boundElements` arrays must include `{"id": "<arrow-id>", "type": "arrow"}`
