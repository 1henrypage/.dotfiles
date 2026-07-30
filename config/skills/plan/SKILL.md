---
name: plan
description: Omnigent's planning-mode skill - before touching any code, fan out a large wave of parallel read-only explore/search sub-agents to map the codebase, synthesize their findings into a single written plan document, save it under ~/.omnigent/plans, and stop for human approval before any implementation begins. Use when the user asks to plan first, wants a plan before code, says "don't code yet", "just plan this out", "come up with a plan", invokes /plan, or is handing over a feature/refactor/bugfix big enough to deserve a written plan before work starts.
user-invocable: true
---

# plan

`plan` is omnigent's answer to Claude Code's built-in planning mode, built for an
orchestrator that has sub-agents instead of a single context window: it doesn't
investigate alone, it fans a large wave of parallel **read-only** explorers out
over the problem, then turns their reports into one written plan the human signs
off on before any code changes happen.

This skill produces a plan and stops. It never edits source, never opens a PR,
and never dispatches an `implement` sub-agent. Implementation is a separate,
later step the human explicitly triggers (typically the `fanout` skill, one
sub-agent per task in the approved plan).

## When this needs a dispatch-capable agent

Fan-out requires an agent with sub-agent dispatch (e.g. `sys_session_send`
against `explore`/`search`-capable workers - this is what `polly` and similar
omnigent orchestrators have). If the running agent has no sub-agents, skip
straight to "Solo fallback" below rather than pretending to fan out. If anything goes wrong, stop and notify the user.

## Process

1. **Decompose the ask into investigation angles**, not into implementation
   tasks. For a feature/refactor/bugfix, typical angles are: the relevant
   existing code paths and their current behavior, the conventions/patterns
   already used nearby, the data model / API surface touched, existing
   tests and how they're structured, related past work (git log / prior
   PRs), configuration and deployment concerns, and edge cases or failure
   modes worth worrying about. Aim for wide coverage - many narrow angles
   beat a few broad ones, because each one becomes an independently
   dispatchable explorer.

2. **Fan out in one turn.** Dispatch one `explore` or `search` sub-agent per
   angle, all in the same turn so they run in parallel (per your own
   orchestration rules on fan-out). Each dispatch:
   - gets a specific, narrowly-scoped question, not "look into the feature";
   - gets a distinct, descriptive `title` (e.g. `explore-auth-middleware`,
     `explore-existing-tests`, `explore-similar-past-prs`);
   - is read-only (`purpose: "explore"` or `"search"`) - no explorer edits
     anything or opens a PR.
   Don't be shy about the count: an under-scoped plan is worse than a few
   extra explorers. Re-fan-out with follow-up explorers if the first wave
   surfaces contradictions, unanswered questions, or a bigger surface area
   than expected.

3. **Synthesize, don't re-investigate.** Collect every explorer's report from
   the inbox and build the plan strictly from what they found - grounded,
   the same way the `investigate` skill treats explorer reports as the
   source of truth rather than your own guesses.

4. **Write the plan document** with this shape (adapt sections to the task,
   but keep the gate at the end):
   - **Goal** - the outcome in the user's own terms.
   - **Current state** - what the explorers found, cited to the relevant
     files/areas.
   - **Approach** - the chosen approach, briefly noting alternatives
     considered and why they lost out.
   - **Task breakdown** - an ordered/parallelizable list of concrete tasks,
     each scoped the way you'd hand it to an `implement` sub-agent later
     (this list is what a subsequent `fanout` run will consume).
   - **Files / areas touched** - best-known list, per task.
   - **Risks & open questions** - anything the explorers couldn't resolve,
     or that needs a human call before implementation starts.
   - **Verification strategy** - how each task's result will be checked
     (tests, gates, manual E2E) once implemented.
   - **Out of scope** - what this plan deliberately does not cover.

5. **Persist it to `~/.omnigent/plans/`**, which this dotfiles repo symlinks
   to `config/omnigent/plans/` (see `symlinks.yaml`) so plans survive across
   sessions and machines. Use a filename like
   `<yyyymmdd-HHMMSS>-<short-slug>.md`.

   Use `sys_os_shell`, not `sys_os_write`/`sys_os_edit`/`sys_os_read` - those
   three are confined to the current environment root (the project
   workspace you're operating in), which is almost never `$HOME`, so they
   cannot reach a `~/.omnigent/...` path. `sys_os_shell` has no such
   confinement. For example:

   ```
   mkdir -p ~/.omnigent/plans
   cat > ~/.omnigent/plans/20260722-143000-auth-refactor.md <<'EOF'
   # <plan content>
   EOF
   ```

6. **Stop for approval.** Show the human a short summary (goal, chosen
   approach, task count, biggest risk/open question) and the plan file's
   path, then end your turn. Do not dispatch any `implement` sub-agent and
   do not start the `fanout` skill in the same turn - planning mode's whole
   point is a human checkpoint between "we know what to do" and "we're
   doing it". Only proceed to implementation on an explicit go-ahead in a
   later turn.

## Solo fallback

No sub-agents available: do a single, appropriately scoped read-only pass
yourself (files, `git log`, existing docs), then still write the plan
document and stop for approval per steps 4-6. Say plainly in the plan's
"Current state" section that it wasn't cross-checked by independent
explorers, so the human knows it carries less confidence than a fanned-out
plan.
