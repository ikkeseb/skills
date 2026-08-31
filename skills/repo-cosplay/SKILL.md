---
name: repo-cosplay
description: >
  Operate in a named target repository from a session rooted elsewhere, only
  when the user explicitly says "repo cosplay" or explicitly asks to operate
  on behalf of that repository. Not for incidental cross-repo references,
  deferred changes, or read-only audits.
---

# Repo Cosplay

Treat the named target as the working repository while the current session
remains elsewhere. The user's explicit ask supplies the authority; this skill
supplies native-session discipline.

## Procedure

1. Resolve the exact target. Read its root and relevant nested `AGENTS.md` or
   `CLAUDE.md`, then any current-state, handoff, or operating documents those
   instructions point to. Report its branch, sync state, and unrelated dirt
   before writing.
2. Work under the target's owners and conventions. Load the documents that own
   the requested area, preserve unrelated changes, and run the target's hooks
   or gates manually because the current session may not inherit them.
3. Follow every repository boundary you find. A symlink target, nested
   repository, or external owner needs its own explicit grant.
4. Finish the target's normal bookkeeping, commit and push only the authorized
   work, and verify it by the target's standard.

If the ask is read-only, stop after answering it. Use coordination for work
that should happen later, not for a change the user asked to make now.
