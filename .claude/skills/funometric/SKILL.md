---
name: funometric
description: Measure whether the game is fun and say why — play matches yourself with `make play` keeping a fun journal, scan bots-only and played matches headless for pacing, interaction, agency, dead air, comebacks and spectacle, and publish a report that ties each verdict to evidence. Use when the user invokes /funometric [ship] [focus], or asks "is it fun?", "what is fun or not and why", "rate the fun", "where is the game boring".
---

# /funometric — play it, measure it, say what is fun and why

`/playtest` hunts bugs. This one judges **fun**: what a player enjoys, what bores or
frustrates them, and the cause, each finding backed by what you felt while playing *and*
what the sim measured. No code fixes come out of it: fun is design, so the end is a
report and, for the strongest findings, `needs-triage` issues.

`$ARGUMENTS` may name a ship (default: the steamer, then one other) and a focus ("the
opening", "the final two", "swimming", "bonuses"). Read the memories `play-tool`,
`keep-context-lean` and `windows-window-lock-leak` first: the play tool's traps hold here.

## The two halves

| Half | Tool | Tells you |
|---|---|---|
| **Feel** | `make play`, a seat played by turns, with a journal | what it is like: confusion, tension, joy, boredom, unfairness — the why |
| **Measure** | `scripts/fun_scan.gd` (via `scripts/fun.sh`) on bots-only matches and on your own replays, judged by `scripts/fun_report.py` | how often, how long, how general: whether what you felt is the game or one match |

Neither is enough alone. A feeling from one match is an anecdote until the scan shows it
across seeds; a number is only a suspicion until playing shows what it is like.

## 1. Baseline — measure first (headless, beside the window)

From an imported checkout (your own worktree, or a detached `play` one):

```sh
S=.claude/skills/funometric/scripts
for seed in 1 2 3; do $S/fun.sh OUT steamer $seed 8 normal; done   # ~45 s a match
python3 $S/fun_report.py OUT/*.fun
```

At most three engines at once. Three seeds per ship at least; the liners take minutes a
match. Read the report's unfun rows: they are what to look for while playing.

What the scan measures, per seat, from the live start: first contact (an opponent within
3 m), time near an opponent (within 6 m, same hull piece), the longest stretch with no beat
(a beat: a shove given or taken, a fall, into or out of the sea, a bonus, a grab, an
opponent coming near), shoves, close calls (climbed out and lived 10 s more, or a Double
life spent), how it went out (shoved = a player has the credit; cold; with her), time
spent watching once out; per match: the first out, the gaps between outs, the final two's
time and shoves, the ship's spectacle beats and their longest gap, and a 15 s heat strip.

## 2. Play — feel it, write it down as it happens

`PLAY_LIMIT=5400 PLAY_IDLE=1200 make play SHIP=steamer SEED=11 RES=1152x648
ARGS=--language=en` in the background, then `timeout 580 tools/play.sh '<cmds>'` per
turn (commands: top of `scenes/game/play_driver.gd`). Play **to win**, as a player would:
go somewhere, pick fights, flee the water, take bonuses, try to be last one dry. Play at
least two whole matches with different plans (one aggressive, one cautious, or one
chasing bonuses) — a single style only measures that style.

Moving by turns is clumsy; two helpers take the clumsiness out of the judgement:
`python3 $S/hunt.py ["wait 10"]` runs at the nearest rival on your level and shoves;
`python3 $S/hunt.py guard` faces them braced and shoves only one in reach;
`python3 .claude/skills/playtest/scripts/go.py X Z` walks a leg. Loop them a few turns
at a time, printing only the `match:` / `me:` lines and the events, and stop the loop the
moment the answer says `me: SWIMMING` — then play that moment by hand (swim for the hull,
try to climb: the cold leaves about four seconds). A turn's mouse look lands a frame
later, so act after `wait 2`, never in the frame of the `turn`. What a helper gets wrong
(steering into a deckhouse, a rival that out-turns you between turns) is the tool's
limit, not the game's: do not journal it as a controls problem unless a player with a
mouse would hit it too.

On the menu, set the seed by clicking the field and erasing what is there first
(`key BackSpace` a few times) — typing adds to the seed shown. The replay's file name
carries the seed that was played.

Keep the journal in the scratchpad as a TSV, one line per moment worth a feeling, written
*right after the turn* it happened in, never reconstructed at the end. Its first line
names the match it is about (the replay's name, filled in once the match is over):

```
# replay: 2026-11-26_20-13-57_steamer_11
t_s	feel	axis	moment	why	shot
12	+1	opening	ran aft, first opponent at the funnel	a choice of where to fight	0003_aft.png
41	-2	agency	shoved over the rail from behind, never saw him	no warning, no counterplay	0007_rail.png
```

- `t_s`: the HUD clock's seconds (it counts the countdown; the report moves them onto the
  scan's clock, which starts at Go).
- `feel`: −2 hated it, −1 dull or annoying, 0 neutral, +1 enjoyed, +2 loved it.
- `axis`: one of `opening`, `interaction`, `agency`, `clarity`, `tension`, `dead-air`,
  `comeback`, `spectacle`, `fairness`, `controls`, `spectating`, `ending`.
- `why`: the cause as a player would put it. "Felt bad" is not a why; "lost to a shove I
  could not see coming" is.

Take a shot at each strong moment (±2); a sheet (`playtest/scripts/sheet.py`) per match,
not single frames. Also note, once per match: *would I press Rematch now, and why?*

When the match ends, copy its replay out before anything else:
`captures/play/home/LastOneDry/replays/*.replay` (newest), then measure your own seat:

```sh
$S/fun.sh OUT replay path/to/that.replay
```

## 3. Judge — feel against measure

```sh
python3 $S/fun_report.py OUT/*.fun --journal m1.tsv --journal m2.tsv
```

The report lists every axis for all seats and for your seats, the pacing strips, and
your best and worst moments with the sim's beats within 3 s of each. Then, for each axis:

- **Felt and measured agree** (an unfun row, and journal lows on that axis): a finding.
  Name the cause in game terms, and the evidence: journal lines, the scan's numbers, a sheet.
- **Measured, not felt** (an unfun row, nothing in the journal): play once more with that
  axis as the focus. Still not felt: the band is wrong — change it in `fun_report.py` and
  say why in the commit.
- **Felt, not measured**: the scan lacks a measure. Note it; add one to `fun_scan.gd` when
  it recurs (a feeling twice in two matches).
- **Fun**: say what works, and why. A report that only lists problems hides what must
  not be broken by the fixes.

The bots stand in for players (D10), but they do not get bored, flee or hide: a bot-only
number about *behaviour* (time near, first contact) says what the game lets happen, your
own seat's number says what a person does with it.

## 4. Report — published, with recommendations

Publish the report as an artifact (Artifact tool, quickstart first): a verdict line ("fun
when …, unfun when …"), the axis table, the three strongest fun findings and the three
strongest unfun ones (each: what a player feels, why, the evidence, how often across the
seeds), the pacing strips, and recommendations: each one a design change worded as a
hypothesis the funometric can re-test ("a 10 s grace before the first shove should raise
first contact to 5–10 s without lifting the lulls").

File each strong unfun finding as a GitHub issue labelled `needs-triage` (search open
issues first; bundle small ones on one issue), with the evidence and the re-test. Give
the user the report link and the issue numbers. Change nothing in the game.

## Re-test

After a design change lands, run the same seeds and the same play plans, and put the old
and new reports side by side. Keep the logs of each run in the scratchpad named by date.
