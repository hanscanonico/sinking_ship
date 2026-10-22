# Outcome census — the barque, seeds 1…40

Written by `make census SHIP=barque SEEDS=40` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 5.0% (2) | 0.0% (0) | — |  |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 10.0% (4) | 10.0% (4) | — |  |
| — gone by the head, capsized or not | 87.5% (35) | 92.5% (37) | — |  |
| — gone by the stern, capsized or not | 5.0% (2) | 5.0% (2) | — |  |
| founders onto her side | 2.5% (1) | 2.5% (1) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 40.0% (16) | 40.0% (16) | — |  |
| capsizes (rolled past 90°) | 85.0% (34) | 90.0% (36) | — |  |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 75.0% (30) | 80.0% (32) | — |  |
| lights out — her generator stopped for good before she went | 0.0% (0) | 0.0% (0) | — |  |
| funnel fell before she went | 0.0% (0) | 0.0% (0) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | — |  |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.05 a match (2 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.05 a match · p95 2 · max 2 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 0.0% (0) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| — | 0 | — | — | — |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 40 matches whose drawn hit sank her: least 0.050 · median 0.399 · p95 2.605 · most 4.253 m².

## From the hit to her going (match census, physics time)

p10 0:02:46 · p50 0:07:48 · p90 0:42:24 · most 1:16:58 · 80.0% (32) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:05:26 · p50 0:05:54 · p90 0:11:05 · most 0:16:02 · 100.0% (40) within 0:16:30. Phases, median share of the sinking: opening 56.4% · middle 26.9% · end 17.6% (asked 25 / 50 / 25); 0.0% (0) with every phase within 5 points. Plunge: p10 26.1 s · p50 30.2 s · least 8.3 s; 97.5% (39) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

Over 2 bots-only matches (seeds 1…2, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 88.0% · median 96.5% · most 96.5%; 0 saw her go.

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| aft_peak | 100.0% (40) | 50 | 0:00:12 · 0:00:20 · 0:28:49 | 14 · 0 · 36 |
| side_tank_p | 87.5% (35) | 79 | 0:00:02 · 0:00:07 · 0:00:10 | 50 · 22 · 7 |
| engine_room | 92.5% (37) | 93 | 0:00:03 · 0:00:07 · 0:00:09 | 57 · 15 · 21 |
| hold | 77.5% (31) | 57 | 0:00:01 · 0:00:04 · 0:00:05 | 36 · 21 · 0 |
| sail_locker | 50.0% (20) | 26 | 0:00:03 · 0:00:05 · 0:00:10 | 22 · 2 · 2 |
| side_tank_s | 77.5% (31) | 68 | 0:00:03 · 0:00:07 · 0:00:10 | 42 · 10 · 16 |
| fore_peak | 97.5% (39) | 64 | 0:00:06 · 0:00:21 · 0:13:56 | 42 · 18 · 4 |
| tween_deck | 97.5% (39) | 95 | 0:00:03 · 0:00:07 · 0:00:10 | 57 · 0 · 38 |
| poop | 100.0% (40) | 52 | 0:00:12 · 0:00:19 · 0:00:24 | 14 · 1 · 37 |
| forecastle | 100.0% (40) | 83 | 0:00:08 · 0:00:21 · 0:00:54 | 65 · 15 · 3 |
| deckhouse | 100.0% (40) | 119 | 0:00:00 · 0:00:06 · 0:00:15 | 115 · 4 · 0 |
| charthouse | 62.5% (25) | 28 | 0:00:02 · 0:00:06 · 0:00:07 | 3 · 18 · 7 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 0 | 0.0% (0) |
| a wall's panel | 39 | 97.5% (39) |
| a hatch | 40 | 100.0% (40) |
| a door, hinged | 0 | 0.0% (0) |
| a window | 40 | 100.0% (40) |
| a porthole | 0 | 0.0% (0) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.041 | 0.061 | 0.061 | yes |
| match census | 0.041 | 0.061 | 0.061 | yes |

The hull creaked — her bending past 80% of her strength — in 0 of 40 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, 13th Gen Intel(R) Core(TM) i7-13650HX)

Load average when measured: unknown. The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 10.24 · p95 19.42 · most 23.10 s | over |
| a match's bakes: p95 under 5.0 s | p50 7.93 · p95 15.54 · most 17.70 s | over |
| the longest timeline under 200 kB | p50 19.9 · p95 24.1 · most 24.6 kB | in |

Steps a bake: p50 801 · p95 3968 · most 3969. The longest sinking (gone at 1:16:58) keeps 391 of 1578 states, 16.1 kB; with every state kept, 28.1 kB.
