# Arena — 2026-10-04

Written by `make arena SEEDS=30` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 27.3 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 182 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 30,73 58,16 74,79; at the end: 9,85 8,20 17,14. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
The build has the hazards (SH10: cargo, railing damage) and the network seam (SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner itself, so the milliseconds are sim and bots, with no snapshots sent.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; an opponent is in sight when no wall, deck or hull stands between their eyes (Surfaces.line_of_sight, the bots' and the HUD's question); dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 80.0% | met |
| No spawn slot wins more than 1.6× its fair share | 2.13× | **missed** |
| ≤ 10% of matches reach the plunge with three or more dry | 6.7% | met |
| Median length 2:30–3:20 | 02:31 | met |
| ≥ 70% of matches still on at the bridge collapse (SH7d's aim) | 83.3% | met |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 3.58 ms, p99 12.26 ms | **missed** |
| Sim + bots p99 ≤ 16 ms per tick at sixteen seats | 16.62 ms | **missed** |
| No bot idle more than 3 s with an opponent in sight within 6 m | 3.7 s (sixteen: seed 1 seat 14 at (-18.9, -4.5, 5.7), 01:40.2) | **missed** |
| normal: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.02 s (longest 1.1 s, seed 18 seat 4) | met |
| hard-easy: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.10 s (longest 1.6 s, seed 3 seat 3) | met |
| sighted: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.03 s (longest 1.0 s, seed 8 seat 4) | met |
| sixteen: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.04 s (longest 1.1 s, seed 2 seat 2) | met |
| Win-share gap, omniscient minus sighted (R16, reported) | -6.7 points | — |

## Eight normal bots — the default match

- Matches: 30 (seeds 1…30), 538 s of wall time.
- Length: median 02:31, mean 02:36; draws 0.
- Reached the plunge with three or more dry: 2 of 30 (6.7%).
- Still on at the first collapse (the bridge): 25 of 30 (83.3%), 2.6 seats in on average; at the plunge: 13 of 30 (43.3%), 2.2 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 13.3%, 1: 3.3%, 2: 10.0%, 3: 13.3%, 4: 16.7%, 5: 10.0%, 6: 6.7%, 7: 26.7%.
- Wins by tier: normal 100.0%.
- Cargo: 1 exits credited to a crate; 38 railing sections broken, 1.3 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.02 s a bot a match; longest 1.1 s (seed 18 seat 4).
- Longest idle streak: 24.2 s (seed 16 seat 1 at (-16.0, 1.2, 0.5), 02:30.5).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 20 seat 7 at (-24.3, -6.6, -4.2), 02:27.0).
- Sim + bots per tick, 8 seats: p50 3.58 ms, p99 12.26 ms, mean 3.72 ms, worst 130.7 ms.

## Four hard and four easy

- Matches: 30 (seeds 1…30), 530 s of wall time.
- Length: median 03:01, mean 02:55; draws 0.
- Reached the plunge with three or more dry: 9 of 30 (30.0%).
- Still on at the first collapse (the bridge): 27 of 30 (90.0%), 3.6 seats in on average; at the plunge: 25 of 30 (83.3%), 2.6 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 10.0%, 1: 16.7%, 2: 10.0%, 3: 6.7%, 4: 16.7%, 5: 30.0%, 6: 6.7%, 7: 3.3%.
- Wins by tier: easy 20.0%, hard 80.0%.
- Cargo: 3 exits credited to a crate; 32 railing sections broken, 1.1 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.10 s a bot a match; longest 1.6 s (seed 3 seat 3).
- Longest idle streak: 3.8 s (seed 1 seat 2 at (-16.9, -5.2, 5.3), 00:46.6).
- Longest idle streak with an opponent in sight within 6 m: 3.5 s (seed 19 seat 1 at (-16.9, 1.2, -4.2), 03:22.6).
- Sim + bots per tick, 8 seats: p50 2.96 ms, p99 8.98 ms, mean 3.27 ms, worst 107.2 ms.

## Four sighted and four omniscient, all normal

- Matches: 30 (seeds 1…30), 340 s of wall time.
- Length: median 02:20, mean 02:27; draws 0.
- Reached the plunge with three or more dry: 1 of 30 (3.3%).
- Still on at the first collapse (the bridge): 17 of 30 (56.7%), 2.9 seats in on average; at the plunge: 11 of 30 (36.7%), 2.1 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 23.3%, 1: 16.7%, 2: 10.0%, 3: 20.0%, 4: 6.7%, 5: 6.7%, 6: 6.7%, 7: 10.0%.
- Wins by tier: normal 100.0%.
- Wins by sight: sighted 53.3%, omniscient 46.7%.
- Cargo: 0 exits credited to a crate; 50 railing sections broken, 1.7 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.03 s a bot a match; longest 1.0 s (seed 8 seat 4).
- Longest idle streak: 5.3 s (seed 2 seat 7 at (-2.8, 4.7, -0.4), 02:13.9).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 20 seat 3 at (-21.5, -4.9, -5.1), 02:05.4).
- Sim + bots per tick, 8 seats: p50 2.57 ms, p99 6.11 ms, mean 2.49 ms, worst 57.8 ms.

## Sixteen normal bots — timing only

- Matches: 10 (seeds 1…10), 229 s of wall time.
- Length: median 02:42, mean 02:35; draws 0.
- Reached the plunge with three or more dry: 0 of 10 (0.0%).
- Still on at the first collapse (the bridge): 8 of 10 (80.0%), 3.4 seats in on average; at the plunge: 6 of 10 (60.0%), 2.0 seats in.
- Wins by spawn slot (fair share 6.2%): 0: 10.0%, 1: 0.0%, 2: 0.0%, 3: 30.0%, 4: 10.0%, 5: 10.0%, 6: 20.0%, 7: 0.0%, 8: 20.0%, 9: 0.0%, 10: 0.0%, 11: 0.0%, 12: 0.0%, 13: 0.0%, 14: 0.0%, 15: 0.0%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 17 railing sections broken, 1.7 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.04 s a bot a match; longest 1.1 s (seed 2 seat 2).
- Longest idle streak: 3.7 s (seed 1 seat 14 at (-18.9, -4.5, 5.7), 01:40.2).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 1 seat 14 at (-18.9, -4.5, 5.7), 01:40.2).
- Sim + bots per tick, 16 seats: p50 4.44 ms, p99 16.62 ms, mean 4.82 ms, worst 108.7 ms.

