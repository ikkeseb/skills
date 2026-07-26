# Changelog

One repository-wide release version, mirrored in `.claude-plugin/plugin.json`
and `.codex-plugin/plugin.json`. Entries summarize what shipped; the git log
carries the detail.

## 0.8.5 — 2026-07-26

- `orchestrate` and `second-opinion`: the provider's cybersecurity classifier
  is a lane-selection input, not a lane outage. It kills a run mid-flight with
  `api_error` and reacts to the prompt's framing rather than to the artifact —
  measured across three runs on 2026-07-26, where hunting bypasses in a
  blocking hook died while the same hook reviewed as parser correctness ran
  clean. Red-teaming a security control now routes to the Claude lane, or gets
  reframed as a correctness review.

## 0.8.4 — 2026-07-26

- **Security: the Codex lane no longer trusts the session's repo.** The helper
  candidate list included `$(git rev-parse --show-toplevel)/skills/orchestrate/
  scripts/codex-worker.sh` — the repo being *worked on*. Any repo shipping an
  executable file at that path would have had it run with the session's
  privileges, on nothing more than a preflight probe: arbitrary code execution
  from the material under review. Reproduced against a throwaway repo, then
  removed. Every surviving candidate is a location this repo's own content is
  deployed to. Found by a Codex review of the 0.8.3 fix.
- Complete the 0.8.3 fix, which reached only the subagent. `orchestrate` had
  no resolution at all — `SKILL.md` and `references/codex-exec.md` wrote the
  helper as a bare relative path, which resolves against the session's cwd —
  and `second-opinion` carried a verbatim copy of the old two-candidate list.
  All three surfaces now share one list, kept identical by the check below.
- `second-opinion`: `--model default` is required, not optional. The skill
  told the model to omit the flag; the helper rejects that as a usage error,
  so every call made by the book failed on the first try.
- `check-helper-resolution.sh`: names the three surfaces explicitly rather
  than discovering them by grep (a reindented anchor would have silently
  dropped a file from coverage), fails on an undeclared fourth copy, models
  the plugin placeholder as literal text substitution rather than an
  environment variable, and adds two canaries that plant a hostile helper in
  the session repo and require it to lose.

## 0.8.3 — 2026-07-26

- Fix `codex-worker`: the subagent could only find its helper script from a
  session rooted in this repo, so the whole Codex lane returned
  `missing_dependency` from every other repo. Neither existing candidate
  covered the symlink deployment — `CLAUDE_PLUGIN_ROOT` is rewritten for
  plugin installs only, and `git rev-parse --show-toplevel` returns the
  session's repo. Two candidates added: the deployed skill symlink
  (`$HOME/.claude/skills/orchestrate/…`) and a `$HOME/skills` backstop.
- New `skills/orchestrate/scripts/check-helper-resolution.sh`: resolves the
  candidate list as extracted from the agent file, from foreign cwds under
  simulated deployment shapes. Verified to fail on the pre-fix list.

## 0.8.2 — 2026-07-25

- Revert the `handoff` model-invocation carve-out from 0.7.4. Its Codex marker
  goes back to `allow_implicit_invocation: false`, and the exception is gone
  from `.agents/invocation.md`, `AGENTS.md`, and `README.md` — every skill in
  the repo is user-invoked again, with no exceptions. Nothing changes for
  `/handoff` or `$handoff`; only the model's autonomous reach at wrap-up is
  withdrawn, and on the Claude Code side that now rests on description wording
  alone, since `disable-model-invocation` stays banned (0.7.5).

## 0.8.1 — 2026-07-25

- `orchestrate`: documented a field-confirmed trap in its "one-off subagents"
  escape hatch — passing `name` to the Agent tool switches a dispatch into
  addressable "teammate" mode, where the result is no longer delivered
  automatically and the agent can fail to relay it even when asked directly.
  Dispatch one-off subagents anonymously.

## 0.8.0 — 2026-07-25

- New `second-opinion` skill: one read-only Codex call on work that already
  exists, answered as a synthesis rather than a relay. It exists because the
  most common Codex need — "what does another model family think of this?" —
  was only reachable through the full delegation posture and its ~1,200 lines
  of lane contract. The skill is the question-writing discipline plus one
  helper invocation.
- The Codex lane no longer gates on a pinned CLI series. `codex-worker.sh`
  checks that `codex exec --help` still advertises every flag it passes and
  ignores the version number; `probe` reports `contract_ok` / `missing_flags`,
  and `version_mismatch` becomes `contract_mismatch`. The old gate's failure
  mode was backwards — a routine release refused every write-capable worker
  (0.144 did precisely that) while a same-series release that dropped a flag
  passed. New `codex-worker.sh verify` closes the remaining gap with one tiny
  billed run asserting the full envelope, replacing the manual re-verification
  ritual.
