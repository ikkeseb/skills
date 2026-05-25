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

Override `--color-accent` and `--color-accent-light` (plus optionally `--color-text` and
`--color-text-secondary`) to change the entire feel.

### Ready-made palettes

**Slate (default — professional, neutral)**
```css
--color-accent: #334155;
--color-accent-light: #f1f5f9;
--color-text: #0f172a;
--color-text-secondary: #64748b;
```

**Ocean (business, consulting)**
```css
--color-accent: #1e4d6e;
--color-accent-light: #e8f1f8;
```

**Teal (medical, health, clinical)**
```css
--color-accent: #0d7377;
--color-accent-light: #e6f5f5;
```

**Terracotta (warm, personal, creative)**
```css
--color-accent: #9c4221;
--color-accent-light: #fef3ec;
```

**Forest (natural, calm)**
```css
--color-accent: #2d6a4f;
--color-accent-light: #e9f5ef;
```

**Ink (formal, legal, traditional)**
```css
--color-accent: #1c1917;
--color-accent-light: #f5f5f4;
```

**Berry (creative, bold)**
```css
--color-accent: #7c3aed;
--color-accent-light: #f3f0ff;
```

**Copper (premium, luxury feel)**
```css
--color-accent: #92400e;
--color-accent-light: #fef7ed;
```

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

  /* --- PALETTE (Slate default — override these to change the feel) --- */
  --color-text: #0f172a;
  --color-text-secondary: #64748b;
  --color-accent: #334155;
  --color-accent-light: #f1f5f9;
  --color-border: #e2e8f0;
  --color-bg: #ffffff;
  --color-bg-subtle: #f8fafc;

  /* --- SPACING SCALE (mm) --- */
  --space-xs: 1.5mm;
  --space-sm: 3mm;
  --space-md: 5mm;
  --space-lg: 8mm;
  --space-xl: 12mm;
  --space-2xl: 18mm;
}

/* ============================================
   PAGE SETUP
   ============================================ */

@page {
  size: A4;
  margin: 28mm 24mm 32mm 24mm;

  @bottom-right {
    content: counter(page);
    font-family: var(--font-sans);
    font-size: 8pt;
    color: var(--color-text-secondary);
    letter-spacing: 0.05em;
  }
}

@page :first {
  margin-top: 36mm;
  @bottom-right { content: none; }
}

/* ============================================
   BASE TYPOGRAPHY
   ============================================ */

body {
  font-family: var(--font-serif);
  font-size: 10.5pt;
  line-height: 1.65;
  color: var(--color-text);
  background: var(--color-bg);
}

/* ---- Headings ---- */

h1, h2, h3, h4 {
  font-family: var(--font-sans);
  line-height: 1.25;
  page-break-after: avoid;
}

h1 {
  font-size: 24pt;
  font-weight: 700;
  color: var(--color-accent);
  margin: 0 0 var(--space-md) 0;
  letter-spacing: -0.025em;
}

h2 {
  font-size: 13.5pt;
  font-weight: 600;
  color: var(--color-text);
  margin: var(--space-xl) 0 var(--space-sm) 0;
  padding-bottom: var(--space-xs);
  border-bottom: 0.75pt solid var(--color-border);
}

h3 {
  font-size: 11pt;
  font-weight: 600;
  color: var(--color-text);
  margin: var(--space-lg) 0 var(--space-xs) 0;
}

