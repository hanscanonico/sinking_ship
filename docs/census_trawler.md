# Outcome census — the trawler, seeds 1…200

Written by `make census SHIP=trawler SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 17.5% (35) | 0.0% (0) | 15–35% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 39.5% (79) | 44.5% (89) | 15–35% | over |
| — gone by the head, capsized or not | 36.5% (73) | 44.0% (88) | — |  |
| — gone by the stern, capsized or not | 43.0% (86) | 52.0% (104) | — |  |
| founders onto her side | 3.0% (6) | 4.0% (8) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 31.5% (63) | 31.5% (63) | 10–30% | over |
| capsizes (rolled past 90°) | 43.0% (86) | 55.5% (111) | 25–50% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 50.0% (100) | 65.0% (130) | 30–60% | in |
| lights out — her generator stopped for good before she went | 82.5% (165) | 100.0% (200) | — |  |
| funnel fell before she went | 82.5% (165) | 100.0% (200) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 0–0% | in |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.24 a match (48 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.24 a match · p95 2 · max 3 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 0.0% (0) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| — | 0 | — | — | — |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 200 matches whose drawn hit sank her: least 0.013 · median 0.126 · p95 0.675 · most 1.484 m².

## From the hit to her going (match census, physics time)

p10 0:03:44 · p50 0:14:29 · p90 0:46:34 · most 1:27:27 · 65.0% (130) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:06:09 · p50 0:07:22 · p90 0:12:22 · most 0:18:25 · 96.5% (193) within 0:16:30. Phases, median share of the sinking: opening 58.4% · middle 25.0% · end 11.3% (asked 25 / 50 / 25); 0.0% (0) with every phase within 5 points. Plunge: p10 7.0 s · p50 23.6 s · least 5.7 s; 52.0% (104) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 20.4% · median 92.7% · most 98.6%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| engine_wing_p | 38.5% (77) | 151 | 0:00:02 · 0:00:14 · 0:00:44 | 105 · 34 · 12 |
| engine_room | 48.0% (96) | 189 | 0:00:02 · 0:00:13 · 0:00:37 | 120 · 51 · 18 |
| engine_wing_s | 39.0% (78) | 154 | 0:00:03 · 0:00:17 · 0:00:37 | 113 · 25 · 16 |
| hold_wing_p | 84.0% (168) | 387 | 0:00:01 · 0:00:11 · 0:00:43 | 259 · 23 · 105 |
| fish_hold | 97.0% (194) | 465 | 0:00:02 · 0:00:11 · 0:00:55 | 309 · 37 · 119 |
| hold_wing_s | 86.5% (173) | 408 | 0:00:02 · 0:00:12 · 0:00:55 | 277 · 13 · 118 |
| fore | 79.0% (158) | 203 | 0:00:08 · 0:00:29 · 0:01:38 | 68 · 66 · 69 |
| deckhouse | 68.0% (136) | 248 | 0:00:00 · 0:00:06 · 0:00:30 | 205 · 43 · 0 |
| wheelhouse | 36.0% (72) | 72 | 0:00:04 · 0:00:07 · 0:00:09 | 1 · 14 · 57 |
| engine_bilge | 57.0% (114) | 263 | 0:00:03 · 0:00:18 · 0:00:44 | 188 · 28 · 47 |
| hold_bilge | 98.0% (196) | 475 | 0:00:02 · 0:00:12 · 0:00:55 | 322 · 16 · 137 |
| fore_stores | 78.0% (156) | 226 | 0:00:08 · 0:00:30 · 0:01:41 | 89 · 19 · 118 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 126 | 63.0% (126) |
| a wall's panel | 197 | 98.5% (197) |
| a hatch | 124 | 62.0% (124) |
| a door, hinged | 0 | 0.0% (0) |
| a window | 189 | 94.5% (189) |
| a porthole | 15 | 7.5% (15) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.039 | 0.078 | 0.078 | yes |
| match census | 0.040 | 0.078 | 0.078 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 200 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 12,44 · 14,98 · 15,75 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 4.81 · p95 7.57 · most 10.06 s | over |
| a match's bakes: p95 under 5.0 s | p50 5.38 · p95 13.38 · most 39.04 s | over |
| the longest timeline under 200 kB | p50 12.1 · p95 16.6 · most 17.9 kB | in |

Steps a bake: p50 800 · p95 3966 · most 3994. The longest sinking (gone at 1:27:27) keeps 461 of 1582 states, 13.3 kB; with every state kept, 21.3 kB.
