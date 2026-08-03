# Draw.io XML essentials

Use this reference for ordinary offline generation. It is intentionally small: prefer simple,
editable mxGraphModel XML over compressed payloads or clever styling.

## Document and page structure

Use an uncompressed `mxfile` wrapper for a named page:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" compressed="false">
  <diagram id="page-1" name="Page-1">
    <mxGraphModel adaptiveColors="auto" grid="1" gridSize="10" page="1" pageWidth="1169" pageHeight="827">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

A raw `mxGraphModel` is also valid for one unnamed page. Every model needs the root cell
`id="0"` and default layer `id="1" parent="0"`; ordinary diagram cells use `parent="1"`.
For multiple pages, add sibling `diagram` elements with unique page IDs and one complete
`mxGraphModel` each. Keep `compressed="false"` so the result stays readable and patchable.

## Nodes

A node is an `mxCell` with `vertex="1"` and one geometry child. Use stable descriptive IDs:

```xml
<mxCell id="api" value="API" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
  <mxGeometry x="320" y="120" width="140" height="60" as="geometry"/>
</mxCell>
```

- Put visible text in `value`; escape XML-sensitive characters.
- Use integer coordinates on a 10 px grid unless the task needs finer placement.
- Give ordinary nodes finite `x`, `y`, `width`, and `height`; width and height must be positive.
- Keep the style as semicolon-separated `key=value` pairs. Use color to clarify groups or
  state, not as the only carrier of meaning.

## Edges and labels

An edge references existing source and target node IDs and has relative geometry:

```xml
<mxCell id="edge-api-db" value="reads" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;endArrow=block;labelBackgroundColor=#ffffff;" edge="1" parent="1" source="api" target="database">
  <mxGeometry relative="1" x="-0.25" as="geometry"/>
</mxCell>
```

- Draw an edge for every real relationship; proximity is not a relationship.
- Keep source and target nodes positioned so orthogonal routing remains simple.
- On the edge geometry, `x` places the label along the route: `-1` near the source, `0` in
  the middle, and `1` near the target. Offset sibling labels so they do not stack.
- Add waypoints only when moving nodes cannot produce a clear route:

```xml
<mxGeometry relative="1" as="geometry">
  <Array as="points">
    <mxPoint x="520" y="150"/>
  </Array>
</mxGeometry>
```

## Escaping and integrity

- Do not emit XML comments, CDATA, doctypes, or compressed/base64 diagram payloads.
- Escape attribute data as `&amp;`, `&lt;`, `&gt;`, `&quot;`, and `&apos;` as applicable.
- Give every `mxCell` a unique ID within its page.
- Ensure every `parent`, `source`, and `target` reference resolves within the same page.
- Do not self-close a vertex or edge cell: its `mxGeometry` child is required.

Run the bundled validator after writing:

```text
node <skill-root>/scripts/validate-drawio.mjs <diagram.drawio>
```

It accepts an uncompressed `mxfile` or raw `mxGraphModel` and checks XML nesting, entities,
page/model structure, cell IDs and references, node geometry, and edge geometry. Passing it
proves structural integrity, not visual quality or application compatibility beyond this
documented subset.
