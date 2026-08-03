# Medical Document / Doctor Summary

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

Palette suggestion: **Teal**. Typography: the default Inter Tight is already a clean sans and
works well; for an even more clinical feel, swap the `@import` to **DM Sans** (see
`references/base-styles.md` → Font pairings). Pair with `body class="scale-compact"` for the dense,
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
