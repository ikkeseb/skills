---
name: agents-md-convert
description: Convert a repo to the AGENTS.md-canonical convention — AGENTS.md holds the instructions, CLAUDE.md becomes a one-line `@AGENTS.md` import — or check an existing conversion. Converts existing instructions; does not author them from scratch.
disable-model-invocation: true
---

# agents-md-convert

Mechanical migration, not a rewrite. The win is one source of truth every harness reads; the failure mode is two instruction files that drift, or a `CLAUDE.md` that silently stops loading because the import line is wrong.

Never touch the *content* of the instructions except the harness-wording pass below. This moves and adapts a file; it does not re-author guidance.

## What "converted" means

- `AGENTS.md` is canonical — it holds the real instruction content.
- `CLAUDE.md` is a one-line `@AGENTS.md` import adapter so Claude Code loads `AGENTS.md`.
- Codex and other agents read `AGENTS.md` directly.

## Step 1 — Preflight and mode selection

Run in order; each has a stop-or-continue criterion.

1. **Resolve root** — `git rev-parse --show-toplevel`. Done when it prints a path. Non-zero exit (not a git repo) → stop and report; this skill needs git for history-preserving moves.
2. **Detect state and name exactly one mode** — inspect the repo root for `CLAUDE.md` and `AGENTS.md` and read whichever exist. Done when one row below is selected:

| Repo state | Mode |
|---|---|
| Only `CLAUDE.md` | **Convert** (Step 2) |
| `AGENTS.md` with content + `CLAUDE.md` that is only `@AGENTS.md` | **Check** (Step 5) |
| Only `AGENTS.md` | **Adapter** (Step 3) |
| Both have real, differing content with no clear import direction | **Stop** — show both, ask the user which is canonical; resume once told |
| Neither exists | **Stop** — out of scope; authoring instructions from scratch is not this skill's job |

3. **Require a clean tree for editing modes** — convert and adapter modes only: `git status --porcelain` must print nothing. Done when output is empty. Any output → stop, show it, tell the user to commit or stash and rerun. (History-preserving `git mv` and a reviewable diff both depend on a clean start.) Check mode is read-only and runs on any tree.

## Step 2 — Convert mode

1. **Move, preserving history** — `git mv CLAUDE.md AGENTS.md`. Done when `git status` shows a rename.
2. **Insert the instruction-source section** — directly after the top-level title in `AGENTS.md`, add:

   ```
   ## Instruction source

   `AGENTS.md` is the canonical agent-instructions file for this repo. `CLAUDE.md` is a
   one-line `@AGENTS.md` import adapter so Claude Code loads these instructions; Codex and
   other agents read `AGENTS.md` directly. Edit `AGENTS.md` only — never edit `CLAUDE.md`.
   ```

   Done when the section sits immediately below the title and above the former first section.
3. **Write the adapter** — create `CLAUDE.md` whose entire contents are the single line `@AGENTS.md` followed by one trailing newline, nothing else. Done when `cat CLAUDE.md` shows exactly that.
4. Continue to Step 4 (wording pass), then Step 4b (nested scopes), then Step 6 (verify).

## Step 3 — Adapter mode

Only `AGENTS.md` exists, so the content is already canonical. Write the adapter per Step 2.3 (same done-when). Then run the wording pass (Step 4) and nested-scope pass (Step 4b) over `AGENTS.md`, then verify (Step 6).

## Step 4 — Harness-wording pass over AGENTS.md

`AGENTS.md` is now read by non-Claude agents too, so neutralize Claude-only phrasing. Work each item; the criterion is "no remaining instance of the pattern, or each remaining one is deliberately labeled Claude Code-specific."

- **Title / intro** — if it says the file is "guidance for Claude Code" (or similar), rephrase to name agents generically ("guidance for agents working in this repo").
- **Slash-command references** — every `/foo` that assumes a slash-command host gains a file-path fallback, e.g. `/foo (or read .claude/skills/foo/SKILL.md)`, so a non-slash harness can still follow it.
- **Hook-dependent behavior** — any rule that relies on a Claude Code hook firing gains one manual-fallback sentence stating what to do when no hook runs.
- **Genuinely Claude-specific sections** — leave the content intact but label the section as Claude Code-specific, so other agents know to skip it rather than misapply it.

## Step 4b — Nested scopes

1. **Find nested files** — locate every `CLAUDE.md` below the root. Done when the list is enumerated.
2. **Give each the same pair treatment** — apply convert or adapter mode (Steps 2–3) to each nested `CLAUDE.md` so each subtree ends with a canonical `AGENTS.md` + one-line `CLAUDE.md` adapter.
3. **Point the root at them** — if any nested `AGENTS.md` now exists, add one line to the root `AGENTS.md` stating that nested `AGENTS.md` files exist (list their directories) and must be read when working in those subtrees. Done when the root file names each nested scope.

## Step 5 — Check mode

Verify each element without editing. Emit one compact pass/gap table, one row per check:

| Check | Pass criterion |
|---|---|
| Canonical file | `AGENTS.md` exists with real instruction content |
| Adapter content | root `CLAUDE.md` matches the Step 2.3 adapter criterion |
| Instruction-source section | present right after the title in `AGENTS.md` |
| Harness-isms | no unlabeled Claude-only wording remains (per Step 4) |
| Nested pairs | every nested `CLAUDE.md` is a one-line adapter beside its `AGENTS.md`, and the root names them |
| Live canary | each installed harness answers the Step 6 canary correctly (run it — a structurally correct pair that doesn't load is still a gap) |

Mark each row pass or gap with a one-line reason. Done when every check has a verdict. Do not edit in check mode — report gaps for the user to rerun in convert mode.

## Step 6 — Verify with a live canary (all modes)

Confirm each installed harness actually resolves `AGENTS.md` as canonical. Ask a canary that forces both a file choice and a quote:

> Which file holds this repo's canonical agent instructions, and quote one section heading from it verbatim?

Run a fresh one-shot per available CLI, from the repo root:

- `claude -p "<canary>"`
- `codex exec --sandbox read-only "<canary>"`

Pass criterion per harness: the answer names `AGENTS.md` **and** the quoted heading appears verbatim in `AGENTS.md`. If a CLI is not installed, run the other and name the untested harness explicitly as a gap in the report — do not claim it passed.

## Step 7 — Report and hand off

The skill never commits or pushes. End with:

1. **What changed** — the exact file operations performed (renames, new adapters, edited sections, nested pairs).
2. **Verification result** — per-harness canary pass/gap, with any untested harness named.
3. **Suggested commit message** — e.g. `chore: adopt AGENTS.md-canonical convention (CLAUDE.md -> @AGENTS.md import)` — for the user to run themselves.
