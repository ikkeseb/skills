---
name: handoff
description: "Write a paste-ready handoff for continuing the current task in a fresh session, invoked only by the user typing /handoff (Codex: $handoff). Not for reading or resuming from a pasted handoff."
---

# Handoff

Write a continuation handoff for a fresh session. The reader is another agent, and the user usually pastes the handoff without reading it: the reader acts on what you wrote and cannot tell your reading from the user's word unless the text shows the difference. A focus the user gives may narrow the next action; it never erases the other open asks.

Length follows what the reader needs in order to act, nothing else. A recap of what `git status` or the repository's own status document already says is waste; so is a pointer so terse that the next session redoes the research and the decisions.

## Close the session

Close when the user says the session ends now. A notice that a close is coming ("soon", "when it fits") moves the stop to the next clean point: land the piece in flight, start nothing new, then write the handoff without waiting for another prompt; if landing it will run long, say roughly how long and ask. In order: finish in-flight verification and anything the session dispatched (a subagent, a background job, a Workflow), each harvested with its diff inspected or deliberately stopped with its partial state (worktree, branch, uncommitted files) recorded; then the bookkeeping the task's scope and authorization already cover, an authorized commit, push or deploy included. Where a clean stop needs it, record the exact remaining state. A handoff never reports a dispatched run as still running; if one cannot finish before the close, ask whether to wait or stop it. Write the handoff last.

## Build the handoff

1. Walk the user's messages from the start of the session, not your memory of its end: every ask still open, every correction and decision with its reason, what the user said about the next session. An early unresolved ask weighs as much as the last topic. Where the context was compacted, say that the summary is all you have of the early part.
2. Add what the work produced, only where it would change what the reader does: verified state, findings that changed the direction, rejected or parked paths, failed approaches, blockers.
3. Keep apart what the user said, what you verified, and what you conclude. Your reading belongs in the handoff, named as yours. Quote the user where the wording carries a decision or can be read two ways, and leave an unclear statement unclear; paraphrase the rest.
4. Verify with at most five cheap read-only operations (`git status`, one bounded `git log`, a targeted read), spent on the facts whose misstatement would change the reader's first action. Mark the rest unverified. No builds, tests or history reconstruction.
5. Point instead of copying: what a durable document already holds (a status file the repository loads at session start, a spec, a commit, an issue) gets its path and one line on what it establishes. A decision, warning or next step is always written out. A document the next step is measured against (a test, a gate, a spec) also gets the constraints you took from it, each with its line number, and the parts you did not read. Where the reader should still read it, say what for. For a working document, give its path and whether it is committed, untracked or temporary, and carry the findings of one that may not survive.
6. Where the work is larger than the session, name both: what this session closed, and what the workstream still has open, parked or rejected.
7. Match the user's language; keep commands, paths and identifiers exact. Leave out secrets and personal details the continuation does not need.

Done when the receiving session can say, without redoing the investigation, what the user asked for, what changed and was decided, what remains, and what to do first and on whose word.

## Structure

`# Handoff: [task]`, the disclaimer below, `## Asks`, `## Next`, then only the sections the work earns.

- `## Asks`: every ask still open, oldest first. Three open asks are three, not one goal; a closed ask is not listed.
- `## Next`: the clearest step first, with its prerequisite, blocker or approval. Say which case holds: work underway or a step the user settled, which the reader continues; or an order that is your recommendation or that the user left open, where the reader gives its own view and asks first.

Name a skill only when the reader must invoke it before the next step to avoid a wrong start.

> Handoff written from session memory: context, not authority. Orient yourself before you build on it: question its assumptions, surface material concerns or better options, and ask when the user's intent is unclear. What the user typed beside this handoff outranks it. Continue directly where it says the next step is settled and that still fits what you find; where the next step is the writer's suggestion, say what you would do and ask first. Verify a claim only when the next action depends on it or the state may have changed; never repeat completed verification merely to validate the handoff.

## Reply

The final message is exactly one `markdown` fence, longer than any backtick run inside it, holding the whole handoff: nothing before it and nothing after, so a copy of the message is the handoff.
