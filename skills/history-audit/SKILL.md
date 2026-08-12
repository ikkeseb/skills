---
name: history-audit
description: >-
  Mine the machine's own agent-session history (Claude Code transcripts,
  Codex session logs) for the mistakes agents actually made, counted per
  model × harness, and turn the top patterns into per-line instruction
  proposals that each cite the run that earned them. An occasional deliberate
  audit, not a monitoring loop. Not for reviewing code, a single session, or
  live behavior.
---

# History audit

Answer, from evidence: what are the most common agent failure modes on this
machine, how often does each model hit them, and which instruction lines
would steer away from them? Corrections live in the user's own messages —
the corpus is what the user actually pushed back on, not what the agent
self-reported.

Deterministic where possible; agents only where judgment is needed.

## Pipeline

1. **Detect and index the corpora by script, not agents.** Probe what exists
   on this machine: Claude Code at `~/.claude/projects/*/*.jsonl`, Codex at
   `~/.codex/sessions/**/rollout-*.jsonl`. Run on what is found; a corpus
   that does not exist is reported as **unknown — never as zero failures**.
   File mtime is unreliable (observed: every file touched recently) — take
   dates from content (first `"timestamp"` in Claude transcripts; the
   `rollout-YYYY-MM-DD` filename for Codex). Take the model set from the
   corpus itself, not from a hard-coded list, and record the date window the
   corpus actually covers. Exclude automated corpora (single-shot
   scheduled/headless sessions, 1 user message per session) — they pollute
   rates. Detect forked sessions (transcripts sharing a message prefix) and
   collapse each shared prefix to one occurrence, so numerator and
   denominator see the same population. Done when the index lists sessions
   with harness, model, date, and cwd, records the covered window and the
   exclusions applied, and states which corpora were absent.
2. **Extract user messages only, per session**, into compact text files with
   a header (harness, model, date, cwd). Skip tool results, meta lines,
   command wrappers, environment blocks — this typically shrinks the corpus
   by two orders of magnitude. Done when every indexed session has an
   extract containing its header and user messages only.
3. **Mine correction events** over size-balanced batches (fan out readers
   where the harness supports subagents; otherwise batch sequentially), with
   a fixed category enum and a confidence field (high/medium), quoting the
   user verbatim. Starting vocabulary: misread-intent, overbuild,
   unverified-done, stopped-early, wrong-tool-or-process,
   destructive-or-risky, language-style, instruction-noncompliance,
   repeat-correction, other. Definition discipline: a correction event
   requires the agent to have done something wrong — normal iterative
   steering does not count; readers drift on exactly this. Done when every
   batch returns enum-tagged, quoted, confidence-marked events, with no
   event counted twice across batches.
4. **Compute denominators deterministically**: user-message counts per
   model × harness from the index, for a corrections-per-100-user-messages
   rate. Done when every rate has a scripted denominator.
5. **Verify cross-family when a second lane exists.** The producing family
   must not verify itself — audit quality is model-dependent. Run a
   precision spot-check (sampled events against sources) and a recall
   spot-check (sampled zero-event files) with a different model family. If
   no second family is available on the machine, state the degraded
   coverage plainly instead of skipping the caveat. Done when the report
   names the verifier (or the missing lane) and the spot-check results.
6. **Propose instruction lines one by one, never wholesale.** Each proposal
   cites its source session and gets individual approval before any
   instruction file changes. High-confidence events are the basis;
   medium-confidence events are candidates at best (observed: roughly a
   third of them are normal steering misread as corrections). Correction
   events double as source material for bad/good example pairs — the
   corrected behavior is the "bad", the outcome the user asked for the
   "good". Done when every accepted line is applied with its citation,
   every rejected one dropped, and nothing was edited unapproved.

## State these caveats in any report

- **Task-mix skew:** different models get different task difficulty; raw
  rates are a candidate list, not a model ranking.
- **Machine-bound corpora:** each machine is its own population — audit
  each, never extrapolate.
- **Perishable retention:** transcript windows roll; an audit is a dated
  snapshot of the window the index recorded.
