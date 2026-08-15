---
name: agent-roles
description: Role registry for the plan/swarm multi-agent workflows - the single place that maps each swarm role (planner, explorer, implementer, merger, adversarial-reviewer, scribe) to a harness, model, and reasoning effort, plus the omnigent dispatch recipe every orchestrator uses. Read this when planning role assignments, dispatching workers, or retuning which model a role runs on.
---

# agent-roles

One shared, harness-neutral role-to-model mapping used by `/plan` (to stamp
roles onto tasks) and `/swarm` (to dispatch workers). Whatever harness is
running the skill - Claude Code, opencode/codex via `~/.agents/skills`, or an
omnigent orchestrator via `discover_host_skills` - reads the same table.

## Roles

| Role | Harness | Model | Effort | Purpose | Notes |
|---|---|---|---|---|---|
| planner | (whatever runs `/plan`) | claude-fable-5 | xhigh | Decompose the feature into a parallelism-maximized dependency graph | Not dispatched via worker.yaml; it is the session running `/plan` |
| explorer | claude-sdk | claude-sonnet-5 | medium | Read-only codebase investigation during planning | Many narrow explorers beat few broad ones |
| implementer | claude-sdk | claude-sonnet-5 | medium | Implement one issue in its own worktree | Swap to qwen/kimi here once those CLIs are installed and authed |
| merger | claude-sdk | claude-opus-5 | high | Merge a wave's branches into the epic integration branch, resolve conflicts, run gates | Uses the `resolving-merge-conflicts` skill |
| adversarial-reviewer | claude-sdk | claude-fable-5 | xhigh | Attack the finished epic diff against the plan's acceptance criteria | Blocking findings become new issues in a fix wave |
| scribe | claude-sdk | claude-sonnet-5 | medium | Update docs/changelogs after each merge | Serialized (one at a time) so docs never conflict |

Retuning a role is a one-line edit to this table (e.g. flip implementer's
harness/model to `qwen` / a qwen model once `qwen` is on PATH and logged in).
Nothing else needs to change - `/plan` and `/swarm` read the table at runtime.

## Dispatch recipe (headless, via the omnigent CLI)

All dispatch goes through the omnigent CLI regardless of which harness runs the
orchestrating skill - it is the only dispatcher that honors this cross-vendor
harness/model mapping. `worker.yaml` (next to this file) is the one generic
agent spec used for every role; the role and the task content arrive in the
`-p` prompt.

```sh
cd <workdir> && omnigent run <this-skill-dir>/worker.yaml \
  --harness <harness> --model <model> \
  -p "<role preamble + task content + acceptance criteria + gates>" \
  > <log-file> 2>&1 &
```

Facts to respect (verified against the installed omnigent):

- `omnigent run` has **no `--cwd` flag**. The worker's working directory is the
  launching shell's cwd (`os_env.cwd: .` resolves to the process cwd, not the
  YAML's directory), so always `cd` into the target worktree first.
- With `-p` set, the run is **one-shot**: it executes to completion and exits
  on its own. Add `--no-session` for an ephemeral, no-daemon variant.
- CLI `--harness`/`--model` override the spec's executor, so one worker.yaml
  serves every role in the table.
- **Exit code 0 does not mean success.** A run whose model fails (e.g. a bad
  model id) still exits 0 with the error only in the output text. Judge a
  worker by its worktree: commits present, tree clean, gates pass - never by
  the exit code. Keep one log file per dispatch for the post-mortem.

Under an omnigent orchestrator that has `sys_session_send` available, the same
table supplies the `agent` / `args.model` values for in-daemon dispatch; the
CLI recipe above remains the portable fallback.

## Stamping roles onto beads issues

Planners record role assignments as beads metadata so any executor can dispatch
without re-deriving them. On each issue (beads treats these `execution_*` keys
as authoritative dispatch hints):

- `execution_agent_type`: the role name from the table
  (e.g. `implementer`, `merger`, `adversarial-reviewer`, `scribe`)
- `execution_suggested_model`: the model id from the table
- `execution_reasoning_effort`: the effort from the table
- `execution_parallel_group`: the wave number

`bd create -t` has no merger/reviewer/scribe issue type - those issues are
plain `task`s distinguished solely by `execution_agent_type`.
