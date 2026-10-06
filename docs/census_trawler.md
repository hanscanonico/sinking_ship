# Outcome census — the trawler, seeds 1…200

Written by `make census SHIP=trawler SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 17.5% (35) | 0.0% (0) | 15–35% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 73.0% (146) | 89.0% (178) | 15–35% | over |
| — gone by the head, capsized or not | 38.5% (77) | 46.5% (93) | — |  |
| — gone by the stern, capsized or not | 39.0% (78) | 48.0% (96) | — |  |
| founders onto her side | 5.0% (10) | 5.5% (11) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 24.0% (48) | 20.0% (40) | 10–30% | in |
| capsizes (rolled past 90°) | 4.5% (9) | 5.5% (11) | 25–50% | under |
| gone within 20 min of physics | 26.0% (52) | 31.5% (63) | 30–60% | under |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.20 a match (40 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.21 a match · p95 2 · max 4 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 0.5% (1) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 1 | 0.057 · 0.057 · 0.057 | 0.006 · 0.006 · 0.006 | 92 |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 199 matches whose drawn hit sank her: least 0.003 · median 0.041 · p95 0.661 · most 1.402 m².

## From the hit to her going (match census, physics time)

p10 0:07:27 · p50 0:39:18 · p90 2:56:22 · most 5:24:09 · 31.5% (63) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 2.0% · median 14.2% · most 96.7%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| engine_wing_p | 21.0% (42) | 55 | 0:01:35 · 0:04:48 · 0:04:48 | 14 · 3 · 38 |
| engine_wing_s | 16.5% (33) | 48 | 0:00:29 · 0:04:51 · 0:04:52 | 17 · 1 · 30 |
| hold_wing_p | 83.0% (166) | 177 | 0:00:19 · 0:04:46 · 0:04:51 | 11 · 8 · 158 |
| fish_hold | 87.5% (175) | 197 | 0:00:19 · 0:04:45 · 0:04:51 | 22 · 65 · 110 |
| hold_wing_s | 85.0% (170) | 189 | 0:00:19 · 0:04:45 · 0:04:51 | 19 · 9 · 161 |
| fore | 62.5% (125) | 148 | 0:00:12 · 0:04:46 · 0:04:54 | 29 · 20 · 99 |
| deckhouse | 38.0% (76) | 77 | 0:00:11 · 0:00:17 · 0:00:18 | 58 · 7 · 12 |
| wheelhouse | 48.0% (96) | 96 | 0:00:05 · 0:00:08 · 0:00:09 | 15 · 5 · 76 |

## What it costs (this machine, Apple M1)

Load average when measured: 3,54 · 3,41 · 3,81 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 1.61 · p95 2.75 · most 4.68 s | over |
| a match's bakes: p95 under 5.0 s | p50 1.52 · p95 3.37 · most 4.86 s | in |
| the longest timeline under 200 kB | p50 7.7 · p95 11.6 · most 14.1 kB | in |

Steps a bake: p50 866 · p95 2012 · most 2807. The longest sinking (gone at 5:24:09) keeps 154 of 2375 states, 4.1 kB; with every state kept, 14.8 kB.
