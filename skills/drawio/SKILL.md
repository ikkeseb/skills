---
name: drawio
disable-model-invocation: true
description: Generate a native `.drawio` (mxGraphModel XML) diagram — flowcharts, architectures, ER/sequence/class diagrams, network topologies — that opens directly in app.diagrams.net. For hand-drawn-style `.excalidraw` JSON use the excalidraw skill; for numerical charts use a charting tool.
---

# Draw.io Diagram Creator

Produce a native `.drawio` file (mxGraphModel XML) that opens directly in [app.diagrams.net](https://app.diagrams.net), fully editable. XML-only by design — no PNG/SVG/PDF export (that needs draw.io Desktop, intentionally unused here; export from the app via **File → Export as**).

> XML reference adapted from [`jgraph/drawio-mcp`](https://github.com/jgraph/drawio-mcp) (Apache-2.0), fetched at runtime — not vendored.

## Steps

1. **Fetch the reference first** (WebFetch) — it carries the reasoning budget, rigid grid, styles, edge routing, swimlanes, layers, and dark mode, so you don't re-derive mechanics from memory (URL pinned to a commit so upstream drift can't silently change the skill): `https://raw.githubusercontent.com/jgraph/drawio-mcp/2e49443f5109590aeebd30bd9ccd2e4c10c9ee44/shared/xml-reference.md`. Done when: the reference content is loaded — if the fetch fails, stop and say so rather than drawing from memory.
2. **Generate** uncompressed mxGraphModel XML (raw XML opens fine — no base64/deflate packing needed).
3. **Write** it to `<descriptive-name>.drawio` (lowercase-with-hyphens), in the cwd unless told otherwise.
4. **Report** the absolute path and how to open it: drag the file onto app.diagrams.net, or **File → Open from → Device**.

## Design quality

A diagram should argue, not just label boxes — strip the text and the structure alone should still carry the concept. Every real relationship gets an edge; position alone doesn't show a connection, so if A depends on B, draw the line. Build hierarchy through size and whitespace — make the important node bigger and give it room — not through decorative color or borders. And if an edge needs tortured routing (hand-placed waypoints, a curve bent around an obstacle) to reach its target, the layout is wrong, not the edge: move the node so the line runs straight.

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

## Label placement on edges (common silent defect)

Two labelled edges leaving the same node (e.g. Yes/No off a decision) default to mid-edge
labels that can stack and collide. Anchor each label along its edge instead: set `x` on the
**edge's own** `mxGeometry` (`relative="1"`), where `x` runs `-1` (at source) → `0` (middle)
→ `1` (at target) — e.g. `<mxGeometry relative="1" x="-0.8" as="geometry"/>` pins the label
near the source node. Add `labelBackgroundColor=#ffffff;` to the edge style so labels stay
legible where they cross lines.

## Visual verification (optional — catches what XML review can't)

The well-formedness checks above are the cheap tier (no browser). Routing and label defects,
though, never show up in the XML — only in the render — and rendering costs a Chromium
cold-start, so reach for it on complex or edge-label-heavy diagrams, not every file. When
Playwright + Chromium are available, render with the official viewer (same engine as
app.diagrams.net):

- Build an HTML page with
  `<div class="mxgraph" data-mxgraph='{"xml":"<escaped-xml>","page":N,"resize":true,"nav":false}'></div>`
  and `<script src="https://viewer.diagrams.net/js/viewer-static.min.js"></script>`. Escape the
  XML for a JSON string inside a single-quoted attribute (double quotes and single quotes especially).
- Load it via Playwright `page.setContent(html, {waitUntil: 'networkidle'})` so the CDN script
  loads, wait for `.mxgraph svg`, screenshot **that svg element**, then LOOK at the PNG.
- Gotchas: don't give the div `display:inline-block` (zero-width container → viewer renders
  nothing); a transparent body + `omitBackground` yields a transparent PNG; `deviceScaleFactor`
  sets the export resolution. The viewer JS loads from the CDN at runtime — pin a version (or
  vendor the file / add Subresource Integrity) if you need reproducibility, offline runs, or
  supply-chain safety.
