# Invoice / Financial Summary

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

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
