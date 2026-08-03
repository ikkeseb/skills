# Design System Reference

Use this file to choose design overrides. Do not copy or read the full executable stylesheet
during a normal run; pass `assets/base.css` directly to WeasyPrint, then apply a small override
stylesheet after it.

## Contents

- [Component classes](#component-classes)
- [Font pairings](#font-pairings)
- [Palettes](#palettes)
- [Optional running section header](#optional-running-section-header)
- [Technical notes](#technical-notes)

## Component classes

The complete class vocabulary the base stylesheet ships. Use these in the HTML; the templates
show only a subset.

- **Headers** (pick one): `.header-typeset`, `.header-minimal`, `.header-side-rule`,
  `.header-centered`, `.header-large-numeral`, `.header-bar`; `.subtitle` inside any of them.
- **Body scale / edges** (on `<body>`): `.scale-compact`, `.scale-generous`,
  `.edges-hairline`, `.edges-chunky`.
- **Layout**: `.two-col`, `.kv-grid` (key–value grid), `.page-break`, `.no-break`.
- **Callouts**: `.callout`, `.callout-warn`, `.callout-ok`.
- **Text**: `.lede`, `.meta`, `.muted`, `.smallcaps`, `.uppercase`, `.small`,
  `.text-center`, `.text-right`.
- **Blocks**: `pre.code-block` (paged code, see gotchas §1), `table.table-bold`
  (accent-filled header row), `img.img-rounded`, `.signature`.

## Font pairings

The base stylesheet loads Inter Tight and Source Code Pro as a neutral fallback. Pick the closest
content cue, import that pairing in the override stylesheet, and set `--font-serif`,
`--font-sans`, and optionally `--font-mono`.

| Content cue | Heading / body | Google Fonts family query |
|---|---|---|
| Default or unsure | Inter Tight / Inter Tight | Already in the base asset |
| Medical, clinical, scannable | DM Sans / DM Sans | `DM+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400` |
| Minimal, precise | Outfit / Outfit | `Outfit:wght@300;400;500;600;700` |
| Modern product or brand brief | Plus Jakarta Sans / same | `Plus+Jakarta+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400` |
| Technical or developer document | Space Grotesk / IBM Plex Serif | `Space+Grotesk:wght@400;500;600;700&family=IBM+Plex+Serif:ital,wght@0,400;0,500;0,600;1,400` |
| Personal letter, journal, essay | Cormorant Garamond / same | `Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400` |
| Formal or traditional report | Playfair Display / EB Garamond | `Playfair+Display:wght@400;600;700&family=EB+Garamond:ital,wght@0,400;0,500;0,600;1,400` |
| Warm long-form document | Libre Franklin / Libre Baskerville | `Libre+Franklin:wght@400;600;700&family=Libre+Baskerville:ital,wght@0,400;0,700;1,400` |
| Calm or Scandinavian | Familjen Grotesk / Lora | `Familjen+Grotesk:wght@400;500;600;700&family=Lora:ital,wght@0,400;0,500;0,600;0,700;1,400` |
| Editorial, magazine, recipe | Fraunces / Work Sans | `Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,600;0,9..144,700;1,9..144,400&family=Work+Sans:wght@300;400;500;600` |
| Editorial classic, neutral | Source Sans 3 / Source Serif 4 | `Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;0,8..60,700;1,8..60,400&family=Source+Sans+3:ital,wght@0,400;0,600;0,700;1,400` |
| Statement, expressive opener | Sora / Bitter | `Sora:wght@400;500;600;700&family=Bitter:ital,wght@0,400;0,500;0,600;0,700;1,400` |

For one-family pairings, create hierarchy with size and weight instead of an artificial family
change. For code-heavy work, add IBM Plex Mono, JetBrains Mono, or Fira Code.

## Palettes

Override the whole palette block so borders, subtle fills, text, and page tone move together.
Use Slate if neutrality is a genuine content fit, not merely because it is the fallback.

### Slate — neutral

```css
:root {
  --color-accent: #334155;
  --color-accent-light: #f1f5f9;
  --color-text: #0f172a;
  --color-text-secondary: #64748b;
  --color-border: #e2e8f0;
  --color-bg-subtle: #f8fafc;
}
```

### Ocean — business

```css
:root {
  --color-accent: #1e4d6e;
  --color-accent-light: #e8f1f8;
  --color-text: #102a43;
  --color-text-secondary: #486581;
  --color-border: #d6e4f0;
  --color-bg-subtle: #f4f8fb;
}
```

### Teal — clinical

```css
:root {
  --color-accent: #0d7377;
  --color-accent-light: #e6f5f5;
  --color-text: #0a3a3d;
  --color-text-secondary: #4b6e70;
  --color-border: #d2e8e8;
  --color-bg-subtle: #f3faf9;
}
```

### Terracotta — warm and personal

```css
:root {
  --color-accent: #9c4221;
  --color-accent-light: #fef3ec;
  --color-text: #3b1e10;
  --color-text-secondary: #8a6952;
  --color-border: #ead7c8;
  --color-bg: #fdfcf9;
  --color-bg-subtle: #faf3ec;
  --color-warn: #b45309;
  --color-warn-bg: #fef6e7;
  --color-ok: #4d7c0f;
  --color-ok-bg: #f6fae8;
}
```

### Forest — calm and natural

```css
:root {
  --color-accent: #2d6a4f;
  --color-accent-light: #e9f5ef;
  --color-text: #15301f;
  --color-text-secondary: #5a7868;
  --color-border: #cfe2d7;
  --color-bg-subtle: #f3f9f5;
}
```

### Ink — formal

```css
:root {
  --color-accent: #1c1917;
  --color-accent-light: #f5f5f4;
  --color-text: #0c0a09;
  --color-text-secondary: #57534e;
  --color-border: #d6d3d1;
  --color-bg-subtle: #fafaf9;
}
```

### Berry — expressive

```css
:root {
  --color-accent: #7c3aed;
  --color-accent-light: #f3f0ff;
  --color-text: #1e1239;
  --color-text-secondary: #6b5a8d;
  --color-border: #e0d5fa;
  --color-bg-subtle: #f8f5ff;
}
```

### Copper — premium and warm

```css
:root {
  --color-accent: #92400e;
  --color-accent-light: #fef7ed;
  --color-text: #2a1607;
  --color-text-secondary: #8c6b50;
  --color-border: #ecd9c4;
  --color-bg: #fdfbf7;
  --color-bg-subtle: #faf3ea;
  --color-warn: #b45309;
  --color-warn-bg: #fef6e7;
  --color-ok: #65a30d;
  --color-ok-bg: #f4fae3;
}
```

For a visually rich document, a custom multi-color palette may fit better than any preset.
Warm custom palettes should also override the warning and success colors.

## Optional running section header

Use only for a multi-page document whose sections benefit from navigation:

```css
h2 { string-set: section content; }

@page {
  @top-right {
    content: string(section);
    font-family: var(--font-sans);
    font-size: 7.5pt;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--color-text-secondary);
  }
}

@page :first { @top-right { content: none; } }
```

Skip it for short documents, letters, covers, and one-pagers.

## Technical notes

- Google Fonts add network latency and silently fall back when unavailable. Self-host fonts with
  `@font-face` for deterministic offline output, then verify the rendered pages.
- Reuse one `FontConfiguration` for every `HTML` and `CSS` object in a batch.
- `HTML(filename=...)` infers the source file as its relative-URL base. With HTML held in a
  string, pass `HTML(string=html, base_url=source_dir)` so relative images, fonts, and linked
  styles resolve. Keep the base inside the task's trusted asset directory.
- WeasyPrint renders static HTML and CSS, not JavaScript. CSS Grid is generally more reliable
  than Flexbox.
- A4 is the default; override `@page { size: letter; }` when needed.
- Set `lang` on `<html>` for automatic hyphenation. Use `<sub>` and `<sup>` rather than
  Unicode substitutes whose glyph coverage varies by font.
