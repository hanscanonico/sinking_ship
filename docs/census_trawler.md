# Outcome census — the trawler, seeds 1…200

Written by `make census SHIP=trawler SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 17.5% (35) | 0.0% (0) | 15–35% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 68.5% (137) | 82.0% (164) | 15–35% | over |
| — gone by the head, capsized or not | 38.0% (76) | 46.5% (93) | — |  |
| — gone by the stern, capsized or not | 39.5% (79) | 45.0% (90) | — |  |
| founders onto her side | 5.0% (10) | 8.5% (17) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 23.0% (46) | 16.5% (33) | 10–30% | in |
| capsizes (rolled past 90°) | 9.0% (18) | 9.5% (19) | 25–50% | under |
| gone within 20 min of physics | 29.5% (59) | 39.0% (78) | 30–60% | under |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.23 a match (45 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.24 a match · p95 3 · max 4 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 1.5% (3) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 3 | 0.057 · 0.106 · 0.684 | 0.006 · 0.010 · 0.083 | 45, 68, 92 |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 197 matches whose drawn hit sank her: least 0.003 · median 0.035 · p95 0.514 · most 1.402 m².

## From the hit to her going (match census, physics time)

p10 0:05:47 · p50 0:33:21 · p90 2:53:26 · most 5:23:22 · 39.0% (78) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 2.0% · median 14.2% · most 97.5%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| engine_wing_p | 21.0% (42) | 55 | 0:01:44 · 0:04:43 · 0:04:47 | 14 · 3 · 38 |
| engine_wing_s | 14.0% (28) | 44 | 0:00:04 · 0:04:28 · 0:04:43 | 16 · 5 · 23 |
| hold_wing_p | 80.5% (161) | 392 | 0:00:00 · 0:01:54 · 0:04:47 | 231 · 7 · 154 |
| fish_hold | 84.5% (169) | 420 | 0:00:00 · 0:01:52 · 0:04:47 | 250 · 58 · 112 |
| hold_wing_s | 85.0% (170) | 418 | 0:00:00 · 0:01:52 · 0:04:47 | 248 · 2 · 168 |
| fore | 59.0% (118) | 135 | 0:00:14 · 0:04:41 · 0:04:49 | 24 · 20 · 91 |
| deckhouse | 51.5% (103) | 107 | 0:00:06 · 0:00:12 · 0:00:18 | 60 · 33 · 14 |
| wheelhouse | 48.0% (96) | 96 | 0:00:06 · 0:00:08 · 0:00:10 | 15 · 5 · 76 |

## What it costs (this machine, Apple M1)

Load average when measured: 3,08 · 3,34 · 3,99 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 2.14 · p95 3.80 · most 4.90 s | over |
| a match's bakes: p95 under 5.0 s | p50 2.51 · p95 5.20 · most 7.91 s | over |
| the longest timeline under 200 kB | p50 7.4 · p95 12.3 · most 16.1 kB | in |

Steps a bake: p50 900 · p95 2016 · most 2791. The longest sinking (gone at 5:23:22) keeps 153 of 2377 states, 4.3 kB; with every state kept, 14.9 kB.
