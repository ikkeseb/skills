# skills

Agent skills for day-to-day work, published as one plugin.
Claude Code ships the full set; Codex exposes the skills marked for both
harnesses.

Browse them on [skills.sh](https://skills.sh/ikkeseb/skills).

## Skills

Invoke skills explicitly: `/name` in Claude Code, the `$` picker in Codex.
No SKILL.md carries `disable-model-invocation`: its effect has changed across
Claude Code versions, and on some it hid the skill from the model and broke
the typed slash command too.
For a symlink or personal install, keep the model from triggering a skill on
its own with `skillOverrides: { "<name>": "name-only" }` in your Claude Code
settings; `html-brief` is the one skill meant to be model-invoked. For a
plugin install those overrides do not apply, so the model may route to any
skill whose description fits; explicit-only enforcement there is unverified.
Codex-supported skills that should stay explicit set
`allow_implicit_invocation: false` there.

### Claude Code and Codex

| Skill | What it does | Claude Code |
|---|---|---|
| **[handoff](skills/handoff)** | Compacts the session into a paste-ready handoff for switching sessions or briefing another agent: the user's open asks, the state, and a next step marked as settled or as the writer's suggestion. | `/handoff` |
| **[pretty-pdf](skills/pretty-pdf)** | PDFs that look designed rather than auto-generated (HTML + CSS via weasyprint). | `/pretty-pdf` |
| **[html-brief](skills/html-brief)** | Dark, self-contained, editorial HTML documents that read at a glance: plans, summaries, breakdowns, explanations, decisions, multi-part packs. | `/html-brief` |
| **[html-slides](skills/html-slides)** | Presentations as one self-contained HTML file: bundled slide engine with keyboard-only navigation and pattern-bound motion, plus a build step that inlines assets. | `/html-slides` |
| **[html-showcase](skills/html-showcase)** | Art-directed single-file HTML pages with editorial ambition: a fresh visual concept per invocation, designed by the session agent against the skill's quality floor. | `/html-showcase` |
| **[history-audit](skills/history-audit)** | Mines the machine's agent-session history for the most common failure modes per model × harness, and proposes instruction lines one by one, each citing the run that earned it. | `/history-audit` |
| **[excalidraw](skills/excalidraw)** | `.excalidraw` diagrams that explain something instead of just labeling boxes. | `/excalidraw` |
| **[drawio](skills/drawio)** | Native `.drawio` XML that opens straight in app.diagrams.net. | `/drawio` |
| **[agents-md-convert](skills/agents-md-convert)** | Audits, converts, or repairs repository instruction scopes so `AGENTS.md` is canonical and `CLAUDE.md` stays a one-line import adapter. | `/agents-md-convert` |
| **[context-audit](skills/context-audit)** | Audits instruction reach and the document skeleton, proposing a leaner context structure without stranding mandatory rules. | `/context-audit` |
| **[repo-cosplay](skills/repo-cosplay)** | Operates as a named repository from a session rooted elsewhere, loading that repository's own contract and gates. Explicit ask required. | `/repo-cosplay` |

In Codex, invoke the same skills through the `$` picker.

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
`html-brief`, `pretty-pdf`, `html-slides`, `html-showcase`, `repo-cosplay`.
`html-slides` and `html-showcase` need browser automation for their
screenshot QA; without it they deliver with an honest unverified list.
`drawio` degrades gracefully where the sandbox denies network
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

## License

MIT — see [LICENSE](LICENSE).
