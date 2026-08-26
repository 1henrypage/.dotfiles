---
name: plan
description: Planning mode - fan out parallel read-only explorers, grill the human through the decomposition, then write a plan whose task breakdown is a parallelism-maximized dependency graph (waves of disjoint tasks, roles from agent-roles) ready for /swarm to execute as a beads epic. Saves plan + graph under ~/.omnigent/plans and stops for approval. Use when the user asks to plan first, says "don't code yet", "just plan this out", "come up with a plan", invokes /plan, or hands over work big enough to deserve a written plan.
user-invocable: true
---

# plan

Planning mode for an orchestrator with sub-agents: fan a wave of parallel
**read-only** explorers over the problem, grill the human on the decomposition,
then produce a plan the human signs off on before any code changes happen. The
plan's task breakdown is not a to-do list - it is a dependency graph engineered
for maximum parallel execution, which `/swarm` later materializes as a beads
epic and runs MapReduce-style across cheap models.

This skill produces a plan and stops. It never edits source, never opens a PR,
never creates beads issues, and never dispatches an implementer. Execution is a
separate, later step the human explicitly triggers with `/swarm`.

## Fan-out is harness-agnostic

- Under an omnigent orchestrator with sub-agent dispatch (`sys_session_send`
  against `explore`/`search` workers): fan out that way.
- Under Claude Code natively: fan out with parallel `Explore` subagents.
- Neither available: skip to "Solo fallback" below rather than pretending to
  fan out. If anything goes wrong, stop and notify the user.

Explorer role defaults (model/effort) come from the `agent-roles` skill.

## Process

1. **Decompose the ask into investigation angles**, not implementation tasks.
   Typical angles: the relevant existing code paths and behavior, nearby
   conventions/patterns, the data model / API surface touched, existing tests
   and their structure, related past work (git log / prior PRs), config and
   deployment concerns, edge cases and failure modes. Aim wide - many narrow
   angles beat a few broad ones, because each becomes an independently
   dispatchable explorer.

2. **Fan out in one turn.** One read-only explorer per angle, all dispatched
   in the same turn so they run in parallel. Each gets a specific,
   narrowly-scoped question and a distinct descriptive title. Don't be shy
   about the count; re-fan-out if the first wave surfaces contradictions or a
   bigger surface than expected.

3. **Synthesize, don't re-investigate.** Build the draft breakdown strictly
   from what the explorers found - their reports are the source of truth, not
   your own guesses.

4. **Grill the human on the decomposition** (new, mandatory unless the user
   explicitly asks for a quick plan / no grilling): run a `/grilling` session
   focused on *human decomposition decisions*, one question at a time with a
   recommended answer per question. Walk past the human, decision by decision:
   - the proposed task breakdown (is each task's scope right? anything
     missing or mergeable?);
   - the dependency edges (is each edge real, or an accidental
     serialization?);
   - the wave structure (could anything move earlier / run wider?);
   - the role assignment per task (from the `agent-roles` table);
   - the **integration base branch** the epic is cut from and merged back
     into. Recommend `origin/HEAD`'s target, else `main`/`master` - but put
     it to the human, because dual-branch setups (e.g. `development`) are a
     policy no detection can infer.
   Facts you can look up yourself - only the decisions go to the human.

5. **Apply the breakdown rules for parallelism** to the agreed decomposition:
   - Tasks get **disjoint file scopes**. If two tasks would touch the same
     file, either merge them or re-cut the boundary; overlap is what makes
     merges hard and serializes work.
   - **Minimize graph depth, maximize width.** Every dependency edge must be
     justified; an unjustified edge costs a whole wave of parallelism.
   - Every fan-in bottleneck becomes an explicit **integration-review task**
     with one `blocks` dependency per sibling task in its wave (never
     `waits-for` - `bd dep add` doesn't offer it; fixed fan-ins are wired as
     plain `blocks` edges). The git merge is mechanical and orchestrator-run,
     so this task is purely the quick cross-agent interaction review that
     runs after those merges land (see `agent-roles`); title it as a review,
     not a merge.
   - **Every wave N+1 task gets a `blocks` dep on wave N's integration-review
     task.** Wave N+1's branches are cut from `epic/<epic-id>`, so they must
     not be created until wave N's merges have landed on it and the seams
     between them have been reviewed.
   - A **scribe task** (docs/changelog) follows each merge, blocking on the
     integration-review task.
   - One final **adversarial-review task** blocks on everything else.
   - Each task gets a role from `agent-roles` and a wave number.
     Integration-review, scribe, and adversarial-review tasks are type `task`
     with the role recorded in `execution_agent_type` metadata (beads has no
     such issue types).

