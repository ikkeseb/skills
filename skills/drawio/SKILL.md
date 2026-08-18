---
name: drawio
description: Generate a native `.drawio` (mxGraphModel XML) diagram — flowcharts, architectures, ER/sequence/class diagrams, network topologies — that opens directly in app.diagrams.net. For hand-drawn-style `.excalidraw` JSON use the excalidraw skill; for numerical charts use a charting tool.
---

# Draw.io Diagram Creator

Produce a native `.drawio` file (mxGraphModel XML) that opens directly in [app.diagrams.net](https://app.diagrams.net), fully editable. The editable XML is the required deliverable; never replace it with a PNG, SVG, or PDF. A local draw.io Desktop installation may be used for native inspection or an explicitly requested derivative export.

## Steps

1. **Read the bundled XML essentials** in [`references/xml-essentials.md`](references/xml-essentials.md). It is the complete offline contract for ordinary nodes, edges, labels, geometry, and pages. Done when: the chosen document structure and ID scheme are clear.
2. **Generate** uncompressed mxGraphModel XML. Prefer the `mxfile` wrapper for a native named page; raw `mxGraphModel` is valid for a single page. Keep the layout conservative when no visual inspection will be available. Done when: every intended relationship is represented by an edge and the file remains editable XML.
3. **Write** it to `<descriptive-name>.drawio` (lowercase-with-hyphens), in the cwd unless told otherwise. Done when: the file exists at the reported path.
4. **Validate structurally** with `node <skill-root>/scripts/validate-drawio.mjs <file.drawio>`. Resolve `<skill-root>` from this `SKILL.md`; never assume the session working directory or a particular Claude Code/Codex install shape. Fix every error before delivery. If Node is unavailable, perform the checks in the bundled reference manually and report that deterministic validation was unavailable. Done when: the validator passes, or the final report names the degraded manual-only check.
5. **Inspect natively when available.** Prefer a local draw.io/diagrams.net application or another already-available native renderer that does not disclose the artifact externally. For complex or edge-label-heavy diagrams, use the optional visual workflow below if permission and tooling allow it. Done when: the diagram was inspected, or the final report clearly limits assurance to structural validation.
6. **Report** the absolute path, validation performed, visual-inspection status, and how to open it: drag the file onto app.diagrams.net, or **File → Open from → Device** (see "Opening in a browser" below before opening it for the user).

For advanced shapes, swimlanes, layers, edge routing, or theme work, the pinned upstream [`drawio-mcp` XML reference](https://raw.githubusercontent.com/jgraph/drawio-mcp/2e49443f5109590aeebd30bd9ccd2e4c10c9ee44/shared/xml-reference.md) is optional depth. Fetch it only when the task needs those features and network access is already allowed; ordinary generation never depends on it.

## Design quality

A diagram should argue, not just label boxes — strip the text and the structure alone should still carry the concept. Every real relationship gets an edge; position alone doesn't show a connection, so if A depends on B, draw the line. Build hierarchy through size and whitespace — make the important node bigger and give it room — not through decorative color or borders. And if an edge needs tortured routing (hand-placed waypoints, a curve bent around an obstacle) to reach its target, the layout is wrong, not the edge: move the node so the line runs straight.

## Visual verification (optional — catches what XML review can't)

The bundled structural validator is the cheap tier (no browser). Routing and label defects,
though, never show up in the XML — only in the render — and rendering costs a browser
cold-start, so reach for it on complex or edge-label-heavy diagrams, not every file.

Before putting a diagram into app.diagrams.net, its CDN viewer, or any other external web
surface, ask for permission for **that artifact** if it may contain internal, personal, or
otherwise non-public information. Do not treat permission for another diagram as reusable.
Without permission, do not load the XML into the external page: deliver the validated file
and report `structural validation only; external visual inspection not authorized`. A local
native renderer that does not transmit the artifact does not need this consent.

When authorized, render with the bundled headless renderer (official viewer engine — same
as app.diagrams.net, faithful sketch strokes and label placement):

```
node <skill-root>/scripts/render-drawio.mjs <file.drawio> [--pages a,b] [--scale 2.5] [--bg white]
```

Then LOOK at the PNGs. Prerequisites: Node + Playwright (or playwright-core) with Chromium,
and network access to `viewer.diagrams.net` (one JS file). If Playwright is missing, ask
before installing. Offline fallback when draw.io Desktop is installed:
`drawio -x -f png -s 2.5 --page-index <N> -o out.png file.drawio`. If neither path is
available, deliver with structural validation only and say so.

Inspect the full-resolution PNG first — use all the image fidelity your harness gives you.
If the harness truncates or rejects the image, inspect a downscaled copy for the overview
plus full-resolution crops of dense areas where possible, and report that visual review was
resolution-limited. Deliverable exports stay full-resolution regardless. If a read or
screenshot tool returns no visible image, the inspection did not happen — treat it as a
failed check, not a pass.

## Opening in a browser

A `.drawio` file opened directly in a browser shows raw XML — that is not a rendering bug.
What renders it is app.diagrams.net (drag the file in, or **File → Open from → Device**) or
a `https://app.diagrams.net/#R<url-encoded-xml>` URL. Long `#R` URLs exceed the Windows
command-line limit (~8k chars) for non-trivial diagrams; work around it with a tiny local
redirect HTML (`location.replace(longUrl)`) opened via `Start-Process`. Because the
externally hosted diagrams.net code gains access to the diagram content, the consent rule
above applies — ask before opening a non-public diagram this way.
