# Outcome census — the titanic, seeds 1…40

Written by `make census SHIP=titanic SEEDS=40` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 37.5% (15) | 0.0% (0) | 20–40% | in |
| — afloat upside down, on her leaking air | 5.0% (2) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 47.5% (19) | 92.5% (37) | 35–60% | in |
| — gone by the head, capsized or not | 35.0% (14) | 72.5% (29) | — |  |
| — gone by the stern, capsized or not | 27.5% (11) | 27.5% (11) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 22.5% (9) | 20.0% (8) | 5–25% | in |
| capsizes (rolled past 90°) | 15.0% (6) | 7.5% (3) | 0–5% | over |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 0.0% (0) | 2.5% (1) | 0–10% | in |
| lights out — her generator stopped for good before she went | 90.0% (36) | 100.0% (40) | — |  |
| funnel fell before she went | 90.0% (36) | 100.0% (40) | — |  |
| breaks (in two or three, SH33) | 60.0% (24) | 25.0% (10) | 1–10% | over |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 1.20 a match (48 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.05 a match (2) | — |
| bakes | 2.60 a match · p95 5 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 27.5% (11) | under 1% |
| — the sure hit | 17.5% (7) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 4 | 5.574 · 6.461 · 10.555 | 0.143 · 0.157 · 0.183 | 8, 27, 28, 31 |
| sure hit | 7 | 2.125 · 2.125 · 2.125 | her data's | — |

Beside them, the holes of the 29 matches whose drawn hit sank her: least 1.372 · median 3.112 · p95 4.662 · most 6.408 m².

## From the hit to her going (match census, physics time)

p10 0:31:11 · p50 0:46:36 · p90 1:21:07 · most 1:28:48 · 2.5% (1) within 20 min.

## From the hit to her going (match census, match time on the paced clock, Q20)

p10 0:16:00 · p50 0:17:59 · p90 0:23:41 · most 0:24:48 · 20.0% (8) within 0:16:30. Phases, median share of the sinking: opening 43.0% · middle 41.0% · end 15.4% (asked 25 / 50 / 25); 2.5% (1) with every phase within 5 points. Plunge: p10 31.8 s · p50 33.2 s · least 31.1 s; 100.0% (40) of 20 s or more.

Where a sinking runs past its length the 6.0× limit held it (realism over length); where a plunge runs short of its least, the 0.15× limit did.

## How much of her sinking a match sees (R33; Q20, the paced clock)

No match was played (MATCHES=0).

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 40 | 100.0% (40) |
| a wall's panel | 40 | 100.0% (40) |
| a hatch | 40 | 100.0% (40) |
| a door, hinged | 40 | 100.0% (40) |
| a window | 40 | 100.0% (40) |
| a porthole | 40 | 100.0% (40) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.941 | 1.004 | 1.025 | NO |
| match census | 0.921 | 1.015 | 1.025 | NO |

The hull creaked — her bending past 80% of her strength — in 37 of 40 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 3,55 · 3,92 · 4,90 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 90.0 s | p50 124.33 · p95 200.31 · most 214.81 s | over |
| a match's bakes: p95 under 150.0 s | p50 199.94 · p95 367.16 · most 432.99 s | over |
| the longest timeline under 2000 kB | p50 474.0 · p95 517.7 · most 539.6 kB | in |

Steps a bake: p50 3476 · p95 4998 · most 5008. The longest sinking (gone at 1:28:48) keeps 3324 of 3399 states, 539.6 kB; with every state kept, 542.4 kB.
