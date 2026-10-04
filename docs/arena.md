# Arena — 2026-10-04

Written by `make arena SEEDS=30` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 50.0 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 334 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 31,20 41,92 52,16; at the end: 46,23 48,40 54,01. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
The build has the hazards (SH10: cargo, railing damage) and the network seam (SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner itself, so the milliseconds are sim and bots, with no snapshots sent.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; an opponent is in sight when no wall, deck or hull stands between their eyes (Surfaces.line_of_sight, the bots' and the HUD's question); dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 93.3% | met |
| No spawn slot wins more than 1.6× its fair share | 1.33× | met |
| ≤ 10% of matches reach the plunge with three or more dry | 6.7% | met |
| Median length 2:30–3:20 | 02:14 | **missed** |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 4.13 ms, p99 31.61 ms | **missed** |
| Sim + bots p99 ≤ 16 ms per tick at sixteen seats | 42.06 ms | **missed** |
| No bot idle more than 3 s with an opponent in sight within 6 m | 3.7 s (normal: seed 14 seat 2 at (-14.4, 1.2, -0.9), 03:15.2) | **missed** |
| normal: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.04 s (longest 1.4 s, seed 27 seat 6) | met |
| hard-easy: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.15 s (longest 1.7 s, seed 25 seat 5) | met |
| sighted: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.05 s (longest 1.0 s, seed 2 seat 5) | met |
| sixteen: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.06 s (longest 1.0 s, seed 10 seat 3) | met |
| Win-share gap, omniscient minus sighted (R16, reported) | +0.0 points | — |

## Eight normal bots — the default match

- Matches: 30 (seeds 1…30), 744 s of wall time.
- Length: median 02:14, mean 02:18; draws 0.
- Reached the plunge with three or more dry: 2 of 30 (6.7%).
- Wins by spawn slot (fair share 12.5%): 0: 13.3%, 1: 13.3%, 2: 16.7%, 3: 13.3%, 4: 3.3%, 5: 16.7%, 6: 16.7%, 7: 6.7%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 37 railing sections broken, 1.2 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.04 s a bot a match; longest 1.4 s (seed 27 seat 6).
- Longest idle streak: 14.2 s (seed 17 seat 4 at (-1.6, 2.5, 0.9), 02:47.9).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 14 seat 2 at (-14.4, 1.2, -0.9), 03:15.2).
- Sim + bots per tick, 8 seats: p50 4.13 ms, p99 31.61 ms, mean 5.82 ms, worst 166.3 ms.

## Four hard and four easy

- Matches: 30 (seeds 1…30), 897 s of wall time.
- Length: median 02:21, mean 02:21; draws 0.
- Reached the plunge with three or more dry: 5 of 30 (16.7%).
- Wins by spawn slot (fair share 12.5%): 0: 23.3%, 1: 13.3%, 2: 26.7%, 3: 10.0%, 4: 3.3%, 5: 13.3%, 6: 3.3%, 7: 6.7%.
- Wins by tier: hard 93.3%, easy 6.7%.
- Cargo: 1 exits credited to a crate; 42 railing sections broken, 1.4 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.15 s a bot a match; longest 1.7 s (seed 25 seat 5).
- Longest idle streak: 9.7 s (seed 12 seat 0 at (-1.2, 4.7, -0.0), 01:05.4).
- Longest idle streak with an opponent in sight within 6 m: 3.5 s (seed 12 seat 4 at (11.9, -4.2, -6.6), 00:44.8).
- Sim + bots per tick, 8 seats: p50 4.76 ms, p99 32.04 ms, mean 6.86 ms, worst 245.1 ms.

## Four sighted and four omniscient, all normal

- Matches: 30 (seeds 1…30), 895 s of wall time.
- Length: median 02:17, mean 02:25; draws 0.
- Reached the plunge with three or more dry: 0 of 30 (0.0%).
- Wins by spawn slot (fair share 12.5%): 0: 10.0%, 1: 6.7%, 2: 10.0%, 3: 20.0%, 4: 3.3%, 5: 20.0%, 6: 6.7%, 7: 23.3%.
- Wins by tier: normal 100.0%.
- Wins by sight: sighted 50.0%, omniscient 50.0%.
- Cargo: 0 exits credited to a crate; 48 railing sections broken, 1.6 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.05 s a bot a match; longest 1.0 s (seed 2 seat 5).
- Longest idle streak: 8.1 s (seed 13 seat 4 at (-2.4, 2.5, 1.4), 02:43.5).
- Longest idle streak with an opponent in sight within 6 m: 3.6 s (seed 17 seat 0 at (11.8, -2.0, -8.2), 01:26.0).
- Sim + bots per tick, 8 seats: p50 5.07 ms, p99 27.32 ms, mean 6.64 ms, worst 196.3 ms.

## Sixteen normal bots — timing only

- Matches: 10 (seeds 1…10), 466 s of wall time.
- Length: median 02:21, mean 02:16; draws 0.
- Reached the plunge with three or more dry: 0 of 10 (0.0%).
- Wins by spawn slot (fair share 6.2%): 0: 10.0%, 1: 0.0%, 2: 10.0%, 3: 0.0%, 4: 10.0%, 5: 0.0%, 6: 10.0%, 7: 10.0%, 8: 0.0%, 9: 0.0%, 10: 20.0%, 11: 10.0%, 12: 10.0%, 13: 0.0%, 14: 10.0%, 15: 0.0%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 23 railing sections broken, 2.3 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.06 s a bot a match; longest 1.0 s (seed 10 seat 3).
- Longest idle streak: 21.1 s (seed 3 seat 5 at (-18.9, 1.2, -2.0), 02:30.2).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 4 seat 11 at (-25.3, -5.0, -4.2), 01:07.6).
- Sim + bots per tick, 16 seats: p50 8.52 ms, p99 42.06 ms, mean 11.15 ms, worst 186.6 ms.

