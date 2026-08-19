---
name: pretty-pdf
description: "Create designed PDFs with WeasyPrint (HTML+CSS to PDF): reports, letters, invoices, CVs, or re-typesetting a docx. Not for reading, merging, splitting, or form-filling existing PDFs, fillable forms, or quick throwaway output."
disable-model-invocation: true
---

# Pretty PDF

Build a semantic HTML document, render it with the bundled CSS asset, and verify the final PDF
page by page. Preserve source meaning and factual content; design must improve reading, not edit
the substance silently.

## Render contract

Resolve this skill's directory and pass `assets/base.css` to WeasyPrint without loading or
copying its full contents into model context. Put only document-specific font, palette, spacing,
and component overrides in `override_css`.

```python
from pathlib import Path
from weasyprint import CSS, HTML
from weasyprint.text.fonts import FontConfiguration

skill_dir = Path("/absolute/path/to/pretty-pdf")
source_dir = Path("/absolute/path/to/document-assets")
output_path = Path("/absolute/path/to/output.pdf")
html_content = "..."  # the semantic HTML document
override_css = "..."  # document-specific overrides, or "" for none

font_config = FontConfiguration()
stylesheets = [
    CSS(filename=skill_dir / "assets" / "base.css", font_config=font_config),
]
if override_css:
    stylesheets.append(CSS(
        string=override_css,
        # CSS() requires a string base_url; it does not coerce Path like HTML() does.
        base_url=str(source_dir),
        font_config=font_config,
    ))

document = HTML(
    string=html_content,
    base_url=str(source_dir),
).render(
    stylesheets=stylesheets,
    font_config=font_config,
)
document.write_pdf(output_path)
page_count = len(document.pages)
```

If rendering an HTML file instead, `HTML(filename=html_path)` infers the file's directory as the
relative-asset base. With an in-memory string, always pass an absolute `base_url`. Keep relative
images and fonts inside the task's trusted asset directory; use absolute paths or data URIs only
when no useful common base exists.

If WeasyPrint is unavailable, read `references/setup.md`. Reuse one `FontConfiguration` for
all HTML and CSS objects in a batch.

## Workflow

1. Read the source completely. Identify document type, audience, reader relationship, tone,
   density, and reading context before choosing a visual treatment.
2. Read `references/base-styles.md` and choose the five axes below from the content.
3. Read exactly one matching template:
   - report or business document: `references/templates/report.md`
   - formal or personal letter: `references/templates/letter.md`
   - medical or clinical summary: `references/templates/medical.md`
   - invoice or financial summary: `references/templates/invoice.md`
   - CV or resume: `references/templates/cv.md`
   - one-page brief: `references/templates/one-pager.md`
   - journal, travel log, or personal document: `references/templates/personal.md`
   - technical specification: `references/templates/technical.md`

   Skip templates and build from scratch when none fits. Do not read all templates to browse.
4. Read only the applicable section of `references/gotchas.md`:
   - §1 for long code blocks that may span pages;
   - §2 for docx sources containing images or crops;
   - §3 for a literary drop cap or a `float_layout` render failure.
5. Write semantic HTML and set `<html lang="...">` for hyphenation. Use the base CSS asset plus
   a small override; do not inline the entire base stylesheet.
6. Render to the user's requested absolute output path. Treat missing fonts, images, or fetch
   warnings as defects, not harmless log noise.
7. Create a temporary preview directory and render every PDF page to an image. Prefer an available
   PDF renderer; with Poppler:
   `pdftoppm -png -r 144 "<absolute-output.pdf>" "<preview-dir>/page"`. Confirm the image count
   matches `page_count` from the final WeasyPrint render.
8. Open and inspect every final page image with the harness's image-capable reader. Check:
   - clipped, overlapping, or missing content;
   - awkward page breaks, stranded headings, sparse final pages, and broken tables;
   - inconsistent margins, hierarchy, alignment, colors, and image treatment;
   - unreadably small text, code, captions, or footers;
   - font fallback, replacement glyphs, and incorrect crops.
9. Correct the HTML or override CSS, rerender the PDF and all page images, then inspect every page
   again. Repeat until the final render passes.
10. Deliver the PDF and state what was verified. If PDF-to-image rendering or image inspection was
    unavailable, say **generated but not visually verified**, explain the missing capability, and
    do not describe the result as polished or verified.

The workflow is done when the source is preserved, the final PDF exists at the intended absolute
path, every final page has been visually inspected, and no known layout defect remains.

## Design selection

Typography carries the design; whitespace creates hierarchy; decoration stays restrained. Use one
dominant accent and make every choice serve the document.

Guard against convergence: do not reach for Inter Tight + Slate because they are already present.
Choose each axis from the source. If fewer than three axes move off their fallback, check whether
that is genuine fit or reflex; similar content may legitimately produce a similar design.

| Axis | Fallback | Choose by content |
|---|---|---|
| Font pairing | Inter Tight | Literary → Cormorant or EB Garamond; clinical → DM Sans; editorial → Fraunces + Work Sans; technical → Space Grotesk + IBM Plex |
| Palette | Slate | Choose a complete palette block from the design reference or build a coherent custom one |
| Header | `.header-typeset` | `.header-minimal`, `.header-side-rule`, `.header-centered`, `.header-large-numeral`, or the loud `.header-bar` |
| Type scale | Editorial | `body class="scale-compact"` or `body class="scale-generous"` |
| Edge weight | Standard | `body class="edges-hairline"` or `body class="edges-chunky"` |

Use `.page-break` deliberately and `.no-break` for components that should stay together, then
let visual inspection decide whether those constraints improve the actual pagination.
