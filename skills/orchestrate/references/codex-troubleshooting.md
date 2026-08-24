# Codex lane: troubleshooting

Failure-time reference. Read on `codex_failed`, suspicious `stderr.log`
content, or a write-worker gate refusal / after-diff that behaves impossibly
in a repo using `.gitattributes` filters.

## Known stderr signals (0.144.x)

- `failed to load/renew models cache: missing field supports_reasoning_summaries`
  recurring on every run is harmless noise (stale `~/.codex` models cache vs
  a newer CLI schema) — don't let it mask the real failure line.
- On Windows, repeated `code-mode host closed its stdout` with exit code
  `-1073741502` (0xC0000142, STATUS_DLL_INIT_FAILED) is an intermittent
  Codex-CLI runtime crash, observed under heavy `max`-effort runs. It is an
  availability failure, not a quality miss: re-route the stage to the Claude
  lane instead of retrying the crash lottery.

## Lossy clean filters

- A *lossy* clean filter (`.gitattributes` `filter=`, e.g. one stripping
  volatile keys from a config file) breaks both the dirty-tree gate and the
  after-diff, reproducibly. Git compares *filtered* content, so `git diff`
  never shows a write inside the stripped region, and `git status` shows it
  only when the byte length changes — a bare ` M` against an empty diff. That
  `M` is what the gate refuses on, so such a repo blocks every write run
  until someone `git add`s the file. It looks like stale stat data and is
  not: git takes a size shortcut and never runs the filter.
- The length-preserving case is the dangerous one — invisible to gate and
  after-diff alike, and it survives `checkout`, `restore`, `stash` and
  `reset --hard`, so the worker's change is discarded with the worktree
  rather than merged. To see it, neutralise the driver
  (`git -c filter.<name>.clean=cat diff`, sound only where the filter has no
  smudge side) or compare the file against `git show HEAD:<path>`. Injective
  filters, `filter=lfs` among them, never do this: the blindness needs a
  many-to-one clean transform.
