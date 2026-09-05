# Changelog

One repository-wide release version, mirrored in `.claude-plugin/plugin.json`
and `.codex-plugin/plugin.json`. Entries summarize what shipped; the git log
carries the detail.

## 0.31.2 — 2026-09-05

`handoff` is invoked only by a typed `/handoff` (Codex `$handoff`); the
description no longer offers itself on "hand off" phrasing. With no
soft trigger to guard against, the `handover:` guard line and the
`/copy` unwrapping note go; the final message is still exactly one
markdown fence holding the saved handoff.

## 0.31.1 — 2026-09-05

`orchestrate` reference diet, no behavior change. `model-map.md` keeps the
contract only (tiers, the delegate table, lane naming, routing rules);
calibration history, price notes and trial datapoints leave the file, and
score provenance now goes in the commit body. It names `gpt-6-astra` as
present but unrouted. `codex-exec.md` keeps the dispatch contract
(preflight, run, dispatch patterns, envelope, write gates); platform lanes
(native Windows read allowlist, WSL bridge), the failure-class catalog and
lost-delivery recovery move to `codex-troubleshooting.md`, which is read on
a failure envelope and before a first Windows dispatch. The always-loaded
reference load drops from about 7,000 words to about 3,600.

## 0.31.0 — 2026-09-03

Codex stages are seat-dispatched by default. The orchestrator writes the
prompt and schema files, starts `codex-worker.sh` in the background with a
labeled call, and harvests the run dir when the harness reports the exit;
no relay agent sits in between, so no Claude context is replayed per stage
(a relay cost about 25k tokens per tool call, five to nine calls each).
The foreground `codex-worker` adapter stays as the one Workflow exception,
for a per-item pipeline that must mix lanes, now over files the seat wrote
so it makes a single call. The active-wait adapter is retired (git history
keeps it). Every seat dispatch prints a stage line at start and at harvest.

## 0.30.2 — 2026-09-03

`orchestrate` fixes: the active-wait adapter recipe now uses a plain `sh`
counter loop instead of GNU `timeout`, which macOS does not ship (the
2026-09-03 rig ran 22 adapters on that substitute). The model map labels
the seat as Fable 5.1 and records the alias re-point as a calibration
note. The skill's description states it is invoked only by the user's
`/orchestrate`; the harness's own subagents and Workflow tool cover
ordinary fan-out.

## 0.30.1 — 2026-09-02

`codex-worker.sh verify` is now a read canary. The one billed run writes a
fresh token to `canary.txt` in its workspace and asks the worker to report
it; the envelope gains `workspace_read`, and `ok` requires it. A worker that
completes and honours the schema but cannot see the workspace (the dead read
lane measured 2026-08-24, where probe and the old capital-of-Norway verify
both sat green) now fails verify. Same single call, no new cost.

## 0.30.0 — 2026-09-02

Codex-lane stages get a budget and report their spend. `codex-worker.sh`
adds `spend` to every envelope (command items completed, token usage from
the turn, wall seconds), degrading to zero commands and null tokens when
the events carry none. `orchestrate` makes `budget:` the third line of every
worker prompt — commands, minutes and the stop — lists spend per stage in
the final report, and names the Map-stage rule: a workhorse that must read
more than about ten files gets cheap readers and their extracts instead.
`second-opinion` bounds its one call the same way and reports the spend.
Driver: a read/cluster stage that ran 27 command items and 3.4M cumulative
input tokens with no bound (model map calibration note).

## 0.29.1 — 2026-09-02

`history-audit` attributes a failure cluster to its parent call before it
blames a prompt: the quick friction pass now says to walk one sampled
failed `tool_result` back to its `tool_use` and record the tool, input
shape and caller ownership.

## 0.29.0 — 2026-09-01

