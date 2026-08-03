# Personal Document (Travel Log, Journal, Notes)

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

Palette suggestion: **Terracotta**, **Forest**, or **Copper**. Go warmer and more expressive.
Swap the `@import` to **Cormorant Garamond** or **EB Garamond** (see
`references/base-styles.md` → Font pairings) for a literary feel — the default Inter Tight is
too neutral for journal-like content.
Add `body class="scale-generous"` for a less crowded reading rhythm.

Personal documents can break from the corporate constraint — use larger type, more whitespace,
and let the content breathe. Use `.header-centered` or `.header-typeset` for a composed,
non-corporate opener. The `.lede` raised-cap component exists if a literary essay-style opener
genuinely fits — but it's a strong gesture, easy to overuse, and not a default. Skip it on
travel logs, journals, anything where the opening paragraph isn't doing literary work.

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
