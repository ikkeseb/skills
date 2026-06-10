---
name: drawio
description: Generate a native `.drawio` (mxGraphModel XML) diagram — flowcharts, architectures, ER/sequence/class diagrams, network topologies, process flows — that opens directly in app.diagrams.net. Invoke ONLY when the user explicitly asks for a draw.io / drawio / `.drawio` diagram or types `/drawio`; do NOT auto-invoke from soft cues like "show me" or "walk me through". For `.excalidraw` use the excalidraw skill; for numerical charts use a charting tool; for UI mockups use frontend-design.
---

# Draw.io Diagram Creator

Produce a native `.drawio` file (mxGraphModel XML) that opens directly in [app.diagrams.net](https://app.diagrams.net), fully editable. XML-only by design — no PNG/SVG/PDF export (that needs draw.io Desktop, intentionally unused here; export from the app via **File → Export as**).

> XML reference adapted from [`jgraph/drawio-mcp`](https://github.com/jgraph/drawio-mcp) (Apache-2.0), fetched at runtime — not vendored.

## Steps

1. **Fetch the reference first** (WebFetch) — it carries the reasoning budget, rigid grid, styles, edge routing, swimlanes, layers, and dark mode, so you don't re-derive mechanics from memory (URL pinned to a commit so upstream drift can't silently change the skill): `https://raw.githubusercontent.com/jgraph/drawio-mcp/2e49443f5109590aeebd30bd9ccd2e4c10c9ee44/shared/xml-reference.md`
2. **Generate** uncompressed mxGraphModel XML (raw XML opens fine — no base64/deflate packing needed).
3. **Write** it to `<descriptive-name>.drawio` (lowercase-with-hyphens), in the cwd unless told otherwise.
4. **Report** the absolute path and how to open it: drag the file onto app.diagrams.net, or **File → Open from → Device**.

## Required skeleton

```xml
<mxGraphModel adaptiveColors="auto">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
  </root>
</mxGraphModel>
```

Both `id="0"` and `id="1"` are mandatory — a missing layer renders blank. Diagram cells use `parent="1"`.

## Well-formedness (any of these → blank or corrupt diagram)

- No XML comments (`<!-- -->`) anywhere in the file.
- Escape `&amp;` `&lt;` `&gt;` `&quot;` in attribute values.
- Unique `id` on every `mxCell`.
- Every edge cell needs a child `<mxGeometry relative="1" as="geometry"/>` — a self-closing edge renders nothing.
