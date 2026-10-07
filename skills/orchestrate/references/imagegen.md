# Image-generation relay stages

Authoring guide for Codex-lane stages whose real labor happens in the image
model the worker prompts. `codex-exec.md` owns dispatch mechanics; the pin
is `gpt-6.1-sol` @ `medium`, an exception to the model map's effort rules
because the image model does the substantive work; it never covers a stage
doing its own research or implementation. Gemini-lane images, on a small
quota and only when the user sends image work there: `gemini-exec.md`.
Which image model suits which job is unmeasured.

The relay worker is an LLM that forwards to the image model through its
prompting skill — triggered explicitly with `$imagegen` or by plain
"generate an image/photo/drawing" phrasing. Given
the actual context of what is being made (purpose, content, style direction —
anything from "be creative" to a named artistic style), sol @ medium develops
the final image prompt itself, so send it context and intent, not a pre-baked
prompt.

Generation works under `read-only`: the image lands outside the workspace in
`$CODEX_HOME/generated_images/<uuid>/*.png`, so have the worker report the
absolute path in its result and let the main loop collect the file.

For edits to an existing raster, send the reference image
plus a direct instruction — "upscale, keep everything visually identical,
change text to X/Y/Z" — and **explicitly forbid manual pixel editing**;
hedged prompts ("prefer native generation but reject it if…") have steered
workers into that fallback.
