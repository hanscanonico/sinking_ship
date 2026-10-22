# Outcome census — the freighter, seeds 1…40

Written by `make census SHIP=freighter SEEDS=40` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 27.5% (11) | 0.0% (0) | — |  |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 65.0% (26) | 87.5% (35) | — |  |
| — gone by the head, capsized or not | 45.0% (18) | 65.0% (26) | — |  |
| — gone by the stern, capsized or not | 20.0% (8) | 22.5% (9) | — |  |
| founders onto her side | 7.5% (3) | 12.5% (5) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 0.0% (0) | 5.0% (2) | — |  |
| capsizes (rolled past 90°) | 0.0% (0) | 0.0% (0) | — |  |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 35.0% (14) | 52.5% (21) | — |  |
| lights out — her generator stopped for good before she went | 72.5% (29) | 100.0% (40) | — |  |
| funnel fell before she went | 72.5% (29) | 100.0% (40) | — |  |
| breaks (in two or three, SH33) | 35.0% (14) | 52.5% (21) | — |  |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.47 a match (19 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.03 a match (1) | — |
| bakes | 1.55 a match · p95 4 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 7.5% (3) | under 1% |
| — the sure hit | 2.5% (1) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 2 | 8.332 · 13.139 · 13.139 | 0.078 · 0.116 · 0.116 | 20, 39 |
| sure hit | 1 | 14.000 · 14.000 · 14.000 | her data's | — |

Beside them, the holes of the 37 matches whose drawn hit sank her: least 0.639 · median 2.410 · p95 18.696 · most 37.191 m².

## From the hit to her going (match census, physics time)

p10 0:04:13 · p50 0:19:56 · p90 1:02:01 · most 1:09:34 · 52.5% (21) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:06:14 · p50 0:07:58 · p90 0:14:18 · most 0:14:57 · 100.0% (40) within 0:16:30. Phases, median share of the sinking: opening 57.5% · middle 19.6% · end 22.7% (asked 25 / 50 / 25); 0.0% (0) with every phase within 5 points. Plunge: p10 4.8 s · p50 47.0 s · least 3.7 s; 65.0% (26) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 37.0% · median 98.3% · most 99.8%; 0 saw her go.

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 0 | 0.0% (0) |
| a wall's panel | 40 | 100.0% (40) |
| a hatch | 40 | 100.0% (40) |
| a door, hinged | 0 | 0.0% (0) |
| a window | 40 | 100.0% (40) |
| a porthole | 0 | 0.0% (0) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.610 | 0.793 | 0.856 | yes |
| match census | 0.654 | 0.802 | 0.856 | yes |

The hull creaked — her bending past 80% of her strength — in 3 of 40 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, 13th Gen Intel(R) Core(TM) i7-13650HX)

Load average when measured: unknown. The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 31.74 · p95 64.74 · most 97.29 s | over |
| a match's bakes: p95 under 5.0 s | p50 25.16 · p95 53.92 · most 82.98 s | over |
| the longest timeline under 200 kB | p50 37.2 · p95 47.4 · most 49.0 kB | in |

Steps a bake: p50 1181 · p95 3966 · most 3967. The longest sinking (gone at 1:09:34) keeps 406 of 1233 states, 29.5 kB; with every state kept, 38.4 kB.
