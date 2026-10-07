# Outcome census — the trawler, seeds 1…200

Written by `make census SHIP=trawler SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 32.0% (64) | 0.0% (0) | 15–35% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 68.0% (136) | 100.0% (200) | 15–35% | over |
| — gone by the head, capsized or not | 44.5% (89) | 64.0% (128) | — |  |
| — gone by the stern, capsized or not | 23.5% (47) | 36.0% (72) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 20.5% (41) | 21.0% (42) | 10–30% | in |
| capsizes (rolled past 90°) | 0.0% (0) | 0.0% (0) | 25–50% | under |
| gone within 20 min of physics | 32.0% (64) | 51.0% (102) | 30–60% | in |
| lights out — her generator stopped for good before she went | 68.0% (136) | 100.0% (200) | — |  |
| funnel fell before she went | 69.0% (138) | 100.0% (200) | — |  |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.42 a match (84 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.46 a match · p95 3 · max 4 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 4.0% (8) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 8 | 0.015 · 0.075 · 0.684 | 0.002 · 0.012 · 0.083 | 14, 61, 68, 110, 122, 152, 157, 162 |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 192 matches whose drawn hit sank her: least 0.002 · median 0.071 · p95 0.623 · most 1.402 m².

## From the hit to her going (match census, physics time)

p10 0:04:38 · p50 0:19:37 · p90 1:52:35 · most 5:23:16 · 51.0% (102) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 2.2% · median 11.8% · most 98.3%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| engine_wing_p | 6.5% (13) | 17 | 0:00:00 · 0:00:04 · 0:00:04 | 16 · 1 · 0 |
| engine_room | 10.5% (21) | 25 | 0:00:00 · 0:00:04 · 0:00:04 | 22 · 3 · 0 |
| engine_wing_s | 4.5% (9) | 9 | 0:00:00 · 0:00:00 · 0:00:00 | 6 · 3 · 0 |
| hold_wing_p | 77.0% (154) | 370 | 0:00:00 · 0:00:08 · 0:00:10 | 310 · 15 · 45 |
| fish_hold | 91.0% (182) | 394 | 0:00:00 · 0:00:08 · 0:00:10 | 311 · 14 · 69 |
| hold_wing_s | 71.5% (143) | 334 | 0:00:00 · 0:00:08 · 0:00:10 | 270 · 12 · 52 |
| fore | 49.0% (98) | 135 | 0:00:01 · 0:00:08 · 0:00:09 | 51 · 12 · 72 |
| deckhouse | 31.0% (62) | 100 | 0:00:02 · 0:00:05 · 0:00:07 | 84 · 16 · 0 |
| wheelhouse | 65.0% (130) | 130 | 0:00:03 · 0:00:03 · 0:00:14 | 0 · 2 · 128 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 132 | 66.0% (132) |
| a wall's panel | 200 | 100.0% (200) |
| a hatch | 133 | 66.5% (133) |
| a door, hinged | 0 | 0.0% (0) |
| a window | 0 | 0.0% (0) |
| a porthole | 0 | 0.0% (0) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.040 | 0.077 | 0.077 | yes |
| match census | 0.046 | 0.077 | 0.077 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; nothing breaks her before SH33.

## What it costs (this machine, Apple M1)

Load average when measured: 2,24 · 2,43 · 2,39 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 1.77 · p95 2.95 · most 4.26 s | over |
| a match's bakes: p95 under 5.0 s | p50 2.41 · p95 5.28 · most 8.29 s | over |
| the longest timeline under 200 kB | p50 8.8 · p95 12.7 · most 19.9 kB | in |

Steps a bake: p50 641 · p95 2003 · most 2332. The longest sinking (gone at 5:23:16) keeps 238 of 2333 states, 6.5 kB; with every state kept, 15.9 kB.
