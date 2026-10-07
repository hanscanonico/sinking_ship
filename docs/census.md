# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 60.0% (120) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 20.5% (41) | 54.0% (108) | 30–55% | under |
| — gone by the head, capsized or not | 28.0% (56) | 62.5% (125) | — |  |
| — gone by the stern, capsized or not | 12.0% (24) | 37.5% (75) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 36.5% (73) | 37.0% (74) | 15–35% | over |
| capsizes (rolled past 90°) | 19.5% (39) | 46.0% (92) | 5–20% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 8.0% (16) | 26.0% (52) | 10–30% | under |
| lights out — her generator stopped for good before she went | 44.5% (89) | 100.0% (200) | — |  |
| funnel fell before she went | 44.5% (89) | 100.0% (200) | — |  |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 1.68 a match (335 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 1.03 a match (207) | — |
| bakes | 1.76 a match · p95 4 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 8.0% (16) | under 1% |
| — the sure hit | 4.5% (9) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 7 | 0.125 · 0.276 · 8.435 | 0.006 · 0.058 · 0.369 | 17, 38, 57, 67, 101, 126, 197 |
| sure hit | 9 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 184 matches whose drawn hit sank her: least 0.007 · median 0.175 · p95 1.091 · most 2.431 m².

## From the hit to her going (match census, physics time)

p10 0:10:54 · p50 0:43:57 · p90 3:12:15 · most 5:28:11 · 26.0% (52) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 1.0% · median 7.8% · most 89.1%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 94.0% (188) | 221 | 0:00:12 · 0:09:32 · 0:50:40 | 69 · 25 · 127 |
| poop_space | 81.5% (163) | 186 | 0:00:11 · 0:05:34 · 0:50:40 | 31 · 30 · 125 |
| aft_bilge_p | 57.5% (115) | 321 | 0:00:04 · 0:00:52 · 0:27:56 | 226 · 51 · 44 |
| aft_bilge_s | 47.5% (95) | 246 | 0:00:06 · 0:01:01 · 0:50:37 | 159 · 48 · 39 |
| aft_cabins | 83.5% (167) | 489 | 0:00:04 · 0:01:20 · 0:50:37 | 313 · 156 · 20 |
| engine_bilge_p | 69.0% (138) | 480 | 0:00:01 · 0:00:46 · 0:19:43 | 429 · 28 · 23 |
| engine_bilge_s | 68.5% (137) | 526 | 0:00:01 · 0:00:44 · 0:34:59 | 465 · 23 · 38 |
| engine_room | 80.5% (161) | 572 | 0:00:01 · 0:00:13 · 0:34:59 | 442 · 129 · 1 |
| hold_bilge | 56.0% (112) | 282 | 0:00:09 · 0:01:07 · 0:34:30 | 251 · 14 · 17 |
| hold | 46.5% (93) | 220 | 0:00:10 · 0:01:17 · 0:34:32 | 202 · 17 · 1 |
| hold_wing_p | 52.0% (104) | 228 | 0:00:11 · 0:01:02 · 0:19:30 | 205 · 15 · 8 |
| hold_wing_s | 50.0% (100) | 226 | 0:00:08 · 0:01:14 · 0:34:59 | 192 · 22 · 12 |
| hold_fwd_top | 93.0% (186) | 289 | 0:00:24 · 0:04:25 · 1:30:27 | 269 · 11 · 9 |
| forepeak | 64.0% (128) | 159 | 0:00:22 · 0:01:54 · 0:25:11 | 89 · 42 · 28 |
| deckhouse_cabins | 61.0% (122) | 164 | 0:00:26 · 0:00:36 · 0:10:10 | 55 · 3 · 106 |
| deckhouse_hall | 58.5% (117) | 155 | 0:00:04 · 0:00:10 · 0:00:45 | 34 · 121 · 0 |
| saloon | 9.0% (18) | 22 | 0:00:09 · 0:00:52 · 0:00:54 | 10 · 12 · 0 |
| wheelhouse | 6.0% (12) | 12 | 0:00:02 · 0:00:14 · 0:00:18 | 0 · 12 · 0 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 164 | 82.0% (164) |
| a wall's panel | 191 | 95.5% (191) |
| a hatch | 199 | 99.5% (199) |
| a door, hinged | 180 | 90.0% (180) |
| a window | 147 | 73.5% (147) |
| a porthole | 73 | 36.5% (73) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.060 | 0.190 | 0.193 | yes |
| match census | 0.069 | 0.190 | 0.192 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; nothing breaks her before SH33.

## What it costs (this machine, Apple M1)

Load average when measured: 4,21 · 4,31 · 5,45 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 4.60 · p95 13.58 · most 18.69 s | over |
| a match's bakes: p95 under 5.0 s | p50 10.79 · p95 20.50 · most 37.42 s | over |
| the longest timeline under 200 kB | p50 19.2 · p95 25.8 · most 30.2 kB | in |

Steps a bake: p50 1092 · p95 2057 · most 2881. The longest sinking (gone at 5:28:11) keeps 617 of 2882 states, 21.4 kB; with every state kept, 38.4 kB.
