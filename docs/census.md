# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 69.0% (138) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 25.5% (51) | 84.0% (168) | 30–55% | under |
| — gone by the head, capsized or not | 20.0% (40) | 58.0% (116) | — |  |
| — gone by the stern, capsized or not | 11.0% (22) | 42.0% (84) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 16.5% (33) | 28.0% (56) | 15–35% | in |
| capsizes (rolled past 90°) | 5.5% (11) | 16.0% (32) | 5–20% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 7.0% (14) | 25.5% (51) | 10–30% | under |
| lights out — her generator stopped for good before she went | 32.0% (64) | 100.0% (200) | — |  |
| funnel fell before she went | 32.0% (64) | 100.0% (200) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 0–0% | in |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 1.87 a match (374 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 1.18 a match (235) | — |
| bakes | 1.83 a match · p95 4 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 10.0% (20) | under 1% |
| — the sure hit | 3.5% (7) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 13 | 0.044 · 0.224 · 9.920 | 0.004 · 0.016 · 0.369 | 57, 61, 67, 71, 86, 108, 122, 126, 132, 151, 157, 171, 199 |
| sure hit | 7 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 180 matches whose drawn hit sank her: least 0.010 · median 0.192 · p95 1.207 · most 2.431 m².

## From the hit to her going (match census, physics time)

p10 0:11:01 · p50 0:45:32 · p90 3:15:35 · most 5:23:39 · 25.5% (51) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 2.4% · median 8.7% · most 56.3%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 99.5% (199) | 231 | 0:00:12 · 0:04:05 · 0:21:59 | 65 · 47 · 119 |
| poop_space | 70.5% (141) | 161 | 0:00:11 · 0:00:17 · 0:08:48 | 21 · 24 · 116 |
| aft_bilge_p | 42.5% (85) | 106 | 0:00:11 · 0:00:52 · 0:05:40 | 36 · 18 · 52 |
| aft_bilge_s | 33.0% (66) | 76 | 0:00:11 · 0:00:37 · 0:05:40 | 18 · 20 · 38 |
| aft_cabins | 65.5% (131) | 233 | 0:00:10 · 0:03:46 · 0:22:17 | 129 · 86 · 18 |
| engine_bilge_p | 62.0% (124) | 250 | 0:00:06 · 0:00:38 · 0:08:13 | 234 · 14 · 2 |
| engine_bilge_s | 60.5% (121) | 249 | 0:00:05 · 0:00:31 · 0:04:13 | 225 · 18 · 6 |
| engine_room | 60.0% (120) | 189 | 0:00:02 · 0:00:07 · 0:08:13 | 137 · 52 · 0 |
| hold_bilge | 47.5% (95) | 203 | 0:00:10 · 0:00:39 · 0:08:13 | 191 · 6 · 6 |
| hold | 43.0% (86) | 186 | 0:00:11 · 0:00:39 · 0:08:13 | 185 · 1 · 0 |
| hold_wing_p | 44.5% (89) | 176 | 0:00:14 · 0:00:39 · 0:08:13 | 168 · 6 · 2 |
| hold_wing_s | 44.5% (89) | 180 | 0:00:10 · 0:00:38 · 0:03:35 | 174 · 4 · 2 |
| hold_fwd_top | 99.0% (198) | 304 | 0:00:18 · 0:01:31 · 1:38:23 | 296 · 4 · 4 |
| forepeak | 55.0% (110) | 115 | 0:00:36 · 0:00:50 · 0:00:57 | 16 · 55 · 44 |
| deckhouse_cabins | 58.5% (117) | 122 | 0:00:31 · 0:00:48 · 0:00:57 | 9 · 0 · 113 |
| deckhouse_hall | 58.5% (117) | 127 | 0:00:07 · 0:00:27 · 0:00:36 | 5 · 122 · 0 |
| saloon | 14.5% (29) | 38 | 0:00:03 · 0:00:52 · 0:00:59 | 16 · 22 · 0 |
| wheelhouse | 52.5% (105) | 107 | 0:00:09 · 0:00:16 · 0:00:20 | 5 · 102 · 0 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 168 | 84.0% (168) |
| a wall's panel | 200 | 100.0% (200) |
| a hatch | 197 | 98.5% (197) |
| a door, hinged | 180 | 90.0% (180) |
| a window | 172 | 86.0% (172) |
| a porthole | 49 | 24.5% (49) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.060 | 0.126 | 0.185 | yes |
| match census | 0.069 | 0.185 | 0.187 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 30,70 · 21,17 · 28,91 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 11.72 · p95 30.54 · most 45.28 s | over |
| a match's bakes: p95 under 5.0 s | p50 27.85 · p95 78.81 · most 134.00 s | over |
| the longest timeline under 200 kB | p50 18.2 · p95 23.9 · most 31.3 kB | in |

Steps a bake: p50 1960 · p95 3993 · most 4529. The longest sinking (gone at 5:23:39) keeps 363 of 4539 states, 13.5 kB; with every state kept, 29.8 kB.
