# Writers

Read this before the first writing stage of a run. `SKILL.md` § Dispatch
owns where workers may write at all: the session's own repository only.

## The writer's brief

On top of `SKILL.md` § The brief, a writing stage's brief names its write
set and forbids commits. A writing stage that owes regression coverage gets
the test seam and cases named, not a follow-up.

## Where a writer works

One exclusive writer may use the main tree on a branch when the tree is
clean at dispatch and nothing else writes there until it returns: record
HEAD and porcelain status at dispatch, read only outside the write set
meanwhile, and at harvest compare `git diff --name-status <base>` plus
status against the write set; a file outside it or a moved HEAD stops
integration. Every other writer gets its own worktree: concurrent writers
in one checkout, a target linked into live configuration, or a cheap-tier
writer outside a machine-gated mechanical task.

Create worktrees in the main loop at current HEAD (a stacked piece at its
predecessor's tip), under the session repo's `.claude/worktrees/`: outside
the project directory, Claude-lane edits there can each prompt for
permission, unattended runs included. Git must ignore that path: add it to
`.git/info/exclude` only when `git check-ignore -q .claude/worktrees/`
fails, since a write under `.git` is one a harness's permission classifier
can refuse. Use `git worktree add --relative-paths` (so a worker reaching
the checkout through another platform view, the WSL lane over `/mnt/c`, can
resolve it), plus the dependency install the repo's docs prescribe; the
harness's `isolation: 'worktree'` has based on session-start HEAD and
installs nothing. A worktree isolates the working tree, not the
repository: `.git`, hooks and `--local` config are shared, and a write
through a tracked symlink pointing outside the repo reaches live state with
nothing in the worktree's status or diff. Repo tooling sees
`.claude/worktrees/`: keep it out of test globs.

## After a writer returns

Inspect partial changes from a failed writer before cleanup; a failed
writer never earns a blind rerun.

When a stage moved or rewrote tests and the seat doubts they still bite, a
mutation probe settles it: a few deliberate small breaks in the code under
test, run by the seat, which the tests must catch. Seat's judgment, no
extra stage. Run it in a copy no reviewer is reading, or finish and restore
it before a reviewer of that tree is dispatched: a mutation probe never
alters a reviewer's tree between dispatch and harvest.

Once the seat has verified that everything worth keeping from a worktree is
on its target branch, it runs `git worktree remove <path>` and
`git branch -d <branch>`; otherwise it reports the worktree and why it
stays. Neither command checks landing (`remove` checks cleanliness, `-d`
ancestry against the upstream or `HEAD`), and a squashed or applied diff
can leave `-d` refusing: inspect every refusal, and force (`--force`, `-D`)
only after accounting for everything forcing would discard.
