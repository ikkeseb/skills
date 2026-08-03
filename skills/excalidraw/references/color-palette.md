# Color palette and brand style

`palette.json` is the single source of truth for every default color. The
builder reads it at runtime; this guide owns only semantic usage. Edit the JSON
to rebrand, then run the bundled test so both themes and structural lines are
checked. Do not copy token values into this file or the builder.

## Canvas and themes

Default to the dark theme. Use light when the user requests it or the
destination requires a white page. Each theme owns its canvas, text,
structural-line, and semantic shape tokens in `palette.json`; an explicit
`canvasBackground` overrides only the canvas token.

## Semantic shapes

Colors encode meaning, not decoration. Each purpose has a fill/stroke pair;
always keep the darker stroke and lighter fill relationship where the theme
allows it.

| Token | Use |
|---|---|
| `primary` | Default or neutral shapes |
| `secondary` | Supporting shapes and secondary paths |
| `tertiary` | Background grouping and low emphasis |
| `start` | Entry points and initiators |
| `success` | Completion, output, or result |
| `warning` | Failures, resets, or danger states |
| `decision` | Branch points and conditionals |
| `ai` | Model interactions and AI components |
| `external` | Third-party systems and integrations |
| `data` | Databases, files, and stores |
| `human` | User actions and manual steps |
| `inactive` | Disabled elements; pair with a dashed stroke |

## Text hierarchy

Use the theme's `title`, `subtitle`, and `body` tokens for free-floating text.
Node labels also use `body` unless the scene explicitly supplies `textColor`.
Use evidence colors only for concrete code, data, or command artifacts; use
the syntax tokens inside those blocks when highlighting improves recognition.

## Lines

Bound arrows inherit the source node's stroke by default. Unbound dividers,
trees, timelines, and feedback paths use the active theme's `structural`
token. Use `marker` for marker dots and `divider` for deliberately faint or
dashed separators.
