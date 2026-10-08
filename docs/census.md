# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 59.5% (119) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 23.5% (47) | 59.0% (118) | 30–55% | under |
| — gone by the head, capsized or not | 28.5% (57) | 64.0% (128) | — |  |
| — gone by the stern, capsized or not | 12.0% (24) | 35.5% (71) | — |  |
| founders onto her side | 0.0% (0) | 0.5% (1) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 37.0% (74) | 43.5% (87) | 15–35% | over |
| capsizes (rolled past 90°) | 17.0% (34) | 41.0% (82) | 5–20% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 8.0% (16) | 26.0% (52) | 10–30% | under |
| lights out — her generator stopped for good before she went | 44.5% (89) | 100.0% (200) | — |  |
| funnel fell before she went | 45.0% (90) | 100.0% (200) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 0–0% | in |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 1.25 a match (249 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.49 a match (99) | — |
| bakes | 1.95 a match · p95 5 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 11.0% (22) | under 1% |
| — the sure hit | 9.0% (18) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 4 | 0.125 · 0.276 · 2.766 | 0.006 · 0.012 · 0.369 | 57, 67, 101, 138 |
| sure hit | 18 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 178 matches whose drawn hit sank her: least 0.007 · median 0.167 · p95 1.048 · most 2.431 m².

## From the hit to her going (match census, physics time)

p10 0:09:19 · p50 0:49:02 · p90 3:04:11 · most 5:27:47 · 26.0% (52) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 1.2% · median 10.1% · most 89.0%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 90.5% (181) | 205 | 0:00:12 · 0:12:13 · 0:57:27 | 54 · 22 · 129 |
| poop_space | 84.5% (169) | 190 | 0:00:11 · 0:09:30 · 0:57:24 | 26 · 35 · 129 |
| aft_bilge_p | 54.0% (108) | 274 | 0:00:05 · 0:00:55 · 0:15:16 | 182 · 45 · 47 |
| aft_bilge_s | 45.5% (91) | 202 | 0:00:09 · 0:01:10 · 0:53:52 | 120 · 33 · 49 |
| aft_cabins | 82.5% (165) | 432 | 0:00:04 · 0:01:15 · 0:53:52 | 281 · 146 · 5 |
| engine_bilge_p | 61.5% (123) | 439 | 0:00:01 · 0:00:40 · 0:53:36 | 400 · 24 · 15 |
| engine_bilge_s | 62.5% (125) | 504 | 0:00:01 · 0:00:33 · 0:39:08 | 441 · 22 · 41 |
| engine_room | 76.0% (152) | 555 | 0:00:01 · 0:00:11 · 0:53:36 | 439 · 114 · 2 |
| hold_bilge | 54.0% (108) | 284 | 0:00:09 · 0:01:15 · 0:53:36 | 260 · 13 · 11 |
| hold | 46.0% (92) | 232 | 0:00:11 · 0:01:27 · 0:53:10 | 213 · 18 · 1 |
| hold_wing_p | 51.5% (103) | 211 | 0:00:10 · 0:01:01 · 0:53:36 | 191 · 13 · 7 |
| hold_wing_s | 44.5% (89) | 202 | 0:00:07 · 0:01:24 · 0:39:08 | 172 · 24 · 6 |
| hold_fwd_top | 92.0% (184) | 300 | 0:00:24 · 0:14:00 · 1:28:44 | 281 · 13 · 6 |
| forepeak | 66.0% (132) | 158 | 0:00:22 · 0:01:27 · 0:24:51 | 79 · 52 · 27 |
| deckhouse_cabins | 62.0% (124) | 174 | 0:00:27 · 0:00:49 · 0:17:22 | 64 · 5 · 105 |
| deckhouse_hall | 57.0% (114) | 147 | 0:00:05 · 0:00:27 · 0:00:38 | 28 · 119 · 0 |
| saloon | 13.0% (26) | 32 | 0:00:31 · 0:00:52 · 0:00:56 | 15 · 17 · 0 |
| wheelhouse | 6.0% (12) | 12 | 0:00:02 · 0:00:15 · 0:00:19 | 0 · 12 · 0 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 152 | 76.0% (152) |
| a wall's panel | 182 | 91.0% (182) |
| a hatch | 199 | 99.5% (199) |
| a door, hinged | 175 | 87.5% (175) |
| a window | 144 | 72.0% (144) |
| a porthole | 64 | 32.0% (64) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.060 | 0.189 | 0.220 | yes |
| match census | 0.070 | 0.191 | 0.220 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 3,22 · 3,20 · 4,61 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 12.10 · p95 24.58 · most 33.04 s | over |
| a match's bakes: p95 under 5.0 s | p50 14.88 · p95 43.04 · most 69.58 s | over |
| the longest timeline under 200 kB | p50 19.6 · p95 27.0 · most 30.7 kB | in |

Steps a bake: p50 1605 · p95 4001 · most 4799. The longest sinking (gone at 5:27:47) keeps 626 of 4800 states, 21.2 kB; with every state kept, 43.7 kB.
