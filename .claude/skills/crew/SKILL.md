---
name: crew
description: Plan and test the online multiplayer mode with several Claude agents, one at each seat of the same match — `make crew` brings up a local server and N play sessions on one lockstep clock, and this session plans the scenarios, spawns one agent per seat, and turns what they report into issues. Use when the user invokes /crew [N] [focus], or asks for "agents to test multiplayer", "several Claudes playing online together" or "a multiplayer test party".
---

# /crew — N agents, one online match, a plan and a report

You are the **organiser**: you plan, start the crew, brief one agent per seat, watch,
and report. The agents play; you do not take seats yourself (except to unblock one).

`$ARGUMENTS` may give N (seats, 1–8; default 3) and a focus ("quick game", "host
leaves", "shoves between people", "rejoin after a drop"). CLAUDE.md's rules hold: your
own worktree, one game window (the crew takes the lock once for all its windows), and
the owner's agent count — the user asking for N agents is the ask.

## The tool

`make crew N=3 [HEADLESS=1] [FREE=1] [RES=640x360] [SEED=1701] [WS_PORT=47941]`, run in
the background from a checkout that has had `make import`: a `--server` on 127.0.0.1 and
N `make play` sessions, seat K named Ada, Bea, Cal, Dee, Eve, Fay, Gus, Hal, each on the
server's Online screen. Everything runs on one **CrewClock**: frame by frame together.

- A turn at seat K: `timeout 580 tools/crew.sh K '<commands>'` — the commands and the
  answers of `tools/play.sh` (`click "TEXT"`, `type`, `hold ACTION`, `wait N`, `until
  text|live|over|out`, `shot`, `turn`, …; `tools/play.sh` with no argument lists them).
- **Held** seats (the default): between its batches a seat's game stands still, and
  so does the whole crew — server included — until its next batch comes. No one's
  match goes on while an agent thinks. Use it in the match, for anything timed.
- **Free** seats (`tools/crew.sh free K|all`, or `FREE=1`): the game plays on between
  batches, holding nobody, at real time. Use it in the menus and whenever a seat waits
  on the others; `tools/crew.sh hold K|all` turns it back.
- The board, for planning and handing over: `tools/crew.sh say NAME 'text'`,
  `tools/crew.sh board [FROM]` (numbered lines; pass the next number to read only what
  is new). `tools/crew.sh status` says each member's frame and who the crew waits on;
  `tools/crew.sh log [LINES]` is the server's log (rooms, joins, match begins/ends, rtt).
- `tools/crew.sh quit` ends every seat and the server.

HEADLESS=1 opens no windows: cheaper, any N, but `shot` fails and positions in the
answers mean nothing — click by text only (a room code's slots are `click "Slot0"`,
then `type abcd`). Windowed, each seat's answer names its frames; keep N ≤ 4 there.

## 1. Plan — on the board, before anyone plays

Read `tools/crew.sh` and the head of `scenes/game/play_driver.gd` once. Write the test
plan as a short numbered list of **scenarios**, each with who does what and what must
be seen. Pick from the focus, or from these (one scenario per agent-run is plenty):

- Create a room; the others join by code typed in lower case; host starts; everyone
  sees the others aboard and the same match begin (server log: `match begins`).
- Quick game: everyone presses Quick game within its wait; one room, bots on the rest.
- Two people at each other: walk to the other seat (`me:` gives position and facing),
  shove, check both sides' events agree (`SHOVE_LANDED`, who fell, who went out).
- The host leaves mid-match / a player quits mid-match: their seat becomes a bot, the
  match finishes for the rest; Back to the room; the room waits again.
- Watch without a seat; results; rematch from the room; leave the room.
- A full room (N=8), a name taken twice, a wrong code, a late join while playing.

Post the plan: `tools/crew.sh say Plan '1) … 2) …'`, one line per scenario.

## 2. Start

```sh
git worktree add --detach ../sinking_ship-worktrees/crew-run origin/main   # once
cd ../sinking_ship-worktrees/crew-run && make import
make crew N=3 FREE=1        # run_in_background; FREE=1 for the menus, held later
```

Wait until its output says `all N seats up` (a first launch bakes for a minute).

## 3. Brief one agent per seat — all in one message

Spawn N `general-purpose` agents with `model: fable`, in the background, one per seat.
Each brief is self-contained; give every agent:

- its seat number and name, the worktree path, and that the crew is already up;
- the tool section above, verbatim enough to use it (turn command with `timeout 580`,
  held/free, board, status);
- the whole plan and **its own lines in it**, with the hand-overs: what it waits for on
  the board (e.g. "Ada posts `ROOM ABCD`"), what it posts when done (`Bea: step 2 done`);
- the rules: read the board between turns; **free your seat before waiting on the
  board** and hold it again once you play timed steps; keep held turns short (`wait 60`
  and look, never `until over` while others act); never `tools/crew.sh quit`; never
  edit the repo;
- the report: at most 30 lines — each finding as *what it did · what it saw · what it
  expected*, the turn numbers and frames (`captures/crew/seatK/shots/…`), and the server
  log lines that bear on it. Nothing else.

## 4. Watch

Check `tools/crew.sh status` and the board every few minutes, not more. A seat
`thinking` for minutes holds the crew: if its agent has finished or hung, `free` it. A
stuck flow (an agent waiting on a post nobody will make) is yours to unblock: `say` on
the board what to do next.

## 5. Report

When the agents are done: `tools/crew.sh quit`. Merge their findings, drop duplicates
and anything the plan expected, check each against `tools/crew.sh log` and
`gh issue list`, and give the user a short table: scenario · passed/failed · finding.
File each real bug as an issue (`needs-triage`, repro steps from the board and the
answers), or, if the user asked for fixes, hand them to `/playtest`'s fix loop. Remove
the run worktree when done.

## Traps

- One window lock: a `make play` or capture elsewhere waits behind the crew, and the
  crew behind it. HEADLESS=1 takes none.
- A crew of held seats moves only while **every** held seat has a batch running: two
  agents each waiting for the other's post with held seats is a deadlock — free one.
- Online `wait N` is N frames of the match; under the clock nobody's frames run ahead.
- A seat left without a batch for PLAY_IDLE (900 s) quits: its player leaves the room.
