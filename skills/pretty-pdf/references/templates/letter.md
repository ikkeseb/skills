# Letter (Formal or Personal)

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

Palette suggestion: **Ink** (formal) or **Terracotta** (personal/warm).
Use `.header-minimal` or `.header-centered` for a quiet, composed opener.
For personal letters, switch the `@import` to a literary serif like Cormorant Garamond or EB
Garamond (see `references/base-styles.md` → Font pairings) and let body + headings share the same
family for a coherent reading rhythm.

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
