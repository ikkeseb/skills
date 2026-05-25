# Setup

`pip install weasyprint`. Platform notes:

- **Windows:** weasyprint also needs the GTK3 runtime (Pango/Cairo/GLib DLLs). Install with
  `winget install tschoonj.GTKForWindows` (one-time, ~50MB, UAC prompt) or download from
  github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases.
  Without GTK3, `import weasyprint` fails at load time with a `cannot load library 'libgobject-2.0-0'` error.
- **macOS:** `brew install pango` first, then `pip install weasyprint`.
- **Linux:** `pip install weasyprint` usually suffices (Pango/Cairo come from system libs;
  on Debian/Ubuntu: `apt install libpango-1.0-0 libpangoft2-1.0-0`).

Verify: `python -c "import weasyprint; print(weasyprint.__version__)"`.
