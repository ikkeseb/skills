# skills

Claude Code skills I use day-to-day, published as a plugin. Four of them also
work in Codex CLI. Pick what you need, ignore the rest.

![Vault note half-life diagram](skills/excalidraw/examples/vault-note-half-life.png)

> Drawn end-to-end by the [`excalidraw`](skills/excalidraw) skill.

## Skills

- **[handoff](skills/handoff)** — compacts the session into a handoff file plus a paste-ready snippet, for switching machines or briefing another agent.
- **[pretty-pdf](skills/pretty-pdf)** — PDFs that look designed rather than auto-generated (HTML+CSS via weasyprint).
- **[excalidraw](skills/excalidraw)** — `.excalidraw` diagrams that explain something, not just label boxes.
- **[drawio](skills/drawio)** — native `.drawio` XML that opens straight in app.diagrams.net.
- **[verify-claims](skills/verify-claims)** — fact-checks prose against traceable sources and returns a classified table.
- **[agents-md-convert](skills/agents-md-convert)** — converts a repo to the AGENTS.md-canonical convention (`CLAUDE.md` becomes a one-line import) and verifies it in each installed harness.
- **[full-send](skills/full-send)** — posture: resource use is authorized, fan out subagents freely, then synthesize.
- **[max-effort](skills/max-effort)** — posture: high-stakes work gets adversarial review instead of a rubber stamp.
- **[afk](skills/afk)** — posture: unattended runs — no clarifying questions, low blast radius, audit trail in the conversation.

Three more are Claude-only by design — their substance is Claude Code
machinery, so porting them would mistranslate rather than translate:

- **[orchestrate](skills/orchestrate)** — the main loop keeps everything critical (design, spec, review, integration) and routes mechanical work to worker models: Claude agents, plus an optional Codex CLI lane.
- **[suggest-loop](skills/suggest-loop)** — turns a repo's documented verification gate into ready-to-paste `/loop` prompts with stop conditions baked in.
- **[context-audit](skills/context-audit)** — audits a bloated `CLAUDE.md` and proposes a leaner context structure, for you to apply by hand.

Each skill folder contains its `SKILL.md`; a few add a README for
install-specific notes (e.g. `excalidraw`'s optional PNG renderer).

## Install

### Claude Code

Add the repo as a marketplace, then install the plugin (ships every skill above):

```bash
/plugin marketplace add ikkeseb/skills
/plugin install ikkeseb-skills@ikkeseb
```

### Codex CLI

The same repo installs as a Codex plugin. It exposes only the Codex-supported
skills — the ones carrying an `agents/openai.yaml`, per
`.agents/adr/0001-agent-agnostic-repo.md`: `agents-md-convert`, `handoff`,
`pretty-pdf`, `verify-claims`.

```bash
codex plugin marketplace add ikkeseb/skills
codex plugin add ikkeseb-skills@ikkeseb
```

Skills surface namespaced (`ikkeseb-skills:<name>`); invoke them through the
TUI's `$` skill picker. Newly installed or upgraded plugins load in the
*next* Codex session. To upgrade later:

```bash
codex plugin marketplace upgrade ikkeseb
codex plugin list   # verify the installed version
```

If you previously symlinked skills from this repo into `~/.agents/skills/`,
remove those symlinks before installing — otherwise the same skills load
twice. Route verified with codex-cli 0.144.5.

### orchestrate's Codex lane

The `orchestrate` skill's Codex worker lane needs the
[Codex CLI](https://github.com/openai/codex) installed and logged in
(`codex login`). Without it the skill runs Claude-only and says so; the
helper's `probe` subcommand reports auth and version drift against the
pinned, verified codex-cli series.

The plugin install also ships the lane's adapter subagent (exposed as
`ikkeseb-skills:codex-worker`). Symlink installs carry skills only — no
agents — so `orchestrate` dispatches the same helper script through default
agents instead; the lane works either way. (OpenAI's separate `codex`
companion plugin is a different integration and isn't required by anything
here.)

## License

MIT — see [LICENSE](LICENSE).
