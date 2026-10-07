# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 68.0% (136) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 27.0% (54) | 86.0% (172) | 30–55% | under |
| — gone by the head, capsized or not | 20.5% (41) | 59.5% (119) | — |  |
| — gone by the stern, capsized or not | 11.5% (23) | 40.5% (81) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 16.5% (33) | 14.5% (29) | 15–35% | in |
| capsizes (rolled past 90°) | 5.0% (10) | 14.0% (28) | 5–20% | in |
| gone within 20 min of physics | 8.5% (17) | 31.5% (63) | 10–30% | under |
| lights out — her generator stopped for good before she went | 35.5% (71) | 100.0% (200) | — |  |
| funnel fell before she went | 33.5% (67) | 100.0% (200) | — |  |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 1.90 a match (379 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 1.18 a match (235) | — |
| bakes | 1.86 a match · p95 4 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 9.5% (19) | under 1% |
| — the sure hit | 4.5% (9) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 10 | 0.125 · 2.766 · 9.920 | 0.006 · 0.225 · 0.369 | 17, 38, 57, 61, 67, 72, 101, 123, 135, 197 |
| sure hit | 9 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 181 matches whose drawn hit sank her: least 0.010 · median 0.195 · p95 1.338 · most 3.638 m².

## From the hit to her going (match census, physics time)

p10 0:06:37 · p50 0:46:32 · p90 3:37:58 · most 5:24:26 · 31.5% (63) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 1.0% · median 13.5% · most 79.1%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 99.0% (198) | 213 | 0:00:11 · 0:03:32 · 0:20:03 | 44 · 45 · 124 |
| poop_space | 65.0% (130) | 139 | 0:00:10 · 0:00:11 · 0:03:53 | 9 · 11 · 119 |
| aft_bilge_p | 11.0% (22) | 30 | 0:00:10 · 0:00:43 · 0:01:17 | 17 · 6 · 7 |
| aft_bilge_s | 6.0% (12) | 21 | 0:00:03 · 0:00:10 · 0:00:20 | 10 · 7 · 4 |
| aft_cabins | 56.0% (112) | 256 | 0:00:19 · 0:03:16 · 0:20:03 | 177 · 58 · 21 |
| engine_bilge_p | 72.0% (144) | 346 | 0:00:04 · 0:00:36 · 0:01:26 | 335 · 7 · 4 |
| engine_bilge_s | 69.0% (138) | 354 | 0:00:04 · 0:00:36 · 0:01:26 | 332 · 12 · 10 |
| engine_room | 69.5% (139) | 375 | 0:00:00 · 0:00:08 · 0:00:22 | 262 · 112 · 1 |
| hold_bilge | 48.0% (96) | 193 | 0:00:15 · 0:00:24 · 0:01:07 | 185 · 7 · 1 |
| hold | 40.5% (81) | 172 | 0:00:16 · 0:00:24 · 0:01:07 | 171 · 1 · 0 |
| hold_wing_p | 44.5% (89) | 181 | 0:00:15 · 0:00:24 · 0:01:07 | 175 · 5 · 1 |
| hold_wing_s | 44.5% (89) | 182 | 0:00:15 · 0:00:24 · 0:01:07 | 168 · 13 · 1 |
| hold_fwd_top | 99.5% (199) | 294 | 0:00:20 · 0:06:24 · 2:17:42 | 286 · 1 · 7 |
| forepeak | 55.0% (110) | 118 | 0:00:29 · 0:00:46 · 0:00:57 | 29 · 46 · 43 |
| deckhouse_cabins | 60.0% (120) | 136 | 0:00:30 · 0:00:44 · 0:00:52 | 22 · 0 · 114 |
| deckhouse_hall | 60.5% (121) | 138 | 0:00:08 · 0:00:25 · 0:00:34 | 13 · 125 · 0 |
| saloon | 16.0% (32) | 40 | 0:00:07 · 0:00:47 · 0:00:53 | 21 · 19 · 0 |
| wheelhouse | 31.5% (63) | 63 | 0:00:12 · 0:00:20 · 0:00:22 | 3 · 60 · 0 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 164 | 82.0% (164) |
| a wall's panel | 191 | 95.5% (191) |
| a hatch | 199 | 99.5% (199) |
| a door, hinged | 187 | 93.5% (187) |
| a window | 176 | 88.0% (176) |
| a porthole | 68 | 34.0% (68) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.060 | 0.192 | 0.193 | yes |
| match census | 0.070 | 0.192 | 0.193 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; nothing breaks her before SH33.

## What it costs (this machine, Apple M1)

Load average when measured: 2,34 · 2,28 · 2,39 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 3.08 · p95 6.61 · most 8.72 s | over |
| a match's bakes: p95 under 5.0 s | p50 6.43 · p95 12.62 · most 18.74 s | over |
| the longest timeline under 200 kB | p50 18.0 · p95 23.5 · most 29.5 kB | in |

Steps a bake: p50 1193 · p95 2086 · most 2674. The longest sinking (gone at 5:24:26) keeps 420 of 2616 states, 15.2 kB; with every state kept, 26.8 kB.
