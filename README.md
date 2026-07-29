# skills

Claude Code skills I use day-to-day, published as a plugin. Seven of them also
work in Codex CLI. Pick what you need, ignore the rest.

## Skills

Every skill here is meant to be reached by an explicit command rather than
firing on its own; nothing in Claude Code enforces that, so the guard is how
the descriptions are written. (In Codex, use the `$` skill picker — see
Install below.)

| Skill | What it does | Invoke |
|---|---|---|
| **[handoff](skills/handoff)** | Compacts the session into a handoff file plus a paste-ready snippet — for switching machines or briefing another agent. | `/handoff` |
| **[pretty-pdf](skills/pretty-pdf)** | PDFs that look designed rather than auto-generated (HTML + CSS via weasyprint). | `/pretty-pdf` |
| **[excalidraw](skills/excalidraw)** | `.excalidraw` diagrams that explain something instead of just labeling boxes. | `/excalidraw` |
| **[drawio](skills/drawio)** | Native `.drawio` XML that opens straight in app.diagrams.net. | `/drawio` |
| **[verify-claims](skills/verify-claims)** | Fact-checks prose against traceable sources and returns a classified table. | `/verify-claims` |
| **[agents-md-convert](skills/agents-md-convert)** | Audits, converts, or repairs repository instruction scopes so `AGENTS.md` is canonical and `CLAUDE.md` stays a one-line import adapter. | `/agents-md-convert` |
| **[context-audit](skills/context-audit)** | Audits a bloated `CLAUDE.md` and proposes a leaner context structure, for you to apply by hand. | `/context-audit` |
| **[full-send](skills/full-send)** | Posture: resources are authorized — fan out subagents freely, then converge. | `/full-send` · `/full-send sustained` |
| **[max-effort](skills/max-effort)** | Posture: high-stakes work gets adversarial review, not a rubber stamp. | `/max-effort` · `/max-effort sustained` |
| **[afk](skills/afk)** | Posture: unattended runs — no clarifying questions, low blast radius, audit trail in the conversation. | `/afk` |

### Claude-only by design

Their substance is Claude Code machinery, so porting them would mistranslate
rather than translate.

| Skill | What it does | Invoke |
|---|---|---|
| **[second-opinion](skills/second-opinion)** | One read-only Codex call on work that already exists, answered as a synthesis rather than a relay. Vendor independence without the delegation ceremony. | `/second-opinion` |
| **[orchestrate](skills/orchestrate)** | The main loop keeps everything critical (design, spec, review, integration) and routes mechanical work to worker models: Claude agents, plus an optional Codex CLI lane. | `/orchestrate` · `/orchestrate sustained` |
| **[suggest-loop](skills/suggest-loop)** | Turns a repo's documented verification gate into ready-to-paste `/loop` prompts with stop conditions baked in. | `/suggest-loop` |

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
skills — the ones carrying an `agents/openai.yaml`: `agents-md-convert`,
`context-audit`, `drawio`, `excalidraw`, `handoff`, `pretty-pdf`,
`verify-claims`. The three added in 0.9.9 ship their Claude bodies as-is —
`drawio` and `excalidraw` degrade gracefully where the sandbox denies network
or exec (no visual render loop), and `context-audit`'s subject stays Claude
Code context whichever harness runs it.

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
helper's `probe` subcommand reports auth plus whether the installed CLI still
advertises every flag the runner passes — the recipe gates on that flag
surface, not on a pinned version.

The plugin install also ships the lane's adapter subagent (exposed as
`ikkeseb-skills:codex-worker`). Symlink installs carry skills only — no
agents — so `orchestrate` dispatches the same helper script through default
agents instead; the lane works either way. (OpenAI's separate `codex`
companion plugin is a different integration and isn't required by anything
here.)

## License

MIT — see [LICENSE](LICENSE).
