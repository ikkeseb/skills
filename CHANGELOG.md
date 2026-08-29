# Changelog

One repository-wide release version, mirrored in `.claude-plugin/plugin.json`
and `.codex-plugin/plugin.json`. Entries summarize what shipped; the git log
carries the detail.

## 0.24.9 — 2026-08-29

`orchestrate`'s codex-exec reference makes the WSL bridge the preferred write route on native Windows: when the machine has a verified WSL VM, bridge write stages through it instead of degrading them to the Claude lane (previously the bridge was documented but the routing sentence sent orchestrators to the Claude lane first). Doc-only, no behavior change.

## 0.24.8 — 2026-08-29

`orchestrate`'s codex-exec reference adds a one-line pointer in the adapter-stages section back to the strict-mode schema contract: adapter-passed `--schema-file`s are orchestrator-authored, and a non-strict schema costs a full dispatch round as `usage` (field, 2026-08-29 — the first live adapter-layer run lost one round to a missing `additionalProperties: false`). Doc-only, no behavior change.

## 0.24.7 — 2026-08-29

`orchestrate`'s codex-exec reference documents the WSL bridge: a native-Windows orchestrator can dispatch write workers through a verified WSL VM (`wsl.exe -e bash -c '…'`), including workspaces under `/mnt/c`, with the two measured traps (interactive-only PATH exports hiding the codex binary; MSYS path-mangling of `/mnt/c` arguments) and the auto-start latency of a stopped VM. Doc-only, no behavior change.

## 0.24.6 — 2026-08-29

`orchestrate`'s codex-exec reference records that a WSL VM on a Windows machine follows the supported Linux write lane (landlock sandbox; `uname` reports Linux), not the unsupported native Windows lane — per-machine runner verification still applies. The helper-resolution check now strips `\r` when extracting the candidate list, so it passes on a CRLF worktree (WSL over a Windows checkout) instead of failing on invisible carriage returns. No skill behavior changes.

## 0.24.5 — 2026-08-28

Depersonalization pass from a cross-repo audit: `orchestrate`'s worker script drops a private repo path from a provenance comment, and `model-map.md` drops a personal name from a decision tag. No behavior change.

## 0.24.4 — 2026-08-27

`handoff` adds a fixed receiving-session posture to every snippet: use the handoff as context rather than authority, bring fresh eyes to its reasoning and proposed next step, surface material concerns or better options, and ask when the user's intent is unclear.

## 0.24.3 — 2026-08-27