`orchestrate` gives native Windows a first-class WSL lane. With
`CODEX_WORKER_LANE=wsl` in the machine's environment, `codex-worker.sh`
re-executes `probe`, `verify` and `run` inside the WSL VM through `wsl.exe`:
path-valued options are translated to the drvfs mount, the run dir stays on
the Windows side, the VM shell is a login shell, MSYS path conversion is
suppressed, and the envelope returns with `lane: "wsl-bridge"` plus
`run_dir_wsl`. Every envelope now carries `lane`; a VM that does not answer
fails closed as `wsl_bridge_failed`. The lane is explicit and per machine —
nothing is auto-detected — and replaces the hand-written
`wsl.exe -e bash -c` bridge the reference used to prescribe. New measured
trap folded into the worktree rule: a worktree whose gitdir is absolute is
unreadable from the other side of the drvfs boundary, so worktrees are
created with `--relative-paths`. Driver: 0.28.2 told the orchestrator to
route stages "through a verified WSL bridge" three times without giving it a
mechanism, and the native read lane lost three of four Map readers in the
field. Hermetic suite: a fake `wsl.exe` covers path translation, login-shell
invocation, run-dir minting, probe, and the fail-closed path; off Windows the
variable is asserted inert.

## 0.28.2 — 2026-09-01

`orchestrate` makes the native-Windows Codex read lane explicit and
fail-closed. `probe` and run envelopes report `read_mode`; the helper appends
the single-command allowlist contract without adding a worker call, stops a
worker on the existing five-second poll when exec policy rejects a command,
and returns `read_policy_denied` so the orchestrator can route the same stage
through verified WSL. Full-shell platforms keep the original prompt. Driver:
a field review looked like a total lane outage because plain reads passed
while pipelines and non-allowlisted commands burned retries. The hermetic
runner suite now covers prompt preservation, one-call normal execution,
capability reporting and the routing verdict.

## 0.28.1 — 2026-09-01

`context-audit` widens its scope to the documents beside the instruction files
(status pages, backlogs, specs, session logs, archives) and asks each what
distinct truth or function it owns that no other file owns. A whole document
is flagged stale only after every item is proven resolved, contradicted or
owned elsewhere against live sources, never by age. Archive placement does not
settle authority: an archived file is still read and cited, so the skill
preserves deliberate archives and required records and otherwise proposes
deletion, when the repository convention or the user confirms git history is
sufficient, after transferring surviving rules and rewriting inbound
references. Procedures gain the protection guardrails already had: a copy,
restore, deploy or recovery procedure keeps each operation, its ordering,
validation and any existing rollback through a trim, with irreversible steps
marked. Smaller repairs: record on-disk and loaded-payload word counts
separately in the read-back, report deltas as payload measurements without
claiming reduced attention, and split only for work that can be invoked on its
own with a routing condition no neighbour shares. Driver: two field runs on
2026-09-01 where a first audit pass had archived stale documents and a week
later the same false claims were still being read, and a trimmed hardening
runbook had lost its copy and rollback commands. A second opinion (sol @ high)
on the draft supplied the archive-convention, per-item proof and rollback
corrections.

## 0.28.0 — 2026-08-31

Adds `repo-cosplay`: an explicitly invoked, Claude Code and Codex skill for
operating as a named repository from a session rooted elsewhere. It loads the
target's own instructions and the operating documents they point to, reports
git state before writing, preserves repository boundaries, runs native gates
manually, and closes the target's normal bookkeeping.

## 0.27.2 — 2026-08-31

`full-send` and `max-effort` are removed after seeing no real use across harnesses or machines. `orchestrate` already owns deliberate breadth through its Shapes, and risk-scaled review remains part of ordinary delivery, so the two posture skills leave no replacement layer.

## 0.27.1 — 2026-08-31

`handoff` now closes the current session before it builds continuation context: it finishes only already authorized verification and repository bookkeeping, preserves the exact remaining state when a clean stop needs new work or authority, then writes the handoff last. The five-read verification budget still applies only to building the handoff. `orchestrate` folds the same field session's narrow operational findings: build specifications name expected regression coverage, adapters keep prompt and schema files out of the helper-owned run dir, and the WSL bridge protects VM-side worktrees from Windows Git cleanup while using a persistent VM-local run dir only when harvest must survive a restart.

