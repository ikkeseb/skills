"""Render Excalidraw JSON to PNG using Playwright + headless Chromium.

Usage:
    cd <skill-path>/references
    uv run python render_excalidraw.py <path-to-file.excalidraw> [flags]

Flags:
    --output, -o     Output PNG path (default: same name with .png)
    --scale, -s      Device scale factor (default: 2)
    --width, -w      Max viewport width (default: 1920)
    --transparent    Transparent background instead of white
    --validate       Validate JSON structure and bindings only — no render

First-time setup:
    cd <skill-path>/references
    uv sync
    uv run playwright install chromium
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def validate_excalidraw(data: dict) -> list[str]:
    """Validate Excalidraw JSON structure. Returns list of errors (empty = valid)."""
    errors: list[str] = []

    if data.get("type") != "excalidraw":
        errors.append(f"Expected type 'excalidraw', got '{data.get('type')}'")

    if "elements" not in data:
        errors.append("Missing 'elements' array")
    elif not isinstance(data["elements"], list):
        errors.append("'elements' must be an array")
    elif len(data["elements"]) == 0:
        errors.append("'elements' array is empty — nothing to render")

    return errors


def validate_bindings(elements: list[dict]) -> list[str]:
    """Walk elements and check that every cross-reference resolves.

    Catches the common failure mode where an Edit introduces a typo in
    `containerId`, `boundElements[].id`, `startBinding.elementId`, or
    `endBinding.elementId`. Without this, a broken binding presents as a
    generic 30s Playwright timeout. With it, you get the bad ID in milliseconds.
    """
    errors: list[str] = []
    ids: dict[str, int] = {}

    for idx, el in enumerate(elements):
        eid = el.get("id")
        if not eid:
            errors.append(f"Element at index {idx} ({el.get('type', '?')}) is missing 'id'")
            continue
        if eid in ids:
            errors.append(f"Duplicate element id '{eid}' (indexes {ids[eid]} and {idx})")
        ids[eid] = idx

    valid = set(ids)

    def check(ref_id: str | None, where: str) -> None:
        if ref_id and ref_id not in valid:
            errors.append(f"{where} references missing element id '{ref_id}'")

    for el in elements:
        eid = el.get("id", "?")
        etype = el.get("type", "?")

        check(el.get("containerId"), f"Element '{eid}' ({etype}).containerId")

        for i, b in enumerate(el.get("boundElements") or []):
            if isinstance(b, dict):
                check(b.get("id"), f"Element '{eid}' ({etype}).boundElements[{i}].id")

        if etype == "arrow":
            sb = el.get("startBinding")
            if isinstance(sb, dict):
                check(sb.get("elementId"), f"Arrow '{eid}'.startBinding.elementId")
            eb = el.get("endBinding")
            if isinstance(eb, dict):
                check(eb.get("elementId"), f"Arrow '{eid}'.endBinding.elementId")

    return errors


def run_validation(excalidraw_path: Path) -> int:
    """Read, parse, and validate an .excalidraw file. Print result and return exit code."""
    raw = excalidraw_path.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {excalidraw_path}: {e}", file=sys.stderr)
        return 1

    errors = validate_excalidraw(data)
    if not errors:
        elements = [e for e in data.get("elements", []) if not e.get("isDeleted")]
        errors = validate_bindings(elements)

    if errors:
        print(f"FAIL: {excalidraw_path}", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    n = len([e for e in data.get("elements", []) if not e.get("isDeleted")])
    print(f"OK: {excalidraw_path} ({n} elements, all bindings resolve)")
    return 0


def compute_bounding_box(elements: list[dict]) -> tuple[float, float, float, float]:
    """Compute bounding box (min_x, min_y, max_x, max_y) across all elements."""
    min_x = float("inf")
    min_y = float("inf")
    max_x = float("-inf")
    max_y = float("-inf")

    for el in elements:
        if el.get("isDeleted"):
            continue
        x = el.get("x", 0)
        y = el.get("y", 0)
        w = el.get("width", 0)
        h = el.get("height", 0)

        # For arrows/lines, points array defines the shape relative to x,y
        if el.get("type") in ("arrow", "line") and "points" in el:
            for px, py in el["points"]:
                min_x = min(min_x, x + px)
                min_y = min(min_y, y + py)
                max_x = max(max_x, x + px)
                max_y = max(max_y, y + py)
        else:
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x + abs(w))
            max_y = max(max_y, y + abs(h))

    if min_x == float("inf"):
        return (0, 0, 800, 600)

    return (min_x, min_y, max_x, max_y)


def render(
    excalidraw_path: Path,
    output_path: Path | None = None,
    scale: int = 2,
    max_width: int = 1920,
    transparent: bool = False,
) -> Path:
    """Render an .excalidraw file to PNG. Returns the output PNG path."""
    # Import playwright here so validation errors show before import errors
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("ERROR: playwright not installed.", file=sys.stderr)
        print("Run: cd <skill-path>/references && uv sync && uv run playwright install chromium", file=sys.stderr)
        sys.exit(1)

    # Read and validate
    raw = excalidraw_path.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {excalidraw_path}: {e}", file=sys.stderr)
        sys.exit(1)

    errors = validate_excalidraw(data)
    if errors:
        print(f"ERROR: Invalid Excalidraw file:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    # When transparent, signal to the template (and exportToSvg) to skip the
    # background rect. Combined with omit_background on the screenshot, this
    # produces a true alpha PNG.
    if transparent:
        data.setdefault("appState", {})["exportBackground"] = False
        data["appState"]["viewBackgroundColor"] = "transparent"

    # Compute viewport size from element bounding box
    elements = [e for e in data["elements"] if not e.get("isDeleted")]
    min_x, min_y, max_x, max_y = compute_bounding_box(elements)
    padding = 80
    diagram_w = max_x - min_x + padding * 2
    diagram_h = max_y - min_y + padding * 2

    # Cap viewport width, let height be natural
    vp_width = min(int(diagram_w), max_width)
    vp_height = max(int(diagram_h), 600)

    # Output path
    if output_path is None:
        output_path = excalidraw_path.with_suffix(".png")

    # Template path (same directory as this script)
    template_path = Path(__file__).parent / "render_template.html"
    if not template_path.exists():
        print(f"ERROR: Template not found at {template_path}", file=sys.stderr)
        sys.exit(1)

    template_url = template_path.as_uri()

    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(headless=True)
        except Exception as e:
            if "Executable doesn't exist" in str(e) or "browserType.launch" in str(e):
                print("ERROR: Chromium not installed for Playwright.", file=sys.stderr)
                print("Run: cd <skill-path>/references && uv run playwright install chromium", file=sys.stderr)
                sys.exit(1)
            raise

        page = browser.new_page(
            viewport={"width": vp_width, "height": vp_height},
            device_scale_factor=scale,
        )

        # Capture browser-side diagnostics so failures (CDN 404s, JS errors,
        # CSP blocks) surface in stderr instead of presenting as a silent timeout.
        diagnostics: list[str] = []
        page.on("console", lambda msg: diagnostics.append(f"[console.{msg.type}] {msg.text}"))
        page.on("pageerror", lambda exc: diagnostics.append(f"[pageerror] {exc}"))
        page.on("requestfailed", lambda req: diagnostics.append(f"[requestfailed] {req.url} — {req.failure}"))

        def fail(msg: str) -> None:
            print(f"ERROR: {msg}", file=sys.stderr)
            if diagnostics:
                print("Browser diagnostics:", file=sys.stderr)
                for line in diagnostics:
                    print(f"  {line}", file=sys.stderr)
            browser.close()
            sys.exit(1)

        # Load the template
        page.goto(template_url)

        # Wait for the ES module to load (imports from esm.sh)
        try:
            page.wait_for_function("window.__moduleReady === true", timeout=30000)
        except Exception as e:
            fail(f"Template module never became ready (timeout): {e}")

        # Inject the diagram data and render
        json_str = json.dumps(data)
        result = page.evaluate(f"window.renderDiagram({json_str})")

        if not result or not result.get("success"):
            error_msg = result.get("error", "Unknown render error") if result else "renderDiagram returned null"
            fail(f"Render failed: {error_msg}")

        # Wait for render completion signal
        try:
            page.wait_for_function("window.__renderComplete === true", timeout=15000)
        except Exception as e:
            fail(f"Render never completed (timeout): {e}")

        # Screenshot the SVG element. The template expands the SVG's viewBox
        # before rendering so font ascenders/descenders aren't clipped.
        svg_el = page.query_selector("#root svg")
        if svg_el is None:
            fail("No SVG element found after render.")

        svg_el.screenshot(path=str(output_path), omit_background=transparent)
        browser.close()

    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Render Excalidraw JSON to PNG")
    parser.add_argument("input", type=Path, help="Path to .excalidraw JSON file")
    parser.add_argument("--output", "-o", type=Path, default=None, help="Output PNG path (default: same name with .png)")
    parser.add_argument("--scale", "-s", type=int, default=2, help="Device scale factor (default: 2)")
    parser.add_argument("--width", "-w", type=int, default=1920, help="Max viewport width (default: 1920)")
    parser.add_argument("--transparent", action="store_true", help="Transparent background instead of white")
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate JSON structure and bindings only — no render, no Chromium",
    )
    args = parser.parse_args()

    if not args.input.exists():
        print(f"ERROR: File not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    if args.validate:
        sys.exit(run_validation(args.input))

    png_path = render(args.input, args.output, args.scale, args.width, args.transparent)
    print(str(png_path))


if __name__ == "__main__":
    main()
