# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 60.0% (120) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 38.0% (76) | 94.0% (188) | 30–55% | in |
| — gone by the head, capsized or not | 26.0% (52) | 53.0% (106) | — |  |
| — gone by the stern, capsized or not | 14.0% (28) | 47.0% (94) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 18.5% (37) | 10.5% (21) | 15–35% | in |
| capsizes (rolled past 90°) | 2.0% (4) | 6.0% (12) | 5–20% | under |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 15.0% (30) | 54.0% (108) | 10–30% | in |
| lights out — her generator stopped for good before she went | 41.5% (83) | 100.0% (200) | — |  |
| funnel fell before she went | 41.0% (82) | 100.0% (200) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 0–0% | in |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 1.44 a match (287 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.73 a match (147) | — |
| bakes | 1.83 a match · p95 4 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 8.5% (17) | under 1% |
| — the sure hit | 4.5% (9) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 8 | 0.812 · 2.202 · 10.272 | 0.059 · 0.105 · 0.382 | 17, 33, 37, 51, 61, 111, 120, 199 |
| sure hit | 9 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 183 matches whose drawn hit sank her: least 0.069 · median 0.425 · p95 1.455 · most 2.460 m².

## From the hit to her going (match census, physics time)

p10 0:08:35 · p50 0:19:12 · p90 0:47:05 · most 1:18:04 · 54.0% (108) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:10:04 · p50 0:11:11 · p90 0:13:55 · most 0:18:49 · 96.5% (193) within 0:16:30. Phases, median share of the sinking: opening 37.3% · middle 46.9% · end 15.3% (asked 25 / 50 / 25); 0.0% (0) with every phase within 5 points. Plunge: p10 31.9 s · p50 51.0 s · least 21.3 s; 100.0% (200) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 35.4% · median 96.9% · most 99.3%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 57.5% (115) | 118 | 0:00:12 · 0:00:14 · 0:01:21 | 6 · 6 · 106 |
| poop_space | 79.5% (159) | 173 | 0:00:11 · 0:00:14 · 0:01:26 | 38 · 29 · 106 |
| aft_bilge_p | 60.0% (120) | 144 | 0:00:11 · 0:00:52 · 0:11:30 | 34 · 7 · 103 |
| aft_bilge_s | 42.5% (85) | 94 | 0:00:11 · 0:00:19 · 0:11:30 | 10 · 9 · 75 |
| aft_cabins | 82.0% (164) | 293 | 0:00:06 · 0:02:58 · 0:17:29 | 158 · 116 · 19 |
| engine_bilge_p | 66.5% (133) | 252 | 0:00:05 · 0:00:29 · 0:03:57 | 231 · 21 · 0 |
| engine_bilge_s | 60.0% (120) | 239 | 0:00:05 · 0:00:25 · 0:03:57 | 225 · 12 · 2 |
| engine_room | 58.5% (117) | 178 | 0:00:02 · 0:00:06 · 0:00:29 | 126 · 49 · 3 |
| hold_bilge | 60.0% (120) | 205 | 0:00:14 · 0:00:37 · 0:04:01 | 187 · 8 · 10 |
| hold | 48.0% (96) | 169 | 0:00:15 · 0:00:37 · 0:04:01 | 167 · 2 · 0 |
| hold_wing_p | 48.5% (97) | 170 | 0:00:15 · 0:00:37 · 0:04:01 | 169 · 0 · 1 |
| hold_wing_s | 50.0% (100) | 177 | 0:00:15 · 0:00:36 · 0:03:38 | 173 · 2 · 2 |
| hold_fwd_top | 99.0% (198) | 280 | 0:00:17 · 0:00:43 · 0:14:03 | 276 · 2 · 2 |
| forepeak | 50.5% (101) | 107 | 0:00:42 · 0:00:53 · 0:00:59 | 21 · 69 · 17 |
| deckhouse_cabins | 53.0% (106) | 112 | 0:00:31 · 0:00:33 · 0:00:35 | 6 · 0 · 106 |
| deckhouse_hall | 53.0% (106) | 113 | 0:00:05 · 0:00:08 · 0:00:11 | 6 · 107 · 0 |
| saloon | 4.0% (8) | 9 | 0:00:01 · 0:00:08 · 0:00:08 | 3 · 6 · 0 |
| wheelhouse | 51.0% (102) | 103 | 0:00:06 · 0:00:15 · 0:00:18 | 5 · 98 · 0 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 160 | 80.0% (160) |
| a wall's panel | 200 | 100.0% (200) |
| a hatch | 200 | 100.0% (200) |
| a door, hinged | 162 | 81.0% (162) |
| a window | 184 | 92.0% (184) |
| a porthole | 35 | 17.5% (35) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.072 | 0.170 | 0.186 | yes |
| match census | 0.070 | 0.160 | 0.182 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 5,29 · 5,04 · 4,54 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 7.10 · p95 10.70 · most 21.03 s | over |
| a match's bakes: p95 under 5.0 s | p50 7.20 · p95 12.67 · most 16.33 s | over |
| the longest timeline under 200 kB | p50 17.6 · p95 22.5 · most 26.4 kB | in |

Steps a bake: p50 1142 · p95 4000 · most 4345. The longest sinking (gone at 1:18:04) keeps 1236 of 1630 states, 23.0 kB; with every state kept, 28.9 kB.