h4 {
  font-size: 10pt;
  font-weight: 600;
  color: var(--color-text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.06em;
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
  font-size: 9pt;
  color: var(--color-text-secondary);
}

/* ---- Links (for digital PDFs) ---- */

a {
  color: var(--color-accent);
  text-decoration: underline;
  text-decoration-thickness: 0.5pt;
  text-underline-offset: 1.5pt;
}

/* ---- Lists ---- */

ul, ol {
  margin: var(--space-xs) 0 var(--space-md) 0;
  padding-left: 6mm;
}

li {
  margin-bottom: var(--space-xs);
  line-height: 1.55;
}

li::marker {
  color: var(--color-accent);
  font-weight: 600;
}

/* ---- Blockquote ---- */

blockquote {
  border-left: 2.5pt solid var(--color-accent);
  margin: var(--space-md) 0;
  padding: var(--space-xs) 0 var(--space-xs) var(--space-md);
  color: var(--color-text-secondary);
  font-style: italic;
}

blockquote p { margin-bottom: var(--space-xs); }

/* ---- Horizontal rule ---- */

hr {
  border: none;
  border-top: 0.5pt solid var(--color-border);
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
  font-size: 9.5pt;
  page-break-inside: auto;
}

thead {
  display: table-header-group;
}

thead th {
  background: var(--color-accent);
  color: white;
  font-weight: 600;
  padding: 2.5mm 3.5mm;
  text-align: left;
  font-size: 8.5pt;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

/* Softer table header variant — use class="table-soft" on <table> */
table.table-soft thead th {
  background: var(--color-bg-subtle);
  color: var(--color-text);
  border-bottom: 1.5pt solid var(--color-accent);
}

tbody td {
  padding: 2.5mm 3.5mm;
  border-bottom: 0.25pt solid var(--color-border);
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
  font-size: 9pt;
  background: var(--color-bg-subtle);
  padding: 0.3mm 1.5mm;
  border-radius: 1mm;
  border: 0.25pt solid var(--color-border);
}

pre {
  background: var(--color-bg-subtle);
  border: 0.5pt solid var(--color-border);
  border-radius: 2mm;
  padding: var(--space-sm) var(--space-md);
  font-family: var(--font-mono);
  font-size: 8.5pt;
  line-height: 1.55;
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
  font-size: 12pt;
  color: var(--color-text-secondary);
  margin: calc(-1 * var(--space-sm)) 0 var(--space-lg) 0;
  font-weight: 300;
  line-height: 1.4;
}

/* ---- Metadata line ---- */

.meta {
  font-family: var(--font-sans);
  font-size: 9pt;
  color: var(--color-text-secondary);
  margin-bottom: var(--space-lg);
  letter-spacing: 0.01em;
}

/* ---- Callout / highlight box ---- */

.callout {
  background: var(--color-accent-light);
  border-left: 3pt solid var(--color-accent);
  padding: var(--space-sm) var(--space-md);
  margin: var(--space-md) 0;
  border-radius: 0 2mm 2mm 0;
}

.callout p { margin: 0; }
.callout p + p { margin-top: var(--space-xs); }

/* Warning variant */
.callout-warn {
  background: #fef9ee;
  border-left-color: #d97706;
}

/* Success variant */
.callout-ok {
  background: #f0fdf4;
  border-left-color: #16a34a;
}

/* ---- Header bar (full-width accent banner) ---- */

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
  font-size: 20pt;
}

.header-bar .subtitle {
  color: rgba(255,255,255,0.8);
  margin: var(--space-xs) 0 0 0;
  font-size: 11pt;
}

/* ---- Minimal header (no bar, just a rule) ---- */

.header-minimal {
  border-bottom: 2pt solid var(--color-accent);
  padding-bottom: var(--space-sm);
  margin-bottom: var(--space-xl);
}

.header-minimal h1 {
  margin-bottom: var(--space-xs);
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
  font-size: 10pt;
  line-height: 1.5;
}

/* ---- Key-value pairs (for metadata, specs, patient info, etc.) ---- */

.kv-grid {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: var(--space-xs) var(--space-md);
  font-family: var(--font-sans);
  font-size: 10pt;
  margin: var(--space-md) 0;
}

.kv-grid dt {
  font-weight: 600;
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
  border-radius: 2mm;
}

figcaption {
  font-family: var(--font-sans);
  font-size: 8.5pt;
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

- **Google Fonts:** The `@import` is fetched at PDF generation time. The container has network
  access to fonts.googleapis.com. If a font fails to load, the fallback chain handles it.
- **Page size:** Default is A4. For US Letter, override with `@page { size: letter; }`.
- **Images:** Must be absolute paths (`/mnt/user-data/uploads/photo.jpg`) or base64 data URIs.
  Relative paths do not resolve.
- **No JavaScript:** Weasyprint renders static HTML+CSS only. No JS execution.
- **CSS Grid:** Supported. Flexbox is partially supported — grid is more reliable.
- **`@page` margin notes:** The `@bottom-right` block creates page numbers. Weasyprint supports
  `@top-left`, `@top-center`, `@top-right`, `@bottom-left`, `@bottom-center`, `@bottom-right`.
- **Print colors:** `background` on elements is rendered by default in weasyprint (unlike browsers
  which suppress backgrounds for print). No need for `-webkit-print-color-adjust`.
- **Unicode:** Full Unicode support. Norwegian characters (æ, ø, å) work perfectly with all
  listed fonts.
- **ReportLab note:** NEVER use Unicode subscript/superscript characters (₀₁₂₃₄₅₆₇₈₉) —
  these render as black boxes. Use `<sub>` and `<sup>` HTML tags instead.
