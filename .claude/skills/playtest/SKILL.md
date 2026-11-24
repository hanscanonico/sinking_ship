---
name: playtest
description: Improve the game on your own — play it with `make play`, sweep it headless, and fix, review and merge every bug found, in a loop until a stop time. Use when the user invokes /playtest [until HH:MM | N hours] [focus], or asks you to "play the game and fix what you find", "improve the game by yourself", "polish it overnight" or "keep finding and fixing bugs".
---

# /playtest — find what a player would hit, fix it, merge it, go again

You run the loop alone: **hunt → triage → fix → review → merge → re-check in the game**.
No new features and no balance changes: polish and bugs. It is the loop of the night of
2026-11-21/22 (about 40 PRs, #748–#797); what is written here is what worked then.

`$ARGUMENTS` may give a stop time ("until 11:00", "3 hours") and a focus ("the freighter",
"swimming", "French UI"). No stop time: run until the user stops you. Read the clock with
`date`, never from memory. "Finish current PRs and stop" means: start nothing new, land
what is open, clean up, report.

CLAUDE.md's rules hold throughout (own worktree per branch, a failing test with every
bugfix, `make verify-changed`, `tools/merge_train.sh`, one game window). Memory holds the
machine's traps: read `play-tool`, `replay-forensics`, `agent-cap-four` and
`keep-context-lean` before starting.

## Set up once

1. A play checkout, reused all session: `git worktree add --detach
   ../sinking_ship-worktrees/play origin/main`, then `make import` and `make native` in
   it. Before each hunt: `git fetch -q && git checkout -q --detach origin/main && make
   import` (a new `class_name` on main kills the session otherwise).
2. A status file in the scratchpad: one line per PR, issue, running agent and what was
   already covered. Update it as things change; after a compaction it is the state.
3. `gh issue list --state open --limit 200` once, so known problems are not hunted again.
   Keep a short "already known / fixed this session" list: every hunt brief ends with it.

## Keep the context lean — the session compacts, the status file carries it

A night's loop outgrows any context. Plan for compaction instead of fighting it:

- **The status file is the memory.** Write it so a fresh context could pick up from it
  alone: stop time, focus, play checkout path, every open PR / issue / agent / train with
  its state and next step, areas covered, the known list. Update it *before* each
  checkpoint below, never after.
- **Checkpoints.** After each merge, each finished agent, and each finished hunt: update
  the status file, then carry nothing forward in your head. Those are the moments the
  harness may compact (auto-compaction runs when the context fills); a compaction there
  loses nothing.
- **After a compaction** (or a resumed session): re-read this SKILL.md and the status
  file, `date`, `gh pr list --author @me --state open`, and carry on from the status
  file's next steps. Do not re-hunt what it lists as covered.
