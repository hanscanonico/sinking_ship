# Outcome census — the trawler, seeds 1…200

Written by `make census SHIP=trawler SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 27.5% (55) | 0.0% (0) | 15–35% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 41.0% (82) | 53.5% (107) | 15–35% | over |
| — gone by the head, capsized or not | 36.5% (73) | 48.0% (96) | — |  |
| — gone by the stern, capsized or not | 35.0% (70) | 50.5% (101) | — |  |
| founders onto her side | 1.0% (2) | 1.5% (3) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 33.0% (66) | 37.0% (74) | 10–30% | over |
| capsizes (rolled past 90°) | 31.5% (63) | 46.5% (93) | 25–50% | in |
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

p10 0:05:21 · p50 0:28:09 · p90 1:59:58 · most 5:23:32 · 42.5% (85) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 2.2% · median 14.9% · most 62.9%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| engine_wing_p | 37.0% (74) | 131 | 0:00:04 · 0:00:18 · 0:06:18 | 75 · 33 · 23 |
| engine_room | 50.5% (101) | 253 | 0:00:00 · 0:00:12 · 0:06:18 | 108 · 130 · 15 |
| engine_wing_s | 38.0% (76) | 156 | 0:00:03 · 0:00:17 · 0:06:18 | 108 · 25 · 23 |
| hold_wing_p | 86.5% (173) | 386 | 0:00:02 · 0:00:12 · 0:01:32 | 251 · 34 · 101 |
| fish_hold | 98.5% (197) | 438 | 0:00:02 · 0:00:13 · 0:06:52 | 299 · 36 · 103 |
| hold_wing_s | 86.5% (173) | 362 | 0:00:02 · 0:00:13 · 0:06:52 | 253 · 14 · 95 |
| fore | 79.5% (159) | 288 | 0:00:09 · 0:00:49 · 0:02:08 | 143 · 88 · 57 |
| deckhouse | 61.0% (122) | 198 | 0:00:01 · 0:00:08 · 0:03:11 | 144 · 54 · 0 |
| wheelhouse | 44.5% (89) | 89 | 0:00:05 · 0:00:07 · 0:00:16 | 0 · 14 · 75 |
| engine_bilge | 51.5% (103) | 231 | 0:00:04 · 0:00:18 · 0:06:18 | 152 · 28 · 51 |
| hold_bilge | 96.5% (193) | 464 | 0:00:02 · 0:00:13 · 0:06:52 | 322 · 26 · 116 |
| fore_stores | 77.0% (154) | 286 | 0:00:11 · 0:00:54 · 0:06:38 | 160 · 16 · 110 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 138 | 69.0% (138) |
| a wall's panel | 198 | 99.0% (198) |
| a hatch | 123 | 61.5% (123) |
| a door, hinged | 0 | 0.0% (0) |
| a window | 0 | 0.0% (0) |
| a porthole | 22 | 11.0% (22) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.037 | 0.078 | 0.078 | yes |
| match census | 0.041 | 0.078 | 0.078 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; nothing breaks her before SH33.

## What it costs (this machine, Apple M1)

Load average when measured: 5,08 · 5,70 · 7,12 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 4.82 · p95 9.36 · most 12.54 s | over |
| a match's bakes: p95 under 5.0 s | p50 5.93 · p95 10.94 · most 23.94 s | over |
| the longest timeline under 200 kB | p50 11.6 · p95 15.7 · most 17.3 kB | in |

Steps a bake: p50 810 · p95 2001 · most 2514. The longest sinking (gone at 5:23:32) keeps 530 of 2515 states, 11.6 kB; with every state kept, 19.0 kB.
