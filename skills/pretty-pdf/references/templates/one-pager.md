# One-Pager / Summary Brief

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

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
