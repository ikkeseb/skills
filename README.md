# skills

A collection of Claude Code skills I use day-to-day.

## Install all

```bash
/plugin install ikkeseb/skills
```

Or clone and symlink individual skills:

```bash
git clone https://github.com/ikkeseb/skills ~/skills
ln -s ~/skills/skills/<name> ~/.claude/skills/<name>
```

## Skills

| Skill | What it does |
|---|---|
| [excalidraw](skills/excalidraw) | Generate `.excalidraw` diagrams that argue visually. Optional headless PNG rendering. |
| [handoff](skills/handoff) | Compact the current session into a handoff for picking up elsewhere. |
| [homelab-companion](skills/homelab-companion) | Fail-mode forensics framework for homelab debugging and config review. |

Each skill has its own README with details.

## License

MIT — see [LICENSE](LICENSE).
