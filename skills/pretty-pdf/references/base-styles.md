# Base Styles Reference

Complete CSS system for pretty-pdf. Copy the entire `<style>` block below as the starting point
for every PDF, then override CSS custom properties to change palette and feel.

## Font Loading

The default stylesheet imports Source Serif 4, Source Sans 3, and Source Code Pro from Google Fonts.
These are the FALLBACK — not the target. For each new document, actively choose fonts that fit
the specific content. Don't default to Source Sans/Serif unless it genuinely suits the document.

**How to swap fonts:** Replace the `@import` URL in the `<style>` block and update the
`--font-serif`, `--font-sans`, and `--font-mono` CSS variables.

### Proven font pairings

Pick one. Don't always reach for the same row.

| Feel | Headings | Body | `@import` (append to `fonts.googleapis.com/css2?family=`) |
|------|----------|------|--------|
| Editorial (default) | Source Sans 3 | Source Serif 4 | *(included in base stylesheet)* |
| Warm humanist | Libre Franklin | Libre Baskerville | `Libre+Franklin:wght@400;600;700&family=Libre+Baskerville:ital,wght@0,400;0,700;1,400` |
| Clinical/medical | DM Sans | DM Sans | `DM+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400` |
| Literary/traditional | Playfair Display | EB Garamond | `Playfair+Display:wght@400;600;700&family=EB+Garamond:ital,wght@0,400;0,500;0,600;1,400` |
| Swiss precision | Outfit | Outfit | `Outfit:wght@300;400;500;600;700` |
| Elegant formal | Cormorant Garamond | Cormorant Garamond | `Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400` |
| Modern geometric | Plus Jakarta Sans | Plus Jakarta Sans | `Plus+Jakarta+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400` |
| Scandinavian clean | Familjen Grotesk | Lora | `Familjen+Grotesk:wght@400;500;600;700&family=Lora:ital,wght@0,400;0,500;0,600;0,700;1,400` |
| Tech/startup | Space Grotesk | IBM Plex Serif | `Space+Grotesk:wght@400;500;600;700&family=IBM+Plex+Serif:ital,wght@0,400;0,500;0,600;1,400` |
| Newspaper/magazine | Fraunces | Work Sans | `Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,600;0,9..144,700;1,9..144,400&family=Work+Sans:wght@300;400;500;600` |
| Bold/expressive | Sora | Bitter | `Sora:wght@400;500;600;700&family=Bitter:ital,wght@0,400;0,500;0,600;0,700;1,400` |

For code-heavy documents, add JetBrains Mono or Fira Code: `&family=JetBrains+Mono:wght@400;600`

**IMPORTANT:** When using a single font family for both headings and body (e.g., DM Sans, Outfit,
Plus Jakarta Sans), create hierarchy through weight contrast and size — not font switching.
Use lighter weights (300–400) for body, heavier weights (600–700) for headings.

## Color Palettes

Each palette overrides 5-7 variables (not just `--color-accent`) so the document's full chrome —
borders, subtle backgrounds, text tone, page background for warm palettes — moves together. A
single-axis swap is what makes palettes feel like "same template, different paint." Use the
full block below.

### Ready-made palettes

**Slate (default — professional, neutral)**
```css
--color-accent: #334155;
--color-accent-light: #f1f5f9;
--color-text: #0f172a;
--color-text-secondary: #64748b;
--color-border: #e2e8f0;
--color-bg-subtle: #f8fafc;
```

**Ocean (business, consulting)**
```css
--color-accent: #1e4d6e;
--color-accent-light: #e8f1f8;
--color-text: #102a43;
--color-text-secondary: #486581;
--color-border: #d6e4f0;
--color-bg-subtle: #f4f8fb;
```

**Teal (medical, health, clinical)**
```css
--color-accent: #0d7377;
--color-accent-light: #e6f5f5;
--color-text: #0a3a3d;
--color-text-secondary: #4b6e70;
--color-border: #d2e8e8;
--color-bg-subtle: #f3faf9;
```