- `--model` is now optional: omitted, the run takes the CLI's built-in default,
  so a new provider model needs no repo change. Runs pass `--ignore-user-config`,
  so this is deliberately *not* the user's `config.toml` model, and the envelope
  records `model: ""` — pin one where reproducibility matters. `--effort`
  validation flipped from an allowlist to a denylist (only `ultra` refused), so
  a new effort level the server accepts is no longer rejected locally.
- Dropped the `skills` key from `.claude-plugin/plugin.json`. Verified on Claude
  Code 2.1.220 across three isolated installs (full list, no list, 3-entry
  subset): all three shipped the same 12 skills, so the key neither restricted
  nor was needed, and the documented "replaces the default scan" mechanic was
  false. One fewer place to keep in sync.
- Honest invocation wording in `README.md` and `AGENTS.md`: both claimed no
  skill ever self-triggers, which stopped being true in 0.7.5 when the enforcing
  flag was removed, and `handoff` is a deliberate exception besides.
- `AGENTS.md` now routes maintainer sessions to `local/STATUS.md` up front, and
  its sync section drops the miscount ("Four places" then "the three").

## 0.7.6 — 2026-07-25

- `orchestrate`: the model map now separates the senior-seat *invariant* (the
  session model holds the seat; this skill never selects it) from the delegate
  table, which previously carried Fable-specific scores on the seat row and was
  internally false in any non-Fable session.
- Claude-lane rows are now written as harness aliases (`opus`, `sonnet`,
  `haiku`) instead of versioned strings, in the table and in all four stale
  fallback cells. Aliases re-point silently on harness update — `opus` was
  observed resolving to Opus 5 under Claude Code 2.1.219 with no repo change.
  Codex-lane rows stay exact model IDs because the worker helper passes them
  straight to `codex -m`. The map documents the asymmetry.
- `opus` intelligence 8 → 9 (Opus 5, vendor-reported); taste deliberately held
  at 8 — benchmarks do not measure the column's subject. The sol-vs-opus
  calibration drops its presumed capability ordering: they are peers, and the
  reason to pair them is vendor independence.
- Verification rules sharpened: still risk-triggered, but when owed, the
  verifier must not share the producer's model family — including the seat's
  own, which is the common case when the seat and the delegate resolve to the
  same model. Same-family verification is declared degraded coverage.
- Explicit effort policy: `high` default for substantive delegated work,
  `medium` floor, `xhigh`/`max` for exhaustive and adversarial work, `low` only
  for transport and bounded mechanical stages. Pinning `{model, effort}` is
  now justified where it is stated — an omitted effort inherits a per-session,
  per-machine setting.
- New pitfall: safety classifiers can swap the model underneath a running
  request with no error, so security work is partitioned before dispatch
  rather than diagnosed after the fact.
- Fixed a contradiction between `SKILL.md` and the map: adversarial and
  verification passes were described as undelegatable while the map assigned
  adversarial verification to a delegate. The invariant is final review and
  integration; producing review *evidence* delegates.
- Corrected the `disable-model-invocation` pitfall, which still carried the
  rationale `.agents/invocation.md` disproved in 0.7.5.
- Added a `Spend` section naming the Workflow `budget` global and the session
  size guideline, and a prioritised-review rule for diffs too large to read
  whole.
- Codex lane: recipe re-verified against codex-cli 0.145.0 (read-only and
  `workspace-write`, `--output-schema`, base-sha and dirty-tree gates) and the
  pin bumped from 0.144, which was blocking all write-capable workers.
  Corrected four documentation overclaims found by audit and confirmed against
  the script: `result.json` is not mirrored for `usage`, `codex_missing`, or
  `interrupted` failures (stdout-only — background dispatch must capture it);
  the helper does not validate schema instances, only parseability, with
  conformance enforced server-side; the semaphore is per-uid and per-`TMPDIR`,
  not machine-global; and the strict-mode lint does not traverse `oneOf`,
  `not`, `if`/`then`/`else`, or external `$ref`. Added the missing `usage`,
  `slot_root_hijacked`, and `interrupted` failure classes, a stop condition on
  quality escalation, and a JSON error envelope for the adapter's
  cannot-hold-foreground branch, which previously returned raw text and broke
  the enclosing schema.

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
