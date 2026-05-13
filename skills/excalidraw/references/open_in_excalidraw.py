"""Copy an Excalidraw JSON file to the system clipboard and open excalidraw.com.

Usage:
    python open_in_excalidraw.py <path-to-file.excalidraw>

The user pastes (Cmd+V / Ctrl+V) onto the Excalidraw canvas to import the scene.

Cross-platform: macOS (pbcopy), Linux (wl-copy / xclip / xsel), Windows (clip).
Pure stdlib — no dependencies, no uv required.
"""

from __future__ import annotations

import argparse
import platform
import shutil
import subprocess
import sys
import webbrowser
from pathlib import Path

EXCALIDRAW_URL = "https://excalidraw.com"


def copy_to_clipboard(data: bytes) -> tuple[bool, str]:
    """Copy bytes to the system clipboard. Returns (ok, tool_used_or_error)."""
    system = platform.system()

    if system == "Darwin":
        subprocess.run(["pbcopy"], input=data, check=True)
        return True, "pbcopy"

    if system == "Windows":
        # `clip` reads from stdin; expects text. Decode UTF-8 (Excalidraw JSON is text).
        subprocess.run(["clip"], input=data, check=True)
        return True, "clip"

    if system == "Linux":
        for cmd in (
            ["wl-copy"],
            ["xclip", "-selection", "clipboard"],
            ["xsel", "--clipboard", "--input"],
        ):
            if shutil.which(cmd[0]):
                subprocess.run(cmd, input=data, check=True)
                return True, cmd[0]
        return False, "no clipboard tool found (install wl-clipboard, xclip, or xsel)"

    return False, f"unsupported platform: {system}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Copy .excalidraw JSON to clipboard and open excalidraw.com.")
    parser.add_argument("file", type=Path, help="Path to the .excalidraw file")
    parser.add_argument("--no-open", action="store_true", help="Copy to clipboard but do not open the browser")
    args = parser.parse_args()

    path: Path = args.file
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        return 1

    try:
        data = path.read_bytes()
    except OSError as exc:
        print(f"Could not read {path}: {exc}", file=sys.stderr)
        return 1

    ok, info = copy_to_clipboard(data)
    if not ok:
        print(f"Clipboard copy failed: {info}", file=sys.stderr)
        return 1

    paste_key = "Cmd+V" if platform.system() == "Darwin" else "Ctrl+V"
    print(f"Copied {path.name} to clipboard via {info}.")

    if not args.no_open:
        webbrowser.open(EXCALIDRAW_URL)
        print(f"Opened {EXCALIDRAW_URL} — paste the diagram with {paste_key} on the canvas.")
    else:
        print(f"Open {EXCALIDRAW_URL} and paste with {paste_key} on the canvas.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