- **Heavy reading goes to agents.** Hunts, log forensics, traces and frame review run in
  agents; each brief caps the reply ("at most 40 lines, findings only, paths not
  contents"). Read only the reply.
- **Never pull bulk into the main context:** logs by `tail -n 40` or `grep`, never whole;
  CI failures through `tools/ci_wait.sh` (it reports only what failed); frames only as
  `sheet.py` sheets, at most one sheet per finding; `scan_totals.py` output, not raw scan
  files; `git diff --stat` before any full diff.
- **Background, not foreground**, for anything long (`merge_train.sh`, `verify-changed`,
  scans): wait for the notification, never poll output files.

## Hunt — four ways, cheapest first

Only one hunt can hold the game window; the headless ones run beside it. Agents: one at a
time by default; with the user's go-ahead, one window agent plus one or two headless ones.

| Hunt | Window | Finds |
|---|---|---|
| **Text audit** — every screen laid out headless in a 1152×648 SubViewport under en, fr, es; each Label's text width against its laid-out size; msgids missing from `locale/*.po` | no | clipped, overflowing, untranslated text |
| **Sim scan** — many bots-only matches, every tick checked for what cannot be right | no | teleports, bodies through walls, state flicker, event spam, stuck bots, matches with no end |
| **Play sweep** — a seat played through `make play`, 30–60 minutes on one theme | yes | everything a player meets: HUD, feed, prompts, results, replays, water, art |
| **Fix re-check** — the merged fixes of the last hours, each reproduced in real play | yes | regressions; a fix that passes its test and fails in the game |

What paid off, in order: UI in French and Spanish and in 4:3; lists and results after a
match (results at 16 seats, replays list, place plate); playing a whole match as a seat;
the sim scan (it found the bug class behind every wall fix); re-checking the night's own
merges (three of them regressed something). What did not: touring interiors as the ghost
with nothing to look for.

Sweep themes that each found something: going overboard and getting back; bonuses; shove
and brace; every ending and what Rematch / Watch replay / Menu do from it; the replay
viewer and spectating; online against a local server; a first-time player with default
choices; each big ship's whole sinking with `FAST=1 GOAL=survival`; swimming and wading
after any physics change. Give a sweep one theme and one or two ships, not the game.

### Playing (yourself or a sweep agent)

- `PLAY_LIMIT=5400 PLAY_IDLE=1200 make play SHIP= SEED= SEATS= RES=1152x648
  ARGS=--language=en` with `run_in_background`; then one `timeout 580 tools/play.sh
  '<cmd>; <cmd>'` per turn. Commands are listed at the top of
  `scenes/game/play_driver.gd`. `timeout 60 tools/play.sh quit` ends it; never `quit`
  with no session up.
- Seats: tug 6, trawler/barque/steamer 8, ferry 10, freighter 12, liners 16. Too many and
  the session dies at once: read the first turn's answer.
- The answer's `me:` / `ghost:` line gives state, ship-space position (x forward, y up,
  z starboard) and facing. `python3 .claude/skills/playtest/scripts/go.py X Z ["cmds"]`
  walks one leg. A ship's map: `"$GODOT" --headless --path . -s
  "$(cygpath -m "$PWD")/.claude/skills/playtest/scripts/ship_map.gd" -- --ship=tug`.
- Frames cost about 1k tokens each: `python3 .claude/skills/playtest/scripts/sheet.py
  OUT.png A.png B.png …` tiles up to six; read the sheet, then crop at full size before
  calling anything a bug. The hand-drawn HUD is only in frames.
- In water a seat lasts about 4 s. Out, key B is the ghost: it walks the flooding ship
  unharmed but never swims. Watch + key E between shots gives every seat's view in a turn.
- Copy evidence (frames, `captures/play/out/*.txt`, the replay) to the scratchpad before
  starting another session: the answers are wiped.

### Sim scan

From an imported checkout, at most 3 engines at once:
`.claude/skills/playtest/scripts/scan.sh OUT SHIP SEED SEATS MODE` per match (MODE
`normal|fast|survival|survival+fast`), then `python3 …/scan_totals.py OUT -e`. Ten seeds
for the small ships, three for the liners (a Titanic match takes about an hour scanned).
`sim_scan.gd` was written against main of 2026-11-22: when it stops loading, fix it in the
skill, in its own PR. Raw hit counts are mostly noise (swimmers beside a heeled hull read
as below her; chairs sliding 80 m down a 37° deck pass 30 m/s honestly): a finding is a
trace, `--x-trace=FROM:TO:SEAT`, that shows an impossible tick. Prove a detector live on a
planted case (`--x-plant=`) before reading its silence as clean. After a batch of sim
fixes lands, rerun the same matches and compare the counts.

### A hunt brief (report-only agent, `general-purpose`)

State: report-only, no commits, no issues, no tracked edits; the one checkout to work in;
window or headless only; the theme, in order, "stop when time is up"; the known list;
and what must come back — findings most serious first, each with what a player sees, the
smallest steps (ship, seed, seats, mode, clock, position), the evidence paths, how often
it was reproduced, and "seen" kept apart from "inferred". Ask it to end every session and
leave no Godot process.

## Triage — every finding gets one of four ends

1. **Small and clear** (wording, a missing translation, a clipped label, a wrong title):
   fix it yourself, now, while agents hunt.
2. **A real bug with a cause to find** (sim, physics, rendering): one `implementer` agent,
   one bug per brief. Give it the reproduction and the per-tick trace, your guess marked
   as a guess ("find the real cause"), and the escape hatch: "if the cause needs a design
   decision or a large rewrite, do not force a fix: report the cause, the options and a
   minimal failing test."
3. **Balance, design, or a matter of taste**: an issue with the evidence, not a fix.
   Bundle small polish items on one running issue rather than one each.
4. **Not reproduced, or by design**: drop it, and note it in the status file so the next
   hunt does not bring it back.

Never batch unrelated fixes in one PR; do batch one cause's several symptoms.

## Fix

- A failing-first test that builds the situation small and directly, not by loading the
  replay. Check it fails without the fix.
- A sim change also reports `make exactness` against main on two or three matches:
  identical, or different only from the tick the bug first acts. Different from tick 1
  is a red flag. A changed golden is regenerated from the CI run (`make goldens RUN=`).
- Code with a native twin under `native/` changes on both sides or says why not.
- A UI or art change is looked at in the game, in the language and window size it was
  found in, before it merges; leave it a draft until the window is free.

## Review and merge

- Any PR that changes `core/`, `ai/` or `native/` behaviour gets a `reviewer` agent before
  it merges. Twice the reviewer found a real defect in the fix, and once a regression in
  the PR before it. UI, wording and translation PRs merge on their test, CI and your own
  look in the game.
- Merge through `tools/merge_train.sh N [N…]` in the background, about 9 minutes a PR.
  A red train: read the failing log. An engine abort at exit after every test passed is
  the known flake (#726): rerun the shard. Two sim PRs green apart can move a golden
  together: regenerate and requeue.
- After a merge: `tools/prune_worktrees.sh --remove`, and stop any Godot or server
  process a finished agent left behind.

## Re-check, then go again

Every few merges, a fix re-check sweep on current main: each fix reproduced by its
original steps, answered "fixed / not fixed / could not reach", then a look round what
the fix touched. A regression found there goes to the front of the queue. Then pick the
next hunt: an area not yet covered, or the scan again after sim fixes.

While agents and the train run, do the small fixes of end 1; when nothing is yours to do,
wait for the notification rather than polling.

## Report

A status every hour or two, and a final one: merged PRs with what each changes for a
player, issues filed, what is still open and why, which fixes were not confirmed in real
play, and which went in without a reviewer. Save to memory only what would change the
next session's hunt.
