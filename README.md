# skills

Agent skills for day-to-day work, published as one plugin.
Claude Code ships the full set; Codex exposes the nine skills marked for both
harnesses.

Browse all 17 skills on [skills.sh](https://skills.sh/ikkeseb/skills).

## Skills

Invoke skills explicitly: `/name` in Claude Code, the `$` picker in Codex.
No SKILL.md carries `disable-model-invocation`: on current Claude Code that
flag hides the skill from the model and breaks the typed slash command too.
For a symlink or personal install, keep the model from triggering a skill on
its own with `skillOverrides: { "<name>": "name-only" }` in your Claude Code
settings; `pretty-html` is the one skill meant to be model-invoked. For a
plugin install those overrides do not apply, so the model may route to any
skill whose description fits; explicit-only enforcement there is unverified.
Codex-supported skills that should stay explicit set
`allow_implicit_invocation: false` there.

### Claude Code and Codex

| Skill | What it does | Claude Code |
|---|---|---|
| **[handoff](skills/handoff)** | Compacts the session into a paste-ready handoff snippet in the reply, for switching machines or briefing another agent. Writes no file. | `/handoff` |
| **[pretty-pdf](skills/pretty-pdf)** | PDFs that look designed rather than auto-generated (HTML + CSS via weasyprint). | `/pretty-pdf` |
| **[pretty-html](skills/pretty-html)** | Polished, self-contained HTML deliverables: single file, dual theme with a toggle, print-friendly. | `/pretty-html` |
| **[history-audit](skills/history-audit)** | Mines the machine's agent-session history for the most common failure modes per model × harness, and proposes instruction lines one by one, each citing the run that earned it. | `/history-audit` |
| **[excalidraw](skills/excalidraw)** | `.excalidraw` diagrams that explain something instead of just labeling boxes. | `/excalidraw` |
| **[drawio](skills/drawio)** | Native `.drawio` XML that opens straight in app.diagrams.net. | `/drawio` |
| **[verify-claims](skills/verify-claims)** | Fact-checks prose against traceable sources: a classified table plus a retract list of unsupported or contradicted claims. | `/verify-claims` |
| **[agents-md-convert](skills/agents-md-convert)** | Audits, converts, or repairs repository instruction scopes so `AGENTS.md` is canonical and `CLAUDE.md` stays a one-line import adapter. | `/agents-md-convert` |
| **[context-audit](skills/context-audit)** | Audits instruction reach and proposes a leaner context structure without stranding mandatory rules. | `/context-audit` |

In Codex, invoke the same nine skills through the `$` picker.

### Claude Code only

These are intentionally omitted from the Codex manifest; their contracts rely
on Claude Code session, agent, or loop behavior, or on tooling (browser
automation, image inspection) not yet verified under Codex.

| Skill | What it does | Invoke |
|---|---|---|
| **[full-send](skills/full-send)** | Posture: resources are authorized. Fan out subagents freely, then converge. | `/full-send` · `/full-send sustained` |
| **[max-effort](skills/max-effort)** | Posture: high-stakes work gets adversarial review, not a rubber stamp. | `/max-effort` · `/max-effort sustained` |
| **[afk](skills/afk)** | Posture: unattended runs with a bounded blast radius and an audit trail in the conversation. | `/afk` |
| **[second-opinion](skills/second-opinion)** | One read-only Codex call on work that already exists, answered as a synthesis rather than a relay. Vendor independence without the delegation ceremony. | `/second-opinion` |
| **[orchestrate](skills/orchestrate)** | The main loop keeps everything critical (design, spec, review, integration) and routes mechanical work to worker models: Claude agents, plus an optional Codex CLI lane. | `/orchestrate` · `/orchestrate sustained` |
| **[suggest-loop](skills/suggest-loop)** | Turns a repo's documented verification gate into ready-to-paste `/loop` prompts with stop conditions baked in. | `/suggest-loop` |
| **[pretty-slides](skills/pretty-slides)** | Presentations as one self-contained HTML file: bundled slide engine with keyboard-only navigation and pattern-bound motion, plus a build step that inlines assets. | `/pretty-slides` |
| **[prettier-html](skills/prettier-html)** | Art-directed single-file HTML pages with editorial ambition: a fresh visual concept per invocation, designed by the session agent against the skill's quality floor. | `/prettier-html` |

Each skill folder contains its `SKILL.md`; Excalidraw also carries setup notes
for its render-and-inspect pipeline.

## Install

### Claude Code

Add the repo as a marketplace, then install the plugin (ships every skill above):

```bash
/plugin marketplace add ikkeseb/skills
/plugin install ikkeseb-skills@ikkeseb
```

### Codex CLI

The same repo installs as a Codex plugin. It exposes only the Codex-supported
skills, the ones carrying an `agents/openai.yaml`: `agents-md-convert`,
`context-audit`, `drawio`, `excalidraw`, `handoff`, `history-audit`,
`pretty-html`, `pretty-pdf`, `verify-claims`. `drawio` degrades gracefully where the sandbox denies network
or exec. `excalidraw` uses the same dependency-free builder, validator, and
layout diagnostic in both harnesses, then requires an official Excalidraw
surface for native visual approval; without one it reports the artifact as
visually unverified. `context-audit` audits the target's effective instruction
reach across Claude Code and Codex, whichever harness runs it.

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
remove those symlinks before installing, otherwise the same skills load
twice.

### orchestrate's Codex lane

The `orchestrate` skill's optional Codex worker lane needs the
[Codex CLI](https://github.com/openai/codex), `jq`, and Bash installed, with
Codex logged in (`codex login`). Without that lane, orchestration continues
through Claude Code workers and says so; the
helper's `probe` subcommand reports auth plus whether the installed CLI still
advertises every flag the runner passes. The recipe gates on that flag
surface, not on a pinned version.

The plugin install also ships the lane's adapter subagent (exposed as
`ikkeseb-skills:codex-worker`). Symlink installs carry skills only, no
agents, so `orchestrate` dispatches the same helper script through default
agents instead; the lane works either way. (OpenAI's separate `codex`
companion plugin is a different integration and isn't required by anything
here.)

## License

MIT — see [LICENSE](LICENSE).
