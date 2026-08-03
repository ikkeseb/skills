# Technical Document / Specification

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

Palette suggestion: **Slate** or **Ink**. Keep it functional — code blocks and tables will
dominate. For code-heavy documents, swap the mono `@import` to **JetBrains Mono** or **IBM Plex
Mono** (see `references/base-styles.md` → Font pairings) for better code legibility than Source Code Pro.

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
