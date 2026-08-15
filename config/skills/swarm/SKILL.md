---
name: swarm
description: Execute an approved /plan as a beads epic, MapReduce-style - parallel implementer agents in their own git worktrees, a merger agent at each fan-in, a scribe after each merge, an adversarial reviewer at the end, all dispatched headlessly via the omnigent CLI with roles/models from agent-roles. Use when the user says "execute the plan", "run the swarm", "implement the approved plan", invokes /swarm, or gives the go-ahead after a /plan approval gate.
user-invocable: true
---

# swarm

The execution counterpart to `/plan`: take the approved plan and its
`.graph.json`, materialize them as a beads epic, and run the graph wave by
wave - implementers in parallel worktrees, mergers at fan-ins, scribes after
merges, one adversarial reviewer at the end. Work lands on a local integration
branch `epic/<epic-id>` cut from the repo's **base branch** (see preflight);
the base branch is never touched and nothing is ever pushed - merging back is
the human's job.

**The orchestrator (you) is the only `bd` writer.** Embedded beads/Dolt is
single-writer; workers never run `bd` - each worker gets its full issue
content, acceptance criteria, and gates inside its prompt.

## bd cheat-sheet (verified against bd 1.2.1)

- **Issue types**: `bd create -t` accepts
  `bug|feature|task|epic|chore|decision|spike|story|milestone`. There is no
  merger/reviewer/scribe type - those are `task`s distinguished by
  `execution_agent_type` metadata.
- **Dependencies**: `bd dep add <issue> <blocker>` means *issue depends on
  (is blocked by) blocker*; default and only type you need is `blocks`.
  `waits-for` is NOT available via `bd dep add` (it exists only through
  `bd create --waits-for <spawner>` for dynamic fanout), so fixed fan-ins are
  wired as one `blocks` dep per sibling.
- **Graph create**: `bd create --graph plan.json` batch-creates issues +
  deps. Schema: `{"nodes": [...], "edges": [...]}`; node fields `key`
  (required), `title`, `type`, `description`, `acceptance_criteria` (NOT
  `acceptance`), `priority`, `labels`, `metadata` (object), `parent` (a node
  key - makes it a child, e.g. of the epic node); edge fields `from_key`,
  `to_key` (NOT `from`/`to`), `type`. **`from_key` is the dependent,
  `to_key` is its blocker.** Unknown fields are silently dropped (with a
  warning). Always validate with `--dry-run` first.
- **Ready/claim/close**: `bd ready --parent <epic>` lists unblocked open
  issues. `bd update <id> --claim` atomically claims (assignee=you, status
  in_progress). `bd close <id> --reason "<summary>"` - closes are what
  unblock dependents, so closing finished issues is mandatory, not
  bookkeeping. `bd close --force` / `bd update --force` override live-blocker
  refusals - don't, unless quarantining.
- **Guards**: `bd update <id> --status open --if-status in_progress` - a
  mismatch writes nothing and exits 13 (other failures exit 1).
- **Stale leases**: `bd reclaim` reverts in_progress issues whose lease
  expired (dead worker) back to ready. `bd ready` excludes in_progress, so a
  dead run's issues hang forever without this.
- **Stealth init** (repo without beads): `bd init --stealth --skip-agents
  --skip-hooks --non-interactive -p <prefix>` - nothing tracked, no
  AGENTS.md, no hooks; `.beads/` is hidden via `.git/info/exclude` + global
  gitignore. Verified: `git status --porcelain` stays empty afterwards.
