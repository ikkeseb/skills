# Changelog

One repository-wide release version, mirrored in `.claude-plugin/plugin.json`
and `.codex-plugin/plugin.json`. Entries summarize what shipped; the git log
carries the detail.

## 0.7.1 — 2026-07-18

Codex-lane hardening from two field sessions' friction logs:

- `codex-worker.sh` lints `--schema-file` locally for OpenAI strict mode
  (`additionalProperties: false` + `required` listing every property key,
  recursively) and fails fast instead of surfacing a 400 after dispatch.
- `codex-exec.md` dispatch contract flipped: background dispatch + run-dir
  harvest is the primary delivery path for runs that may exceed ~8 minutes;
  foreground adapter relay is short-runs-only (`--timeout 540`, Bash tool
  600000 ms — the tool hard-caps there and auto-backgrounds past it, which
  the previous 900000/840 recipe missed).
- Fresh run dir per attempt documented (resolves the collision between the
  run-dir-must-be-empty guard and Workflow resume replays).
- Sandbox guidance: `read-only` blocks all process spawning — match sandbox
  to whether the task must run tests/linters, not just whether it writes.
- Soft, task-shaped timeout guidance (headroom + a stated time budget in
  verification-heavy prompts) instead of per-role numbers.
- Known-noise and Windows code-mode-crash (0xC0000142) diagnosis notes.
- orchestrate SKILL.md gains an instrument-pitfalls section: stringified
  Workflow `args`, resume-cache blindness to referenced files, schema-valid
  placeholder output (anti-stub clause), and the sanctioned Bash route for
  user-ordered plugin commands guarded by `disable-model-invocation`.

## 0.7.0 — 2026-07-17

- Lost-delivery contract: one job, one delivery owner, fixed at dispatch.

## 0.6.x — 2026-07-17

- 0.6.7 Harden Codex adapter timeout and completion contract.
- 0.6.6 Add missing done-whens to drawio fetch and handoff write sequence.
- 0.6.5 Make workflows primary-not-only; ship verified Codex adapter prompt.
- 0.6.4 Rewrite descriptions for the reader; dedupe skill bodies.
- 0.6.1–0.6.3 Add gitignored `local/` maintainer workspace and tighten its
  note.
- 0.6.0 Make every skill user-invoked; README invocation table.

## 0.5.x — 2026-07-17

- 0.5.1 Polish README, archive the planning doc out of the repo.
- 0.5.0 Add Codex CLI plugin distribution route.
