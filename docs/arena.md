# Arena — 2026-10-03

Written by `make arena SEEDS=60` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 95.9 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 320 minutes at this run's pace.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 58.3% | **missed** |
| No spawn slot wins more than 1.6× its fair share | 1.73× | **missed** |
| ≤ 10% of matches reach the plunge with three or more dry | 18.3% | **missed** |
| Median length 2:30–3:20 | 02:52 | met |
| Sim + bots p99 ≤ 2 ms per tick at eight seats | 30.00 ms | **missed** |
| No bot idle more than 3 s with an opponent within 6 m | 10.5 s (sixteen: seed 1 seat 8 at (3.4, 0.0, 1.5), 01:51.7) | **missed** |
| Win-share gap, omniscient minus sighted (R16, reported) | -10.0 points | — |

## Eight normal bots — the default match

- Matches: 60 (seeds 1…60), 908 s of wall time.
- Length: median 02:52, mean 02:30; draws 0.
- Reached the plunge with three or more dry: 11 of 60 (18.3%).
- Wins by spawn slot (fair share 12.5%): 0: 15.0%, 1: 13.3%, 2: 11.7%, 3: 11.7%, 4: 21.7%, 5: 6.7%, 6: 3.3%, 7: 16.7%.
- Wins by tier: normal 100.0%.
- Longest idle streak: 21.7 s (seed 52 seat 1 at (-18.9, 1.2, -3.5), 02:30.8).
- Longest idle streak with an opponent within 6 m: 10.1 s (seed 60 seat 2 at (3.4, 0.0, 1.5), 01:51.7).
- Sim + bots per tick, 8 seats: p50 1.71 ms, p99 30.00 ms, mean 3.29 ms, worst 395.0 ms.

## Four hard and four easy

- Matches: 60 (seeds 1…60), 2551 s of wall time.
- Length: median 02:58, mean 02:54; draws 0.
- Reached the plunge with three or more dry: 30 of 60 (50.0%).
- Wins by spawn slot (fair share 12.5%): 0: 10.0%, 1: 8.3%, 2: 15.0%, 3: 8.3%, 4: 8.3%, 5: 11.7%, 6: 16.7%, 7: 21.7%.
- Wins by tier: easy 41.7%, hard 58.3%.
- Longest idle streak: 21.2 s (seed 53 seat 6 at (-14.9, 1.2, 3.9), 02:31.1).
- Longest idle streak with an opponent within 6 m: 9.1 s (seed 57 seat 3 at (3.4, 0.0, 1.5), 01:54.3).
- Sim + bots per tick, 8 seats: p50 4.36 ms, p99 48.10 ms, mean 7.96 ms, worst 783.7 ms.

## Four sighted and four omniscient, all normal

- Matches: 60 (seeds 1…60), 1943 s of wall time.
- Length: median 02:43, mean 02:19; draws 0.
- Reached the plunge with three or more dry: 7 of 60 (11.7%).
- Wins by spawn slot (fair share 12.5%): 0: 16.7%, 1: 15.0%, 2: 13.3%, 3: 13.3%, 4: 8.3%, 5: 10.0%, 6: 11.7%, 7: 11.7%.
- Wins by tier: normal 100.0%.
- Wins by sight: omniscient 45.0%, sighted 55.0%.
- Longest idle streak: 20.7 s (seed 38 seat 0 at (-18.5, 1.2, -4.1), 02:29.0).
- Longest idle streak with an opponent within 6 m: 7.0 s (seed 23 seat 2 at (-12.0, 0.0, 4.6), 00:26.0).
- Sim + bots per tick, 8 seats: p50 3.37 ms, p99 52.72 ms, mean 7.56 ms, worst 1153.8 ms.

## Sixteen normal bots — timing only

- Matches: 10 (seeds 1…10), 354 s of wall time.
- Length: median 03:02, mean 02:44; draws 0.
- Reached the plunge with three or more dry: 2 of 10 (20.0%).
- Wins by spawn slot (fair share 6.2%): 0: 0.0%, 1: 10.0%, 2: 20.0%, 3: 20.0%, 4: 0.0%, 5: 0.0%, 6: 0.0%, 7: 0.0%, 8: 0.0%, 9: 30.0%, 10: 0.0%, 11: 10.0%, 12: 0.0%, 13: 10.0%, 14: 0.0%, 15: 0.0%.
- Wins by tier: normal 100.0%.
- Longest idle streak: 14.9 s (seed 5 seat 5 at (-15.0, 1.2, -3.9), 02:27.9).
- Longest idle streak with an opponent within 6 m: 10.5 s (seed 1 seat 8 at (3.4, 0.0, 1.5), 01:51.7).
- Sim + bots per tick, 16 seats: p50 4.39 ms, p99 41.87 ms, mean 7.01 ms, worst 154.4 ms.

