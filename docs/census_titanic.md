# Outcome census — the titanic, seeds 1…6

Written by `make census SHIP=titanic SEEDS=6` (tools/census.gd): bakes alone, as §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here before any of them gates (R24); nothing in `make verify` reads this file.

## Each label's share against its band

The raw census bakes each seed's first drawn hit as drawn, past the quick check; the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4 expects the match census's other shares to rise in proportion as it drops the survivors, but where she survived a seed's first hit the rule bakes another, so a share can fall as well as rise.

| Label | Raw census | Match census | Band (raw, est.) | Raw against it |
|---|---|---|---|---|
| survives | 0.0% (0) | 0.0% (0) | 20–40% | under |
| — afloat upside down, on her leaking air | 0.0% (0) | 0.0% (0) | — |  |
| founders upright, by the head or the stern | 100.0% (6) | 100.0% (6) | 35–60% | over |
| — gone by the head, capsized or not | 83.3% (5) | 83.3% (5) | — |  |
| — gone by the stern, capsized or not | 16.7% (1) | 16.7% (1) | — |  |
| founders onto her side | 0.0% (0) | 0.0% (0) | — |  |
| heavy list (≥ 15° for ≥ 5 min afloat) | 0.0% (0) | 0.0% (0) | 5–25% | under |
| capsizes (rolled past 90°) | 0.0% (0) | 0.0% (0) | 0–5% | in |
| comes to rest aground, part of her dry (a coast's, SH32) | 0.0% (0) | 0.0% (0) | — |  |
| gone within 20 min of physics | 0.0% (0) | 0.0% (0) | 0–10% | in |
| lights out — her generator stopped for good before she went | 100.0% (6) | 100.0% (6) | — |  |
| funnel fell before she went | 100.0% (6) | 100.0% (6) | — |  |
| breaks (in two or three, SH33) | 0.0% (0) | 0.0% (0) | 1–10% | under |

Capsizes counts a roll past 90° only while her trim is under 45°: stood further on end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll then is no capsize. The founders rows read how she stands as she goes, so a hull that capsized is counted by the end she goes with unless she goes on her side; founders upright leaves the capsized out, its two sub-rows keep them.

## The must-sink rule, per match

| Measure | Measured | Band (est.) |
|---|---|---|
| hits drawn again | 0.00 a match (0 in all) | 0.2–1.5 |
| of them thrown out by the quick check | 0.00 a match (0) | — |
| bakes | 1.00 a match · p95 1 · max 1 | 1.0–1.7 on average, 5 at most (§5b.1) |
| fallback used (a rung or the sure hit) | 0.0% (0) | under 1% |
| — the sure hit | 0.0% (0) | — |
| afloat at the bake's end | 0.0% (0) | 0% by construction |

## The fallback's rungs, and the holes they make

Each rung doubles the hit's equivalent width and runs the gash on into the next cell (§5b.1). Where a match took a rung, the hole it was struck with:

| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |
|---|---|---|---|---|
| — | 0 | — | — | — |
| sure hit | 0 | — | — | — |

Beside them, the holes of the 6 matches whose drawn hit sank her: least 1.057 · median 1.447 · p95 2.026 · most 2.026 m².

## From the hit to her going (match census, physics time)

p10 0:43:18 · p50 1:31:20 · p90 3:47:08 · most 3:47:08 · 0.0% (0) within 20 min.

## How much of her sinking a match sees (R33; Q20, the clock at 1.0)

No match was played (MATCHES=0).

## How long the air pockets last (match census, physics time; SH29)

A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from then until it is gone, cut where she went. Its leak is the cell's leak area (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out — blown out — or as the water squeezes it to nothing.

| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most | Blown out · leaked or squeezed out · held as she went |
|---|---|---|---|---|
| db_after_hold_aft | 100.0% (6) | 12 | 0:42:46 · 2:50:09 · 3:38:20 | 3 · 5 · 4 |
| db_after_hold_fwd | 100.0% (6) | 12 | 0:42:46 · 2:38:12 · 3:38:20 | 5 · 3 · 4 |
| db_electric_room | 50.0% (3) | 27 | 0:00:05 · 0:02:12 · 0:03:43 | 21 · 5 · 1 |
| db_turbine_room | 100.0% (6) | 30 | 0:00:06 · 0:02:50 · 0:13:30 | 20 · 7 · 3 |
| db_engine_room | 100.0% (6) | 20 | 0:00:39 · 0:13:30 · 1:19:45 | 13 · 7 · 0 |
| db_boiler_room_1 | 100.0% (6) | 29 | 0:00:05 · 0:09:23 · 1:25:20 | 21 · 8 · 0 |
| db_boiler_room_2 | 100.0% (6) | 71 | 0:00:03 · 0:02:33 · 1:24:46 | 59 · 11 · 1 |
| db_boiler_room_3 | 100.0% (6) | 44 | 0:00:04 · 0:01:59 · 1:07:15 | 28 · 15 · 1 |
| db_boiler_room_4 | 83.3% (5) | 24 | 0:00:09 · 0:05:06 · 0:59:59 | 15 · 8 · 1 |
| db_boiler_room_5 | 100.0% (6) | 21 | 0:00:02 · 0:03:58 · 0:36:24 | 10 · 11 · 0 |
| db_boiler_room_6 | 100.0% (6) | 32 | 0:00:04 · 0:08:01 · 0:35:04 | 20 · 9 · 3 |
| db_hold_3 | 83.3% (5) | 74 | 0:00:08 · 0:07:54 · 0:31:54 | 59 · 13 · 2 |
| db_hold_2 | 83.3% (5) | 34 | 0:00:21 · 0:14:22 · 0:59:08 | 27 · 6 · 1 |
| db_hold_1 | 83.3% (5) | 19 | 0:00:32 · 0:33:25 · 1:16:27 | 14 · 4 · 1 |
| forepeak_tank | 83.3% (5) | 28 | 0:00:01 · 0:07:07 · 0:12:34 | 19 · 8 · 1 |
| forepeak | 83.3% (5) | 8 | 0:01:32 · 0:12:05 · 0:12:05 | 4 · 4 · 0 |
| hold_1 | 66.7% (4) | 22 | 0:00:01 · 0:01:01 · 0:12:46 | 14 · 8 · 0 |
| hold_1_tween | 83.3% (5) | 11 | 0:00:04 · 0:12:59 · 0:15:28 | 7 · 1 · 3 |
| hold_2_port | 50.0% (3) | 3 | 0:00:01 · 0:00:21 · 0:00:21 | 2 · 1 · 0 |
| hold_2_starboard | 33.3% (2) | 2 | 0:00:00 · 0:00:00 · 0:00:00 | 0 · 2 · 0 |
| hold_2 | 83.3% (5) | 31 | 0:00:10 · 0:00:52 · 0:24:42 | 24 · 7 · 0 |
| hold_3_port | 33.3% (2) | 4 | 0:00:01 · 0:00:02 · 0:00:02 | 1 · 3 · 0 |
| hold_3_starboard | 33.3% (2) | 2 | 0:00:09 · 0:00:09 · 0:00:09 | 0 · 2 · 0 |
| hold_3 | 83.3% (5) | 31 | 0:00:07 · 0:02:12 · 0:03:49 | 26 · 5 · 0 |
| firemens_passage | 50.0% (3) | 8 | 0:00:03 · 0:10:54 · 0:10:54 | 6 · 2 · 0 |
| bunker_6 | 66.7% (4) | 5 | 0:01:40 · 0:22:24 · 0:22:24 | 2 · 2 · 1 |
| boiler_room_6 | 100.0% (6) | 15 | 0:00:15 · 0:22:24 · 0:24:51 | 9 · 4 · 2 |
| bunker_5 | 66.7% (4) | 4 | 0:15:16 · 0:48:48 · 0:48:48 | 1 · 2 · 1 |
| boiler_room_5 | 100.0% (6) | 8 | 0:01:55 · 0:49:40 · 0:49:40 | 2 · 3 · 3 |
| boiler_room_5_f | 100.0% (6) | 9 | 0:01:46 · 0:04:45 · 0:04:45 | 5 · 3 · 1 |
| bunker_4 | 66.7% (4) | 8 | 0:02:06 · 0:17:38 · 0:17:38 | 5 · 2 · 1 |
| boiler_room_4 | 100.0% (6) | 10 | 0:04:23 · 0:34:25 · 0:34:25 | 6 · 2 · 2 |
| boiler_room_4_f | 83.3% (5) | 12 | 0:00:12 · 0:00:39 · 0:02:56 | 11 · 0 · 1 |
| bunker_3 | 83.3% (5) | 17 | 0:00:25 · 0:17:12 · 0:18:23 | 10 · 4 · 3 |
| boiler_room_3 | 100.0% (6) | 33 | 0:00:06 · 0:03:26 · 0:25:00 | 18 · 11 · 4 |
| boiler_room_3_f | 16.7% (1) | 1 | 0:00:07 · 0:00:07 · 0:00:07 | 1 · 0 · 0 |
| bunker_2 | 83.3% (5) | 34 | 0:00:20 · 0:07:53 · 1:23:12 | 20 · 11 · 3 |
| boiler_room_2 | 100.0% (6) | 50 | 0:00:03 · 0:04:08 · 1:24:15 | 38 · 9 · 3 |
| boiler_room_2_f | 83.3% (5) | 8 | 0:00:45 · 0:02:09 · 0:02:09 | 4 · 1 · 3 |
| bunker_1 | 100.0% (6) | 26 | 0:00:19 · 0:05:08 · 1:14:48 | 8 · 16 · 2 |
| boiler_room_1 | 100.0% (6) | 29 | 0:00:16 · 0:09:23 · 1:23:02 | 27 · 1 · 1 |
| boiler_room_1_f | 83.3% (5) | 7 | 0:01:19 · 0:01:48 · 0:01:48 | 2 · 0 · 5 |
| engine_room | 100.0% (6) | 26 | 0:00:12 · 0:03:57 · 1:19:43 | 12 · 13 · 1 |
| turbine_room | 100.0% (6) | 16 | 0:00:10 · 0:02:15 · 0:13:00 | 10 · 5 · 1 |
| turbine_room_tween | 33.3% (2) | 2 | 0:00:30 · 0:00:30 · 0:00:30 | 0 · 2 · 0 |
| electric_room | 50.0% (3) | 8 | 0:00:05 · 0:03:05 · 0:03:05 | 5 · 1 · 2 |
| electric_room_tween | 16.7% (1) | 2 | 0:01:52 · 0:01:52 · 0:01:52 | 1 · 1 · 0 |
| after_hold_fwd | 100.0% (6) | 9 | 0:55:42 · 3:38:20 · 3:38:20 | 3 · 1 · 5 |
| after_hold_fwd_orlop | 16.7% (1) | 6 | 0:00:06 · 0:00:18 · 0:00:18 | 4 · 2 · 0 |
| after_hold_fwd_tween | 16.7% (1) | 2 | 0:02:19 · 0:02:19 · 0:02:19 | 1 · 1 · 0 |
| after_hold_aft | 100.0% (6) | 12 | 0:42:46 · 2:50:10 · 3:38:20 | 5 · 3 · 4 |
| after_hold_aft_orlop | 16.7% (1) | 1 | 0:00:14 · 0:00:14 · 0:00:14 | 0 · 1 · 0 |
| after_hold_aft_tween | 16.7% (1) | 2 | 0:00:03 · 0:00:03 · 0:00:03 | 2 · 0 · 0 |
| after_peak_tank | 16.7% (1) | 1 | 0:00:01 · 0:00:01 · 0:00:01 | 0 · 1 · 0 |
| after_peak_tween | 16.7% (1) | 1 | 0:02:00 · 0:02:00 · 0:02:00 | 0 · 1 · 0 |
| forecastle | 83.3% (5) | 12 | 0:01:11 · 0:03:28 · 0:03:56 | 12 · 0 · 0 |
| forecastle_head | 83.3% (5) | 8 | 0:01:47 · 0:03:28 · 0:03:28 | 4 · 4 · 0 |
| c_deck | 16.7% (1) | 1 | 0:00:43 · 0:00:43 · 0:00:43 | 0 · 0 · 1 |
| poop | 16.7% (1) | 2 | 0:01:10 · 0:01:10 · 0:01:10 | 2 · 0 · 0 |
| b_deck | 16.7% (1) | 1 | 0:00:43 · 0:00:43 · 0:00:43 | 0 · 0 · 1 |
| a_deck | 100.0% (6) | 6 | 0:00:21 · 0:01:06 · 0:01:06 | 0 · 0 · 6 |
| officers_house | 100.0% (6) | 6 | 0:01:34 · 0:02:02 · 0:02:02 | 0 · 5 · 1 |
| staircase_house | 100.0% (6) | 6 | 0:01:25 · 0:01:44 · 0:01:44 | 0 · 5 · 1 |

## What gave way, and her bending (match census; SH31)

| Gave way before she went | Sinkings | Share |
|---|---|---|
| a watertight door | 6 | 100.0% (6) |
| a wall's panel | 6 | 100.0% (6) |
| a hatch | 6 | 100.0% (6) |
| a door, hinged | 6 | 100.0% (6) |
| a window | 0 | 0.0% (0) |
| a porthole | 6 | 100.0% (6) |

| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |
|---|---|---|---|---|
| raw census | 0.923 | 1.018 | 1.018 | NO |
| match census | 0.923 | 1.018 | 1.018 | NO |

The hull creaked — her bending past 80% of her strength — in 4 of 6 sinkings; she breaks only at a weak spot of hers, past its share of it (SH33).

## What it costs (this machine, Apple M1)

Load average when measured: 4,61 · 9,52 · 36,29 (1 · 5 · 15 min). The cost lines depend on the machine's load; the plan's R20 budgets are judged on a quiet machine.

| Budget (§5b.4, est.) | Measured | Against it |
|---|---|---|
| one bake: p95 under 90.0 s | p50 477.71 · p95 836.23 · most 836.23 s | over |
| a match's bakes: p95 under 150.0 s | p50 111.60 · p95 176.66 · most 176.66 s | over |
| the longest timeline under 2000 kB | p50 253.0 · p95 313.8 · most 313.8 kB | in |

These cost lines were measured at a 15-minute load average of 36; a quiet-load bake of the night's damage is 76 s.

Steps a bake: p50 3601 · p95 4923 · most 4923. The longest sinking (gone at 3:47:08) keeps 3899 of 4924 states, 253.0 kB; with every state kept, 269.7 kB.
