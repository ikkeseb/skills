---
name: handoff
description: "Write a paste-ready handoff for continuing the current task in a fresh session, saved temporarily and returned in the reply. Use when asked to hand off or produce continuation context. Not for reading or resuming from a pasted handoff."
---

# Handoff

Write a compact continuation handoff, tailored to any next-session focus the user provides.

Include only what the next session cannot recover cheaply: the goal, decisions, failed approaches, blockers, and an executable next step. Link to specs, plans, ADRs, issues, commits, and diffs instead of repeating them.

Run only cheap, read-only checks needed for accuracy. State checked facts as facts. Label expectations and complete boundaries such as "only these files" or "nothing else" as unverified unless checked.

Do not continue the task or edit durable repository guidance. Match the user's language, keep technical text exact, and redact secrets and unnecessary personal details.

Format the handoff as `# Handoff: [task]`, the disclaimer below, `## Goal`, `## Next`, and only other sections that carry useful context.

> Handoff written from session memory.

## Save and reply

Save the exact handoff to a uniquely named `.md` file in the operating system's temporary directory and verify its contents. Do not maintain or prune a persistent handoff directory.

Reply with these parts and nothing after the fence:

1. `Saved temporary copy to <absolute path>.`
2. `Paste the snip below into the receiving session, opening with "handover: " (leading with the literal word "handoff" can invoke this skill again).`
3. A `markdown` fence containing the same handoff, longer than any backtick run inside it.

If saving fails, report that briefly and still return parts 2-3.

Done when: the file and snippet match, or the save failure is reported without losing the snippet.
