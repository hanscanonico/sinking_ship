# Outcome census — the trawler, seeds 1…200

Written by `make census SHIP=trawler SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 27.5% (55) | 0.0% (0) | 15–35% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 43.5% (87) | 56.5% (113) | 15–35% | over |
| — gone by the head, capsized or not | 36.5% (73) | 48.0% (96) | — |  |
| — gone by the stern, capsized or not | 34.5% (69) | 50.0% (100) | — |  |
| founders onto her side | 1.5% (3) | 2.0% (4) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 33.0% (66) | 37.0% (74) | 10–30% | over |
| capsizes (rolled past 90°) | 29.0% (58) | 43.5% (87) | 25–50% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 29.0% (58) | 42.5% (85) | 30–60% | under |
| lights out — her generator stopped for good before she went | 72.5% (145) | 100.0% (200) | — |  |
| funnel fell before she went | 72.5% (145) | 100.0% (200) | — |  |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.33 a match (66 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.34 a match · p95 3 · max 4 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 1.5% (3) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 3 | 0.015 · 0.028 · 0.039 | 0.002 · 0.002 · 0.003 | 14, 89, 162 |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 197 matches whose drawn hit sank her: least 0.003 · median 0.064 · p95 0.553 · most 1.402 m².

## From the hit to her going (match census, physics time)

p10 0:05:19 · p50 0:28:15 · p90 1:59:38 · most 5:22:44 · 42.5% (85) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 6.2% · median 16.1% · most 97.5%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| engine_wing_p | 37.0% (74) | 133 | 0:00:04 · 0:00:18 · 0:05:51 | 81 · 33 · 19 |
| engine_room | 51.5% (103) | 256 | 0:00:00 · 0:00:11 · 0:05:51 | 110 · 133 · 13 |
| engine_wing_s | 38.0% (76) | 162 | 0:00:02 · 0:00:17 · 0:05:51 | 113 · 27 · 22 |
| hold_wing_p | 87.5% (175) | 403 | 0:00:00 · 0:00:11 · 0:01:06 | 287 · 23 · 93 |
| fish_hold | 98.5% (197) | 446 | 0:00:01 · 0:00:12 · 0:06:25 | 319 · 26 · 101 |
| hold_wing_s | 89.5% (179) | 386 | 0:00:01 · 0:00:12 · 0:06:25 | 274 · 17 · 95 |
| fore | 81.0% (162) | 287 | 0:00:10 · 0:00:47 · 0:01:38 | 137 · 92 · 58 |
| deckhouse | 58.5% (117) | 188 | 0:00:01 · 0:00:08 · 0:05:52 | 142 · 45 · 1 |
| wheelhouse | 44.0% (88) | 88 | 0:00:04 · 0:00:06 · 0:00:16 | 0 · 9 · 79 |
| engine_bilge | 52.5% (105) | 232 | 0:00:04 · 0:00:18 · 0:05:51 | 157 · 23 · 52 |
| hold_bilge | 97.0% (194) | 475 | 0:00:01 · 0:00:12 · 0:06:25 | 341 · 18 · 116 |
| fore_stores | 78.0% (156) | 282 | 0:00:11 · 0:00:50 · 0:06:10 | 161 · 14 · 107 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 143 | 71.5% (143) |
| a wall's panel | 198 | 99.0% (198) |
| a hatch | 122 | 61.0% (122) |
| a door, hinged | 0 | 0.0% (0) |
| a window | 0 | 0.0% (0) |
| a porthole | 23 | 11.5% (23) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.037 | 0.078 | 0.078 | yes |
| match census | 0.041 | 0.078 | 0.078 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; nothing breaks her before SH33.

## What it costs (this machine, Apple M1)

Load average when measured: 6,34 · 11,21 · 12,99 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 7.64 · p95 15.15 · most 22.65 s | over |
| a match's bakes: p95 under 5.0 s | p50 10.25 · p95 24.16 · most 33.00 s | over |
| the longest timeline under 200 kB | p50 11.5 · p95 15.7 · most 18.1 kB | in |

Steps a bake: p50 938 · p95 3967 · most 4357. The longest sinking (gone at 5:22:44) keeps 439 of 4328 states, 9.9 kB; with every state kept, 20.6 kB.
