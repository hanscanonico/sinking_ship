# Outcome census — the titanic, seeds 1…40

Written by `make census SHIP=titanic SEEDS=40` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 52.5% (21) | 0.0% (0) | 20–40% | over |
| — afloat upside down, on her leaking air | 2.5% (1) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 30.0% (12) | 60.0% (24) | 35–60% | under |
| — gone by the head, capsized or not | 22.5% (9) | 60.0% (24) | — |  |
| — gone by the stern, capsized or not | 25.0% (10) | 40.0% (16) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 17.5% (7) | 42.5% (17) | 5–25% | in |
| capsizes (rolled past 90°) | 17.5% (7) | 40.0% (16) | 0–5% | over |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 0.0% (0) | 0.0% (0) | 0–10% | in |
| lights out — her generator stopped for good before she went | 72.5% (29) | 100.0% (40) | — |  |
| funnel fell before she went | 82.5% (33) | 100.0% (40) | — |  |
| breaks (in two or three, SH33) | 62.5% (25) | 55.0% (22) | 1–10% | over |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.85 a match (34 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 2.02 a match · p95 5 · max 5 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 10.0% (4) | under 1% |
| — the sure hit | 7.5% (3) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| 1 | 1 | 2.787 · 2.787 · 2.787 | 0.071 · 0.071 · 0.071 | 27 |
| sure hit | 3 | 2.125 · 2.125 · 2.125 | her data's | — |

Beside them, the holes of the 36 matches whose drawn hit sank her: least 0.457 · median 1.524 · p95 2.478 · most 3.204 m².

## From the hit to her going (match census, physics time)

p10 0:44:04 · p50 1:30:46 · p90 4:53:35 · most 5:22:52 · 0.0% (0) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

No match was played (MATCHES=0).

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 40 | 100.0% (40) |
| a wall's panel | 40 | 100.0% (40) |
| a hatch | 40 | 100.0% (40) |
| a door, hinged | 40 | 100.0% (40) |
| a window | 0 | 0.0% (0) |
| a porthole | 40 | 100.0% (40) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.946 | 1.022 | 1.048 | NO |
| match census | 0.935 | 1.036 | 1.048 | NO |

The hull creaked — her bending past 80% of her strength — in 34 of 40 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 4,08 · 4,04 · 4,33 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 90.0 s | p50 77.71 · p95 153.15 · most 213.51 s | over |
| a match's bakes: p95 under 150.0 s | p50 127.59 · p95 249.87 · most 357.56 s | over |
| the longest timeline under 2000 kB | p50 226.5 · p95 287.7 · most 290.1 kB | in |

Steps a bake: p50 3226 · p95 5223 · most 5909. The longest sinking (gone at 5:22:52) keeps 3884 of 6239 states, 241.5 kB; with every state kept, 270.2 kB.
