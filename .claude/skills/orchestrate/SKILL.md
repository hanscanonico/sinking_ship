---
name: orchestrate
description: Make the session model (Fable) orchestrate instead of working — any task the user gives is delegated to Opus subagents with effort set by role (scouts low, implementers medium with one retry at high, reviewers high, QA low), using the agent kit in `.claude/agents` and the `improve` workflow. Use when the user invokes /orchestrate <task>, asks you to "delegate this", "don't do it yourself", or "spawn agents for this".
---

# /orchestrate — delegate the given task, never do it

The session model is the ORCHESTRATOR and does not implement, research or review directly.
Everything substantive goes to the agents in `.claude/agents/`, every one on the latest
Opus available (`model: opus` — the alias, never Fable, never a dated Opus id), effort set
by role: `scout` low, `implementer` medium (the `improve` workflow retries once at high on
a red gate or a reject), `reviewer` high, `qa` low. Main-loop work is only: understanding
the ask, splitting it, launching agents, reading their structured results, merging when
authorized, and short user-facing summaries.

Direct work is allowed only for trivia: single-file config/memory/doc edits, git and gh
plumbing, small reads for triage.

## Loop

1. **Understand.** Read `$ARGUMENTS` (the task). If the task needs codebase knowledge you
   don't already hold, spawn 1–3 `scout` agents (`subagent_type: 'scout'`) to research it
   and return diff-concrete specs: title, files, spec, verification, risk, size (S/M, one
   agent ≤90 min). Don't read across the repo yourself.
2. **Split.** Cut the task into disjoint slices — no two slices in one batch may share a
   hot file (a scene or core class several slices would touch, shared test helpers,
   CLAUDE.md). A small task is one slice. Write each slice's spec to a scratchpad file the
   brief points at. Check `git worktree list` first; never scope into an area another
   session owns. A slice that must build on another goes in the same batch with
   `after: ['<slug>']` rather than in a later run by hand: it starts once that slice is
   approved and branches from its branch. Scout lines tagged UNVERIFIED stay tagged in
   the spec, so the implementer re-derives them.
   When the gate's or the captures' tools are flaky — a guard exiting non-zero on a clean
   run, a stale lock — the batch's first slice fixes the tool, and the slices that need
   it go `after` it. Briefs never tell an agent to work around a tool with an env var
   (`ENGINE_GUARD_IGNORE`, a raised `TEST_SLOTS`).
3. **Run.** `Workflow({ name: 'improve', args: { label: '<batch name>', tasks: [{slug,
   task, reviewNote, after}...], concurrency, stagger_seconds, trailers: <this session's
   commit trailers>, footer: <this session's PR footer> } })` —
   each slice becomes one PR by an `implementer` agent, adversarially reviewed in the same
   worktree by a `reviewer` agent, with one retry at high effort on a red gate (the
   implementer's `local_gate` anything but `completed`) or a reject.
   Always pass `label` (e.g. `'water batch 6'`): every run is named `improve`, and the
   label is what tells batches apart in agent labels (`impl:<label>/<slug>`), the
   narrator line and the returned `summary`. `concurrency` (default 3) caps implementers
   + reviewers at once and `stagger_seconds` (default 60) spaces their starts — this is
   a shared 16 GB machine; raise neither without a reason. Unknown or cyclic `after`
   slugs fail the run before any agent starts.
   Use the workflow even for a single slice: the Agent tool has no effort override, so a
   direct `implementer` → `reviewer` pair cannot retry at high — reserve that pair for a
   slice where no retry would be wanted. Non-code deliverables (a report, a measurement, a
   doc) go to a `scout` when they are read-only, otherwise to a `general-purpose` agent
   (`model: 'opus'` as always, the session's effort) with the same spec shape and a structured return.
4. **Merge.** The run returns `{ label, summary, results }`; each result carries `verdict`
   (approve | reject | verify_failed | gate_timed_out | abandoned | unreviewed | no_result
   | skipped | error) and, on the last attempt's `impl`, `local_gate` and `ci_green`
   (`verify_pass` is only `local_gate == 'completed'`, kept for older readers). A
   `skipped` result names its blocker in `reason` (`after:<slug> <verdict>`).
   **Merge only if the user has authorized merging**; otherwise leave PRs open and report
   them. A slice is mergeable when `local_gate` is `completed`, the verdict is `approve`,
   AND you have yourself read CI's verify check as concluded success on the PR head
   (`gh pr view N --json statusCheckRollup`) — `ci_green` is only what the implementer
   saw when it reported. Merge sequentially, dependencies first: `gh pr merge N
   --squash`; on a stale-branch error `gh pr update-branch N`, wait ~25s, retry. After a
   merge, `gh pr update-branch` every PR that was `after` it and wait for its CI again. After each merged branch:
   `git -C <main checkout> worktree remove <worktree>`, using the `worktree` path the
   implementer returned, then delete the local branch. Without `--force`: a refusal means
   uncommitted files, so stop and report them. A worktree whose PR is not merged stays.
5. **QA.** After UI-touching work, once the repo has a `make smoke` capture sweep, spawn a
   `qa` agent over main — swept from a detached, imported worktree at origin/main, never
   the main checkout itself: `make smoke`, then the frames read as images — a
   sweep that only checks a frame was written passes a blank one. Until that target
   exists, skip QA and say so in the wrap-up.
6. **Wrap.** Summarize what shipped, what is open, and what the agents found wrong with
   the ask; record durable findings in memory.

## Hard rules

- Nothing merges without all three: the implementer's `local_gate` `completed` (its
  `make verify-changed` seen to end green — `timed_out` is not green), CI's full
  `make verify` green on the PR head as you read it yourself, AND reviewer approve — on a
  retried slice, the retry's own gate, CI run and review. `make verify` stays runnable locally; CI is where
  it gates.
- One retry, never more: a slice still red or rejected after its high-effort attempt is
  reported to the user, not re-queued.
- Reviewers verify claims independently and may push small fixes; fundamental problems
  are rejected, never rewritten in review.
- An honest "this task is wrong / already done" report from an agent is relayed to the
  user, not overridden.
- Balance numbers move only with measurement.
- If you catch yourself opening source files to implement or review, stop and delegate.
