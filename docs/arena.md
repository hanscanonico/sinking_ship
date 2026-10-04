# Arena — 2026-10-04

These numbers were measured before the hazards (SH10) and network (SH11) milestones were merged.

Written by `make arena SEEDS=30` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 61.2 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 408 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 6,79 8,47 10,66; at the end: 14,51 15,38 16,43. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 70.0% | **missed** |
| No spawn slot wins more than 1.6× its fair share | 1.60× | met |
| ≤ 10% of matches reach the plunge with three or more dry | 53.3% | **missed** |
| Median length 2:30–3:20 | 03:02 | met |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 4.04 ms, p99 48.01 ms | **missed** |
| Sim + bots p99 ≤ 16 ms per tick at sixteen seats | 68.79 ms | **missed** |
| No bot idle more than 3 s with an opponent within 6 m | 5.2 s (hard-easy: seed 20 seat 2 at (-1.1, 4.7, 0.0), 01:50.2) | **missed** |
| Win-share gap, omniscient minus sighted (R16, reported) | +0.0 points | — |

## Eight normal bots — the default match

- Matches: 30 (seeds 1…30), 1008 s of wall time.
- Length: median 03:02, mean 02:58; draws 0.
- Reached the plunge with three or more dry: 16 of 30 (53.3%).
- Wins by spawn slot (fair share 12.5%): 0: 20.0%, 1: 13.3%, 2: 10.0%, 3: 10.0%, 4: 10.0%, 5: 6.7%, 6: 20.0%, 7: 10.0%.
- Wins by tier: normal 100.0%.
- Longest idle streak: 18.3 s (seed 11 seat 5 at (-19.6, 1.2, 0.7), 02:31.1).
- Longest idle streak with an opponent within 6 m: 3.7 s (seed 3 seat 2 at (-13.2, 0.9, 4.0), 03:08.3).
- Sim + bots per tick, 8 seats: p50 4.04 ms, p99 48.01 ms, mean 6.21 ms, worst 350.6 ms.

## Four hard and four easy

- Matches: 30 (seeds 1…30), 1137 s of wall time.
- Length: median 03:00, mean 02:53; draws 1.
- Reached the plunge with three or more dry: 16 of 30 (53.3%).
- Wins by spawn slot (fair share 12.5%): 0: 16.7%, 1: 16.7%, 2: 3.3%, 3: 10.0%, 4: 3.3%, 5: 13.3%, 6: 20.0%, 7: 13.3%.
- Wins by tier: hard 70.0%, easy 26.7%.
- Longest idle streak: 25.0 s (seed 3 seat 0 at (-1.1, 4.7, 0.0), 02:05.1).
- Longest idle streak with an opponent within 6 m: 5.2 s (seed 20 seat 2 at (-1.1, 4.7, 0.0), 01:50.2).
- Sim + bots per tick, 8 seats: p50 4.76 ms, p99 47.44 ms, mean 7.22 ms, worst 387.7 ms.

## Four sighted and four omniscient, all normal

- Matches: 30 (seeds 1…30), 842 s of wall time.
- Length: median 03:02, mean 03:01; draws 0.
- Reached the plunge with three or more dry: 17 of 30 (56.7%).
- Wins by spawn slot (fair share 12.5%): 0: 13.3%, 1: 20.0%, 2: 3.3%, 3: 20.0%, 4: 13.3%, 5: 10.0%, 6: 13.3%, 7: 6.7%.
- Wins by tier: normal 100.0%.
- Wins by sight: omniscient 50.0%, sighted 50.0%.
- Longest idle streak: 22.5 s (seed 19 seat 4 at (-14.9, 1.2, -3.7), 02:28.2).
- Longest idle streak with an opponent within 6 m: 3.7 s (seed 15 seat 6 at (-14.7, 1.2, 3.9), 03:16.2).
- Sim + bots per tick, 8 seats: p50 4.38 ms, p99 22.56 ms, mean 5.11 ms, worst 219.4 ms.

## Sixteen normal bots — timing only

- Matches: 10 (seeds 1…10), 685 s of wall time.
- Length: median 03:09, mean 03:09; draws 0.
- Reached the plunge with three or more dry: 8 of 10 (80.0%).
- Wins by spawn slot (fair share 6.2%): 0: 0.0%, 1: 0.0%, 2: 10.0%, 3: 0.0%, 4: 10.0%, 5: 10.0%, 6: 10.0%, 7: 20.0%, 8: 0.0%, 9: 0.0%, 10: 10.0%, 11: 20.0%, 12: 0.0%, 13: 0.0%, 14: 10.0%, 15: 0.0%.
- Wins by tier: normal 100.0%.
- Longest idle streak: 13.4 s (seed 7 seat 14 at (-1.6, 2.5, -0.4), 02:48.2).
- Longest idle streak with an opponent within 6 m: 3.7 s (seed 1 seat 14 at (-14.2, 1.2, 0.8), 03:14.5).
- Sim + bots per tick, 16 seats: p50 8.81 ms, p99 68.79 ms, mean 11.95 ms, worst 232.8 ms.

