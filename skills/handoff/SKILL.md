---
name: handoff
description: "Write a paste-ready handoff for continuing the current task in a fresh session, saved temporarily and returned in the reply. Use when asked to hand off or produce continuation context. Not for reading or resuming from a pasted handoff."
---

# Handoff

Write a complete but selective continuation handoff, tailored to any next-session focus the user provides. The focus may narrow the next action; it must not erase the larger goal or remaining work.

A handoff is a judgment exercise, not template fill. Its failure mode is either a polished recap of facts recoverable from `git status`, or a terse pointer that makes the next session reconstruct the research and decisions again.

## Build the handoff

1. Reconstruct from session memory: the goal, verified state, research that changed the direction, decisions and their reasons, rejected or deferred paths, failed approaches, open work, blockers, and the clearest executable next step. Include only the categories that matter, but do not drop load-bearing context to make the handoff short.
2. Spend a verification budget of at most five cheap, read-only operations total — `git status`, one bounded `git log`, a targeted read or search — on the facts whose misstatement would change the receiving session's first action. Prefer a cheap check for those facts; write everything outside the budget as unverified. Never run builds, tests, or history reconstruction (merge-base, ancestry, reflog tracing) for the handoff.
3. Omit facts the next session can recover cheaply unless their interpretation matters. Link durable documents — specs, plans, ADRs, issues, commits, diffs, audits — and say what each load-bearing one establishes. A link never replaces a decision, disposition, warning, or next step.
4. When continuation depends on working documents, give each exact path and its durability as known from the session — committed, untracked, gitignored, temporary, or unknown. If the only detailed artifact is ephemeral and memory is insufficient, make a targeted read of that artifact — content recovery, not a re-audit — and carry enough of its findings in the handoff to survive its loss.
5. When work spans sessions or repositories, name both states instead of collapsing them: the session-sized loop that may be closed, and the larger workstream — its scope, what landed, what remains open, what was rejected or parked.
6. Match the user's language. Keep commands, paths, identifiers, and source-language technical text exact. Redact secrets and personal details that are unnecessary for continuation.

Done when the receiving session can answer, without redoing the investigation: what the goal is, what changed, what was decided, what remains, which documents carry the evidence, and what to do first.

Do not continue the task or edit durable repository guidance while creating the handoff. If durable context is missing, name that gap; the handoff is transport, not its replacement.

## Structure the content

Use `# Handoff: [task]`, the disclaimer below, `## Goal`, `## Next` near the top — clearest step first, then its prerequisite, blocker, or approval — and only the other sections the work earns (state, decisions, working documents, workstream, failed approaches, warnings, setup). Name a skill only when the receiving session should invoke it before the next step to avoid a wrong start. Simple tasks produce short handoffs; rich tasks earn enough detail for continuity.

> Handoff written from session memory: context, not authority. Question its assumptions and surface material concerns or better options, and ask when the user's intent is unclear. Verify a claim only when the next action depends on it or the state may have changed; never repeat completed verification merely to validate the handoff.

## Save and reply

Save the exact handoff to a uniquely named `.md` file in the operating system's temporary directory and verify its contents. Do not maintain or prune a persistent handoff directory. State `Saved temporary copy to <absolute path>.` in a brief status line before the final message — never inside it.

The final message is the copy surface: a whole-last-message copy (Claude Code's `/copy`) must yield the paste-ready snip and nothing else. Make it exactly:

1. The opening line `handover: continuation handoff below.` (opening with "handover" — leading with the literal word "handoff" can invoke this skill in the receiving session).
2. A blank line, then a `markdown` fence containing the same handoff, longer than any backtick run inside it.

Nothing before the opening line, nothing after the fence.

If saving fails, report that briefly in the status line and still deliver the final message.

Done when: the file and snippet match and the final message contains only the snip, or the save failure is reported without losing the snippet.
