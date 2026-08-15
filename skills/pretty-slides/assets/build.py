#!/usr/bin/env python3
"""Inline fonts and images into a deck template -> one self-contained HTML.

Copy this next to your template.html and adjust the CONFIG values.

Tokens in template.html:
  /* __FONTS_CSS__ */   -> replaced with the FONTS file's contents, which must
                           already be @font-face rules with base64 data URIs
                           (this script does not fetch or encode fonts).
                           FONTS = None -> system font stacks apply.
  __IMG_<NAME>__        -> replaced with a base64 data URI per IMAGES entry.

The build fails if a configured image is missing or if any __IMG_*__ token
is left unresolved in the output.
"""
from pathlib import Path
import base64
import re

HERE = Path(__file__).parent

# ---- CONFIG ----
TEMPLATE = HERE / "template.html"   # copy engine-template.html here
FONTS = None                        # or HERE / "fonts.css" (base64 @font-face)
OUT = HERE / "deck.html"            # the deliverable
IMAGES = {
    # "__IMG_HERO__": HERE / "assets" / "hero.png",
}
# ----------------

MIME = {
    ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
    ".gif": "image/gif", ".webp": "image/webp", ".svg": "image/svg+xml",
}

if not TEMPLATE.is_file():
    raise SystemExit(
        "missing template.html; copy engine-template.html as template.html "
        "before running build.py"
    )

html = TEMPLATE.read_text(encoding="utf-8")
if FONTS and FONTS.exists():
    html = html.replace("/* __FONTS_CSS__ */", FONTS.read_text(encoding="utf-8"))
elif FONTS:
    raise SystemExit(f"fonts file not found: {FONTS}")
for token, path in IMAGES.items():
    if not path.is_file():
        raise SystemExit(f"image not found for {token}: {path}")
    mime = MIME.get(path.suffix.lower())
    if not mime:
        raise SystemExit(f"unsupported image type for {token}: {path.suffix}")
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    html = html.replace(token, f"data:{mime};base64,{b64}")
leftover = sorted(set(re.findall(r"__IMG_[A-Z0-9_]+__", html)))
if leftover:
    raise SystemExit(f"unresolved image tokens in template: {', '.join(leftover)}")
OUT.write_text(html, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size / 1_048_576:.1f} MB)")
