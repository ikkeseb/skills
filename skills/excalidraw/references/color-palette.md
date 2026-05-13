# Color Palette & Brand Style

**Single source of truth for all colors.** Edit this file to rebrand — everything else in the skill is universal methodology.

---

## Canvas Background

| Mode   | Background Color |
|--------|-----------------|
| Light  | `#ffffff`        |
| Dark   | `#1e1e2e`        |

Default to light. Use dark when the user requests it or when the diagram is primarily technical/code-heavy.

---

## Shape Colors (Semantic)

Colors encode meaning, not decoration. Each semantic purpose has a fill/stroke pair.

| Semantic Purpose    | Fill        | Stroke      | When to Use                        |
|--------------------|-------------|-------------|-------------------------------------|
| Primary / Neutral   | `#dbeafe`   | `#1e40af`   | Default for most shapes             |
| Secondary           | `#e0e7ff`   | `#3730a3`   | Supporting shapes, secondary paths  |
| Tertiary            | `#f1f5f9`   | `#475569`   | Background grouping, low emphasis   |
| Start / Trigger     | `#fef3c7`   | `#b45309`   | Entry points, initiators            |
| End / Success       | `#d1fae5`   | `#047857`   | Completion, output, result          |
| Warning / Error     | `#fee2e2`   | `#b91c1c`   | Failures, resets, danger states     |
| Decision            | `#fde68a`   | `#92400e`   | Branch points, conditionals         |
| AI / LLM            | `#ede9fe`   | `#6d28d9`   | AI components, model interactions   |
| External / API      | `#e0f2fe`   | `#0369a1`   | Third-party systems, integrations   |
| Data / Storage      | `#f0fdf4`   | `#15803d`   | Databases, files, data stores       |
| User / Human        | `#fce7f3`   | `#be185d`   | User actions, manual steps          |
| Inactive / Disabled | `#f1f5f9`   | `#94a3b8`   | Use dashed stroke                   |

**Rule**: Always pair a darker stroke with a lighter fill for contrast.

---

## Text Colors (Hierarchy)

Free-floating text uses color to create visual hierarchy without containers.

| Level         | Light Canvas | Dark Canvas  | Use For                             |
|---------------|-------------|-------------|--------------------------------------|
| Title          | `#0f172a`   | `#f1f5f9`   | Section headings, major labels       |
| Subtitle       | `#1e40af`   | `#93c5fd`   | Subheadings, secondary labels        |
| Body / Detail  | `#64748b`   | `#94a3b8`   | Descriptions, annotations, metadata  |
| On light fills | `#1e293b`   | —           | Text inside light-colored shapes     |
| On dark fills  | `#f8fafc`   | —           | Text inside dark-colored shapes      |

---

## Evidence Artifact Colors

For code snippets, data examples, and concrete evidence inside technical diagrams.

| Artifact Type    | Background  | Text Color                         |
|-----------------|-------------|-------------------------------------|
| Code snippet     | `#1e293b`   | `#e2e8f0` (base), syntax-colored   |
| JSON / data      | `#1e293b`   | `#4ade80` (green)                   |
| Command / CLI    | `#0f172a`   | `#38bdf8` (sky blue)               |

### Syntax Colors (for code snippets)

| Token Type  | Color      |
|------------|------------|
| Keyword     | `#c084fc`  |
| String      | `#4ade80`  |
| Number      | `#fb923c`  |
| Comment     | `#64748b`  |
| Function    | `#38bdf8`  |
| Type        | `#fbbf24`  |

---

## Stroke & Line Colors

| Element                                   | Color                                          |
|------------------------------------------|------------------------------------------------|
| Arrows                                    | Source element's stroke color                   |
| Structural lines (dividers, trees, timelines) | `#475569` (slate)                            |
| Marker dots (fill + stroke)               | `#3b82f6` (blue)                               |
| Dashed dividers                           | `#cbd5e1` (light slate)                        |

---

## Dark Canvas Adjustments

When using `viewBackgroundColor: "#1e1e2e"`:

- Shape fills become slightly more saturated and darker (reduce lightness ~15%)
- Shape strokes become lighter for contrast
- Use dark-canvas text colors from the hierarchy table above
- Evidence artifacts keep the same dark backgrounds (they already contrast well)
- Structural lines use `#64748b` instead of `#475569`