**Terracotta (warm, personal, creative)** — also shifts page background warm
```css
--color-accent: #9c4221;
--color-accent-light: #fef3ec;
--color-text: #3b1e10;
--color-text-secondary: #8a6952;
--color-border: #ead7c8;
--color-bg: #fdfcf9;
--color-bg-subtle: #faf3ec;
--color-warn: #b45309;   /* warm-tuned to match accent temperature */
--color-warn-bg: #fef6e7;
--color-ok: #4d7c0f;     /* desaturated green that doesn't clash */
--color-ok-bg: #f6fae8;
```

**Forest (natural, calm)**
```css
--color-accent: #2d6a4f;
--color-accent-light: #e9f5ef;
--color-text: #15301f;
--color-text-secondary: #5a7868;
--color-border: #cfe2d7;
--color-bg-subtle: #f3f9f5;
```

**Ink (formal, legal, traditional)**
```css
--color-accent: #1c1917;
--color-accent-light: #f5f5f4;
--color-text: #0c0a09;
--color-text-secondary: #57534e;
--color-border: #d6d3d1;
--color-bg-subtle: #fafaf9;
```

**Berry (creative, bold)**
```css
--color-accent: #7c3aed;
--color-accent-light: #f3f0ff;
--color-text: #1e1239;
--color-text-secondary: #6b5a8d;
--color-border: #e0d5fa;
--color-bg-subtle: #f8f5ff;
```

**Copper (premium, luxury feel)** — also shifts page background warm
```css
--color-accent: #92400e;
--color-accent-light: #fef7ed;
--color-text: #2a1607;
--color-text-secondary: #8c6b50;
--color-border: #ecd9c4;
--color-bg: #fdfbf7;
--color-bg-subtle: #faf3ea;
--color-warn: #b45309;
--color-warn-bg: #fef6e7;
--color-ok: #65a30d;
--color-ok-bg: #f4fae3;
```

### Status colors: when to override per-palette

The default `--color-warn` (amber) and `--color-ok` (cool green) are tuned to cool/neutral
palettes (Slate, Ocean, Teal, Ink, Berry). For warm palettes (Terracotta, Copper), they create
a temperature clash — the success callout looks like it belongs to a different document. The
Terracotta and Copper blocks above include warm-tuned overrides. If you build a custom palette
in a warm hue, override the four status vars too.

---

## Complete Base Stylesheet

Copy this entire block into every PDF's `<style>` tag, then override variables as needed.

