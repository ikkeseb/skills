# After Delivery: Opt-In Follow-Ups (Claude Code only)

The skill does **not** auto-render. Get the diagram right by following the methodology —
rendering is a verification tool the user opts into, and Chromium cold-start is slow enough
(~6–10s) that it's rude to spend it without permission.

After saving the `.excalidraw` file, offer both follow-ups in one short prompt, e.g.:

> Diagram saved to `path/to/file.excalidraw`. Want me to render a PNG, open it in Excalidraw, or both?

**Skip both follow-ups in Claude Chat** — the user already has the file via the chat UI.

## First-time setup

Run once per environment before the render command works:

```bash
cd <skill-path>/references && uv sync && uv run playwright install chromium
```

## Render to PNG

If the user wants a PNG (or you've decided a complex diagram needs visual verification):

```bash
cd <skill-path>/references && uv run python render_excalidraw.py <path-to-file.excalidraw>
```

Useful flags:
- `--transparent` — transparent background instead of white (for embedding on dark surfaces)
- `--validate` — fast JSON walk that catches missing element IDs, broken `containerId` /
  `boundElements` / arrow bindings, and duplicate IDs **without** launching Chromium. Run
  this first if you suspect ID typos in cross-section bindings; it turns a 30s Playwright
  timeout into a millisecond error message.

If a render reveals problems, fix the JSON and re-render. One concrete fix per render —
over-correcting wastes the round-trip. If an arrow needs tortured waypoints to dodge a
shape, move the shape (see "Layout fixes beat arrow gymnastics" in SKILL.md).

## Open in Excalidraw

If the user wants to edit the diagram interactively:

```bash
python <skill-path>/references/open_in_excalidraw.py <path-to-file.excalidraw>
```

Pure stdlib (no `uv` needed). Copies the JSON to the system clipboard via the platform-native
tool — `pbcopy` (macOS), `clip` (Windows), `wl-copy`/`xclip`/`xsel` (Linux) — and opens
[excalidraw.com](https://excalidraw.com) in the default browser. The user pastes (Cmd+V /
Ctrl+V) onto the canvas to import the scene.

Then surface the link and the paste hint:

> JSON copied to clipboard. Open: https://excalidraw.com — paste with Cmd+V on the canvas.

**Why paste instead of auto-load?** Excalidraw can't fetch local files via URL (browser
security), and `#json=`-style share links would upload the diagram to Excalidraw's backend.
Clipboard paste keeps it local.
