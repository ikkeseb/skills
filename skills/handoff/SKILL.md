---
name: handoff
description: "Write a paste-ready handoff for continuing the current task in a fresh session, invoked only by the user typing /handoff (Codex: $handoff). Not for reading or resuming from a pasted handoff."
---

# Handoff

Write a complete but selective continuation handoff, tailored to any next-session focus the user provides. The focus may narrow the next action; it must not erase the other open asks or remaining work.

A handoff is a judgment exercise, not template fill. Its failure mode is either a polished recap of facts recoverable from `git status`, or a terse pointer that makes the next session reconstruct the research and decisions again.

The reader is another agent, and the user usually pastes the handoff without reading it. Nobody corrects it on the way: the reader acts on what you wrote and cannot tell your reading from the user's word unless the text shows the difference.

## Close the session

Before building the handoff, finish in-flight verification and normal repository bookkeeping allowed by the existing task scope and authorization, including an already authorized commit, push, or deploy. Do not start new product work. If a clean stop needs new implementation or authority, preserve the exact remaining state. Write the handoff last, from that state.

## Build the handoff

1. Walk the user's messages from the start of the session, not your memory of its end: every ask still open, every correction and decision with its reason, and what the user said about the next session. An early ask that is not resolved weighs as much as the last topic. Where the context was compacted, the summary is all you have of the early part: say so.
2. Add what the work produced: verified state, research that changed the direction, rejected or deferred paths, failed approaches, blockers. Include only the categories that matter, but do not drop load-bearing context to make the handoff short.
3. Keep three things apart wherever they could steer the reader: what the user said, what you verified, and what you conclude or recommend. Your reading belongs in the handoff, named as yours. Quote the user where the wording carries a decision or can be read two ways, and leave an unclear statement unclear instead of resolving it; paraphrase the rest.
4. Spend a verification budget of at most five cheap, read-only operations total — `git status`, one bounded `git log`, a targeted read or search — on the facts whose misstatement would change the receiving session's first action. Write everything outside the budget as unverified. Never run builds, tests, or history reconstruction (merge-base, ancestry, reflog tracing) for the handoff.
5. Omit facts the next session can recover cheaply unless their interpretation matters. Link durable documents — specs, plans, ADRs, issues, commits, diffs, audits — and say what each load-bearing one establishes. A link never replaces a decision, disposition, warning, or next step.
6. When continuation depends on working documents, give each exact path and its durability as known from the session — committed, untracked, gitignored, temporary, or unknown. If the only detailed artifact is ephemeral, carry enough of its findings in the handoff to survive its loss.
7. When work spans sessions or repositories, name both states instead of collapsing them: the session-sized loop that may be closed, and the larger workstream — its scope, what landed, what remains open, what was rejected or parked.
8. Match the user's language. Keep commands, paths, identifiers, and source-language technical text exact. Redact secrets and personal details that are unnecessary for continuation.

Done when the receiving session can answer, without redoing the investigation: what the user asked for, what changed, what was decided, what remains, which documents carry the evidence, what to do first, and whether that first step is the user's or your suggestion.

## Structure the content

Use `# Handoff: [task]`, the disclaimer below, then `## Asks` and `## Next` near the top, and only the other sections the work earns (state, decisions, working documents, workstream, failed approaches, warnings, setup).

- `## Asks`: what the user wants: every ask still open, oldest first. A session that left three asks open has three, not one goal; an ask that was closed is not listed here.
- `## Next`: the clearest step first, then its prerequisite, blocker, or approval. Say which case holds. Work that was underway, or a next step the user settled: the reader continues with it. An order that is your recommendation, or that the user left open: say so, and the reader gives its own view and asks before starting.

Name a skill only when the receiving session should invoke it before the next step to avoid a wrong start. Simple tasks produce short handoffs; rich tasks earn enough detail for continuity.

> Handoff written from session memory: context, not authority. Orient yourself before you build on it: question its assumptions, surface material concerns or better options, and ask when the user's intent is unclear. What the user typed beside this handoff outranks it. Continue directly where it says the next step is settled and that still fits what you find; where the next step is the writer's suggestion, say what you would do and ask first. Verify a claim only when the next action depends on it or the state may have changed; never repeat completed verification merely to validate the handoff.

## Reply

The final message is the copy surface: exactly one `markdown` fence, longer than any backtick run inside it, containing the whole handoff. Nothing before the fence, nothing after it, so a copy of the message is the handoff and nothing else.

Done when the final message contains only the fence and the fence holds the whole handoff.