```css
@import url('https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,300;0,8..60,400;0,8..60,600;0,8..60,700;1,8..60,400&family=Source+Sans+3:ital,wght@0,300;0,400;0,600;0,700;1,400&family=Source+Code+Pro:wght@400;600&display=swap');

:root {
  /* --- FONTS --- */
  --font-serif: 'Source Serif 4', 'Liberation Serif', Georgia, serif;
  --font-sans: 'Source Sans 3', 'Liberation Sans', 'Helvetica Neue', sans-serif;
  --font-mono: 'Source Code Pro', 'Liberation Mono', 'Courier New', monospace;

  /* --- TYPE SCALE (Editorial — default; override via body.scale-compact / body.scale-generous) --- */
  --fs-h1: 24pt;
  --fs-h2: 13.5pt;
  --fs-h3: 11pt;
  --fs-h4: 10pt;
  --fs-body: 10.5pt;
  --fs-small: 9pt;
  --fs-table: 9.5pt;
  --fs-code: 8.5pt;
  --fs-pagenum: 8pt;

  --lh-tight: 1.25;
  --lh-body: 1.65;
  --lh-list: 1.55;
  --lh-code: 1.55;

  --tracking-display: -0.025em;
  --tracking-caps: 0.06em;
  --tracking-pagenum: 0.05em;
  --weight-h1: 700;
  --weight-heading: 600;

  /* --- EDGE LANGUAGE (Standard — default; override via body.edges-hairline / body.edges-chunky) --- */
  --border-hair: 0.25pt;
  --border-thin: 0.5pt;
  --border-normal: 0.75pt;
  --border-strong: 1.5pt;
  --border-bold: 2pt;
  --border-heavy: 2.5pt;
  --radius-sm: 1mm;
  --radius-md: 2mm;

  /* --- PALETTE (Slate default — override these to change the feel) --- */
  --color-text: #0f172a;
  --color-text-secondary: #64748b;
  --color-accent: #334155;
  --color-accent-light: #f1f5f9;
  --color-border: #e2e8f0;
  --color-bg: #ffffff;
  --color-bg-subtle: #f8fafc;

  /* --- STATUS COLORS (override per palette so warm/cool palettes can re-tune them) --- */
  --color-warn: #d97706;
  --color-warn-bg: #fef9ee;
  --color-ok: #16a34a;
  --color-ok-bg: #f0fdf4;

  /* --- SPACING SCALE (mm) --- */
  --space-xs: 1.5mm;
  --space-sm: 3mm;
  --space-md: 5mm;
  --space-lg: 8mm;
  --space-xl: 12mm;
  --space-2xl: 18mm;
}

/* ============================================
   NAMED VARIANTS — apply to <body class="...">
   ============================================ */

/* Type scales: pick one or stay on default Editorial */
body.scale-compact {
  --fs-h1: 20pt;
  --fs-h2: 12pt;
  --fs-h3: 10pt;
  --fs-h4: 9pt;
  --fs-body: 9.5pt;
  --fs-table: 9pt;
  --lh-body: 1.5;
  --lh-list: 1.4;
}

body.scale-generous {
  --fs-h1: 30pt;
  --fs-h2: 16pt;
  --fs-h3: 12.5pt;
  --fs-h4: 10.5pt;
  --fs-body: 11.5pt;
  --lh-body: 1.8;
  --lh-list: 1.7;
}

/* Edge weights: hairline (refined / precise) or chunky (bold / editorial) */
body.edges-hairline {
  --border-hair: 0.15pt;
  --border-thin: 0.25pt;
  --border-normal: 0.4pt;
  --border-strong: 0.75pt;
  --border-bold: 1pt;
  --border-heavy: 1.5pt;
  --radius-sm: 0;
  --radius-md: 0.5mm;
}

body.edges-chunky {
  --border-hair: 0.5pt;
  --border-thin: 1pt;
  --border-normal: 1.5pt;
  --border-strong: 2.5pt;
  --border-bold: 3.5pt;
  --border-heavy: 4.5pt;
  --radius-sm: 2mm;
  --radius-md: 4mm;
}

/* ============================================
   PAGE SETUP
   ============================================ */

@page {
  size: A4;
  margin: 28mm 24mm 32mm 24mm;
  /* Page background fills the full sheet (including margins), so warm-bg palettes
     like Terracotta and Copper tint the entire page, not just the content rect. */
  background: var(--color-bg);

  @bottom-right {
    content: counter(page);
    font-family: var(--font-sans);
    font-size: var(--fs-pagenum);
    color: var(--color-text-secondary);
    letter-spacing: var(--tracking-pagenum);
  }
}

@page :first {
  /* Note: no extra top margin here. Earlier drafts set 36mm to give covers more
     breathing room, but that breaks .header-bar (which uses a negative top margin
     calibrated to the default 28mm). Templates without a banner can add their own
     top space via a leading h1 margin. */
  @bottom-right { content: none; }
}

/* ============================================
   BASE TYPOGRAPHY
   ============================================ */

body {
  font-family: var(--font-serif);
  font-size: var(--fs-body);
  line-height: var(--lh-body);
  color: var(--color-text);
  background: var(--color-bg);
}

/* ---- Headings ---- */

h1, h2, h3, h4 {
  font-family: var(--font-sans);
  line-height: var(--lh-tight);
  page-break-after: avoid;
}

h1 {
  font-size: var(--fs-h1);
  font-weight: var(--weight-h1);
  color: var(--color-accent);
  margin: 0 0 var(--space-md) 0;
  letter-spacing: var(--tracking-display);
}

h2 {
  font-size: var(--fs-h2);
  font-weight: var(--weight-heading);
  color: var(--color-text);
  margin: var(--space-xl) 0 var(--space-sm) 0;
  padding-bottom: var(--space-xs);
  border-bottom: var(--border-normal) solid var(--color-border);
}

h3 {
  font-size: var(--fs-h3);
  font-weight: var(--weight-heading);
  color: var(--color-text);
  margin: var(--space-lg) 0 var(--space-xs) 0;
}

h4 {
  font-size: var(--fs-h4);
  font-weight: var(--weight-heading);
  color: var(--color-text-secondary);
  text-transform: uppercase;
  letter-spacing: var(--tracking-caps);
  margin: var(--space-md) 0 var(--space-xs) 0;
}

/* ---- Body text ---- */

p {
  margin: 0 0 var(--space-sm) 0;
  orphans: 3;
  widows: 3;
}

strong { font-weight: 600; }

small, .small {
  font-size: var(--fs-small);
  color: var(--color-text-secondary);
}

/* ---- Links (for digital PDFs) ---- */

a {
  color: var(--color-accent);
  text-decoration: underline;
  text-decoration-thickness: var(--border-thin);
  text-underline-offset: 1.5pt;
}

/* ---- Lists ---- */

ul, ol {
  margin: var(--space-xs) 0 var(--space-md) 0;
  padding-left: 6mm;
}

li {
  margin-bottom: var(--space-xs);
  line-height: var(--lh-list);
}

li::marker {
  color: var(--color-accent);
  font-weight: var(--weight-heading);
}

/* ---- Blockquote ---- */

blockquote {
  border-left: var(--border-heavy) solid var(--color-accent);
  margin: var(--space-md) 0;
  padding: var(--space-xs) 0 var(--space-xs) var(--space-md);
  color: var(--color-text-secondary);
  font-style: italic;
}

blockquote p { margin-bottom: var(--space-xs); }

/* ---- Horizontal rule ---- */

hr {
  border: none;
  border-top: var(--border-thin) solid var(--color-border);
  margin: var(--space-lg) 0;
}

/* ============================================
   TABLES
   ============================================ */

table {
  width: 100%;
  border-collapse: collapse;
  margin: var(--space-md) 0 var(--space-lg) 0;
  font-family: var(--font-sans);
  font-size: var(--fs-table);
  page-break-inside: auto;
}

thead {
  display: table-header-group;
}

thead th {
  background: var(--color-accent);
  color: white;
  font-weight: var(--weight-heading);
  padding: 2.5mm 3.5mm;
  text-align: left;
  font-size: calc(var(--fs-table) - 1pt);
  text-transform: uppercase;
  letter-spacing: var(--tracking-pagenum);
}

/* Softer table header variant — use class="table-soft" on <table> */
table.table-soft thead th {
  background: var(--color-bg-subtle);
  color: var(--color-text);
  border-bottom: var(--border-strong) solid var(--color-accent);
}

tbody td {
  padding: 2.5mm 3.5mm;
  border-bottom: var(--border-hair) solid var(--color-border);
  vertical-align: top;
}

tbody tr:nth-child(even) {
  background: var(--color-bg-subtle);
}

/* Right-align numbers */
td.num, th.num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* ============================================
   CODE
   ============================================ */

code {
  font-family: var(--font-mono);
  font-size: var(--fs-small);
  background: var(--color-bg-subtle);
  padding: 0.3mm 1.5mm;
  border-radius: var(--radius-sm);
  border: var(--border-hair) solid var(--color-border);
}

pre {
  background: var(--color-bg-subtle);
  border: var(--border-thin) solid var(--color-border);
  border-radius: var(--radius-md);
  padding: var(--space-sm) var(--space-md);
  font-family: var(--font-mono);
  font-size: var(--fs-code);
  line-height: var(--lh-code);
  overflow-wrap: break-word;
  white-space: pre-wrap;
  margin: var(--space-sm) 0 var(--space-md) 0;
}

pre code {
  background: none;
  border: none;
  padding: 0;
  font-size: inherit;
}

/* Multi-page code blocks: prevent PDF reading-order from pulling page footers
   into the user's text selection. If a <pre> may span pages, tag it with
   class="code-block" and opt it into the code-page named page defined below.
   See references/gotchas.md §1 for the full story. */
pre.code-block {
  page: code-page;
  page-break-inside: auto;
}

@page code-page {
  margin: 20mm 22mm 22mm 22mm;
  @bottom-left  { content: none; }
  @bottom-right { content: none; }
  @top-left     { content: none; }
  @top-right    { content: none; }
}

/* ============================================
   COMPONENTS
   ============================================ */

/* ---- Subtitle (below h1) ---- */

.subtitle {
  font-family: var(--font-sans);
  font-size: calc(var(--fs-body) + 1.5pt);
  color: var(--color-text-secondary);
  margin: calc(-1 * var(--space-sm)) 0 var(--space-lg) 0;
  font-weight: 300;
  line-height: 1.4;
}

/* ---- Metadata line ---- */

.meta {
  font-family: var(--font-sans);
  font-size: var(--fs-small);
  color: var(--color-text-secondary);
  margin-bottom: var(--space-lg);
  letter-spacing: 0.01em;
}

/* ---- Callout / highlight box ---- */

.callout {
  background: var(--color-accent-light);
  border-left: var(--border-bold) solid var(--color-accent);
  padding: var(--space-sm) var(--space-md);
  margin: var(--space-md) 0;
  border-radius: 0 var(--radius-md) var(--radius-md) 0;
}

.callout p { margin: 0; }
.callout p + p { margin-top: var(--space-xs); }

/* Warning variant (override --color-warn / --color-warn-bg per palette to tune) */
.callout-warn {
  background: var(--color-warn-bg);
  border-left-color: var(--color-warn);
}

/* Success variant (override --color-ok / --color-ok-bg per palette to tune) */
.callout-ok {
  background: var(--color-ok-bg);
  border-left-color: var(--color-ok);
}

/* ---- Header bar (full-width accent banner) ----
   The negative margins (-12mm -24mm) assume the default @page margin of 28mm/24mm.
   Side margins (-24mm) fully bleed left/right; top (-12mm) intentionally leaves ~16mm
   of breathing room above the bar — it's not edge-to-top by design. If you change the
   page margin, update these to match. */

.header-bar {
  background: var(--color-accent);
  color: white;
  padding: var(--space-md) var(--space-lg);
  margin: -12mm -24mm var(--space-xl) -24mm;
  font-family: var(--font-sans);
}

.header-bar h1 {
  color: white;
  margin: 0;
  font-size: calc(var(--fs-h1) * 0.83);
}

.header-bar .subtitle {
  color: rgba(255,255,255,0.8);
  margin: var(--space-xs) 0 0 0;
  font-size: calc(var(--fs-body) + 0.5pt);
}

/* ---- Minimal header (no bar, just a rule) ---- */

.header-minimal {
  border-bottom: var(--border-bold) solid var(--color-accent);
  padding-bottom: var(--space-sm);
  margin-bottom: var(--space-xl);
}

.header-minimal h1 {
  margin-bottom: var(--space-xs);
}

/* ---- Centered header (no rule, pure typography) ----
   For personal/literary/formal documents that want their opening to feel composed,
   not chrome'd. Title and subtitle both centered. */

.header-centered {
  text-align: center;
  margin-bottom: var(--space-2xl);
}

.header-centered h1 {
  margin: 0 0 var(--space-sm) 0;
}

.header-centered .subtitle {
  margin-top: 0;
}

/* ---- Side-rule header (vertical accent bar left of title) ----
   Distinctive editorial look — feels journalistic, suits reports and essays. */

.header-side-rule {
  border-left: var(--border-bold) solid var(--color-accent);
  padding-left: var(--space-md);
  margin-bottom: var(--space-xl);
}

.header-side-rule h1 {
  margin: 0 0 var(--space-xs) 0;
}

.header-side-rule .subtitle {
  margin-top: 0;
}

/* ---- Large-numeral header (display-scale title, no decoration) ----
   For documents where the title itself carries the visual weight —
   covers, dividers, statement openers. Use sparingly. */

.header-large-numeral {
  margin-bottom: var(--space-2xl);
}

.header-large-numeral h1 {
  font-size: calc(var(--fs-h1) * 1.8);
  line-height: 1.05;
  margin: 0 0 var(--space-md) 0;
  font-weight: var(--weight-h1);
  letter-spacing: -0.03em;
}

.header-large-numeral .subtitle {
  font-size: var(--fs-body);
  margin-top: 0;
}

/* ---- Pure-typesetting header (no geometry, refined and quiet) ----
   For formal letters, literary documents, fine-print contexts where any banner
   or rule would feel loud. Title is set in the body serif at modest weight. */

.header-typeset {
  margin-bottom: var(--space-2xl);
}

.header-typeset h1 {
  font-family: var(--font-serif);
  font-size: calc(var(--fs-h1) * 0.7);
  font-weight: 400;
  letter-spacing: 0;
  color: var(--color-text);
  margin: 0 0 var(--space-xs) 0;
}

.header-typeset .subtitle {
  font-family: var(--font-serif);
  font-style: italic;
  font-size: var(--fs-body);
  margin-top: 0;
}

/* ---- Two-column layout ---- */

.two-col {
  columns: 2;
  column-gap: var(--space-lg);
}

/* ---- Signature block ---- */

.signature {
  margin-top: var(--space-2xl);
  font-family: var(--font-sans);
  font-size: var(--fs-h4);
  line-height: 1.5;
}

/* ---- Key-value pairs (for metadata, specs, patient info, etc.) ---- */

.kv-grid {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: var(--space-xs) var(--space-md);
  font-family: var(--font-sans);
  font-size: var(--fs-h4);
  margin: var(--space-md) 0;
}

.kv-grid dt {
  font-weight: var(--weight-heading);
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.kv-grid dd {
  margin: 0;
}

/* ---- Figure / Image ---- */

figure {
  margin: var(--space-md) 0 var(--space-lg) 0;
  text-align: center;
  page-break-inside: avoid;
}

figure img {
  max-width: 100%;
  border-radius: var(--radius-md);
}

figcaption {
  font-family: var(--font-sans);
  font-size: var(--fs-code);
  color: var(--color-text-secondary);
  margin-top: var(--space-xs);
}

/* ============================================
   UTILITY CLASSES
   ============================================ */

.page-break { page-break-before: always; }
.no-break { page-break-inside: avoid; }
.text-center { text-align: center; }
.text-right { text-align: right; }
.mt-0 { margin-top: 0; }
.mb-0 { margin-bottom: 0; }
.muted { color: var(--color-text-secondary); }
.font-sans { font-family: var(--font-sans); }
.font-serif { font-family: var(--font-serif); }
.uppercase { text-transform: uppercase; letter-spacing: 0.06em; }
```