## 0.27.0 — 2026-08-31

`orchestrate` drops the `opus-medium` / `opus-high` / `opus-xhigh` agent definitions (0.26.0–0.26.6). A plain Agent dispatch now pins `model` and inherits the session's effort; a stage that needs more than the seat runs at — deep verification of another lane's work — goes as a one-agent Workflow with `effort` pinned on the `agent()` call. Why: custom agents in `~/.claude/agents/` are visible to the model in every session and no frontmatter field scopes them to a skill, so the 0.26.6 description gate was the only guard and a soft one; the effort control they bought is nice-to-have on the Claude lane (the Codex lane pins effort through the helper, unchanged). Both effort mechanisms were verified in transcripts before the decision; second-opinion (gpt-5.6-sol high) concurred. Consumers: remove the three links from `~/.claude/agents/`; `codex-worker.md` stays.

## 0.26.6 — 2026-08-31

The `opus-medium` / `opus-high` / `opus-xhigh` agent definitions now open their description with "Only when the orchestrate skill is active in this session; otherwise use general-purpose." Custom agents in `~/.claude/agents/` are visible to the model in every session and no frontmatter field scopes them to a skill (vendor sub-agents doc, checked 2026-08-31); the wording is the only available gate. Field driver: an unattended non-orchestrate session picked `opus-xhigh` for two plain read-only tasks (a 5.5k-line CSS inventory, a 22-screenshot critique) because the description said "exhaustive inventory"; both ran 22–38 minutes without returning and were stopped.

## 0.26.5 — 2026-08-31

`orchestrate` model map logs the first cheap-tier field outcome after 0.26.0: five terra @ high read-only classification stages in one Workflow, clean.

## 0.26.4 — 2026-08-31

`history-audit` friction scan after second-opinion review (gpt-5.6-sol high): per-model sums no longer overwrite across lanes (a real miscount: 8 reported where 102 occurred), `EISDIR` gets its own `read-directory` bucket, the Codex tools line is dropped (outputs carry no tool name), the header reports how many files yielded recognised records and flags FORMAT UNKNOWN when none do, and the denominator table carries its own caveat (task mix, small denominators, Claude `is_error` vs Codex text heuristic, raw population). Declined: failure-streak metric (add only if a report needs spiral ranking) and delegating fan-out to `orchestrate` (skills stay self-contained and Codex-usable).

## 0.26.3 — 2026-08-31

`history-audit` gains `scripts/friction-scan.py`: a deterministic, stdlib-only count of failed tool calls across Claude Code transcripts (main and subagent lanes) and Codex rollouts, bucketed by cause (hook blocks, permission denials, read-before-edit, edit mismatches, exit codes, Codex `Script failed`) per harness, lane and model, with dated pointers and credential masking. Field driver: a subagent's harness refusal was noticed by luck; subagent transcripts are rarely read, so mechanical friction had no measurement.

## 0.26.2 — 2026-08-31

The three tier definitions (`opus-medium`, `opus-high`, `opus-xhigh`) tell the worker to Read-tool every file before it Edits it. Field driver: a dispatched stage read its inputs through the shell (`cat`), hit the harness's built-in "File must be read first" refusal on its first Edit, and spent the rest of the stage on a replace-script workaround.

## 0.26.1 — 2026-08-31

`orchestrate` adds the `opus-medium` tier definition and puts opus @ medium in trial for tightly specified builds, mechanical refactors and test updates. The effort rule's "best performance-per-cost in the high band" has no field citation; the model map logs outcomes and promotes or drops on evidence.

## 0.26.0 — 2026-08-31