`handoff` makes its final message exactly the paste-ready snip — an opening `handover:` line plus the fenced handoff, with the temp-file path moved to an earlier status line — so a whole-last-message copy (Claude Code's `/copy`, which no longer offers per-block selection) yields precisely what the receiving session needs.

## 0.24.2 — 2026-08-27

Doc-only: `AGENTS.md` is trimmed to a short public contract (structure, authoring baseline, check gate). Release procedure, sync lists and the full frontmatter policy move to the maintainer-local workspace, which the file points to. No skill behavior changes.

## 0.24.1 — 2026-08-27

Doc-only: the AGENTS.md `disable-model-invocation` convention now records that the flag's behavior flips across Claude Code versions (uninvocable on 2.1.237, user-only again on 2.1.247) and grounds the ban on that instability. No skill behavior changes.

## 0.24.0 — 2026-08-27

`afk` and `suggest-loop` are removed: neither saw real use. The public inventory is now 15 skills; the Codex-supported set is unchanged at 11.

## 0.23.4 — 2026-08-25

`orchestrate` replaces the background adapter stage with an active-wait adapter: long Codex runs inside a Workflow now hold their stage open with bounded foreground waits on the run dir instead of ending the turn and waiting to be woken. Harness re-invocation on background exit only exists for the main loop — the old recipe silently lost a live worker at workflow teardown.

## 0.23.3 — 2026-08-24

The changelog is rewritten to consumer grade: every entry now summarizes what shipped in a few lines, and the git log carries the full detail. No skill behavior changes.

## 0.23.2 — 2026-08-24

`orchestrate` restores read-only Codex workers on native Windows with Codex CLI 0.149.1 and later by bundling an exec-policy allowlist for safe read commands. Blocked empty results now fail the lane, and reviews of uncommitted work cannot fall back to a remote copy.

## 0.23.1 — 2026-08-24

`orchestrate` reduces its instruction bundle from 8,727 to 7,398 words without changing routing or mechanics. It also fixes recovery ordering and moves image relay and troubleshooting guidance into conditional references.

## 0.23.0 — 2026-08-24

`orchestrate` makes mixed Claude and Codex workflows the default and adds a background adapter for long Codex stages. The model map assigns gpt-5.6-sol to primary execution, opus to Claude work and cross-family review, and sonnet at low effort to adapter stages. `second-opinion` now checks independence from the producer's model family.

## 0.22.8 — 2026-08-24

`context-audit` treats write-back as a placement cost. It recommends extracting content into a skill only when that content is stable or already maintained by a mechanical update workflow.

## 0.22.7 — 2026-08-23

`handoff` restores fuller continuity for complex work while keeping verified temporary-file delivery. Handoffs now cover research, decisions, rejected paths, working-document durability, and the wider goal without forcing simple tasks to be long.

## 0.22.6 — 2026-08-23

`context-audit` flags contradictory live instructions and requires environment claims in proposed drafts to be checked by running the relevant commands or suites.

## 0.22.5 — 2026-08-23

`context-audit` splits reviews into two phases: verdict and classification first, then draft changes after the user chooses a direction. New weak-pointer and environment-cache flags identify content to rewrite, inline, or remove.

## 0.22.4 — 2026-08-23

The Excalidraw test suite uses a deterministic executable for its unavailable-PNG branch and no longer launches an installed GUI browser during repository checks.

## 0.22.3 — 2026-08-23

`handoff` saves a verified copy in the operating system's temporary directory and returns the same paste-ready snippet. It removes the persistent handoff directory and tailors content to the next session's focus.

## 0.22.2 — 2026-08-23

`history-audit` identifies Codex spawned threads correctly and reports exclusion counts. `second-opinion` requires citations for repository facts. `orchestrate` validates real image transparency, and `pretty-html` forces a light palette and white background when printing.

## 0.22.1 — 2026-08-22

The `orchestrate` model map raises gpt-5.6-sol's taste score and adds taste and review work to its default role. Fable remains reserved for underspecified intent.

## 0.22.0 — 2026-08-22

`pretty-slides` and `prettier-html` become available through Codex as explicitly invoked skills, bringing the Codex-supported set to eleven.

## 0.21.2 — 2026-08-21

`handoff` becomes reply-only. The paste-ready snippet is the complete deliverable, with no saved file or handoff-directory cleanup.

## 0.21.1 — 2026-08-20

All skills remove `disable-model-invocation`, and repository checks ban it because the flag can hide skills from explicit invocation. User-controlled exposure remains available through `skillOverrides: name-only`.

## 0.21.0 — 2026-08-20

Invocation policy becomes a per-skill choice, and `pretty-html` returns to model invocation. All skill prose also receives a plain-language edit without behavior changes.

## 0.20.0 — 2026-08-20

All skills move user-only invocation enforcement into frontmatter and receive shorter trigger descriptions. Repository checks also validate the flag and shared cross-skill file references.

## 0.19.0 — 2026-08-19

Security hardening adds pre-model redaction and prompt-injection boundaries to `history-audit`, makes `afk` honor safety and permission hooks, clarifies data transfer in `second-opinion`, binds `pretty-slides` QA to localhost, and tightens `orchestrate` helper handling.

## 0.18.3 — 2026-08-18

`drawio` follows the consumer repository's declared deliverables location when one exists and otherwise saves in the current directory.

## 0.18.2 — 2026-08-18

The README links to the skills.sh listing where all 17 skills can be browsed.

## 0.18.1 — 2026-08-18

The `excalidraw` scene builder rejects unknown fields, malformed collections, null items, and invalid inherited font values with clear build errors.

## 0.18.0 — 2026-08-18

`drawio` adds a bundled headless PNG renderer with multi-page, scale, and background options plus clearer visual-inspection guidance. `excalidraw` adds an optional sans-serif font mode while keeping Excalifont as the default.

## 0.17.3 — 2026-08-17

`orchestrate` moves model, effort, and task information into the visible dispatch label. Lane values now carry provenance, use `unknown` when unresolved, and update after cross-tier retries.

## 0.17.2 — 2026-08-17

Every `orchestrate` delegation prompt now opens with explicit model and effort fields, including inherited markers when no override is supplied.

## 0.17.1 — 2026-08-17

`orchestrate` keeps session-level authority with the main loop, restricts read-only stages to text output, and checks the worktree afterward. Codex read-only workers use simple shell reads.

## 0.17.0 — 2026-08-17

Native Windows workspace-write workers now fail closed as `unsupported_lane`, and probes no longer engage a Windows sandbox or trigger UAC. An environment-variable escape hatch retains the earlier elevated mode for explicitly repaired setups.

## 0.16.0 — 2026-08-15

New skill `prettier-html` creates art-directed single-file HTML without a fixed template or house palette. It includes a required concept step, responsive dual themes, measured WCAG AA contrast, print support, reusable wiring, and limits on repeated visual patterns.

## 0.15.1 — 2026-08-15

`pretty-slides` removes the decorative drawn band from its title-slide template. Hero bands are now optional and image-only, and decorative elements must not resemble data visualizations.

## 0.15.0 — 2026-08-15

New skill `pretty-slides` creates self-contained HTML presentations with inlined assets, keyboard navigation, eleven slide patterns, pattern-specific motion, reusable design tokens, and a deterministic screenshot-QA mode.

## 0.14.0 — 2026-08-14

One explicit `orchestrate` invocation now grants session-long routing discretion. Later qualifying tasks can re-enter the skill with an `[orchestrate]` announcement, while explicit invocation remains the only initial entry point.

## 0.13.0 — 2026-08-12

New skills `pretty-html` and `history-audit` add polished self-contained HTML reports and evidence-based analysis of agent-session histories. `orchestrate` also adds a boundary that keeps live secrets out of files, prompts, logs, and returned output.

## 0.12.3 — 2026-08-12

The Codex worker converts its shell child to a native Windows path before running the write probe, preventing valid write support from being reported as unavailable.

## 0.12.2 — 2026-08-11

The Codex worker uses the elevated Windows sandbox only for write runs and leaves read-only runs unpinned. Documentation also warns that a passing probe does not guarantee the sandbox will remain healthy.

## 0.12.1 — 2026-08-11

`orchestrate` adds a dedicated image-generation relay route using gpt-5.6-sol at medium effort. Relay prompts carry context and intent, run read-only, and forbid manual pixel-edit fallbacks for raster edits.

## 0.12.0 — 2026-08-11

`verify-claims` adds honest coverage reporting and scope-aware verdicts. `handoff` standardizes output and cleanup, `suggest-loop` adds measurable bounds and stop rules, and `context-audit` improves harness detection, no-op verdicts, and scope classification.

## 0.11.4 — 2026-08-07

Codex probes now report wholesale sandbox failures as unavailable write support, and worker runs fail closed as `sandbox_denied` when the execution layer cannot launch.

## 0.11.3 — 2026-08-05

`orchestrate` resolves informal Codex model names from its model map instead of guessing. It also avoids stale Workflow worktrees by creating one from the current HEAD when same-session commits matter.

## 0.11.2 — 2026-08-04

The Codex write lane gains native Windows support, a real write-capability probe, `workspace_changed` reporting, and fail-closed handling for degraded sandboxes. The model map limits fable to medium or high effort.

## 0.11.1 — 2026-08-03

The Codex worker resolves verdict-shaping text tools as direct executables to prevent shell-function overrides. `pretty-pdf` restores its Source Sans 3 with Source Serif 4 and Sora with Bitter font pairings.

## 0.11.0 — 2026-08-03

`orchestrate` becomes shorter and makes the Codex lane require explicit models, direct dependencies, and authoritative result envelopes. Context and unattended skills clarify authority and completion bounds. PDF and diagram skills gain stronger deterministic and visual checks, and one repository command now validates the full plugin surface.

## 0.10.9 — 2026-08-03

The Codex worker disables fsmonitor for its marked-index check, preventing repositories with `core.fsmonitor=true` from hanging the write gate.

## 0.10.8 — 2026-08-02

The `orchestrate` model map updates for GPT-5.6 pricing changes. Terra gains small reviews and simple coding, luna moves to higher effort, and sonnet remains a conductor rather than an execution delegate.

## 0.10.7 — 2026-08-02

`orchestrate` requires a diff hash only when the reviewed prompt actually embeds a diff.

## 0.10.6 — 2026-08-02

Background Codex jobs now show model, effort, and topic labels in the shell UI, while worker start banners identify the active run without contaminating the JSON result channel.

## 0.10.5 — 2026-08-01

`second-opinion` and `orchestrate` classify background review results as fresh, stale, or unknown before use. `second-opinion` also pins gpt-5.6-sol by default, accepts per-call model and effort overrides, and rejects invalid values.

## 0.10.4 — 2026-08-01

`second-opinion` moves long reviews to background jobs with one-hour worker limits and a single authoritative result harvest, avoiding the foreground shell timeout.

## 0.10.3 — 2026-07-31

A `second-opinion` follow-up now starts a fresh call with the previous response and new evidence supplied as explicit artifacts.

## 0.10.2 — 2026-07-31

`drawio` can use any browser automation already available in the session for optional visual inspection, rather than requiring Playwright specifically.

## 0.10.1 — 2026-07-30

`excalidraw` adds a clear inspection ladder using an available browser, manual import, or an honest `native visually unverified` result. It never installs or bundles a browser.

## 0.10.0 — 2026-07-30

`excalidraw` adds a dependency-free Node CLI that builds and validates native diagrams from a compact scene format, then requires inspection in an official Excalidraw surface. It defaults to Excalifont on a black canvas and removes the older Python, CDN, and clipboard workflow.

## 0.9.9 — 2026-07-30

`drawio`, `excalidraw`, and `context-audit` become Codex-supported. `drawio` falls back to its inline skeleton when external references are unavailable, and public invocation conventions move from `.agents/` into `AGENTS.md`.

## 0.9.8 — 2026-07-29

`orchestrate` routes effort-sensitive one-off stages through a single-stage Workflow or an agent definition that can pin effort, since the plain Agent tool cannot.

## 0.9.7 — 2026-07-28

`context-audit` now checks for duplicate rules across the full always-loaded instruction stack and trims prose already enforced by deterministic hooks.

## 0.9.6 — 2026-07-28

`orchestrate` reports each delegate's resolved model and effort. `second-opinion` stops workers from probing the filesystem when the complete review artifact is already pasted into the prompt.

## 0.9.5 — 2026-07-28

The `orchestrate` model map adds a calibrated fable delegate row, updated cost relationships, guidance for underspecified tasks, and a rule requiring evidence whenever model scores change.

## 0.9.4 — 2026-07-28

`orchestrate` and `second-opinion` fix contradictions about worker context, lane outages, and requested output volume.

## 0.9.3 — 2026-07-28

`orchestrate` accounts for user-level instructions inherited by delegated workers and requires prompts to state their needed output scope and volume. `second-opinion` continues through nonfatal flag-contract drift and documents its blocking call, result recovery, and total timeout. Model and effort pins are both required for independent review.

## 0.9.2 — 2026-07-26

The Codex write gate disables Git's untracked cache and fsmonitor during preflight so stale repository caches cannot hide files from safety checks.

## 0.9.1 — 2026-07-26

Codex write refusals now include the affected paths. Documentation explains why lossy Git clean filters cannot be handled safely and makes isolated worktrees mandatory for writing workers while naming their limits.

## 0.9.0 — 2026-07-26

The Codex dirty-tree gate separates Git stdout from warnings, honors untracked files and dirty submodules, and rejects merges, rebases, bisects, hidden index entries, and other unsafe write states.

## 0.8.6 — 2026-07-26

The README now describes the Codex probe's flag-contract check instead of the removed pinned-version check.

## 0.8.5 — 2026-07-26

`orchestrate` and `second-opinion` route security-control red-teaming away from Codex classifier failures or frame it as a correctness review.

## 0.8.4 — 2026-07-26

The Codex lane resolves its helper only from trusted plugin locations, never from the repository under review. `orchestrate` and `second-opinion` share the same checked path list, and `second-opinion` supplies the required `--model default` value.

## 0.8.3 — 2026-07-26

The Codex worker can find its helper from repositories outside this plugin by checking installed-skill and local deployment locations. A new check validates helper resolution across deployment layouts.

## 0.8.2 — 2026-07-25

`handoff` returns to explicit invocation only, making every skill user-invoked again while leaving `/handoff` and `$handoff` available.

## 0.8.1 — 2026-07-25

`orchestrate` dispatches one-off subagents anonymously so their results return automatically instead of entering teammate mode.

## 0.8.0 — 2026-07-25

New skill `second-opinion` asks one read-only Codex worker to review existing work and returns a synthesis. The Codex helper checks required CLI flags instead of pinning a version, accepts the CLI's default model and new supported effort levels, and adds an end-to-end verification command. Claude skill discovery no longer depends on a manifest allowlist.

## 0.7.6 — 2026-07-25

`orchestrate` separates the session seat from delegate selection, uses stable Claude model aliases, requires cross-family verification when review is owed, and defines effort and spend guidance. The Codex lane updates for CLI 0.145.0 and documents its actual result, schema, semaphore, and failure behavior.

## 0.7.5 — 2026-07-22

All skills remove `disable-model-invocation` because it hides them from explicit slash commands in affected Claude Code versions. Codex keeps explicit-invocation markers, and Claude users can use `skillOverrides: name-only`.

## 0.7.4 — 2026-07-22

`handoff` becomes model-invokable in both Claude Code and Codex so agents can use it automatically at session wrap-up. Every other skill remains user-invoked.

## 0.7.3 — 2026-07-19

`agents-md-convert` adds user-selected Audit and Apply modes, repository-wide instruction mapping, nested repairs, conflicting-override detection, and safe handling of dirty worktrees. Deterministic checks remain separate from optional authenticated canaries.

## 0.7.2 — 2026-07-18

The Codex helper writes a complete result envelope for success and failure, counts queue time toward the total timeout, and improves strict-schema validation. `orchestrate` also permits main-loop background dispatch for Codex workers.

## 0.7.1 — 2026-07-18

The Codex worker validates strict output schemas before dispatch. Long runs use background delivery with a fresh run directory per attempt, while updated guidance covers timeouts, sandbox choice, resume caching, and placeholder results.

## 0.7.0 — 2026-07-17

`orchestrate` assigns one fixed delivery owner to every delegated job, preventing completed work from being lost between agents.

## 0.6.x — 2026-07-17

The 0.6 series hardens Codex adapter timeouts and completion reporting, adds checkable completion conditions to `drawio` and `handoff`, makes workflows the preferred but optional route, shortens skill descriptions, adds the local maintainer workspace, and makes every skill user-invoked.

## 0.5.x — 2026-07-17

The 0.5 series adds Codex CLI plugin distribution, polishes the README, and removes the archived planning document from the public repository.
