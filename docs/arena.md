# Arena — 2026-10-06

Written by `make arena SEEDS=8` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 17.1 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 427 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 2,76 3,81 3,92; at the end: 7,06 5,05 4,42. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
The build has the hazards (SH10: cargo, railing damage) and the network seam (SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner itself, so the milliseconds are sim and bots, with no snapshots sent.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; an opponent is in sight when no wall, deck or hull stands between their eyes (Surfaces.line_of_sight, the bots' and the HUD's question); dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 75.0% | met |
| No spawn slot wins more than 1.6× its fair share | 2.00× | **missed** |
| ≤ 10% of matches reach the plunge with three or more dry | 0.0% | met |
| Median length 2:30–3:20 | 04:34 | **missed** |
| ≥ 70% of matches still on at the bridge collapse (SH7d's aim) | 0.0% | **missed** |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 2.30 ms, p99 5.15 ms | **missed** |
| Sim + bots p99 ≤ 16 ms per tick at sixteen seats | 12.87 ms | met |
| No bot idle more than 3 s with an opponent in sight within 6 m | 3.7 s (hard-easy: seed 4 seat 4 at (-10.5, -5.2, -5.3), 02:52.0) | **missed** |
| normal: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.14 s (longest 2.8 s, seed 7 seat 4) | met |
| hard-easy: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.10 s (longest 3.2 s, seed 6 seat 1) | met |
| sighted: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.14 s (longest 1.2 s, seed 6 seat 2) | met |
| sixteen: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.07 s (longest 3.3 s, seed 7 seat 7) | met |
| Win-share gap, omniscient minus sighted (R16, reported) | +0.0 points | — |

## Eight normal bots — the default match

- Matches: 8 (seeds 1…8), 184 s of wall time.
- Length: median 04:34, mean 04:51; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 0.0%, 1: 12.5%, 2: 0.0%, 3: 0.0%, 4: 25.0%, 5: 25.0%, 6: 12.5%, 7: 25.0%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 9 railing sections broken, 1.1 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.14 s a bot a match; longest 2.8 s (seed 7 seat 4).
- Longest idle streak: 3.7 s (seed 2 seat 3 at (13.8, -4.6, -4.9), 01:25.9).
- Longest idle streak with an opponent in sight within 6 m: 3.6 s (seed 4 seat 2 at (20.0, -6.5, -5.8), 03:44.0).
- Sim + bots per tick, 8 seats: p50 2.30 ms, p99 5.15 ms, mean 2.39 ms, worst 27.8 ms.

## Four hard and four easy

- Matches: 8 (seeds 1…8), 298 s of wall time.
- Length: median 03:48, mean 04:39; draws 0; still on at 15:00 and stopped: 1.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 25.0%, 1: 12.5%, 2: 25.0%, 3: 0.0%, 4: 0.0%, 5: 12.5%, 6: 0.0%, 7: 12.5%.
- Wins by tier: hard 75.0%, easy 12.5%.
- Cargo: 0 exits credited to a crate; 7 railing sections broken, 0.9 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.10 s a bot a match; longest 3.2 s (seed 6 seat 1).
- Longest idle streak: 3.8 s (seed 4 seat 4 at (-10.5, -5.2, -5.3), 02:52.1).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 4 seat 4 at (-10.5, -5.2, -5.3), 02:52.0).
- Sim + bots per tick, 8 seats: p50 3.13 ms, p99 7.20 ms, mean 3.21 ms, worst 57.9 ms.

## Four sighted and four omniscient, all normal

- Matches: 8 (seeds 1…8), 188 s of wall time.
- Length: median 03:37, mean 03:56; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 12.5%, 1: 12.5%, 2: 0.0%, 3: 12.5%, 4: 12.5%, 5: 0.0%, 6: 25.0%, 7: 25.0%.
- Wins by tier: normal 100.0%.
- Wins by sight: omniscient 50.0%, sighted 50.0%.
- Cargo: 0 exits credited to a crate; 11 railing sections broken, 1.4 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.14 s a bot a match; longest 1.2 s (seed 6 seat 2).
- Longest idle streak: 3.7 s (seed 3 seat 5 at (20.7, -2.9, 6.7), 02:49.4).
- Longest idle streak with an opponent in sight within 6 m: 3.5 s (seed 7 seat 1 at (17.2, -5.8, 11.1), 03:04.6).
- Sim + bots per tick, 8 seats: p50 2.89 ms, p99 5.99 ms, mean 2.96 ms, worst 57.6 ms.

## Sixteen normal bots — timing only

- Matches: 8 (seeds 1…8), 356 s of wall time.
- Length: median 05:55, mean 05:25; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 6.2%): 0: 12.5%, 1: 12.5%, 2: 0.0%, 3: 25.0%, 4: 0.0%, 5: 12.5%, 6: 0.0%, 7: 0.0%, 8: 12.5%, 9: 0.0%, 10: 0.0%, 11: 0.0%, 12: 0.0%, 13: 0.0%, 14: 12.5%, 15: 12.5%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 14 railing sections broken, 1.8 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.07 s a bot a match; longest 3.3 s (seed 7 seat 7).
- Longest idle streak: 3.8 s (seed 4 seat 5 at (18.2, -6.4, -3.7), 02:34.5).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 6 seat 10 at (-20.2, -5.6, -7.6), 01:54.3).
- Sim + bots per tick, 16 seats: p50 3.04 ms, p99 12.87 ms, mean 4.24 ms, worst 63.5 ms.

