# Outcome census — the ferry, seeds 1…40

Written by `make census SHIP=ferry SEEDS=40` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 17.5% (7) | 0.0% (0) | — |  |
| — afloat upside down, on her leaking air | 2.5% (1) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 27.5% (11) | 30.0% (12) | — |  |
| — gone by the head, capsized or not | 47.5% (19) | 45.0% (18) | — |  |
| — gone by the stern, capsized or not | 35.0% (14) | 55.0% (22) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 55.0% (22) | 72.5% (29) | — |  |
| capsizes (rolled past 90°) | 57.5% (23) | 70.0% (28) | — |  |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 12.5% (5) | 17.5% (7) | — |  |
| lights out — her generator stopped for good before she went | 85.0% (34) | 100.0% (40) | — |  |
| funnel fell before she went | 85.0% (34) | 100.0% (40) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | — |  |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.72 a match (29 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.03 a match (1) | — |
| bakes | 1.88 a match · p95 5 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 12.5% (5) | under 1% |
| — the sure hit | 5.0% (2) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 3 | 2.363 · 2.436 · 6.467 | 0.087 · 0.107 · 0.282 | 1, 28, 32 |
| sure hit | 2 | 4.160 · 4.160 · 4.160 | her data's | — |

Beside them, the holes of the 35 matches whose drawn hit sank her: least 0.395 · median 1.216 · p95 8.399 · most 11.273 m².

## From the hit to her going (match census, physics time)

p10 0:09:19 · p50 0:47:59 · p90 1:20:51 · most 1:26:43 · 17.5% (7) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:09:41 · p50 0:16:00 · p90 0:19:30 · most 0:23:12 · 65.0% (26) within 0:16:30. Phases, median share of the sinking: opening 38.8% · middle 32.4% · end 23.4% (asked 25 / 50 / 25); 2.5% (1) with every phase within 5 points. Plunge: p10 35.6 s · p50 56.2 s · least 26.3 s; 100.0% (40) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

Over 2 bots-only matches (seeds 1…2, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 46.3% · median 85.4% · most 85.4%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 55.0% (22) | 35 | 0:02:50 · 0:26:08 · 0:56:15 | 17 · 10 · 8 |
| engine_wing_p | 85.0% (34) | 60 | 0:00:09 · 0:07:44 · 0:26:08 | 29 · 5 · 26 |
| engine_room | 100.0% (40) | 67 | 0:00:12 · 0:07:16 · 0:26:08 | 26 · 14 · 27 |
| engine_wing_s | 62.5% (25) | 47 | 0:00:06 · 0:07:16 · 0:26:08 | 23 · 6 · 18 |
| quarters_wing_p | 85.0% (34) | 50 | 0:00:20 · 0:08:19 · 0:22:20 | 20 · 16 · 14 |
| crew_quarters | 97.5% (39) | 64 | 0:00:15 · 0:07:40 · 0:27:44 | 27 · 22 · 15 |
| quarters_wing_s | 67.5% (27) | 43 | 0:00:14 · 0:11:22 · 0:27:44 | 19 · 10 · 14 |
| tank_wing_p | 72.5% (29) | 50 | 0:00:32 · 0:11:22 · 0:33:40 | 20 · 7 · 23 |
| tanks | 77.5% (31) | 53 | 0:00:31 · 0:09:45 · 0:35:05 | 26 · 2 · 25 |
| tank_wing_s | 75.0% (30) | 50 | 0:00:25 · 0:11:22 · 0:35:05 | 22 · 4 · 24 |
| fore_peak | 20.0% (8) | 12 | 0:01:31 · 0:54:06 · 1:05:37 | 10 · 2 · 0 |
| car_deck | 92.5% (37) | 52 | 0:00:15 · 0:07:59 · 0:22:20 | 15 · 1 · 36 |
| passenger_house | 65.0% (26) | 29 | 0:01:22 · 0:04:17 · 0:07:43 | 15 · 9 · 5 |
| wheelhouse | 10.0% (4) | 5 | 0:08:13 · 0:09:33 · 0:09:33 | 2 · 3 · 0 |
| engine_bilge | 95.0% (38) | 62 | 0:00:12 · 0:07:59 · 0:26:08 | 30 · 4 · 28 |
| quarters_bilge | 87.5% (35) | 57 | 0:00:27 · 0:08:29 · 0:27:44 | 23 · 17 · 17 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 33 | 82.5% (33) |
| a wall's panel | 40 | 100.0% (40) |
| a hatch | 0 | 0.0% (0) |
| a door, hinged | 17 | 42.5% (17) |
| a window | 33 | 82.5% (33) |
| a porthole | 0 | 0.0% (0) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.070 | 0.108 | 0.110 | yes |
| match census | 0.075 | 0.108 | 0.110 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 40 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, 13th Gen Intel(R) Core(TM) i7-13650HX)

Load average when measured: unknown. The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 12.83 · p95 24.13 · most 29.18 s | over |
| a match's bakes: p95 under 5.0 s | p50 17.20 · p95 34.02 · most 34.68 s | over |
| the longest timeline under 200 kB | p50 32.4 · p95 41.3 · most 49.7 kB | in |

Steps a bake: p50 1772 · p95 4132 · most 4627. The longest sinking (gone at 1:26:43) keeps 1015 of 1888 states, 32.6 kB; with every state kept, 47.4 kB.
