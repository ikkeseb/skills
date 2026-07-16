# skills

A small set of Claude Code skills I use day-to-day. Each one does a single thing and stays out of the way — pick what you need, ignore the rest.

![Vault note half-life diagram](skills/excalidraw/examples/vault-note-half-life.png)

> Generated end-to-end by the [`excalidraw`](skills/excalidraw) skill.

## Skills

- **[handoff](skills/handoff)** — compacts the current session into a handoff file plus a paste-ready snippet. Invoke with `/handoff` when switching machine, hitting a context limit, or briefing another agent.
- **[pretty-pdf](skills/pretty-pdf)** — generates visually distinctive PDFs (HTML+CSS via weasyprint) that adapt typography and palette to the content instead of reusing the same template. Use when the PDF should look designed, not auto-generated.
- **[excalidraw](skills/excalidraw)** — generates `.excalidraw` diagrams that argue visually, not just label boxes. Use when a diagram needs to teach something, not decorate a slide.
- **[drawio](skills/drawio)** — generates native `.drawio` (mxGraphModel XML) diagrams that open directly in app.diagrams.net. XML-only by design; no desktop-app export step. Use for flowcharts, architectures, ER/sequence/class diagrams when you want a draw.io file rather than `.excalidraw`.
- **[full-send](skills/full-send)** — posture for when resource use is authorized: free rein on subagents and agent teams, fan out widely then synthesize. Workflows stay opt-in. Invoke with `/full-send` (single-task) or `/full-send sustained` (session).
- **[max-effort](skills/max-effort)** — posture for high-stakes / irreversible work: adversarial review that tries to break the work and checks load-bearing claims against source-of-truth instead of rubber-stamping. Invoke with `/max-effort` (single-task) or `/max-effort sustained` (session).
- **[verify-claims](skills/verify-claims)** — audits factual claims in prose for traceable sources and returns a classified table. Use when you want to fact-check Claude's own output or a document — distinct from `/verify`, which runs the app to confirm code behavior.
- **[afk](skills/afk)** — posture for unattended autonomous work: no clarifying questions, low-blast default, audit trail in the conversation itself. Invoke with `/afk` when handing off an overnight run, audit, or any session you won't supervise.
- **[agents-md-convert](skills/agents-md-convert)** — converts a repo to the AGENTS.md-canonical convention (`AGENTS.md` holds the instructions, `CLAUDE.md` becomes a one-line `@AGENTS.md` import adapter) or checks an existing conversion, then verifies with fresh one-shot canaries in each installed harness CLI. Invoke with `/agents-md-convert` in Claude Code or `$agents-md-convert` in Codex.

### Claude-only by design

These skills' substance is Claude Code machinery — porting them to another harness would mistranslate, not translate. Don't "fix" them into Codex.

- **[orchestrate](skills/orchestrate)** — posture for how Fable spends itself: the main loop owns everything critical — design (frontend/UI included), spec, planning, architecture, review, integration — and delegates mechanical execution to opus agents at high effort inside dynamic Workflow scripts (workflows only, no subagents or agent teams). Invoke with `/orchestrate` (single-task) or `/orchestrate sustained` (session). *Claude-only: built on Fable/Opus model routing, per-agent effort, and the Workflow tool.*
- **[suggest-loop](skills/suggest-loop)** — reads a target repo's documented verification gate and proposes 2–3 ready-to-paste `/loop` prompts with stop conditions baked in, each marking which half stays a human taste-gate. Use when you want an autonomous fix/babysit loop for a repo but can't author the prompt yourself. *Claude-only: packs `/loop` + scheduling mechanics that have no Codex CLI surface.*
- **[context-audit](skills/context-audit)** — audits a project's `CLAUDE.md` and context architecture, then proposes a leaner structure that moves domain-specific rules out of always-on static context into auto-loading skills, nested `CLAUDE.md` files, or hooks. Analysis-only: hands back a classification, draft files, and an honest worth-it verdict for you to apply by hand. Invoke with `/context-audit` when a `CLAUDE.md` feels bloated. *Claude-only for now: its subject matter is Claude Code's context architecture; a Codex-aware variant (AGENTS.md / config auditing) is plausible later.*

Each skill folder contains its `SKILL.md`. A few add their own README for install-specific notes (e.g. `excalidraw`'s optional PNG renderer).

## Install

Install the whole bundle as a plugin — add the repo as a marketplace, then install:

```bash
/plugin marketplace add ikkeseb/skills
/plugin install ikkeseb-skills@ikkeseb
```

Or clone and symlink individual skills:

```bash
git clone https://github.com/ikkeseb/skills ~/skills
ln -s ~/skills/skills/<name> ~/.claude/skills/<name>
```

## License

MIT — see [LICENSE](LICENSE).