`orchestrate` gains a throughput posture. Field driver: a multi-hour build session ran fully serial — an hour of seat-side recon, one writer per stage, review as a serial tail, and a one-agent Workflow for a single pinned stage — while the skill's only wall-clock rule was "specify the next piece while a worker runs" and breadth was deferred to a posture skill no longer in use. New `Shapes` section: five composable shapes (Map, Build, Check, Sweep, Second look) with no mandatory order; scout inline, fan out the reading; scale to the ask; the instrument follows the shape (one stage → a plain Agent through a tier definition, fan-out or multi-stage → one mixed-lane Workflow, never a one-row tree). Senior review keeps its mandate at a depth set by risk. The blanket per-writer worktree rule becomes a write-set rule: writers declare what they may change and never commit; one exclusive writer may use the main tree on a branch (clean at dispatch, HEAD and status recorded, harvest compares `git diff --name-status <base>` against the set); any concurrent writer, live-linked target, or unbounded cheap-tier write gets a worktree, created in the main loop with the repo's own dependency install. Model map: a Tiers section (seat / workhorse / cheap, cut by blast radius and final say), the cheap tier fans out by default — returning evidence, never verdicts — with a trial list split into read-only and gated-write classes replacing "deliberately underused", and the pin rule names the tier definitions. New agent definitions `opus-high` and `opus-xhigh` pin effort for plain dispatches (the Agent tool exposes `model` only). codex-exec's write-worker gate and the helper's non-git error text follow the new isolation rule. Second-opinion reviewed (gpt-5.6-sol high): its finding that disjoint concurrent writers cannot share the main tree (whole-workspace helper lock, dirty-tree refusal) reshaped the rule; its risk-not-category review depth, evidence-not-verdict cheap output, long-Codex-stage dispatch path and description wording were folded in. Deployment note: symlink installs need links for the two new agents.

## 0.25.2 — 2026-08-30

`handoff` moves the `handover:` guard line inside the markdown fence. Field find (home PC, Claude Code 2026-08-30): `/copy` now returns the fence content unwrapped, dropping everything outside it — the pasted handoff led with the literal word "Handoff", exactly what the guard line existed to prevent. With the guard as the fence's first line the paste starts with `handover:` whether `/copy` copies the message verbatim or unwraps the block. Done-when updated to match.

## 0.25.1 — 2026-08-30

`handoff` gets a bounded verification contract, tuned by transcript measurement (Claude lane: 1–4 tool calls per handoff; Codex lane: 5–27, driven by verification archaeology the old elastic wording invited). Writing side: an explicit budget of at most five cheap read-only operations, spent on facts whose misstatement would change the receiving session's first action, with builds, tests, and history reconstruction banned; working-document durability is stated as known from the session (`unknown` allowed) instead of demanding a per-document repository check, with a targeted-read carve-out when the only detailed artifact is ephemeral and memory is insufficient. Receiving side: the disclaimer switches from "bring fresh eyes" to just-in-time verification — never repeat completed verification merely to validate the handoff; check a claim only when the next action depends on it or the state may have changed. Structure section gains a conditional suggested-skill line and folds the section list into one paragraph. Delivery mechanics unchanged. Second-opinion reviewed (gpt-5.6-sol high).

## 0.25.0 — 2026-08-30

`context-audit` grows a doctrine core and a prose pass. New Target shape section states the default the audit judges against (minimal always-loaded skeleton with a routing table, one on-demand owner per truth, environment owns what it can show, slim never at the cost of reach — deliberate repo deviations win). The Map step now flags skeleton gaps (ownerless truths, double owners, unrouted documents). Three new classification flags carry the prose pass: frozen enumeration (present-tense counts that freeze at write time), evidence-laden (rules still carrying the history that earned them), and no-op (sentences the agent already obeys); the flag paragraph is restructured as a list. The verdict names which budget a proposal spends — placement or prose — since they are different passes and a full audit runs both. Description now covers the skeleton dimension.

## 0.24.10 — 2026-08-29

Closes the routing gaps 0.24.9 left: the probe section's `write_ready: false` sentence — the first routing text a native-Windows orchestrator hits — now carves out the WSL bridge (probe inside the VM before degrading to the Claude lane), the `unsupported_lane` error description routes over the bridge first, and the gates sentence operationalizes "verified" (per-machine verification per the WSL bullet; a VM-side probe over the bridge is the runtime check). Doc-only, no behavior change.

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
