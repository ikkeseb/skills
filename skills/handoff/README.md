# handoff

A Claude Code skill that compacts the current session into a handoff for picking up elsewhere — either a fresh Claude Code session on the same machine, or any other context where you paste the snippet.

Saves a markdown file to `~/.claude/handoffs/YYYY-MM-DD-HHmm-<slug>.md` and shows the same content inside a 4-backtick markdown block in chat. File for same-machine pickup; snippet for cross-context paste.

## Install

Part of the [`ikkeseb-skills`](https://github.com/ikkeseb/skills) plugin bundle:

```bash
/plugin install ikkeseb/skills
```

Or symlink just this skill from your own clone of the bundle:

```bash
git clone https://github.com/ikkeseb/skills ~/skills
ln -s ~/skills/skills/handoff ~/.claude/skills/handoff
```

## Usage

```
/handoff
```

Claude reconstructs the session, writes the file, and shows the same content as a snippet in a 4-backtick markdown block. For same-machine pickup, point the next session at the saved path. For cross-context use, paste the snippet and say "continue from this".

## Snippet structure

**Opt-in inclusion** — sections appear only when they give the next session something they can't trivially get from git or the codebase. Default is to omit. A handoff that earns every line beats one that follows a template.

- Required: `# Handoff: [task]` title, one-line disclaimer blockquote.
- Almost always: Goal, Next.
- Opt-in (judgment call): Failed Approaches, Key Decisions, Code Context, Current State, Warnings, Setup.

The disclaimer is verbatim — primes the next session to verify load-bearing claims against git/code rather than read the handoff as spec.

## TTL

Files older than 30 days in `~/.claude/handoffs/` are deleted on the next `/handoff` run. To keep one as documentation, move it out of the directory.

## What this skill won't do

- **Won't auto-detect on session start.** The next session reads the file or the snippet — you tell it to.
- **Won't replace `git log`.** Captures session-level context git can't see — failed approaches, design rationale, in-progress thinking.

## License

MIT
