# Arena — 2026-10-12

Written by `make arena SEEDS=8` (tools/arena.gd) on MacBookAir10,1, Apple M1, in 74.9 minutes.
Fewer seeds than the plan's 200: SEEDS is the knob, and 200 seeds a lobby would take about 1874 minutes at this run's pace.
Load average (1, 5, 15 min) at the start: 13,22 21,11 15,07; at the end: 107,78 109,77 122,31. The milliseconds are what this machine gave at that load: with a load above its 8 cores they are measured under load, not a reading of the budget.
The build has the hazards (SH10: cargo, railing damage) and the network seam (SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner itself, so the milliseconds are sim and bots, with no snapshots sent.
A dated record: the next run supersedes this file whole. Each lobby plays the default match (data/match/default.tres) on seeds 1…N; match time is the transcript's clock, countdown included. A bot is idle on a tick when it is in, free to act, presses nothing and its feet move less than 5 mm; an opponent is in sight when no wall, deck or hull stands between their eyes (Surfaces.line_of_sight, the bots' and the HUD's question); dry means in and not in the sea. Everything but the milliseconds is the same on a rerun on the same build (D4).

The tick-cost targets are the SH7 review's and supersede the plan's "sim + bots p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; bots that look through line of sight, route a walk graph and probe the edges spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing.

## Targets

| Target | Measured | |
|---|---|---|
| Hard wins ≥ 75% of four-hard-four-easy lobbies | 62.5% | **missed** |
| No spawn slot wins more than 1.6× its fair share | 3.00× | **missed** |
| ≤ 10% of matches reach the plunge with three or more dry | 0.0% | met |
| Median length 2:30–3:20 | 04:00 | **missed** |
| ≥ 70% of matches still on at the bridge collapse (SH7d's aim) | 0.0% | **missed** |
| Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats | p50 5.48 ms, p99 21.23 ms | **missed** |
| Sim + bots p99 ≤ 16 ms per tick at sixteen seats | 85.81 ms | **missed** |
| No bot idle more than 3 s with an opponent in sight within 6 m | 5.6 s (hard-easy: seed 4 seat 6 at (3.3, 0.0, 1.7), 01:05.1) | **missed** |
| normal: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.03 s (longest 0.7 s, seed 6 seat 1) | met |
| hard-easy: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.19 s (longest 1.6 s, seed 6 seat 3) | met |
| sighted: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.15 s (longest 2.5 s, seed 7 seat 4) | met |
| sixteen: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, feet over a body's height above the sea | 0.02 s (longest 0.8 s, seed 7 seat 6) | met |
| Win-share gap, omniscient minus sighted (R16, reported) | +0.0 points | — |

## Eight normal bots — the default match

- Matches: 8 (seeds 1…8), 617 s of wall time.
- Length: median 04:00, mean 04:24; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 37.5%, 1: 0.0%, 2: 12.5%, 3: 12.5%, 4: 0.0%, 5: 12.5%, 6: 12.5%, 7: 12.5%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 7 railing sections broken, 0.9 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.03 s a bot a match; longest 0.7 s (seed 6 seat 1).
- Longest idle streak: 3.8 s (seed 2 seat 6 at (-1.6, 4.7, -0.2), 03:50.7).
- Longest idle streak with an opponent in sight within 6 m: 3.5 s (seed 7 seat 4 at (27.9, -5.2, 1.9), 02:26.5).
- Sim + bots per tick, 8 seats: p50 5.48 ms, p99 21.23 ms, mean 6.71 ms, worst 144.6 ms.

## Four hard and four easy

- Matches: 8 (seeds 1…8), 1831 s of wall time.
- Length: median 03:59, mean 05:23; draws 0; still on at 15:00 and stopped: 3.
- Reached the plunge with three or more dry: 1 of 8 (12.5%).
- Still on at the first collapse (the bridge): 1 of 8 (12.5%), 6.0 seats in on average; at the plunge: 2 of 8 (25.0%), 4.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 0.0%, 1: 0.0%, 2: 12.5%, 3: 0.0%, 4: 0.0%, 5: 12.5%, 6: 25.0%, 7: 12.5%.
- Wins by tier: hard 62.5%.
- Cargo: 0 exits credited to a crate; 11 railing sections broken, 1.4 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.19 s a bot a match; longest 1.6 s (seed 6 seat 3).
- Longest idle streak: 575.0 s (seed 7 seat 2 at (-1.7, 4.7, -0.6), 11:44.7).
- Longest idle streak with an opponent in sight within 6 m: 5.6 s (seed 4 seat 6 at (3.3, 0.0, 1.7), 01:05.1).
- Sim + bots per tick, 8 seats: p50 8.79 ms, p99 61.41 ms, mean 12.25 ms, worst 434.8 ms.

## Four sighted and four omniscient, all normal

- Matches: 8 (seeds 1…8), 741 s of wall time.
- Length: median 04:41, mean 04:52; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 12.5%): 0: 12.5%, 1: 12.5%, 2: 12.5%, 3: 0.0%, 4: 0.0%, 5: 0.0%, 6: 37.5%, 7: 25.0%.
- Wins by tier: normal 100.0%.
- Wins by sight: omniscient 50.0%, sighted 50.0%.
- Cargo: 0 exits credited to a crate; 11 railing sections broken, 1.4 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.15 s a bot a match; longest 2.5 s (seed 7 seat 4).
- Longest idle streak: 3.7 s (seed 2 seat 1 at (-10.7, -4.9, 10.9), 03:16.0).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 6 seat 3 at (-7.6, -6.3, -7.5), 02:46.9).
- Sim + bots per tick, 8 seats: p50 6.33 ms, p99 39.13 ms, mean 8.04 ms, worst 182.6 ms.

## Sixteen normal bots — timing only

- Matches: 8 (seeds 1…8), 1308 s of wall time.
- Length: median 03:36, mean 04:21; draws 0; still on at 15:00 and stopped: 0.
- Reached the plunge with three or more dry: 0 of 8 (0.0%).
- Still on at the first collapse (the bridge): 0 of 8 (0.0%), 0.0 seats in on average; at the plunge: 0 of 8 (0.0%), 0.0 seats in.
- Wins by spawn slot (fair share 6.2%): 0: 0.0%, 1: 0.0%, 2: 0.0%, 3: 12.5%, 4: 0.0%, 5: 25.0%, 6: 0.0%, 7: 12.5%, 8: 12.5%, 9: 0.0%, 10: 0.0%, 11: 0.0%, 12: 25.0%, 13: 0.0%, 14: 0.0%, 15: 12.5%.
- Wins by tier: normal 100.0%.
- Cargo: 0 exits credited to a crate; 18 railing sections broken, 2.2 a match.
- Climbing out or fleeing on a dry ship, feet over a body's height above the sea: 0.02 s a bot a match; longest 0.8 s (seed 7 seat 6).
- Longest idle streak: 3.7 s (seed 1 seat 6 at (17.6, -4.8, 4.5), 00:13.3).
- Longest idle streak with an opponent in sight within 6 m: 3.7 s (seed 2 seat 10 at (-9.6, -4.9, -5.5), 03:01.2).
- Sim + bots per tick, 16 seats: p50 12.57 ms, p99 85.81 ms, mean 17.37 ms, worst 1293.5 ms.

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
