# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 72.5% (145) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 21.0% (42) | 75.5% (151) | 30–55% | under |
| — gone by the head, capsized or not | 16.5% (33) | 54.5% (109) | — |  |
| — gone by the stern, capsized or not | 11.0% (22) | 45.5% (91) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 15.0% (30) | 5.0% (10) | 15–35% | in |
| capsizes (rolled past 90°) | 6.5% (13) | 24.5% (49) | 5–20% | in |
| gone within 20 min of physics | 7.0% (14) | 31.5% (63) | 10–30% | under |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 2.49 a match (498 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 2.15 a match (429) | — |
| bakes | 1.44 a match · p95 3 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 6.5% (13) | under 1% |
| — the sure hit | 3.0% (6) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 5 | 0.099 · 0.283 · 9.920 | 0.004 · 0.016 · 0.369 | 17, 61, 87, 108, 156 |
| 3 | 2 | 1.682 · 6.992 · 6.992 | 0.091 · 0.311 · 0.311 | 139, 199 |
| sure hit | 6 | 3.900 · 3.900 · 3.900 | her data's | — |

Beside them, the holes of the 187 matches whose drawn hit sank her: least 0.010 · median 0.195 · p95 1.104 · most 2.431 m².

## From the hit to her going (match census, physics time)

p10 0:08:25 · p50 0:39:32 · p90 3:27:57 · most 5:25:28 · 31.5% (63) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 1.8% · median 12.6% · most 90.0%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 98.5% (197) | 217 | 0:01:00 · 0:04:30 · 0:24:37 | 38 · 64 · 115 |
| poop_space | 58.0% (116) | 116 | 0:00:49 · 0:01:06 · 0:02:20 | 0 · 7 · 109 |
| aft_bilge_p | 54.5% (109) | 109 | 0:00:47 · 0:01:05 · 0:02:19 | 0 · 0 · 109 |
| aft_bilge_s | 54.5% (109) | 109 | 0:00:47 · 0:01:05 · 0:02:19 | 0 · 0 · 109 |
| aft_cabins | 100.0% (200) | 354 | 0:00:13 · 0:03:30 · 0:24:05 | 181 · 120 · 53 |
| engine_bilge_p | 96.0% (192) | 242 | 0:01:06 · 0:03:09 · 0:21:22 | 51 · 1 · 190 |
| engine_bilge_s | 95.5% (191) | 241 | 0:01:06 · 0:03:09 · 0:21:22 | 51 · 0 · 190 |
| engine_room | 85.5% (171) | 225 | 0:00:03 · 0:03:15 · 0:21:22 | 48 · 119 · 58 |
| hold_bilge | 45.5% (91) | 160 | 0:00:41 · 0:00:50 · 0:00:56 | 73 · 0 · 87 |
| hold | 45.5% (91) | 160 | 0:00:41 · 0:00:50 · 0:00:56 | 73 · 0 · 87 |
| hold_wing_p | 52.0% (104) | 176 | 0:00:41 · 0:00:54 · 0:14:07 | 76 · 2 · 98 |
| hold_wing_s | 52.5% (105) | 173 | 0:00:41 · 0:00:55 · 0:04:06 | 72 · 3 · 98 |
| hold_fwd_top | 100.0% (200) | 272 | 0:00:44 · 0:04:30 · 0:40:37 | 101 · 1 · 170 |
| forepeak | 50.0% (100) | 149 | 0:00:28 · 0:01:34 · 0:03:30 | 86 · 63 · 0 |
| deckhouse_cabins | 55.5% (111) | 111 | 0:02:13 · 0:03:53 · 0:21:20 | 0 · 2 · 109 |
| deckhouse_hall | 55.5% (111) | 111 | 0:00:13 · 0:00:21 · 0:00:25 | 0 · 111 · 0 |
| saloon | 1.5% (3) | 4 | 0:00:10 · 0:00:12 · 0:00:12 | 1 · 3 · 0 |
| wheelhouse | 37.5% (75) | 75 | 0:00:32 · 0:02:30 · 0:06:06 | 1 · 74 · 0 |

## What it costs (this machine, Apple M1)

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 1.34 · p95 4.55 · most 6.05 s | over |
| a match's bakes: p95 under 5.0 s | p50 4.08 · p95 8.77 · most 11.63 s | over |
| the longest timeline under 200 kB | p50 15.5 · p95 19.8 · most 21.9 kB | in |

Steps a bake: p50 976 · p95 2025 · most 2708. The longest sinking (gone at 5:25:28) keeps 294 of 2647 states, 10.9 kB; with every state kept, 25.3 kB.
