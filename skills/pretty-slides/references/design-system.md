# Design system — skinning the deck

Read this at workflow step 3. The engine reads every color and the core
durations from the token block at the top of the template (a few bespoke
timings — spring, timeline, count-up — are fixed in place; see
`references/motion.md`); a skin never touches anything below the block.

## The decision ladder

Work down; stop at the first rung that fits. State the chosen rung to the
user — the default is a deliberate choice, not a silent fallback.

1. **Keep the default.** The shipped skin (near-black warm surfaces,
   off-white type, one muted accent, one warm-red identity mark) is a
   proven direction that works with zero design effort. Right when the
   project has no visual identity worth honoring, or the user just wants a
   good deck now.
2. **Swap tokens to match the project.** If the session's context shows an
   obvious visual identity — a brand color in the repo, an approved
   artifact, a logo, an existing styled document — pull 2–4 values from it:
   `--identity` (the brand mark color), `--accent` (a calmer companion),
   optionally the font stacks and surface temperature (warm/cool blacks —
   or a light skin if the identity demands one). Minutes, not a design
   project. Two things sit outside the token block and follow `--identity`
   by hand: the favicon's fill in the `<head>` data URI, and — if the deck
   has code panels — check that `--code-string` stays distinguishable from
   the new identity color.
3. **Adopt a proven custom direction.** Only when a full design language
   already exists (a styled site, a design system, an approved deck):
   extract its tokens into the block wholesale. Never *require* producing
   such a language first — this rung is for harvesting one that exists.

## Token contract

Color roles: `--bg`, `--surface`, `--media-bg` (behind images/diagrams);
`--ink`, `--ink2`, `--ink3` (primary → muted); `--line`, `--line-strong`,
`--hair`, `--rail-track` (rules, from panel borders down to background
grid); `--shadow`; `--accent` / `--accent-strong` (continuity: rail,
sources, timeline); `--identity` (the scalpel); `--code-string`. Fonts:
`--sans`, `--mono`. Motion tokens live in the same block but are
choreography, not skin — a re-skin normally leaves them alone
(`references/motion.md`).

## Invariants that survive any skin

- **One accent carries continuity; one identity color is a scalpel.** Deck
  furniture (the kicker's brand square, the rail tick) is exempt; beyond it,
  at most one identity-colored content mark per slide, never for warnings
  or decoration. Only that content mark carries `.idmark` (and its spring).
- **Ornament budget:** hairlines, dotted rules, one soft shadow per panel.
  Nothing else. The budget extends to motion.
- **Type does the hierarchy:** display sizes with tight tracking for
  claims, letter-spaced mono caps for microlabels. No decorative fonts.
- **Contrast is not negotiable:** body text stays readable at projector
  distance whatever the palette.

## Fonts

The default is system stacks (`system-ui` / `ui-monospace`) — zero bytes,
works offline everywhere. For identical typography across machines, put
`@font-face` rules with base64-embedded WOFF2 into a deck-local `fonts.css`
and point `build.py`'s `FONTS` at it. Embed only fonts whose license
permits it (OFL faces like Archivo or IBM Plex do); the build inserts the
file's contents verbatim — it does not fetch or encode fonts itself.