---

## Weasyprint Technical Notes

- **Google Fonts:** The `@import` is fetched at PDF generation time. Requires internet access
  to fonts.googleapis.com — if unavailable (offline, firewall), the fallback chain handles it,
  but the document will visibly fall back to system fonts. If you need a fully offline build,
  download the fonts and reference them as `@font-face { src: url('./fonts/...'); }`.
- **Page size:** Default is A4. For US Letter, override with `@page { size: letter; }`.
- **Images:** Must be absolute paths (e.g., `C:\Users\name\photo.jpg` on Windows or
  `/home/user/photo.jpg` on Linux/macOS) or base64 data URIs. Relative paths do not resolve.
- **No JavaScript:** Weasyprint renders static HTML+CSS only. No JS execution.
- **CSS Grid:** Supported. Flexbox is partially supported — grid is more reliable.
- **`@page` margin notes:** The `@bottom-right` block creates page numbers. Weasyprint supports
  `@top-left`, `@top-center`, `@top-right`, `@bottom-left`, `@bottom-center`, `@bottom-right`.
- **Print colors:** `background` on elements is rendered by default in weasyprint (unlike browsers
  which suppress backgrounds for print). No need for `-webkit-print-color-adjust`.
- **Unicode:** Full Unicode support. Norwegian characters (æ, ø, å) work perfectly with all
  listed fonts. For subscript/superscript, use `<sub>` and `<sup>` HTML tags rather than
  Unicode characters (₀₁₂₃₄₅) — Unicode versions depend on font glyph coverage and may render
  inconsistently across pairings.
