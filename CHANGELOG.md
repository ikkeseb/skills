# Changelog

One repository-wide release version, mirrored in `.claude-plugin/plugin.json`
and `.codex-plugin/plugin.json`. Entries summarize what shipped; the git log
carries the detail.

## 0.7.5 — 2026-07-22

- Remove `disable-model-invocation: true` from every remaining SKILL.md. In
  current Claude Code the flag hides the skill from the model entirely, and
  since typed `/name` runs go through the model's Skill tool, author-locked
  skills were uninvocable even by explicit slash command (upstream
  anthropics/claude-code #26251, #38969, #43875; unfixed as of v2.1.217).
  The 0.7.4 assumption that slash invocation kept working was wrong.
- User-invoked intent now rests on human-readable descriptions plus, on Codex,
  the unchanged `allow_implicit_invocation: false` markers; consumers can tune
  Claude Code exposure with settings `skillOverrides` (`name-only` works;
  `user-invocable-only` currently re-triggers the hiding bug). Convention
  rewritten in `.agents/invocation.md`; `context-audit`'s skill-architecture
  advice updated to stop recommending the broken flag.

## 0.7.4 — 2026-07-22

- `handoff` is now model-invokable in both harnesses (removed
  `disable-model-invocation` from its frontmatter; set
  `allow_implicit_invocation: true` in its Codex marker). It is the one skill the
  model legitimately reaches for on its own at session wrap-up; the blanket
  user-invoked convention hid it from the model, which then improvised a
  `handoff.md` in the working repo instead of using the skill. Slash invocation
  was unaffected throughout. Carve-out documented in `.agents/invocation.md`;
  every other skill stays user-invoked.

## 0.7.3 — 2026-07-19

- Redesign `agents-md-convert` around user-selected Audit or Apply operations,
  repository-wide instruction mapping, partial and nested repairs, competing
  override detection, and overlap-safe work in dirty trees.
- Separate deterministic ownership, adapter, routing, reference, and diff
  checks from optional paid/authenticated harness canaries.
- Keep the public workflow environment-neutral and make the one-line adapter
  strict without assuming LF versus CRLF.

## 0.7.2 — 2026-07-18

Fixes from an adversarial (Codex) review of 0.7.1:

- The helper now mirrors its full result envelope atomically to
  `RUN_DIR/result.json` (success and every failure class), so a background
  harvest gets the authoritative `ok`/`error_class` verdict instead of just
  the model payload in `final.json`. Harvest steps updated to gate on it.
- `--timeout` is now the total wall-clock deadline including worker-slot
  queue wait — the foreground relay's 540/600000 invariant previously broke
  under slot contention (queue wait started before the run clock).
- The schema lint traversal is schema-keyword-aware
  (`properties`/`items`/`anyOf`/`allOf`/`$defs`/`definitions`) instead of
  matching any object containing a `properties` key — a field literally
  named `properties` no longer false-positives — and it now rejects
  non-object and `anyOf` roots.
- orchestrate SKILL.md explicitly authorizes main-loop background dispatch
  of Codex workers as delegation mechanics (was contradictory with the new
  primary path).

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
