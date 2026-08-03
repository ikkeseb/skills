# WeasyPrint Setup

Current WeasyPrint requires Python 3.10+ and Pango 1.44+. Prefer an isolated virtual environment.
Verify the installed renderer with:

```shell
python -m weasyprint --info
```

## Windows

The official standalone executable is the easiest choice when the CLI is sufficient. For the
Python API used by this skill:

1. Install Python 3.10 or newer.
2. Install MSYS2 with default options.
3. In the MSYS2 shell, run:
   `pacman -S mingw-w64-x86_64-pango`
4. In Command Prompt, create a virtual environment and install WeasyPrint:

```bat
python -m venv venv
venv\Scripts\activate.bat
python -m pip install weasyprint
python -m weasyprint --info
```

If WeasyPrint cannot find a Pango DLL, point it at the verified DLL directory:

```bat
set WEASYPRINT_DLL_DIRECTORIES=C:\msys64\mingw64\bin
```

Do not restore the retired GTK-for-Windows installer as the primary path; current WeasyPrint
documentation recommends MSYS2 for Python-library use.

## macOS

The current documented default is:

```shell
brew install weasyprint
```

If using a separate Python environment, ensure its WeasyPrint process can find Homebrew's Pango
libraries, then run `python -m weasyprint --info`.

## Linux

Prefer the distribution package when current enough, for example `apt install weasyprint`.
For a virtual environment on current Debian or Ubuntu, install Python plus the Pango and HarfBuzz
runtime packages documented for that distribution before `python -m pip install weasyprint`.

## Visual QA dependency

The workflow also needs a PDF-to-image renderer. Use any reliable renderer available in the
harness; Poppler's `pdftoppm` is the reference command. If no renderer or image inspection
capability is available, report the output as generated but not visually verified.

Source of truth: https://doc.courtbouillon.org/weasyprint/stable/first_steps.html

WeasyPrint can fetch network resources and read local files referenced by HTML or CSS. Keep
`base_url` inside the trusted task directory and do not render untrusted HTML without an
appropriate sandbox.
