# Documents

Read only the section for the document at hand. Each gives the choices from
`design.md` that usually fit and a skeleton to adapt, not a layout to fill:
cut what the content lacks, add what it needs.

## Report or business document

Serif voice, reading density, `.doc-head ruled`. Lead with the conclusion:
the opener's title states it, `figures` carries the numbers that prove it,
one `callout` holds the decision or finding the reader must act on.

```html
<header class="doc-head ruled">
  <p class="kicker">Rollout review · Q3 2026</p>
  <h1>The conclusion, stated as the title</h1>
  <p class="subtitle">What this document covers and for whom.</p>
  <p class="meta">Prepared for … · date</p>
</header>
<div class="figures"><div><b>4 / 6</b><span>what it counts</span></div>…</div>
<p>The answer in one paragraph.</p>
<div class="callout"><p><strong>Decision needed by …:</strong> …</p></div>
<h2>Section named for its content</h2>
<table><thead><tr><th>Item</th><th>State</th><th class="num">Value</th></tr></thead>
<tbody><tr><td>…</td><td class="ok">Accepted</td><td class="num">112</td></tr></tbody></table>
```

## Letter

Serif voice, no `.doc-head`: sender and date in a `pair`, then recipient,
then the body. A personal letter may open with `.lede`; a formal one never
does. Close with `signature`.

```html
<div class="pair">
  <p class="small muted">Sender<br>Street<br>Postcode City</p>
  <p class="small muted" style="text-align:right">City, date</p>
</div>
<p style="margin-top:14mm"><strong>Recipient</strong></p>
<p>Body…</p>
<div class="signature"><p>Closing</p><p class="name" style="margin-top:10mm">Name</p><p class="role">Role</p></div>
```

## Invoice or financial summary

`body class="sans compact"`, formal accent. The issuer in the opener, the
parties and payment facts in a `pair` of `facts`, one table of lines closed
by `tr.total`, payment instructions in a `callout`.

```html
<body class="sans compact">
<header class="doc-head"><p class="kicker">Invoice 2026-041</p><h1>Issuer</h1>
  <p class="meta">Business line · Org. no.</p></header>
<div class="pair">
  <dl class="facts"><dt>Billed to</dt><dd>…</dd><dt>Reference</dt><dd>…</dd></dl>
  <dl class="facts"><dt>Issued</dt><dd class="num">…</dd><dt>Due</dt><dd class="num">…</dd></dl>
</div>
<table>… <tr class="total"><td>Total NOK</td><td></td><td class="num">139 906</td></tr></table>
<div class="callout"><p>Payment instructions.</p></div>
```

## CV

`body class="compact"`, sans voice when the reader will scan it. The name is
the `h1`; role and contact go in `subtitle` and `meta`. Each role is an `h3`
("Title — Organisation"), a `small muted` date line and two or three
outcome bullets, wrapped in `.no-break`. Skills and languages go in `facts`.
Aim for one page, two at most.

## Clinical or medical summary

`body class="sans compact"`, a calm accent (green or neutral). Patient and
case details in `facts`, findings in a table, the one instruction that must
be followed (dosage, warning, next appointment) in `callout-warn`. Dense but
never cramped: keep the base spacing.

## One-pager

`body class="compact"`, no page number:
`@page { @bottom-right { content: none; } }`. `.two-col` only for running
text that reads in columns, never for tables. If it runs over, cut content
before shrinking type below the compact scale.

## Technical specification

Serif or sans voice by audience, `.doc-head ruled`, numbered `h2`s when
sections are referenced elsewhere. Code in `pre`; a long listing goes in a
`section.code-block` with its heading (`gotchas.md` §1). Tables for parameters and
interfaces, with `code` in the cells.

## Personal document: journal, travel log, essay

Serif voice, reading density, a warm accent. A `.doc-head` without rule, or
`cover` for a long piece. `.lede` on the first paragraph is right here.
Images go in `figure` with a `figcaption`; let them take the full text
width.
