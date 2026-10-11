# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 68.5% (137) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 31.0% (62) | 99.0% (198) | 30–55% | in |
| — gone by the head, capsized or not | 20.5% (41) | 62.5% (125) | — |  |
| — gone by the stern, capsized or not | 11.0% (22) | 37.5% (75) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 14.5% (29) | 23.0% (46) | 15–35% | under |
| capsizes (rolled past 90°) | 0.5% (1) | 1.0% (2) | 5–20% | under |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 6.0% (12) | 26.0% (52) | 10–30% | under |
| lights out — her generator stopped for good before she went | 31.5% (63) | 100.0% (200) | — |  |
| funnel fell before she went | 32.0% (64) | 100.0% (200) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 0–0% | in |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 2.01 a match (402 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 1.36 a match (272) | — |
| bakes | 1.80 a match · p95 5 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 9.0% (18) | under 1% |
| — the sure hit | 6.0% (12) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 6 | 0.065 · 0.336 · 2.239 | 0.006 · 0.031 · 0.138 | 6, 39, 71, 91, 104, 156 |
| sure hit | 12 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 182 matches whose drawn hit sank her: least 0.010 · median 0.183 · p95 1.770 · most 2.860 m².

## From the hit to her going (match census, physics time)

p10 0:10:54 · p50 0:46:58 · p90 3:42:42 · most 5:27:09 · 26.0% (52) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 2.5% · median 19.0% · most 83.3%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 99.0% (198) | 229 | 0:00:12 · 0:08:12 · 0:25:17 | 38 · 58 · 133 |
| poop_space | 69.0% (138) | 138 | 0:00:11 · 0:00:13 · 0:00:44 | 0 · 13 · 125 |
| aft_bilge_p | 28.0% (56) | 74 | 0:00:11 · 0:00:21 · 0:10:40 | 21 · 14 · 39 |
| aft_bilge_s | 27.5% (55) | 73 | 0:00:11 · 0:00:21 · 0:10:40 | 20 · 16 · 37 |
| aft_cabins | 63.0% (126) | 206 | 0:00:07 · 0:13:18 · 0:25:53 | 136 · 58 · 12 |
| engine_bilge_p | 59.5% (119) | 223 | 0:00:06 · 0:00:20 · 0:00:48 | 205 · 10 · 8 |
| engine_bilge_s | 62.0% (124) | 217 | 0:00:06 · 0:00:20 · 0:00:31 | 202 · 8 · 7 |
| engine_room | 52.5% (105) | 128 | 0:00:03 · 0:00:06 · 0:00:48 | 123 · 4 · 1 |
| hold_bilge | 46.5% (93) | 118 | 0:00:16 · 0:00:24 · 0:00:48 | 104 · 9 · 5 |
| hold | 38.5% (77) | 88 | 0:00:16 · 0:00:24 · 0:00:24 | 86 · 2 · 0 |
| hold_wing_p | 44.0% (88) | 103 | 0:00:16 · 0:00:24 · 0:00:48 | 94 · 7 · 2 |
| hold_wing_s | 43.0% (86) | 99 | 0:00:16 · 0:00:24 · 0:00:24 | 91 · 8 · 0 |
| hold_fwd_top | 99.5% (199) | 213 | 0:00:19 · 0:21:11 · 1:40:10 | 207 · 1 · 5 |
| forepeak | 60.5% (121) | 123 | 0:00:40 · 0:00:51 · 0:01:09 | 11 · 60 · 52 |
| deckhouse_cabins | 63.0% (126) | 132 | 0:00:31 · 0:00:48 · 0:01:02 | 10 · 0 · 122 |
| deckhouse_hall | 66.0% (132) | 138 | 0:00:07 · 0:00:27 · 0:00:38 | 7 · 131 · 0 |
| saloon | 19.0% (38) | 48 | 0:00:05 · 0:00:56 · 0:01:01 | 18 · 30 · 0 |
| wheelhouse | 76.0% (152) | 153 | 0:00:08 · 0:00:16 · 0:00:19 | 2 · 151 · 0 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 174 | 87.0% (174) |
| a wall's panel | 200 | 100.0% (200) |
| a hatch | 200 | 100.0% (200) |
| a door, hinged | 127 | 63.5% (127) |
| a window | 181 | 90.5% (181) |
| a porthole | 16 | 8.0% (16) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.062 | 0.126 | 0.184 | yes |
| match census | 0.071 | 0.183 | 0.185 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 5,26 · 5,30 · 13,59 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 22.83 · p95 51.02 · most 70.57 s | over |
| a match's bakes: p95 under 5.0 s | p50 15.54 · p95 56.77 · most 206.48 s | over |
| the longest timeline under 200 kB | p50 16.3 · p95 24.4 · most 30.6 kB | in |

Steps a bake: p50 2000 · p95 3992 · most 4537. The longest sinking (gone at 5:27:09) keeps 1418 of 4457 states, 25.3 kB; with every state kept, 43.3 kB.
