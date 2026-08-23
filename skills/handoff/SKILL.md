---
name: handoff
description: "Write a paste-ready handoff for continuing the current task in a fresh session, saved temporarily and returned in the reply. Use when asked to hand off or produce continuation context. Not for reading or resuming from a pasted handoff."
---

# Handoff

Write a complete but selective continuation handoff, tailored to any next-session focus the user provides. The focus may narrow the next action; it must not erase the larger goal or remaining work.

A handoff is a judgment exercise, not template fill. Its failure mode is either a polished recap of facts recoverable from `git status`, or a terse pointer that makes the next session reconstruct the research and decisions again.

## Build the handoff

1. Reconstruct the goal, verified state, research that changed the direction, decisions and their reasons, rejected or deferred paths, failed approaches, open work, blockers, and the clearest executable next step. Include only the categories that matter, but do not drop load-bearing context to make the handoff short.
2. Run only cheap, read-only checks needed for accuracy. State checked facts as facts. Label expectations and complete boundaries such as "only these files" or "nothing else" as unverified unless checked.
3. Omit facts the next session can recover cheaply unless their interpretation matters. Link to durable specs, plans, ADRs, issues, commits, diffs, audits, and reports, then say what each load-bearing document establishes and why the next session should read it. A link never replaces a decision, disposition, warning, or next step.
4. When the work produced or depended on research, an audit, a report, a spec, or another working document, include `## Working Documents`. Give each exact path, whether it is committed, untracked, gitignored, or temporary, and the part that matters for continuation. Check that durability in the document's repository; never infer it from the path or surrounding prose. If the only detailed artifact is ephemeral, carry enough of its findings in the handoff to survive its loss.
5. When work spans sessions or repositories, include `## Workstream State`: the current scope, what landed, what remains open, and what was explicitly rejected or parked. A session-sized loop may be closed while the larger workstream remains active; name both states instead of collapsing them.
6. Match the user's language. Keep commands, paths, identifiers, and source-language technical text exact. Redact secrets and personal details that are unnecessary for continuation.

Done when the receiving session can answer, without redoing the investigation: what the goal is, what changed, what was decided, what remains, which documents carry the evidence, and what to do first.

Do not continue the task or edit durable repository guidance while creating the handoff. If durable context is missing, name that gap; the handoff is transport, not its replacement.

## Structure the content

Use `# Handoff: [task]`, the disclaimer below, `## Goal`, `## Next`, and the other sections earned by the work. Common sections are `## Current State`, `## Key Decisions`, `## Working Documents`, `## Workstream State`, `## Failed Approaches`, `## Verification`, `## Code Context`, `## Warnings`, and `## Setup`.

Put `## Next` near the top. Lead with the clearest next step, then name its prerequisite, blocker, or approval. Simple tasks should still produce short handoffs. Rich tasks earn enough detail for continuity; do not optimize them for brevity.

> Handoff written from session memory.

## Save and reply

Save the exact handoff to a uniquely named `.md` file in the operating system's temporary directory and verify its contents. Do not maintain or prune a persistent handoff directory.

Reply with these parts and nothing after the fence:

1. `Saved temporary copy to <absolute path>.`
2. `Paste the snip below into the receiving session, opening with "handover: " (leading with the literal word "handoff" can invoke this skill again).`
3. A `markdown` fence containing the same handoff, longer than any backtick run inside it.

If saving fails, report that briefly and still return parts 2-3.

Done when: the file and snippet match, or the save failure is reported without losing the snippet.
