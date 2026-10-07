# Arena — 2026-10-07

Written by `make arena SEEDS=50 SCENARIO=steamer_coast` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 35.3 minutes.
Every lobby here plays the default match's rules on steamer's steamer_coast scenario (data/sinking/steamer_coast.tres), in place of the open sea the rest of this says.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 141 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 8,52 8,31 9,77; at the end: 14,08 11,35 10,56. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
The build has the hazards (SH10: cargo, railing damage) and the network seam (SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner itself, so the milliseconds are sim and bots, with no snapshots sent.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; an opponent is in sight when no wall, deck or hull stands between their eyes (Surfaces.line_of_sight, the bots' and the HUD's question); dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| No spawn slot wins more than 1.6× its fair share | 1.76× | **missed** |
| ≤ 10% of matches reach the plunge with three or more dry | 0.0% | met |
| Median length 2:30–3:20 | 04:04 | **missed** |
| ≥ 70% of matches still on at the bridge collapse (SH7d's aim) | 0.0% | **missed** |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 3.55 ms, p99 18.42 ms | **missed** |
| No bot idle more than 3 s with an opponent in sight within 6 m | 34.6 s (normal: seed 11 seat 2 at (4.3, 0.0, 1.4), 14:43.4) | **missed** |
| normal: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.05 s (longest 1.4 s, seed 40 seat 5) | met |

## Eight normal bots — the default match

- Matches: 50 (seeds 1…50), 2118 s of wall time.
- Length: median 04:04, mean 04:46; draws 0; still on at 15:00 and stopped: 1.
- On steamer_coast's wreck, at rest aground with part of her dry (Q21: on until one is left): 0 of 50 matches still on when she came to rest; played on her then for a median 00:00, the longest 00:00; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 50 (0.0%).
- Still on at the first collapse (the bridge): 0 of 50 (0.0%), 0.0 seats in on average; at the plunge: 0 of 50 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 10.0%, 1: 12.0%, 2: 10.0%, 3: 18.0%, 4: 12.0%, 5: 10.0%, 6: 4.0%, 7: 22.0%.
- Wins by tier: normal 98.0%.
- Cargo: 1 exits credited to a crate; 49 railing sections broken, 1.0 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.05 s a bot a match; longest 1.4 s (seed 40 seat 5).
- Longest idle streak: 34.6 s (seed 11 seat 2 at (4.3, 0.0, 1.4), 14:43.4).
- Longest idle streak with an opponent in sight within 6 m: 34.6 s (seed 11 seat 2 at (4.3, 0.0, 1.4), 14:43.4).
- Sim + bots per tick, 8 seats: p50 3.55 ms, p99 18.42 ms, mean 4.30 ms, worst 310.0 ms.

