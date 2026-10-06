# Arena — 2026-10-06

Written by `make arena SEEDS=8` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 12.6 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 316 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 3,44 4,04 4,09; at the end: 3,73 4,10 4,40. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
The build has the hazards (SH10: cargo, railing damage) and the network seam (SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner itself, so the milliseconds are sim and bots, with no snapshots sent.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; an opponent is in sight when no wall, deck or hull stands between their eyes (Surfaces.line_of_sight, the bots' and the HUD's question); dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 87.5% | met |
| No spawn slot wins more than 1.6× its fair share | 2.00× | **missed** |
| ≤ 10% of matches reach the plunge with three or more dry | 87.5% | **missed** |
| Median length 2:30–3:20 | 04:44 | **missed** |
| ≥ 70% of matches still on at the bridge collapse (SH7d's aim) | 0.0% | **missed** |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 3.13 ms, p99 12.82 ms | **missed** |
| Sim + bots p99 ≤ 16 ms per tick at sixteen seats | 8.68 ms | met |
| No bot idle more than 3 s with an opponent in sight within 6 m | 9.3 s (hard-easy: seed 6 seat 2 at (12.3, 1.8, 0.0), 04:50.0) | **missed** |
| normal: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.05 s (longest 0.6 s, seed 1 seat 3) | met |
| hard-easy: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.04 s (longest 0.7 s, seed 1 seat 1) | met |
| sighted: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.01 s (longest 0.2 s, seed 6 seat 7) | met |
| sixteen: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.01 s (longest 0.3 s, seed 4 seat 14) | met |
| Win-share gap, omniscient minus sighted (R16, reported) | +50.0 points | — |

## Eight normal bots — the default match

- Matches: 8 (seeds 1…8), 201 s of wall time.
- Length: median 04:44, mean 04:11; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 7 of 8 (87.5%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 8 of 8 (100.0%), 5.4 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 0.0%, 1: 12.5%, 2: 25.0%, 3: 25.0%, 4: 12.5%, 5: 0.0%, 6: 12.5%, 7: 12.5%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 3 railing sections broken, 0.4 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.05 s a bot a match; longest 0.6 s (seed 1 seat 3).
- Longest idle streak: 16.5 s (seed 2 seat 7 at (-1.7, 4.7, -0.2), 04:59.6).
- Longest idle streak with an opponent in sight within 6 m: 8.6 s (seed 6 seat 1 at (12.1, 1.8, 0.0), 04:49.7).
- Sim + bots per tick, 8 seats: p50 3.13 ms, p99 12.82 ms, mean 3.22 ms, worst 71.5 ms.

## Four hard and four easy

- Matches: 8 (seeds 1…8), 162 s of wall time.
- Length: median 04:40, mean 04:09; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 8 of 8 (100.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 8 of 8 (100.0%), 4.5 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 0.0%, 1: 25.0%, 2: 12.5%, 3: 25.0%, 4: 12.5%, 5: 12.5%, 6: 12.5%, 7: 0.0%.
- Wins by tier: hard 87.5%, easy 12.5%.
- Cargo: 0 exits credited to a crate; 4 railing sections broken, 0.5 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.04 s a bot a match; longest 0.7 s (seed 1 seat 1).
- Longest idle streak: 25.7 s (seed 8 seat 7 at (14.5, -2.6, 1.9), 03:42.6).
- Longest idle streak with an opponent in sight within 6 m: 9.3 s (seed 6 seat 2 at (12.3, 1.8, 0.0), 04:50.0).
- Sim + bots per tick, 8 seats: p50 2.44 ms, p99 5.79 ms, mean 2.61 ms, worst 22.1 ms.

## Four sighted and four omniscient, all normal

- Matches: 8 (seeds 1…8), 156 s of wall time.
- Length: median 04:42, mean 04:09; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 8 of 8 (100.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 8 of 8 (100.0%), 4.9 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 25.0%, 1: 12.5%, 2: 0.0%, 3: 0.0%, 4: 0.0%, 5: 37.5%, 6: 25.0%, 7: 0.0%.
- Wins by tier: normal 100.0%.
- Wins by sight: omniscient 75.0%, sighted 25.0%.
- Cargo: 0 exits credited to a crate; 5 railing sections broken, 0.6 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.01 s a bot a match; longest 0.2 s (seed 6 seat 7).
- Longest idle streak: 14.9 s (seed 4 seat 0 at (12.8, 1.8, -0.0), 04:18.5).
- Longest idle streak with an opponent in sight within 6 m: 7.9 s (seed 2 seat 3 at (12.1, 1.8, -0.0), 04:52.8).
- Sim + bots per tick, 8 seats: p50 2.48 ms, p99 4.67 ms, mean 2.51 ms, worst 18.9 ms.

## Sixteen normal bots — timing only

- Matches: 8 (seeds 1…8), 237 s of wall time.
- Length: median 04:41, mean 04:10; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 7 of 8 (87.5%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 8 of 8 (100.0%), 5.1 seats in.
- Wins by spawn slot (fair share 6.2%): 0: 0.0%, 1: 12.5%, 2: 0.0%, 3: 0.0%, 4: 0.0%, 5: 0.0%, 6: 0.0%, 7: 0.0%, 8: 0.0%, 9: 12.5%, 10: 12.5%, 11: 12.5%, 12: 0.0%, 13: 25.0%, 14: 12.5%, 15: 12.5%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 6 railing sections broken, 0.8 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.01 s a bot a match; longest 0.3 s (seed 4 seat 14).
- Longest idle streak: 22.0 s (seed 6 seat 5 at (-1.7, 4.7, -0.6), 05:04.6).
- Longest idle streak with an opponent in sight within 6 m: 4.9 s (seed 2 seat 8 at (12.1, 1.8, 0.0), 04:58.9).
- Sim + bots per tick, 16 seats: p50 3.31 ms, p99 8.68 ms, mean 3.83 ms, worst 36.0 ms.

