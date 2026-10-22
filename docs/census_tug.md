# Outcome census — the tug, seeds 1…40

Written by `make census SHIP=tug SEEDS=40` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 35.0% (14) | 0.0% (0) | 20–50% | in |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 65.0% (26) | 100.0% (40) | 50–80% | in |
| — gone by the head, capsized or not | 0.0% (0) | 0.0% (0) | — |  |
| — gone by the stern, capsized or not | 65.0% (26) | 100.0% (40) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 0.0% (0) | 0.0% (0) | 0–10% | in |
| capsizes (rolled past 90°) | 0.0% (0) | 0.0% (0) | 0–10% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 22.5% (9) | 50.0% (20) | 10–40% | in |
| lights out — her generator stopped for good before she went | 65.0% (26) | 100.0% (40) | — |  |
| funnel fell before she went | 65.0% (26) | 100.0% (40) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 0–0% | in |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.57 a match (23 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.63 a match · p95 4 · max 4 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 5.0% (2) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 2 | 0.098 · 0.582 · 0.582 | 0.015 · 0.093 · 0.093 | 8, 19 |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 38 matches whose drawn hit sank her: least 0.021 · median 0.080 · p95 0.510 · most 0.738 m².

## From the hit to her going (match census, physics time)

p10 0:05:16 · p50 0:20:15 · p90 0:53:30 · most 1:28:19 · 50.0% (20) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:06:59 · p50 0:08:17 · p90 0:12:57 · most 0:18:45 · 95.0% (38) within 0:16:30. Phases, median share of the sinking: opening 55.7% · middle 33.7% · end 9.3% (asked 25 / 50 / 25); 0.0% (0) with every phase within 5 points. Plunge: p10 11.6 s · p50 23.9 s · least 8.0 s; 55.0% (22) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

Over 2 bots-only matches (seeds 1…2, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 18.1% · median 43.3% · most 43.3%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 95.0% (38) | 440 | 0:00:00 · 0:00:03 · 0:03:39 | 437 · 1 · 2 |
| engine_room | 75.0% (30) | 30 | 0:00:07 · 0:00:08 · 0:00:09 | 0 · 22 · 8 |
| crew_mess | 100.0% (40) | 46 | 0:07:59 · 0:34:15 · 1:28:08 | 9 · 5 · 32 |
| fore_peak | 90.0% (36) | 37 | 0:00:07 · 0:00:08 · 0:05:19 | 0 · 1 · 36 |
| casing | 100.0% (40) | 40 | 0:00:06 · 0:00:07 · 0:00:09 | 40 · 0 · 0 |
| forecastle | 97.5% (39) | 39 | 0:00:07 · 0:00:08 · 0:00:09 | 0 · 0 · 39 |
| wheelhouse | 77.5% (31) | 31 | 0:00:01 · 0:00:03 · 0:00:07 | 0 · 31 · 0 |
| engine_bilge | 87.5% (35) | 35 | 0:00:07 · 0:00:08 · 0:00:09 | 1 · 18 · 16 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 12 | 30.0% (12) |
| a wall's panel | 39 | 97.5% (39) |
| a hatch | 0 | 0.0% (0) |
| a door, hinged | 40 | 100.0% (40) |
| a window | 40 | 100.0% (40) |
| a porthole | 0 | 0.0% (0) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.032 | 0.039 | 0.040 | yes |
| match census | 0.032 | 0.039 | 0.040 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 40 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, 13th Gen Intel(R) Core(TM) i7-13650HX)

Load average when measured: unknown. The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 7.84 · p95 18.97 · most 27.71 s | over |
| a match's bakes: p95 under 5.0 s | p50 6.68 · p95 18.35 · most 18.37 s | over |
| the longest timeline under 200 kB | p50 10.0 · p95 11.8 · most 12.8 kB | in |

Steps a bake: p50 782 · p95 3970 · most 3973. The longest sinking (gone at 1:28:19) keeps 274 of 1584 states, 8.8 kB; with every state kept, 17.5 kB.
