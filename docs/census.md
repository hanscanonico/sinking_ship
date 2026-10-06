# Outcome census — the steamer, seeds 1…200

Written by `make census SHIP=steamer SEEDS=200` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). The match census drops the survivors, so its other shares rise in proportion (§5b.4).

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 72.5% (145) | 0.0% (0) | 20–40% | over |
| founders upright, by the head or the stern | 23.0% (46) | 87.0% (174) | 30–55% | under |
| — by the head | 16.5% (33) | 54.5% (109) | — |  |
| — by the stern | 11.0% (22) | 45.5% (91) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 15.0% (30) | 5.0% (10) | 15–35% | in |
| capsizes (rolled past 90°) | 4.5% (9) | 13.0% (26) | 5–20% | under |
| gone within 20 min of physics | 8.0% (16) | 33.5% (67) | 10–30% | under |
| breaks | 0 | 0 | 0 in 500 | in — no breaking stage yet (SH33) |

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

p10 0:07:20 · p50 0:36:41 · p90 3:21:01 · most 5:24:42 · 33.5% (67) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

Over 20 bots-only matches (seeds 1…20, each to its end or 0:15:00), the share of the sinking from the hit to her going that the match saw: least 1.9% · median 13.8% · most 95.6%; 0 saw her go.

## What it costs (this machine, Apple M1)

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 2.4 s | p50 0.89 · p95 1.96 · most 2.63 s | in |
| a match's bakes: p95 under 5.0 s | p50 1.57 · p95 3.48 · most 4.71 s | in |
| the longest timeline under 200 kB | p50 13.9 · p95 19.7 · most 26.7 kB | in |

Steps a bake: p50 955 · p95 2004 · most 2626. The longest sinking (gone at 5:24:42) keeps 377 of 2612 states, 11.3 kB; with every state kept, 23.0 kB.
