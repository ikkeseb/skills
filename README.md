# skills

A small set of Claude Code skills I use day-to-day. Each one does a single thing and stays out of the way — pick what you need, ignore the rest.

![Vault note half-life diagram](skills/excalidraw/examples/vault-note-half-life.png)

> Generated end-to-end by the [`excalidraw`](skills/excalidraw) skill.

## Skills

- **[afk](skills/afk)** — posture for unattended autonomous work: no clarifying questions, low-blast default, audit trail in the conversation itself. Invoke with `/afk` when handing off an overnight run, audit, or any session you won't supervise.
- **[excalidraw](skills/excalidraw)** — generates `.excalidraw` diagrams that argue visually, not just label boxes. Use when a diagram needs to teach something, not decorate a slide.
- **[handoff](skills/handoff)** — compacts the current session into a handoff file plus a paste-ready snippet. Invoke with `/handoff` when switching machine, hitting a context limit, or briefing another agent.
- **[max-effort](skills/max-effort)** — posture for high-stakes / irreversible work: dispatches subagents widely, then runs an orchestrator-pass that's the load-bearing verification step. Invoke with `/max-effort` (single-task) or `/max-effort sustained` (session).
- **[pretty-pdf](skills/pretty-pdf)** — generates visually distinctive PDFs (HTML+CSS via weasyprint) that adapt typography and palette to the content instead of reusing the same template. Use when the PDF should look designed, not auto-generated.
- **[verify-claims](skills/verify-claims)** — audits factual claims in prose for traceable sources and returns a classified table. Use when you want to fact-check Claude's own output or a document — distinct from `/verify`, which runs the app to confirm code behavior.

Each skill folder contains its `SKILL.md`. A few add their own README for install-specific notes (e.g. `excalidraw`'s optional PNG renderer).

## Install

Install the whole bundle as a plugin:

```bash
/plugin install ikkeseb/skills
```

Or clone and symlink individual skills:

```bash
git clone https://github.com/ikkeseb/skills ~/skills
ln -s ~/skills/skills/<name> ~/.claude/skills/<name>
```

## License

MIT — see [LICENSE](LICENSE).
