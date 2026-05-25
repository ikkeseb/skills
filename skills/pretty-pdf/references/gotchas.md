# Gotchas & Edge Cases

Empirical problems that have bitten real PDFs, and the fixes.

## 1. Multi-page code blocks leak footer text into copy/paste

### The problem

When a `<pre>` block spans multiple pages, PDF viewers (Acrobat, Preview, Chrome, Edge) follow
*reading order* when the user drags to select text. Between page breaks, the page's footer and
header boxes sit in the reading order. Result: dragging across a page break to copy the code
also picks up the footer text — the user ends up with page numbers, document titles, or author
names interleaved into their copied code. Practical blocker for any reference doc where people
need to copy code out.

### Fix: suppress footer on code pages via a named `@page`

CSS named pages let you scope `@page` rules to specific elements. Tag the `<pre>` as belonging
to a `code-page` named page, and strip the margin boxes on that named page:

```css
@page code-page {
  margin: 20mm 22mm 22mm 22mm;
  @bottom-left   { content: none; }
  @bottom-right  { content: none; }
  @top-left      { content: none; }
  @top-right     { content: none; }
}

pre.code-block {
  page: code-page;
  page-break-inside: auto;
}
```

```html
<pre class="code-block"><code>... long code listing ...</code></pre>
```

Any page that contains this `<pre>` renders under `code-page` rules → no footer → selecting
across page breaks no longer picks up footer text. Works in weasyprint 60+.

**Caveat:** if only part of the pre spans page N, the whole of page N uses the code-page rules.
Any other content that lands on that page also loses its footer. In practice long code blocks
own their pages end-to-end, so this is rarely visible — but worth knowing.

### Before reaching for named pages: try to fit on one page

A multi-page code block is always worse UX than a single-page one. Before applying the named
page trick, check if shrinking gets you onto a single page:

- Reduce code font from 9–10pt to **7–8pt** (still readable in print)
- Reduce `line-height` from 1.55 to **1.40–1.45**
- Tighten padding: `padding: var(--space-xs) var(--space-sm)`
- Remove the rounded border if present (small wins)

This buys roughly 40% more lines per page. Good enough for scripts up to ~150 lines of C#/Java
or ~200 lines of Python.

### Do NOT split into a sidecar file as a reflex

Shipping code as a separate `.cs`/`.py`/`.sql` file next to the PDF fragments the deliverable
and makes the PDF feel incomplete. Only do this if the code is genuinely too long to fit even
at 6pt (rare — usually >300 lines) and the user explicitly prefers it.

---

## 2. Docx images with crops: the crop lives in `document.xml`, not the image file

### The problem

When a docx is the source of content being rebuilt as a pretty PDF, and the author cropped
images inside Word, the raw PNG/JPEG in `word/media/` is the **uncropped source**. Word stores
the crop as percentages in an `a:srcRect` element on `<pic:blipFill>` inside `word/document.xml`.
Extracting the media file alone loses the crop entirely. The PDF ends up shipping full
uncropped images — usually with obvious extra whitespace, screenshot chrome, or off-subject
edges the author deliberately trimmed.

Easy to miss because the image file itself looks fine; you only notice once the rendered PDF
is next to the original docx.

### Detection

Before extracting, grep `word/document.xml` (after unzipping the docx):

```bash
unzip -p doc.docx word/document.xml | grep -c 'a:srcRect'
```

A non-zero count means at least one image has a crop and you must handle it properly.

### Fix: parse srcRect and apply the crop with PIL before embedding

```python
import zipfile
import xml.etree.ElementTree as ET
from PIL import Image
import io, os

NS = {
    'w':   'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'a':   'http://schemas.openxmlformats.org/drawingml/2006/main',
    'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
    'r':   'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
}

def extract_images_with_crops(docx_path, out_dir):
    """Extract all images from a docx, honoring Word's srcRect crops.
    Returns a list of output paths in document order."""
    os.makedirs(out_dir, exist_ok=True)
    results = []

    with zipfile.ZipFile(docx_path) as z:
        # rId -> media path
        rels = ET.fromstring(z.read('word/_rels/document.xml.rels'))
        rid_to_path = {
            rel.get('Id'): 'word/' + rel.get('Target')
            for rel in rels
            if rel.get('Target', '').startswith('media/')
        }

        doc = ET.fromstring(z.read('word/document.xml'))
        for idx, blip_fill in enumerate(doc.iter(f'{{{NS["pic"]}}}blipFill')):
            blip = blip_fill.find('a:blip', NS)
            if blip is None:
                continue
            rid = blip.get(f'{{{NS["r"]}}}embed')
            if rid not in rid_to_path:
                continue

            # Load the raw image
            img = Image.open(io.BytesIO(z.read(rid_to_path[rid]))).convert('RGBA')

            # Apply crop if present — values are percentages × 1000.
            # e.g. l="12500" means "crop 12.5% off the left edge".
            # Right and bottom are *insets from the edge*, not absolute coords.
            src = blip_fill.find('a:srcRect', NS)
            if src is not None:
                l = int(src.get('l', 0)) / 100000.0
                t = int(src.get('t', 0)) / 100000.0
                r = int(src.get('r', 0)) / 100000.0
                b = int(src.get('b', 0)) / 100000.0
                w, h = img.size
                img = img.crop((
                    int(w * l),
                    int(h * t),
                    int(w * (1 - r)),
                    int(h * (1 - b)),
                ))

            out_path = os.path.join(out_dir, f'image_{idx}.png')
            img.save(out_path)
            results.append(out_path)

    return results
```

Key details that are easy to get wrong:

- `srcRect` values are percentages × 1000. `l="12500"` → 12.5%, not 12500 pixels.
- All four sides (`l`, `t`, `r`, `b`) are optional and default to 0.
- `r` and `b` are **insets from that edge**, not absolute coordinates. Convert via
  `(1 - r) * width` and `(1 - b) * height`.
- Apply the crop **before** embedding the image in HTML (data URI or file path). After is
  too late — the PDF has already captured the uncropped source.

### When to run this

Any docx → pretty-PDF conversion where the source contains images. If `a:srcRect` isn't
present the script is a no-op on that image, so it's cheap to run unconditionally. When
skipping this, note it in a comment — the failure mode is silent and the user may not
notice until side-by-side comparison.