- **Single-writer lock**: embedded Dolt holds a file lock per `bd` command.
  Overlapping commands from another process fail loudly ("The Dolt database
  is locked"). Wrap EVERY orchestrator `bd` call in a retry helper:
  exponential backoff (1s, 2s, 4s, ... capped at 60s) up to 5 minutes total,
  then stop and escalate to the human. One swarm orchestrator per repo at a
  time; if concurrent epics are ever wanted, that's shared-server mode
  (`bd config set dolt.shared-server true`), not more retries.
- **Never `bd edit`** - it opens `$EDITOR` and hangs a headless session. Use
  `bd update` flags instead.

## wt cheat-sheet (sh-treehouse)

In non-interactive shells resolve the binary first:
`WT="$(command -v wt || echo ~/.cache/zsh/antigen/bundles/1henrypage/sh-treehouse-main/bin/wt)"`.
Direct `bin/wt` calls never change your cwd - `cd` yourself when needed.

- Worktrees live at `$WT_DIR/<repo>/<branch with / -> ->` (default
  `~/.treehouse`). `wt add <branch>` reuses a pre-existing local branch.
- `wt run <branch> "<cmd>"` runs in a subshell inside the worktree - no cwd
  change, no prompts. Use it for gates.
- `wt reset [-f] <branch> [<ref>]` **defaults `<ref>` to wt's guess of the
  default branch when omitted** (local `main`, then local `master`, then the
  primary worktree's checked-out branch - `wt-git.sh:96-108`; it never asks
  `origin/HEAD`). Never rely on that guess: always pass the ref explicitly,
  `wt reset -f <branch> epic/<epic-id>`.
- `wt rm` needs `-y` (else it reads /dev/tty); `-y` also answers yes to
  deleting the branch. Without `-f` it refuses on untracked files.
- `wt` works without an `origin` remote (falls back to the repo dir name), so
  the local-only handoff is fine.

## Procedure

### 1. Load and preflight

Load the approved plan and its `.graph.json` from `~/.omnigent/plans/` (ask
the human which plan if ambiguous), and read the `agent-roles` skill for the
role table and dispatch recipe. Then preflight, failing fast on any miss:

- `bd --version`, `omnigent --version`, `$WT help` all work.
- **Resolve the base branch** `<base>` - the branch the epic is cut from and
  eventually merged back into. Repos aren't always `main`: master-based and
  dual-branch (`development`) setups exist, and no detection can know which
  branch integrates features. Resolution order:
  1. the base branch the plan declares (a grilling decision, recorded in the
     plan doc and on the epic node's metadata as `integration_base`);
  2. `git symbolic-ref refs/remotes/origin/HEAD` if an origin exists;
  3. local `main`, then local `master`;
  4. otherwise ask the human.
  State the resolved `<base>` in the preflight summary; if it looks ambiguous
  (e.g. both `master` and `development` exist and the plan is silent), ask
  rather than guess. Use `<base>` everywhere below.
- The primary worktree is clean (`git status --porcelain` empty).
- No other swarm orchestrator is running against this repo (single-writer -
  see cheat-sheet).
- **Beads bootstrap**: if the repo has no `.beads/` directory, stealth-init
  it (recipe in the cheat-sheet) with a short prefix derived from the repo
  name. If `.beads/` exists, use it as-is, respecting its existing config.

### 2. Materialize the epic

- `bd create --graph <plan>.graph.json --dry-run`; if the schema validates,
  create for real and record the key->id mapping it prints. If the installed
  bd rejects the artifact, fall back to per-issue `bd create` (epic first,
  then children with `--parent <epic-id>`) plus `bd dep add <dependent>
  <blocker>` per edge.
- Ensure every issue carries its `execution_*` metadata from the plan/roles
  table (`bd update <id> --metadata '<json>'` for any the graph didn't set).
- `bd swarm create <epic-id>` (so `bd swarm status`/`list` work as the
  resume entry point), then `bd swarm validate <epic-id>` to catch cycles,
  orphans, and wrong-direction deps **before** any dispatch.

### 3. Integration branch

`git branch epic/<epic-id> <base>` then `$WT add epic/<epic-id>`. (The
two-step is deliberate: `wt add` alone bases a brand-new branch on the
primary worktree's HEAD, or silently tracks a same-named remote branch -
pre-creating the branch pins the base.) All merging happens in this worktree;
`<base>` is never checked out or written.

### 4. Wave loop

Repeat until only the adversarial-review issue remains open:

- `bd ready --parent <epic-id>`. Claim each ready implementer issue:
  `bd update <id> --claim`.
- Per claimed issue: `git branch bd/<issue-id>-<slug> epic/<epic-id>`, then
  `$WT add bd/<issue-id>-<slug>`, then dispatch backgrounded from inside the
  worktree (`omnigent run` has no `--cwd` flag; cwd comes from the shell):

  ```sh
  cd <worktree> && omnigent run <agent-roles-dir>/worker.yaml \
    --harness <role harness> --model <role model> \
    -p "<role preamble + full issue content + acceptance criteria + gates +
        'commit everything, leave the tree clean'>" \
    > <log-dir>/<issue-id>.log 2>&1 &
  ```

  One log file per issue. All of a wave's dispatches go out together.
- On each worker's exit: **ignore the exit code** (omnigent exits 0 even on
  model failure - the error is only in the log). Judge by the worktree:
  commits exist on the issue branch, tree is clean, and gates pass via
  `$WT run <branch> "<project gates>"` (prefer the project's `no-mistakes`
  pipeline when configured).
  - Success: `bd close <id> --reason "<one-line summary>"`. Mandatory - the
    close is what unblocks the merger.
  - Failure: `$WT reset -f <branch> epic/<epic-id>` (ref explicit - wt's
    default is its own default-branch guess, not the epic!) and re-dispatch
    once. Second failure: mark the issue
    blocked (`bd update <id> --status blocked`), leave its worktree and
    branch untouched for inspection, and escalate to the human.
- **Merger issue ready** (all its wave's issues closed): claim it, dispatch
  the merger role *in the integration worktree*: merge each sibling
  `bd/<issue-id>-*` branch into `epic/<epic-id>`, resolving conflicts per
  the `resolving-merge-conflicts` skill, run the gates, commit. Verify the
  merge commits landed and gates pass, then the orchestrator closes the
  merger issue - that close is what releases wave N+1.
- **Scribe issue** after the merge commit: dispatch serialized (never two
  scribes at once, so docs can't conflict), verify, close.

### 5. Adversarial review

Dispatch the adversarial-reviewer role (model/effort from `agent-roles`)
against `git diff <base>...epic/<epic-id>` plus the plan's acceptance
criteria,
prompted to attack: missing acceptance criteria, silent behavior changes,
untested paths, spec drift. Blocking findings become new beads issues
(`bd create ... --deps discovered-from:<review-issue-id>`) wired as a fix
wave (implementers + a merger, per the wave rules), then loop: fix wave,
re-review. Exit only when the adversary passes.

### 6. Handoff

- Close the epic issue.
- Report: epic status (`bd epic status <epic-id>`), gate results, adversary
  verdict, and the integration branch + worktree path.
- Clean up **merged** implementer worktrees: `$WT rm -y -f <branch>` (`-y`
  also deletes the per-issue branch - intended, the work lives in the epic
  branch's merge commits; `-f` so stray untracked artifacts can't wedge
  cleanup). Worktrees of blocked/escalated issues are kept, quarantined, and
  listed in the report.
- Keep the integration branch and its worktree. **Never push, never PR** -
  merging `epic/<epic-id>` into `<base>` is the human's call.

### 7. Resume after a crash

State lives in beads. On restart: `bd swarm status <epic-id>` +
`bd list --parent <epic-id>` + `$WT ls`, and reconcile issue state against
worktrees:

- in_progress issues from the dead run (they'd hang forever - `bd ready`
  excludes them): `bd reclaim`, or the guarded
  `bd update <id> --status open --if-status in_progress` (mismatch writes
  nothing, exits 13).
- Any half-done worktree being re-run: `$WT reset -f <branch>
  epic/<epic-id>` first.
- A branch already merged into the epic branch whose issue is still open:
  just close the issue.

Then re-enter the wave loop at step 4.
