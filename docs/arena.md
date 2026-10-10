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

## Bench at scale — `make bench SEATS=64` (SH18)

Measured by `make bench` (tools/bench_sim.gd) on MacBookAir10,1, Apple M1, on 2026-10-09, and written here by hand; `make arena` carries this section over as it found it. Every seat is a wanderer on its own seeded dice — it walks one way for 20 to 60 ticks, turns, shoves one heading in four (let go at once or held into a charge) and jumps one in six — and no bots: bot planning on a hull this size is SH20's. The match is played once through MatchRunner, then its input log replayed through bare MatchSims, two rounds with the spatial index and two without it — IndexRules' cells and bands INF: one cell, one band, every query a scan of everything — taking turns. The milliseconds are MatchSim.step alone; no snapshot, no digest. "Without" is not the build before SH18: that one already kept the surfaces on a 1 m grid (SH3b's rooms); without is the scan the index replaces everywhere.

The fixture is tests/fixtures/titanic_scale.gd: 270 × 28 m, nine decks 2.8 m apart, nine bays a deck, a corridor between walls with a door into every room below the top deck, a stair a bay, an open railed top deck with four funnels — 2,441 surfaces and 56 railings.

| Match | Index | p50 | p99 | mean | worst |
|---|---|---|---|---|---|
| Fixture, 64 seats, 1,800 ticks | on (cells 1 m, bodies 2 m) | 3.96 ms | 9.41 ms | 4.16 ms | 44.29 ms |
| Fixture, 64 seats, 1,800 ticks | off | 117.26 ms | 146.17 ms | 117.98 ms | 196.38 ms |
| Steamer, 8 seats, 1,800 ticks | on | 0.52 ms | 0.78 ms | 0.53 ms | 1.01 ms |
| Steamer, 8 seats, 1,800 ticks | off | 1.38 ms | 2.95 ms | 1.60 ms | 3.37 ms |
| Fixture, 64 seats, 1,800 ticks | on, no bands, no scan (SH18's grid, 2026-10-09) | 3.69 ms | 5.02 ms | 3.75 ms | 27.21 ms |
| Fixture, 64 seats, 1,800 ticks | on, with height bands (2.8 m, scan over 256 cells, 2026-10-10) | 2.74 ms | 3.41 ms | 2.77 ms | 9.86 ms |
| Steamer, 8 seats, 1,800 ticks | on, no bands, no scan (2026-10-09) | 0.47 ms | 0.77 ms | 0.49 ms | 2.00 ms |
| Steamer, 8 seats, 1,800 ticks | on, with height bands (2026-10-10) | 0.45 ms | 0.72 ms | 0.47 ms | 1.27 ms |

Load average (1, 5, 15 min) at the fixture's start: 4,41 4,54 8,04; at its end: 5,36 4,48 6,50; at the steamer's end: 4,54 4,35 6,40 — other worktrees' tools were running beside it. A run an hour earlier, at much the same load, gave the fixture p50 3.39 ms and p99 7.46 ms with the index: the tail moves with the machine, and misses either way. The review's run at a quieter moment (load 2,89 3,74 5,53 at the start, 4,14 3,97 4,91 at the end) gave the fixture p50 3.84 ms, p99 4.63 ms, worst 8.49 ms with the index (without: p99 154.12 ms), and the steamer p50 0.50 ms, p99 0.74 ms — still a miss, by about a sixth rather than twice over. Both ways' digests match each other and the match played, on both ships: the index changes how fast, never what (D4).

With height bands (after SH18): the surface grid is cut into bands 2.8 m high (IndexRules.surface_band, the fixture's deck spacing) as well, each listing only the surfaces and railings whose heights reach into it, so a body's obstacle query sifts its own deck's walls rather than nine decks'; and a query reaching more than 256 cells of it (IndexRules.scan_over) — a long sight line's — is handed every surface instead, a scan cheaper than gathering so many. The rows above marked "no bands, no scan" are this build with both INF, SH18's grid, and reproduce its numbers. Both pairs ran at a quiet moment: SH18's grid at load 3,69 28,67 36,58 at the start and 4,74 10,36 24,19 at the end (draining after other worktrees' renders), the bands at 3,77 13,59 24,82 and 2,78 6,21 17,17. Every run's digests match each other and the match played — the fixture's 3c20108708d0…167a and the steamer's fea7ac9e7115…de08 whichever way — and five matches (SEED=1701, its golden 203b39497543c3d9; SEED=36; SHIP=trawler SEED=1; SHIP=steamer_weak SEED=2; SCENARIO=steamer_coast SEED=14) print byte for byte the transcripts of the build before the bands.

A sight line on the fixture, per call, both eyes on one deck, the line up to 10, 40 and 60 m long in a random heading (3,000 lines each; load 2,54 5,76 16,56): a scan of everything 76.5, 63.2 and 64.1 µs; SH18's grid 22.5, 141.9 and 222.1 µs — slower than the scan past a few metres, gathering every cell's nine decks; the grid with bands and the scan past 256 cells 8.2, 27.2 and 33.4 µs. The scan alone, without bands, brings SH18's grid to 87.7 µs at 60 m: still slower than the scan, so it is the bands that make a long line cheap and the scan that bounds it.

| Target | Measured | |
|---|---|---|
| Sim step p99 ≤ 4 ms per tick, 64 seats on the fixture | 9.41 ms (p50 3.96 ms), SH18 | **missed** |
| Sim step p99 ≤ 4 ms per tick, 64 seats on the fixture, with height bands | 3.41 ms (p50 2.74 ms) | met |

Where the time goes, from timers put in for one run and taken out again: of 3.6 ms a tick through MatchRunner, 2.3 ms is the move's contact passes — 1.7 ms of it obstacle_contacts, about 140 calls a tick at 12 µs each, 0.6 ms the bodies' pairs off the grid — 0.4 ms what each body stands on, and the rest under 0.2 ms a step. The grid is in the ship plane, so each of its cells holds the surfaces of all nine decks over it, and every obstacle query sifts nine decks' walls by height. R7's fallbacks, in its order, none applied: a slower think rate for easy and normal bots (no bots here; it would price the bots, not this step); caching per-tick geometry queries — an obstacle query's answer kept per body across a tick's four contact passes while it has not moved, or the grid cut into height bands as well, so a query meets only its own deck's surfaces; early-outs on distant pairs (the grid is this, for bodies and surfaces); last, a GDExtension for the hot loop — a plan decision with a toolchain cost. The height bands above are the second of them, cut after SH18; nothing else is.
