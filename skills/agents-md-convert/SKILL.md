---
name: agents-md-convert
description: >-
  Audit, convert, or repair a Git repository so AGENTS.md owns agent guidance
  and CLAUDE.md is a one-line @AGENTS.md adapter. Use for existing root or
  nested instructions, including partial conversions; does not author guidance
  from scratch.
disable-model-invocation: true
---

# agents-md-convert

Make repository instruction ownership unambiguous without flattening every
specialized rule into one file.

## Endpoint

- At every in-scope instruction directory, `AGENTS.md` owns repository agent
  guidance and routing. Specialized behavior may remain in its owning surface;
  `AGENTS.md` points to it when agents must discover it.
- `CLAUDE.md` contains exactly one line, `@AGENTS.md`, followed by one line
  terminator. It has no BOM, extra whitespace, or other content. Honor an
  explicit repository EOL policy; otherwise accept LF or CRLF.

## 1. Establish intent and scope

Resolve the Git root. Infer **Audit** (read-only) or **Apply** (convert or
repair) from the request; ask only if neither is authorized. Work only inside
that repository and explicitly included nested repositories or worktrees.
Never assume an operating system, shell, home-directory layout, install method,
marketplace, or private companion repository. Exclude generated trees, vendor
trees, and caches unless the user includes them.

Snapshot status, staged and unstaged diffs, and unmerged entries. Unrelated
dirty files are allowed. In Apply, do not edit an instruction file or semantic
consumer with overlapping user changes; stop that affected scope and report it.

**Done when:** the operation, Git boundary, exclusions, and editable scopes are
explicit.

## 2. Build the instruction map

Enumerate tracked and non-ignored untracked instruction files. Also detect
known local override files even when ignored. Inspect, where present:

- `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`, and `CLAUDE.local.md`;
- project-configured instruction fallback names and path-specific rules;
- imports, ancestor routers, live authority references, and functional
consumers that read, copy, validate, or generate instruction files.

If no in-scope repository guidance exists, stop: authoring it from scratch is
outside this skill.

Separate live semantics from historical narration, examples, generated output,
and true descriptions of the adapter mechanism. For each instruction directory,
classify the pair as legacy, canonical without a valid adapter, converted, or
ambiguous because authority is split, masked, or contradictory. Record whether
root-launched agents can discover every nested scope.

**Done when:** one compact map names every in-scope pair, its authority, routing,
consumers, classification, and editability.

## 3. Decide once

In Audit, report ambiguity instead of resolving it. In Apply, continue through
unambiguous mechanical work without asking. Use one compact checkpoint only
when the result depends on unresolved authority, nested-repository inclusion,
the disposition of a competing override, or a semantic harness-specific
rewrite.

**Done when:** every ambiguous Apply scope is resolved or explicitly excluded.

## 4. Convert or repair

Work hunk by hunk:

1. Move legacy substantive content to `AGENTS.md`, preserving Git history when
   the destination does not exist. When both files contain guidance, merge only
   after authority is resolved; never overwrite one body with the other.
2. Preserve behavior while neutralizing vendor-only prose. Route genuinely
   harness-specific behavior to a narrow labeled branch or its owning surface.
   Reuse or add one concise ownership sentence; require no fixed heading or
   boilerplate.
3. Replace `CLAUDE.md` with the exact adapter from the endpoint.
4. Reuse or repair ancestor routing so a root-launched agent is told to read
   the applicable nested `AGENTS.md` before working in that subtree. Do not add
   a second router that duplicates an existing one.
5. Rewrite live authority references and functional consumers to the canonical
   file. Preserve historical references and intentional explanations of
   `CLAUDE.md` as the import adapter.

Do not absorb local overrides into committed files unless the user explicitly
includes them.

**Done when:** every editable scope satisfies the endpoint without unrelated or
duplicate changes.

## 5. Verify deterministically

Check every scope, then inspect the complete diff:

- `AGENTS.md` contains substantive guidance or intentional routing;
- `CLAUDE.md` satisfies the one-line content, BOM, whitespace, and EOL rules;
- no tracked override masks the canonical file, the pair's substantive body is
  not split, and imports or authority references do not loop;
- ancestor routing covers each nested scope from the supported launch points;
- live authority references, routers, and functional consumers target the
  correct file;
- no unmerged entries or unintended edits remain.

Run the target repository's relevant normal gate when the conversion changes
code, tests, comments, generated inputs, or operational documentation. Audit
runs the same structural checks without editing.

**Done when:** every deterministic check has a per-scope pass or gap and the
diff contains only intended work.

## 6. Offer live canaries

Treat live harness probes as optional evidence, not structural validation. Run
them only when the user already authorized them or approves once after being
told they may use authenticated or paid CLIs. Check each installed harness's
current `--help`, use fresh sessions, and give root and nested scopes unique
sentinels selected from existing rules; never add test-only guidance to the
target repository.

- For startup probes from the root and from a nested directory, disable tools
  or reject results that obtained the answer by reading instruction files.
- For a root-launched task that enters a subtree, permit only the repository
  reads needed to exercise discovery. Distinguish Claude Code's access-time
  nested loading from Codex following explicit ancestor routing.

Missing, declined, unsupported, trust-blocked, or inconclusive harnesses are
**not tested**, not structural failures.

**Done when:** each attempted scope/harness probe has pass, fail, or not-tested
status with its evidence.

## 7. Report

Name the operation and scope, exact edits, deterministic results, live results,
remaining gaps, overlapping dirty files left untouched, and commit/push
disposition. Do not commit or push unless the user requested it or target-repo
guidance requires it.

**Done when:** the report distinguishes structural correctness from optional
runtime evidence and makes every remaining action explicit.