6. **Write the plan document** (adapt sections to the task, keep the gate):
   - **Goal** - the outcome in the user's own terms.
   - **Current state** - what the explorers found, cited to files/areas.
   - **Approach** - the chosen approach; alternatives briefly, and why they
     lost.
   - **Task breakdown** - the wave-by-wave graph: per task its title, scope
     (files), acceptance criteria, role, wave; integration reviews, scribes,
     and the adversarial review listed
     explicitly. This is what `/swarm` executes.
   - **Files / areas touched** - per task; verify disjointness here.
   - **Integration base branch** - the grilled decision from step 4; `/swarm`
     cuts `epic/<id>` from it and hands the result back onto it.
   - **Dependency graph preview** - the path to the HTML visualization (step
     8).
   - **Risks & open questions** - anything unresolved or needing a human
     call.
   - **Verification strategy** - the gates each task/wave must pass.
   - **Out of scope.**

7. **Write the machine-readable graph artifact** next to the plan:
   `~/.omnigent/plans/<same-stem>.graph.json`, shaped for `bd create --graph`
   (verified against bd 1.2.1; `/swarm` re-validates with `--dry-run` and
   falls back to per-issue creation if the installed bd rejects it):

   ```json
   {
     "nodes": [
       {"key": "epic", "type": "epic", "title": "<feature>",
        "description": "<goal + plan path>",
        "metadata": {"integration_base": "<base branch from step 4>"}},
       {"key": "t1", "type": "task", "title": "...", "parent": "epic",
        "description": "<full task content an implementer needs>",
        "acceptance_criteria": "...", "priority": 1,
        "metadata": {"execution_agent_type": "implementer",
                      "execution_suggested_model": "<from agent-roles>",
                      "execution_reasoning_effort": "<from agent-roles>",
                      "execution_parallel_group": "1"}},
       {"key": "m1", "type": "task", "title": "wave 1 interaction review",
        "parent": "epic",
        "metadata": {"execution_agent_type": "integration-reviewer",
                     "...": "..."}}
     ],
     "edges": [
       {"from_key": "m1", "to_key": "t1", "type": "blocks"}
     ]
   }
   ```

   Edge direction: **`from_key` is the dependent, `to_key` is its blocker**
   (`m1` waits for `t1`). Field names matter: `acceptance_criteria` (not
   `acceptance`), `from_key`/`to_key` (not `from`/`to`); unknown fields are
   silently dropped with a warning.

8. **Generate the HTML dependency preview**: a self-contained (no external
   assets) HTML visualization at `/tmp/<slug>-graph.html` - waves as
   horizontal layers, one node per task, integration reviews and the
   adversarial reviewer
   visually highlighted, edges drawn between layers. Reference its path from
   the plan doc so the human can eyeball the parallelization before
   approving.

9. **Persist to `~/.omnigent/plans/`** (symlinked to `config/omnigent/plans/`
   in the dotfiles, so plans survive across sessions and machines). Filename:
   `<yyyymmdd-HHMMSS>-<short-slug>.md` plus the `.graph.json` sibling. Under
   omnigent, use `sys_os_shell` for these writes - `sys_os_write`/`sys_os_edit`
   are confined to the environment root and cannot reach `~/.omnigent/...`:

   ```sh
   mkdir -p ~/.omnigent/plans
   cat > ~/.omnigent/plans/20260722-143000-auth-refactor.md <<'EOF'
   # <plan content>
   EOF
   ```

10. **Stop for approval.** Show the human a short summary (goal, approach,
    task count, wave count / max width, biggest risk) plus the plan file's
    path and the HTML preview's path, then end your turn. State plainly: on
    approval, `/swarm` will materialize this graph as a beads epic - **no
    beads issues are created during planning**. (If the user said "no beads",
    skip the graph artifact and say so.) Do not start execution in the same
    turn - planning mode's whole point is a human checkpoint between "we know
    what to do" and "we're doing it".

## Solo fallback

No sub-agents available: do a single, appropriately scoped read-only pass
yourself (files, `git log`, existing docs), then still grill (step 4), apply
the breakdown rules, write the plan + artifacts, and stop for approval. Say
plainly in "Current state" that the findings weren't cross-checked by
independent explorers, so the human knows it carries less confidence.
