# Excalidraw Diagram Skill

Generate `.excalidraw` JSON files that argue visually — not just boxes-and-arrows. Works in Claude Code and Claude Chat.

Based on [coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill), adapted for dual-environment use with a refined color palette and expanded semantic coverage.

![OAuth 2.0 authorization code flow](examples/oauth-flow.png)

> Generated end-to-end by the skill itself. Source: [`examples/oauth-flow.excalidraw`](examples/oauth-flow.excalidraw)

## Install

```bash
git clone https://github.com/ikkeseb/excalidraw-skill ~/excalidraw-skill
ln -s ~/excalidraw-skill ~/.claude/skills/excalidraw
```

For opt-in PNG rendering (Claude Code only — Claude offers it after delivery):

```bash
brew install uv  # or: curl -LsSf https://astral.sh/uv/install.sh | sh
cd ~/.claude/skills/excalidraw/references
uv sync && uv run playwright install chromium
```

## Use

Ask Claude to diagram something:

> "Create an Excalidraw diagram of an OAuth 2.0 authorization code flow"

> "Diagram our microservices with a message queue between them"

After delivery, Claude offers to open the diagram in Excalidraw — it copies the JSON to your clipboard and opens [excalidraw.com](https://excalidraw.com) so you can paste it onto the canvas. No upload, no third party.

Methodology and design rules live in [SKILL.md](SKILL.md). Color tokens in [`references/color-palette.md`](references/color-palette.md) — edit to rebrand.

---

## Other install paths

### Windows

```
mklink /D "%USERPROFILE%\.claude\skills\excalidraw" "%CD%"
```

Needs Developer Mode enabled or an elevated terminal. For uv: `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`. The `references/` setup is identical — just replace the path with `%USERPROFILE%\.claude\skills\excalidraw\references`.

### Project-scoped (overrides global)

Symlink to `<project>/.claude/skills/excalidraw` instead of the user-global path. Project-level skills win when names collide.

### Claude Chat (claude.ai)

Upload the skill via the Skills UI, or distribute it as a plugin. The runtime path (`/mnt/skills/user/excalidraw/`) is managed for you. No render pipeline runs in Chat — the skill produces `.excalidraw` JSON, the user opens it in [excalidraw.com](https://excalidraw.com).

### No symlink?

Copy the folder to the install path instead. Trade-off: `git pull` won't auto-update the installed skill.
