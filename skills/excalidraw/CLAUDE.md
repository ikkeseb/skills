# CLAUDE.md

This repo is the **source** of the `excalidraw` skill — not a project that consumes it. It gets symlinked into `~/.claude/skills/excalidraw` (or a project's `.claude/skills/`) and loaded when a user asks Claude to draw something.

## Where things live

- [SKILL.md](SKILL.md) — the skill itself: methodology, design rules, the render-validate loop. This is the canonical document; almost every change will land here.
- [references/](references/) — files loaded on demand by Claude (color palette, JSON schema, element templates) and helper scripts (`render_excalidraw.py`, `open_in_excalidraw.py`).
- [examples/](examples/) — diagrams generated end-to-end by the skill, used as visual proof in the README.

## When modifying this skill

Route changes through the `skill-creator` skill if available — it knows the conventions for SKILL.md structure, descriptions, and eval loops. Hand-editing is fine for typos and small clarifications, but treat anything touching the `description` frontmatter or methodology sections as a real skill update, not a casual edit.

## Two environments, one skill

The skill must keep working in both **Claude Code** (full render-validate loop via Playwright + clipboard/browser open) and **Claude Chat** (JSON-only output, no shell). When adding capabilities, gate them clearly on the environment — see the "Environment Detection" section in SKILL.md.

## Path conventions

Scripts and references are addressed as `<skill-path>/references/...` in SKILL.md so the skill works regardless of install location (user-global, project-scoped, or Chat's `/mnt/skills/user/`). Don't hardcode absolute paths.

## Design philosophy

Diagrams should **argue visually**, not just label boxes. The Isomorphism Test and the Education Test in SKILL.md are load-bearing — preserve them. Color tokens live in [`references/color-palette.md`](references/color-palette.md) so the skill can be rebranded without touching methodology.
