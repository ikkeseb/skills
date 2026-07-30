# Reaching an official Excalidraw surface

Read this when `check` has exited `2` and no official Excalidraw surface is
already open. It covers how to reach one, and what the resulting pixels do and
do not prove.

## Before opening excalidraw.com

Importing a diagram into the web app hands the file contents to JavaScript
served by `https://excalidraw.com`. Ask the user first, per invocation, and say
exactly that — do not classify sensitivity on their behalf, and do not carry an
earlier approval into a later diagram. Diagrams frequently describe internal
architecture.

## Driving a browser surface

Any Playwright-based browser automation available in the session can open the
web app. Nothing here is bundled: if no such surface exists, skip to manual
import. Never install a browser or an npm package to complete this step.

Run headed when the user is present, so they can take over the canvas and edit
directly; headless is for unattended runs. What the recipe needs:

1. Open `https://excalidraw.com` and wait for a `canvas` element.
2. Import by dispatching `dragenter`, `dragover`, and `drop` on the
   `.excalidraw` container with a `DataTransfer` carrying the file contents as
   a `File`. This is the app's own open path.
3. **Confirm the scene actually loaded** before treating pixels as evidence —
   read the element count back from `localStorage.excalidraw` and compare it to
   the built file. A canvas that rendered is not a scene that imported.
4. Zoom to fit (`Shift+1`) and screenshot.

Two failure modes worth knowing in advance:

- **Writing the scene into `localStorage` is not a supported import path.** The
  app overwrites the injected value on reload and you get an empty canvas that
  still screenshots successfully.
- Playwright may demand a browser build the machine does not have. Pin an
  installed executable explicitly rather than letting it resolve a revision.

The screenshot includes the app's own toolbar and zoom widget. That is fine for
geometry review; it is not a clean export.

## Manual import

Always available: the user opens `https://excalidraw.com` or any official
Excalidraw surface, uses **File → Open** or drags the file onto a fresh canvas,
zooms to fit, and shares the screenshot back.

## When neither works

Report `structurally valid, layout previewed, native visually unverified`. That
is an honest end state, not a failure — an automated screenshot of an
unconfirmed import would be worse than no screenshot at all.
