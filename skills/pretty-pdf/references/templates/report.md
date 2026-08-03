# Report / Business Document

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

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
