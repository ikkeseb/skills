# Document Templates Reference

HTML templates for common document types. Each template uses the base stylesheet from
`base-styles.md` — copy that `<style>` block first, then drop in the relevant template HTML.

**Each template below shows ONE layout choice.** That's a starting point, not a default to
always pick. For real anti-convergence (see SKILL.md "Anti-Convergence Rule"), swap among the
six header components (`.header-typeset` is the default, then `.header-minimal`,
`.header-side-rule`, `.header-centered`, `.header-large-numeral`, `.header-bar`), the three
type scales (default Editorial, `body.scale-compact`, `body.scale-generous`), and the three
edge weights (default Standard, `body.edges-hairline`, `body.edges-chunky`) — not just palette
and font. A medical doc rendered with `.header-side-rule` + `.scale-compact` + `.edges-hairline`
should look like a different document family from a personal letter in `.header-centered` +
`.scale-generous` + standard edges.

---

## Table of Contents

1. [Report / Business Document](#report)
2. [Letter (formal or personal)](#letter)
3. [Medical Document / Doctor Summary](#medical)
4. [Invoice / Financial Summary](#invoice)
5. [CV / Resume](#cv)
6. [One-Pager / Summary Brief](#one-pager)
7. [Personal Document (travel log, journal, notes)](#personal)
8. [Technical Document / Specification](#technical)
9. [Design Guidance by Context](#design-guidance)

---

<a id="report"></a>
## 1. Report / Business Document

Palette suggestion: **Ocean** or **Slate**. Default to `.header-typeset` for a quiet, typographic
opener; reach for `.header-bar` only when the document genuinely warrants the loudest chrome
(quarterly review with brand-forward tone, etc.). The example below uses `.header-bar` to show
the assertive variant.

```html
<div class="header-bar">
  <h1>Report Title Goes Here</h1>
  <p class="subtitle">Subtitle or context line · Date</p>
</div>

<p class="meta">Prepared by Author Name · Organization · Date</p>

<h2>Executive Summary</h2>
<p>Lead with the conclusion. One paragraph that tells the reader what they need to know
if they read nothing else.</p>

<div class="callout">
  <p><strong>Key finding:</strong> State the single most important takeaway here.</p>
</div>

<h2>Section Title</h2>
<p>Body content with supporting detail...</p>

<h3>Subsection</h3>
<p>Deeper detail as needed...</p>

<table>
  <thead><tr><th>Metric</th><th>Value</th><th>Change</th></tr></thead>
  <tbody>
    <tr><td>Item</td><td class="num">1,234</td><td class="num">+12%</td></tr>
  </tbody>
</table>

<div class="page-break"></div>
<h2>Next Major Section</h2>
<p>Continue on a fresh page for major topic shifts...</p>
```

---

<a id="letter"></a>
## 2. Letter (Formal or Personal)

Palette suggestion: **Ink** (formal) or **Terracotta** (personal/warm).
Use `.header-minimal` or `.header-centered` for a quiet, composed opener.
For personal letters, switch the `@import` to a literary serif like Cormorant Garamond or EB
Garamond (see `base-styles.md` → Font Loading → "Pick by content") and let body + headings share
the same family for a coherent reading rhythm.

```html
<div class="header-minimal">
  <h1 style="font-size: 16pt;">Subject of the Letter</h1>
</div>

<dl class="kv-grid">
  <dt>Dato</dt><dd>13. april 2026</dd>
  <dt>Til</dt><dd>Mottaker, Organisasjon</dd>
  <dt>Fra</dt><dd>Avsender</dd>
  <dt>Ref.</dt><dd>Referansenummer (om relevant)</dd>
</dl>

<p>Kjære ...</p>

<p>Opening paragraph establishing context and purpose.</p>

<p>Body paragraphs with the substance of the letter. Keep paragraphs
relatively short for readability.</p>

<p>Closing paragraph with any call to action or next steps.</p>

<div class="signature">
  <p>Med vennlig hilsen,</p>
  <br>
  <p><strong>Full Name</strong><br>
  Title<br>
  Organization<br>
  Phone / Email</p>
</div>
```

---

<a id="medical"></a>
## 3. Medical Document / Doctor Summary

Palette suggestion: **Teal**. Typography: the default Inter Tight is already a clean sans and
works well; for an even more clinical feel, swap the `@import` to **DM Sans** (see
`base-styles.md` → Font Loading). Pair with `body class="scale-compact"` for the dense,
scannable rhythm clinical reading wants.

Key design principles for medical docs:
- **High information density** with clear visual hierarchy
- **Key-value layout** (`.kv-grid`) for patient info, dates, references
- **Callout boxes** for important warnings, dosages, or action items
- **Sans-serif throughout** (default — body is already sans)
- **No decorative elements** — function over form

```html
<div class="header-minimal">
  <h1>Document Title</h1>
  <p class="subtitle">Type of document (e.g., Epikrise, Henvisning, Legeerklæring)</p>
</div>

<dl class="kv-grid">
  <dt>Pasient</dt><dd>Full Name (fødselsdato)</dd>
  <dt>Fastlege</dt><dd>Dr. Name</dd>
  <dt>Dato</dt><dd>13. april 2026</dd>
  <dt>Vår ref.</dt><dd>Reference number</dd>
</dl>

<hr>

<h2>Bakgrunn</h2>
<p>Brief medical history or reason for the document...</p>

<h2>Aktuelt</h2>
<p>Current situation, symptoms, findings...</p>

<div class="callout">
  <p><strong>Pågående medisinering:</strong> List medications, dosages, and frequency.</p>
</div>

<h2>Vurdering</h2>
<p>Clinical assessment and reasoning...</p>

<h2>Tiltak / Anbefaling</h2>
<ul>
  <li>Specific action item or recommendation</li>
  <li>Follow-up appointment or referral</li>
  <li>Lifestyle or medication adjustments</li>
</ul>

<div class="signature">
  <p><strong>Dr. Name</strong><br>
  Specialty<br>
  Clinic / Hospital<br>
  Phone</p>
</div>
```

---

<a id="invoice"></a>
## 4. Invoice / Financial Summary

Palette suggestion: **Slate** or **Ink**. Clean, tabular layout.
Right-align all monetary values using `class="num"`.

```html
<div class="header-minimal">
  <h1 style="font-size: 18pt;">Faktura</h1>
  <p class="subtitle">Fakturanr: 2026-0042</p>
</div>

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8mm; margin-bottom: 8mm;">
  <div>
    <h4>Fra</h4>
    <p>Company Name<br>Address Line 1<br>Org.nr: 123 456 789</p>
  </div>
  <div>
    <h4>Til</h4>
    <p>Client Name<br>Client Address<br>Org.nr: 987 654 321</p>
  </div>
</div>

<dl class="kv-grid" style="font-size: 9pt;">
  <dt>Fakturadato</dt><dd>13.04.2026</dd>
  <dt>Forfallsdato</dt><dd>27.04.2026</dd>
  <dt>KID</dt><dd>1234567890123456</dd>
  <dt>Kontonr</dt><dd>1234.56.78901</dd>
</dl>

<table>
  <thead>
    <tr><th>Beskrivelse</th><th class="num">Antall</th><th class="num">Pris</th><th class="num">Sum</th></tr>
  </thead>
  <tbody>
    <tr><td>Consulting hours</td><td class="num">40</td><td class="num">1 200,00</td><td class="num">48 000,00</td></tr>
    <tr><td>Travel expenses</td><td class="num">1</td><td class="num">3 500,00</td><td class="num">3 500,00</td></tr>
  </tbody>
</table>

<div style="text-align: right; margin-top: 4mm;">
  <p>Subtotal: <strong>51 500,00 kr</strong></p>
  <p>MVA 25%: <strong>12 875,00 kr</strong></p>
  <p style="font-size: 14pt; margin-top: 2mm;"><strong>Totalt: 64 375,00 kr</strong></p>
</div>
```

---

<a id="cv"></a>
## 5. CV / Resume

Palette suggestion: **Slate** or personal preference. Use `.kv-grid` for structured data.
Consider a two-column layout for compact CVs. The candidate's name should carry visual weight —
`.header-large-numeral` or `.header-typeset` both work well; the example below uses a bare h1
with custom sizing, but try `<div class="header-large-numeral"><h1>...</h1></div>` for a more
statement opener.

```html
<h1 style="margin-bottom: 2mm;">Full Name</h1>
<p class="subtitle">Title / Role / Tagline</p>

<p class="meta">
  email@example.com · +47 123 45 678 · Oslo, Norway · linkedin.com/in/username
</p>

<hr>

<h2>Summary</h2>
<p>Two to three sentences capturing your profile, experience level, and what you bring.</p>

<h2>Experience</h2>

<div class="no-break">
  <h3 style="margin-bottom: 0;">Job Title — Company Name</h3>
  <p class="meta" style="margin-bottom: 2mm;">Jan 2023 – Present · Location</p>
  <p>Description of role, responsibilities, and key achievements. Focus on impact and outcomes.</p>
</div>

<div class="no-break">
  <h3 style="margin-bottom: 0;">Previous Job Title — Previous Company</h3>
  <p class="meta" style="margin-bottom: 2mm;">Jun 2020 – Dec 2022 · Location</p>
  <p>Description...</p>
</div>

<h2>Education</h2>
<div class="no-break">
  <h3 style="margin-bottom: 0;">Degree — Institution</h3>
  <p class="meta">2016 – 2020</p>
</div>

<h2>Skills</h2>
<p>Skill 1 · Skill 2 · Skill 3 · Skill 4 · Skill 5</p>
```

---

<a id="one-pager"></a>
## 6. One-Pager / Summary Brief

Palette: match to context. Use `.two-col` for information density.
Force everything onto one page — remove page numbers, reduce margins if needed.

```html
<!-- Override page setup for single-page documents -->
<style>
  @page { margin: 20mm 18mm 20mm 18mm; @bottom-right { content: none; } }
  @page :first { margin-top: 20mm; }
</style>

<h1>Topic Title</h1>
<p class="subtitle">One-page overview · Date</p>

<div class="two-col">
  <h3>Key Point One</h3>
  <p>Concise explanation...</p>

  <h3>Key Point Two</h3>
  <p>Concise explanation...</p>

  <h3>Key Point Three</h3>
  <p>Concise explanation...</p>

  <div class="callout">
    <p><strong>Bottom line:</strong> The single takeaway the reader should remember.</p>
  </div>
</div>
```

---

<a id="personal"></a>
## 7. Personal Document (Travel Log, Journal, Notes)

Palette suggestion: **Terracotta**, **Forest**, or **Copper**. Go warmer and more expressive.
Swap the `@import` to **Cormorant Garamond** or **EB Garamond** (see `base-styles.md` → Font
Loading) for a literary feel — the default Inter Tight is too neutral for journal-like content.
Add `body class="scale-generous"` for a less crowded reading rhythm.

Personal documents can break from the corporate constraint — use larger type, more whitespace,
and let the content breathe. The `.lede` component (dropcap + small-caps first line) is
specifically designed for this kind of opener. Use `.header-centered` or `.header-typeset` for
a composed, non-corporate opener.

```html
<div class="header-centered">
  <h1>Title of the Document</h1>
  <p class="subtitle">A brief description or date range</p>
</div>

<hr>

<p style="font-size: 11.5pt; line-height: 1.75;">
  Opening paragraph with generous typography. Personal documents benefit from
  slightly larger text and more line spacing — this isn't a report, it's something
  someone will want to read for pleasure.
</p>

<h2>Section Title</h2>
<p>Continue with content...</p>

<blockquote>
  <p>A memorable quote or observation from the experience.</p>
</blockquote>

<figure>
  <img src="data:image/jpeg;base64,..." alt="Description">
  <figcaption>Caption describing the image</figcaption>
</figure>
```

---

<a id="technical"></a>
## 8. Technical Document / Specification

Palette suggestion: **Slate** or **Steel**. Keep it functional — code blocks and tables will
dominate. For code-heavy documents, swap the mono `@import` to **JetBrains Mono** or **IBM Plex
Mono** (see `base-styles.md` → Font Loading) for better code legibility than Source Code Pro.

```html
<div class="header-minimal">
  <h1>Technical Specification: Feature Name</h1>
</div>

<dl class="kv-grid">
  <dt>Version</dt><dd>1.0</dd>
  <dt>Author</dt><dd>Name</dd>
  <dt>Status</dt><dd>Draft</dd>
  <dt>Last updated</dt><dd>2026-04-13</dd>
</dl>

<h2>Overview</h2>
<p>What this document covers and why it exists.</p>

<h2>Requirements</h2>
<table>
  <thead><tr><th>ID</th><th>Requirement</th><th>Priority</th></tr></thead>
  <tbody>
    <tr><td>REQ-01</td><td>The system shall...</td><td>Must</td></tr>
    <tr><td>REQ-02</td><td>The system should...</td><td>Should</td></tr>
  </tbody>
</table>

<h2>Technical Details</h2>
<pre><code>// Code example
function example() {
  return "Hello, World!";
}</code></pre>

<div class="callout-warn callout">
  <p><strong>Note:</strong> Important caveat or dependency.</p>
</div>
```

---

<a id="design-guidance"></a>
## 9. Design Guidance by Context

When choosing how to design a document, think about three contextual dimensions, then five
formal axes (the axes from the Anti-Convergence Rule in SKILL.md).

### Contextual dimensions

**1. Formality**
- High formality (legal, medical, corporate) → conservative palette, traditional serif, more structure
- Low formality (personal, creative, notes) → warmer palette, expressive fonts, more whitespace

**2. Density**
- High density (invoices, specs, reference docs) → smaller font, tighter spacing, tables
  → reach for `body.scale-compact`
- Low density (letters, personal docs, summaries) → larger font, generous margins, fewer elements
  → reach for `body.scale-generous`

**3. Reader relationship**
- Known reader (doctor, colleague, friend) → can be more personal, assume context
- Unknown reader (application, public report) → more formal, more self-explanatory

### Formal axes — vary these to defeat convergence

| Axis | What it controls | Default (fallback) | Alternatives |
|------|------------------|---------|--------------|
| Font pairing | Glyph character | Inter Tight (clean sans, single-family) | Cormorant / EB Garamond (literary), DM Sans (clinical), Fraunces + Work Sans (editorial), Space Grotesk + IBM Plex (tech) — full table in `base-styles.md` |
| Palette | Color temperature, chrome tone | Slate | 7 other palettes (each overrides 5-7 vars) |
| Header | Document opener | `.header-typeset` (pure-type, quiet) | `.header-minimal`, `.header-side-rule`, `.header-centered`, `.header-large-numeral` (sparingly), `.header-bar` (sparingly, loudest) |
| Type scale | Density and rhythm | Editorial | `body.scale-compact`, `body.scale-generous` |
| Edge weight | Borders, rules, radii | Standard | `body.edges-hairline`, `body.edges-chunky` |

**Defaults are fallbacks, not picks.** Inter Tight is for "I genuinely don't know what this is".
Every document where you DO know the tone should override at least the font + palette + header.
A travel journal should not look like a quarterly business review. Stretch on at least three
axes per document.
