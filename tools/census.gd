extends SceneTree
## `make census SHIP=steamer SEEDS=200 [MATCHES=20]`: the outcome census (§5b.4), written
## to docs/census.md — bakes alone, no match played but the MATCHES that measure how much
## of a sinking a match sees. It runs twice over seeds 1…SEEDS. The raw census bakes each
## seed's first drawn hit as drawn, past the quick check — a check on the physics, where
## surviving keeps its band — and holds the quick check to throwing out only hits the
## bake leaves afloat. The match census applies the must-sink rule (MustSink): afloat is
## 0% by construction, and it records how often a hit was drawn again, the bakes, and the
## fallback's rungs with the holes they make. Each label's share (OutcomeClassifier)
## stands beside its band, which nothing gates on yet (R24); then the hit → gone times,
## the share of each sinking MATCHES bots-only matches saw (R33, Q20), how long each
## cell's air pockets last (SH29), what gave way and the worst bending against her
## strength (SH31), and what the bakes cost on this machine, at its load average,
## against §5b.4's budgets, with the timelines' sizes. Progress goes to stderr.
## Another ship's census goes to docs/census_SHIP.md, beside the default ship's.
##
##   godot --headless --path . -s res://tools/census.gd -- --ship=steamer --seeds=200

const RunMatch := preload("res://tools/run_match.gd")
const DEFAULT_SHIP := "steamer"
const DEFAULT_SEEDS := 200
const DEFAULT_MATCHES := 20
const OUT := "res://docs/census.md"
const SHIP_OUT := "res://docs/census_%s.md"
## How long a measuring match may run before it is stopped, as `make arena` stops one.
const MATCH_STOP := 900.0
## §5b.4's bands per ship, raw census, in percent (est.): [low, high]; and its budgets.
const BANDS := {
	"steamer":
	{
		"survives": [20, 40],
		"founders upright, by the head or the stern": [30, 55],
		"heavy list (≥ 15° for ≥ 5 min afloat)": [15, 35],
		"capsizes (rolled past 90°)": [5, 20],
		"gone within 20 min of physics": [10, 30],
		"breaks (in two or three, SH33)": [0, 0],
	},
	"trawler":
	{
		"survives": [15, 35],
		"founders upright, by the head or the stern": [15, 35],
		"heavy list (≥ 15° for ≥ 5 min afloat)": [10, 30],
		"capsizes (rolled past 90°)": [25, 50],
		"gone within 20 min of physics": [30, 60],
		"breaks (in two or three, SH33)": [0, 0],
	},
	"titanic":
	{
		"survives": [20, 40],
		"founders upright, by the head or the stern": [35, 60],
		"heavy list (≥ 15° for ≥ 5 min afloat)": [5, 25],
		"capsizes (rolled past 90°)": [0, 5],
		"gone within 20 min of physics": [0, 10],
		"breaks (in two or three, SH33)": [1, 10],
	},
}
## §5b.4's budgets — one bake's p95 and a match's bakes' p95 in seconds, the longest
## timeline in bytes —, the steamer's but where a ship has her own (SH34: est.).
const BUDGETS := {"titanic": [9.0, 20.0, 2000000]}
const BAKE_BUDGET := 2.4
const MATCH_BAKES_BUDGET := 5.0
const SIZE_BUDGET := 200000
const L := OutcomeClassifier.Outcome

var _ship: StringName
var _structure: ShipStructure
var _scenario: SinkScenario


func _initialize() -> void:
	var ship := DEFAULT_SHIP
	var seeds := DEFAULT_SEEDS
	var matches := DEFAULT_MATCHES
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--ship":
				ship = value
			"--seeds":
				seeds = value.to_int()
			"--matches":
				matches = value.to_int()
	var layout := Fleet.layout(ship)
	var scenario := Fleet.scenario(ship)
	if layout == null:
		printerr("census: no ship called %s; the fleet has %s" % [ship, ", ".join(Fleet.names())])
		quit(1)
		return
	if layout.structure == null or scenario.hit == null or seeds < 1:
		printerr("census: %s needs a structure, a hit's bands and SEEDS of 1 or more" % ship)
		quit(1)
		return
	_ship = StringName(ship)
	_structure = layout.structure
	_scenario = scenario
	var raw := _raw(layout.structure, scenario, seeds)
	var chosen := _matches(layout.structure, scenario, seeds)
	var seen := _seen(chosen, mini(matches, seeds))
	var text := _written(ship, seeds, raw, chosen, seen)
	var file := FileAccess.open(OUT if ship == DEFAULT_SHIP else SHIP_OUT % ship, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	printraw(text)
	quit()


## Each seed's first hit, baked as drawn in the sea drawn after it: its labels, whether
## the quick check would have thrown it out, its bake's seconds and steps.
func _raw(structure: ShipStructure, scenario: SinkScenario, seeds: int) -> Array[Dictionary]:
	var sea := SeaPhysics.load_default()
	var hull := LevelHull.new(structure.sections)
	var made: Array[Dictionary] = []
	for seed_value in range(1, seeds + 1):
		var stream := SeedStreams.derive(seed_value, "sink")
		var hit := IcebergHit.draw(scenario.hit, stream)
		var damage := HitMapper.map(hit, structure, scenario.hit, stream)
		damage.wave_height = scenario.draw_wave_height(stream)
		var spare := scenario.spare_deck
		var founders := MustSink.founders(
			structure, damage, hull, sea, spare, scenario.quick_failing
		)
		var started := Time.get_ticks_usec()
		var bake := SinkBake.of(structure, damage, sea, scenario.bake_cap)
		var timeline := bake.timeline()
		var took := (Time.get_ticks_usec() - started) / 1e6
		(
			made
			. append(
				{
					"labels": OutcomeClassifier.labels(timeline),
					"bending": timeline.bending,
					"thrown": not founders,
					"seconds": took,
					"steps": timeline.steps,
				}
			)
		)
		printerr("raw %d/%d · %.2f s" % [seed_value, seeds, took])
	return made


## Each seed's match hit, as the must-sink rule chose it, and what choosing it cost.
func _matches(structure: ShipStructure, scenario: SinkScenario, seeds: int) -> Array[Dictionary]:
	var sea := SeaPhysics.load_default()
	var made: Array[Dictionary] = []
	for seed_value in range(1, seeds + 1):
		var stream := SeedStreams.derive(seed_value, "sink")
		var started := Time.get_ticks_usec()
		var choice := MustSink.choose(structure, scenario, stream, sea)
		var took := (Time.get_ticks_usec() - started) / 1e6
		made.append({"choice": choice, "seconds": took, "seed": seed_value})
		printerr("match %d/%d · %.2f s · %d bakes" % [seed_value, seeds, took, choice.bakes])
	return made


## For the first [param count] seeds, a bots-only match played to its end or MATCH_STOP:
## the share of her sinking — the physics seconds from the hit to her going — it saw.
func _seen(chosen: Array[Dictionary], count: int) -> PackedFloat64Array:
	var shares := PackedFloat64Array()
	for index in count:
		var config := RunMatch.default_config(chosen[index]["seed"], 0, _ship)
		var host := RunMatch.served(config)
		var stop := Ticks.from_seconds(MATCH_STOP)
		while not host.is_over() and host.tick() < stop:
			host.step()
		var schedule := host.runner.sim.schedule
		var timeline := schedule.timeline()
		var since := Ticks.to_seconds(maxi(host.tick() - schedule.hit_tick(), 0))
		since *= config.scenario.clock
		shares.append(minf(since / timeline.gone_at, 1.0))
		printerr("seen %d/%d · %.1f%%" % [index + 1, count, shares[-1] * 100.0])
	return shares


func _written(
	ship: String,
	seeds: int,
	raw: Array[Dictionary],
	chosen: Array[Dictionary],
	seen: PackedFloat64Array
) -> String:
	var lines := PackedStringArray()
	lines.append("# Outcome census — the %s, seeds 1…%d" % [ship, seeds])
	lines.append("")
	lines.append(
		(
			(
				"Written by `make census SHIP=%s SEEDS=%d` (tools/census.gd): bakes alone, as"
				+ " §5b.4 runs them. The bands are §5b.4's, every one an estimate, shown here"
				+ " before any of them gates (R24); nothing in `make verify` reads this file."
			)
			% [ship, seeds]
		)
	)
	lines.append("")
	lines.append_array(_bands_section(ship, raw, chosen))
	lines.append_array(_rule_section(chosen))
	lines.append_array(_rungs_section(chosen))
	lines.append_array(_gone_section(chosen, seen))
	lines.append_array(_pockets_section(chosen))
	lines.append_array(_failures_section(raw, chosen))
	lines.append_array(_cost_section(raw, chosen))
	return "\n".join(lines) + "\n"


func _bands_section(
	ship: String, raw: Array[Dictionary], chosen: Array[Dictionary]
) -> PackedStringArray:
	var raw_labels: Array = []
	for entry: Dictionary in raw:
		raw_labels.append(entry["labels"])
	var match_labels: Array = []
	for entry: Dictionary in chosen:
		match_labels.append(OutcomeClassifier.labels(entry["choice"].timeline))
	var lines := PackedStringArray()
	lines.append("## Each label's share against its band")
	lines.append("")
	lines.append(
		(
			"The raw census bakes each seed's first drawn hit as drawn, past the quick check;"
			+ " the match census bakes the hit the must-sink rule chose (§5b.1). §5b.4"
			+ " expects the match census's other shares to rise in proportion as it drops the"
			+ " survivors, but where she survived a seed's first hit the rule bakes another,"
			+ " so a share can fall as well as rise."
		)
	)
	lines.append("")
	lines.append("| Label | Raw census | Match census | Band (raw, est.) | Raw against it |")
	lines.append("|---|---|---|---|---|")
	var bands: Dictionary = BANDS.get(ship, {})
	var rows := [
		["survives", [L.AFLOAT, L.AFLOAT_UPSIDE_DOWN], false],
		["— afloat upside down, on her leaking air", [L.AFLOAT_UPSIDE_DOWN], false],
		["founders upright, by the head or the stern", [L.BY_THE_HEAD, L.BY_THE_STERN], true],
		["— gone by the head, capsized or not", [L.BY_THE_HEAD], false],
		["— gone by the stern, capsized or not", [L.BY_THE_STERN], false],
		["founders onto her side", [L.ONTO_HER_SIDE], false],
		["heavy list (≥ 15° for ≥ 5 min afloat)", [L.HEAVY_LIST], false],
		["capsizes (rolled past 90°)", [L.CAPSIZED], false],
		["comes to rest aground, part of her dry (a coast's, SH32)", [L.AGROUND], false],
		["gone within 20 min of physics", [L.FAST], false],
		["lights out — her generator stopped for good before she went", [L.LIGHTS_OUT], false],
		["funnel fell before she went", [L.FUNNEL_FELL], false],
		["breaks (in two or three, SH33)", [L.BROKE_IN_TWO, L.BROKE_IN_THREE], false],
	]
	for row: Array in rows:
		var raw_count := _counted(raw_labels, row[1], row[2])
		var match_count := _counted(match_labels, row[1], row[2])
		var band: Array = bands.get(row[0], [])
		var share := 100.0 * raw_count / raw_labels.size()
		var against := ""
		var shown := "—"
		if not band.is_empty():
			shown = "%d–%d%%" % [band[0], band[1]]
			against = "under" if share < band[0] else ("over" if share > band[1] else "in")
		(
			lines
			. append(
				(
					"| %s | %s | %s | %s | %s |"
					% [
						row[0],
						_share(raw_count, raw_labels.size()),
						_share(match_count, match_labels.size()),
						shown,
						against,
					]
				)
			)
		)
	lines.append("")
	lines.append(
		(
			"Capsizes counts a roll past 90° only while her trim is under 45°: stood further on"
			+ " end she has no list to speak of (the lurch rule's reading, §5b.4), so a roll"
			+ " then is no capsize. The founders rows read how she stands as she goes, so a"
			+ " hull that capsized is counted by the end she goes with unless she goes on her"
			+ " side; founders upright leaves the capsized out, its two sub-rows keep them."
		)
	)
	lines.append("")
	return lines


## What gave way in the match census's sinkings before she went (SinkFailures, SH31) —
## in how many a watertight door, a wall's panel, a hatch, a hinged door, a window, a
## porthole (her funnels and generator are bands) — and her bending's worst against her
## strength, raw and match: the median, the 95th percentile and the most of each seed's
## peak, which §5b.4 holds under 1 on the small ships (HullStressed at stressed_share).
func _failures_section(raw: Array[Dictionary], chosen: Array[Dictionary]) -> PackedStringArray:
	var kinds := {
		"a watertight door": [ShipOpening.Kind.WATERTIGHT_DOOR],
		"a wall's panel": [ShipOpening.Kind.PANEL],
		"a hatch": [ShipOpening.Kind.HATCH],
		"a door, hinged": [ShipOpening.Kind.DOOR],
		"a window": [ShipOpening.Kind.WINDOW],
		"a porthole": [ShipOpening.Kind.PORTHOLE],
	}
	var kind_of := {}
	for opening: ShipOpening in _structure.openings:
		kind_of[opening.name] = opening.kind
	for panel: ShipOpening in SinkFailures.panels(_structure):
		kind_of[panel.name] = panel.kind
	var counts := {}
	var bendings := PackedFloat64Array()
	var stressed := 0
	for entry: Dictionary in chosen:
		var timeline: SinkTimeline = entry["choice"].timeline
		var gone := timeline.gone_at if timeline.is_gone() else INF
		var seen := {}
		for event: SinkTimeline.Event in timeline.events:
			if event.seconds > gone:
				continue
			if event.kind == SinkTimeline.Kind.GAVE_WAY:
				for row: String in kinds:
					if kind_of.get(event.name, -1) in kinds[row]:
						seen[row] = true
			elif event.kind == SinkTimeline.Kind.HULL_STRESSED:
				seen["stressed"] = true
		for row: String in seen:
			counts[row] = counts.get(row, 0) + 1
		stressed += 1 if seen.has("stressed") else 0
		bendings.append(absf(timeline.bending))
	var lines := PackedStringArray()
	lines.append("## What gave way, and her bending (match census; SH31)")
	lines.append("")
	lines.append("| Gave way before she went | Sinkings | Share |")
	lines.append("|---|---|---|")
	for row: String in kinds:
		var count: int = counts.get(row, 0)
		lines.append("| %s | %d | %s |" % [row, count, _share(count, chosen.size())])
	lines.append("")
	var raw_bendings := PackedFloat64Array()
	for entry: Dictionary in raw:
		raw_bendings.append(absf(entry["bending"]))
	lines.append("| Peak bending against her strength | p50 | p95 | most | under 1 in every seed |")
	lines.append("|---|---|---|---|---|")
	for row: Array in [["raw census", raw_bendings], ["match census", bendings]]:
		var values: PackedFloat64Array = row[1]
		var most := 0.0
		for value: float in values:
			most = maxf(most, value)
		lines.append(
			(
				"| %s | %.3f | %.3f | %.3f | %s |"
				% [row[0], _at(values, 0.5), _at(values, 0.95), most, "yes" if most < 1.0 else "NO"]
			)
		)
	lines.append("")
	lines.append(
		(
			(
				"The hull creaked — her bending past %.0f%% of her strength — in %d of %d sinkings;"
				+ " she breaks only at a weak spot of hers, past its share of it (SH33)."
			)
			% [SeaPhysics.load_default().stressed_share * 100.0, stressed, chosen.size()]
		)
	)
	lines.append("")
	return lines


## How many of [param all] carry any of [param wanted] — and, when [param upright],
## never capsized.
static func _counted(all: Array, wanted: Array, upright: bool) -> int:
	var count := 0
	for labels: Array in all:
		if upright and L.CAPSIZED in labels:
			continue
		for label: int in wanted:
			if label in labels:
				count += 1
				break
	return count


static func _share(count: int, of: int) -> String:
	return "%.1f%% (%d)" % [100.0 * count / of, count]


func _rule_section(chosen: Array[Dictionary]) -> PackedStringArray:
	var again := 0
	var thrown := 0
	var bakes := PackedFloat64Array()
	var fallback := 0
	var sure := 0
	var afloat := 0
	for entry: Dictionary in chosen:
		var choice: MustSink.Choice = entry["choice"]
		if not MustSink.played(choice.timeline.end):
			afloat += 1
		again += choice.draws - 1
		thrown += choice.thrown
		bakes.append(choice.bakes)
		if choice.rung > 0 or choice.sure:
			fallback += 1
		if choice.sure:
			sure += 1
	var count := chosen.size()
	var lines := PackedStringArray()
	lines.append("## The must-sink rule, per match")
	lines.append("")
	lines.append("| Measure | Measured | Band (est.) |")
	lines.append("|---|---|---|")
	lines.append(
		"| hits drawn again | %.2f a match (%d in all) | 0.2–1.5 |" % [float(again) / count, again]
	)
	lines.append(
		(
			"| of them thrown out by the quick check | %.2f a match (%d) | — |"
			% [float(thrown) / count, thrown]
		)
	)
	lines.append(
		(
			"| bakes | %.2f a match · p95 %d · max %d | 1.0–1.7 on average, 5 at most (§5b.1) |"
			% [_mean(bakes), int(_at(bakes, 0.95)), int(_at(bakes, 1.0))]
		)
	)
	lines.append(
		"| fallback used (a rung or the sure hit) | %s | under 1%% |" % _share(fallback, count)
	)
	lines.append("| — the sure hit | %s | — |" % _share(sure, count))
	lines.append("| afloat at the bake's end | %s | 0%% by construction |" % _share(afloat, count))
	lines.append("")
	return lines


## The fallback's rungs (§5b.1): how many matches each rung was baked on, and the holes
## those rungs made — the decision on capping their width is the plan's.
func _rungs_section(chosen: Array[Dictionary]) -> PackedStringArray:
	var by_rung := {}
	var sure_areas := PackedFloat64Array()
	for entry: Dictionary in chosen:
		var choice: MustSink.Choice = entry["choice"]
		if choice.sure:
			sure_areas.append(choice.damage.area())
		elif choice.rung > 0:
			if not by_rung.has(choice.rung):
				by_rung[choice.rung] = []
			by_rung[choice.rung].append([choice.damage.area(), choice.hit.width, entry["seed"]])
	var lines := PackedStringArray()
	lines.append("## The fallback's rungs, and the holes they make")
	lines.append("")
	lines.append(
		(
			"Each rung doubles the hit's equivalent width and runs the gash on into the next cell"
			+ " (§5b.1). Where a match took a rung, the hole it was struck with:"
		)
	)
	lines.append("")
	lines.append("| Rung | Matches | Hole area (m²): least · median · most | Width (m) | Seeds |")
	lines.append("|---|---|---|---|---|")
	var rungs := by_rung.keys()
	rungs.sort()
	for rung: int in rungs:
		var areas := PackedFloat64Array()
		var widths := PackedFloat64Array()
		var named := PackedStringArray()
		for item: Array in by_rung[rung]:
			areas.append(item[0])
			widths.append(item[1])
			named.append(str(item[2]))
		(
			lines
			. append(
				(
					"| %d | %d | %.3f · %.3f · %.3f | %.3f · %.3f · %.3f | %s |"
					% [
						rung,
						areas.size(),
						_at(areas, 0.0),
						_at(areas, 0.5),
						_at(areas, 1.0),
						_at(widths, 0.0),
						_at(widths, 0.5),
						_at(widths, 1.0),
						", ".join(named),
					]
				)
			)
		)
	if rungs.is_empty():
		lines.append("| — | 0 | — | — | — |")
	var sure_line := "| sure hit | %d | " % sure_areas.size()
	if sure_areas.is_empty():
		sure_line += "— | — | — |"
	else:
		sure_line += (
			"%.3f · %.3f · %.3f | her data's | — |"
			% [_at(sure_areas, 0.0), _at(sure_areas, 0.5), _at(sure_areas, 1.0)]
		)
	lines.append(sure_line)
	lines.append("")
	var drawn := PackedFloat64Array()
	for entry: Dictionary in chosen:
		var choice: MustSink.Choice = entry["choice"]
		if choice.rung == 0 and not choice.sure:
			drawn.append(choice.damage.area())
	if not drawn.is_empty():
		(
			lines
			. append(
				(
					(
						"Beside them, the holes of the %d matches whose drawn hit sank her: least %.3f ·"
						+ " median %.3f · p95 %.3f · most %.3f m²."
					)
					% [
						drawn.size(),
						_at(drawn, 0.0),
						_at(drawn, 0.5),
						_at(drawn, 0.95),
						_at(drawn, 1.0)
					]
				)
			)
		)
		lines.append("")
	return lines


func _gone_section(chosen: Array[Dictionary], seen: PackedFloat64Array) -> PackedStringArray:
	var gone := PackedFloat64Array()
	for entry: Dictionary in chosen:
		gone.append(entry["choice"].timeline.gone_at)
	var within := 0
	for seconds: float in gone:
		if seconds <= OutcomeClassifier.FAST_SECONDS:
			within += 1
	var lines := PackedStringArray()
	lines.append("## From the hit to her going (match census, physics time)")
	lines.append("")
	(
		lines
		. append(
			(
				"p10 %s · p50 %s · p90 %s · most %s · %s within 20 min."
				% [
					MatchTranscript.physics_clock(_at(gone, 0.1)),
					MatchTranscript.physics_clock(_at(gone, 0.5)),
					MatchTranscript.physics_clock(_at(gone, 0.9)),
					MatchTranscript.physics_clock(_at(gone, 1.0)),
					_share(within, gone.size()),
				]
			)
		)
	)
	lines.append("")
	lines.append("## How much of her sinking a match sees (R33; Q20, the clock at 1.0)")
	lines.append("")
	if seen.is_empty():
		lines.append("No match was played (MATCHES=0).")
	else:
		(
			lines
			. append(
				(
					(
						"Over %d bots-only matches (seeds 1…%d, each to its end or %s), the share of"
						+ " the sinking from the hit to her going that the match saw: least %.1f%% ·"
						+ " median %.1f%% · most %.1f%%; %d saw her go."
					)
					% [
						seen.size(),
						seen.size(),
						MatchTranscript.physics_clock(MATCH_STOP),
						_at(seen, 0.0) * 100.0,
						_at(seen, 0.5) * 100.0,
						_at(seen, 1.0) * 100.0,
						_count_at_least(seen, 1.0),
					]
				)
			)
		)
	lines.append("")
	return lines


## The air pockets the accepted bakes trapped (SinkAir), cell by cell: in how many
## sinkings one formed there, how long each lasted — from its air trapped to the pocket
## gone, cut where she went — and how it ended: let out as its cell's air went free, leaked
## away or squeezed out, or still held as she went.
func _pockets_section(chosen: Array[Dictionary]) -> PackedStringArray:
	var lasted: Array[PackedFloat64Array] = []
	var sinkings := PackedInt32Array()
	var ends := PackedInt32Array()
	for cell in _structure.cells.size():
		lasted.append(PackedFloat64Array())
	sinkings.resize(_structure.cells.size())
	ends.resize(_structure.cells.size() * 3)
	for entry: Dictionary in chosen:
		var timeline: SinkTimeline = entry["choice"].timeline
		var end := timeline.gone_at if timeline.is_gone() else timeline.length()
		var vented := {}
		for event: SinkTimeline.Event in timeline.events:
			if event.kind == SinkTimeline.Kind.VENTED:
				vented["%s@%d" % [event.name, roundi(event.seconds * SinkTimeline.PER_SECOND)]] = true
		for cell in timeline.cells:
			var named := _structure.cells[cell].name
			var from := -1.0
			var formed := false
			for frame in range(1, timeline.count()):
				var at := timeline.times[frame]
				var held := timeline.pockets[frame * timeline.cells + cell] > 0.0
				var was := timeline.pockets[(frame - 1) * timeline.cells + cell] > 0.0
				if held and not was and at < end:
					from = at
					formed = true
				elif was and not held and from >= 0.0:
					lasted[cell].append(minf(at, end) - from)
					var key := "%s@%d" % [named, roundi(at * SinkTimeline.PER_SECOND)]
					ends[cell * 3 + (0 if vented.has(key) else 1)] += 1
					from = -1.0
			if from >= 0.0:
				lasted[cell].append(end - from)
				ends[cell * 3 + 2] += 1
			if formed:
				sinkings[cell] += 1
	var lines := PackedStringArray()
	lines.append("## How long the air pockets last (match census, physics time; SH29)")
	lines.append("")
	lines.append(
		(
			"A pocket is a cell's air trapped under its ceiling after the hit (SinkAir): from"
			+ " then until it is gone, cut where she went. Its leak is the cell's leak area"
			+ " (10⁻³ m² per 1 000 m³, est.); a pocket also goes as its cell's air is let out"
			+ " — blown out — or as the water squeezes it to nothing."
		)
	)
	lines.append("")
	lines.append(
		(
			"| Cell | Sinkings with one | Pockets | Lasted: p50 · p90 · most"
			+ " | Blown out · leaked or squeezed out · held as she went |"
		)
	)
	lines.append("|---|---|---|---|---|")
	for cell in _structure.cells.size():
		if lasted[cell].is_empty():
			continue
		var times := lasted[cell]
		times.sort()
		(
			lines
			. append(
				(
					"| %s | %s | %d | %s · %s · %s | %d · %d · %d |"
					% [
						_structure.cells[cell].name,
						_share(sinkings[cell], chosen.size()),
						times.size(),
						MatchTranscript.physics_clock(_at(times, 0.5)),
						MatchTranscript.physics_clock(_at(times, 0.9)),
						MatchTranscript.physics_clock(_at(times, 1.0)),
						ends[cell * 3],
						ends[cell * 3 + 1],
						ends[cell * 3 + 2],
					]
				)
			)
		)
	lines.append("")
	return lines


func _cost_section(raw: Array[Dictionary], chosen: Array[Dictionary]) -> PackedStringArray:
	var one := PackedFloat64Array()
	var steps := PackedFloat64Array()
	for entry: Dictionary in raw:
		one.append(entry["seconds"])
		steps.append(entry["steps"])
	var per_match := PackedFloat64Array()
	var sizes := PackedFloat64Array()
	var longest: MustSink.Choice = null
	for entry: Dictionary in chosen:
		per_match.append(entry["seconds"])
		var choice: MustSink.Choice = entry["choice"]
		sizes.append(choice.timeline.size())
		if longest == null or choice.timeline.length() > longest.timeline.length():
			longest = choice
	var sea := SeaPhysics.load_default()
	var every := SinkBake.of(_structure, longest.damage, sea, _scenario.bake_cap)
	var budgets: Array = BUDGETS.get(String(_ship), [BAKE_BUDGET, MATCH_BAKES_BUDGET, SIZE_BUDGET])
	var lines := PackedStringArray()
	lines.append("## What it costs (this machine, %s)" % OS.get_processor_name())
	lines.append("")
	lines.append(
		(
			(
				"Load average when measured: %s. The cost lines depend on the machine's load;"
				+ " the plan's R20 budgets are judged on a quiet machine."
			)
			% _load_average()
		)
	)
	lines.append("")
	lines.append("| Budget (§5b.4, est.) | Measured | Against it |")
	lines.append("|---|---|---|")
	(
		lines
		. append(
			(
				"| one bake: p95 under %.1f s | p50 %.2f · p95 %.2f · most %.2f s | %s |"
				% [
					budgets[0],
					_at(one, 0.5),
					_at(one, 0.95),
					_at(one, 1.0),
					"in" if _at(one, 0.95) <= budgets[0] else "over",
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"| a match's bakes: p95 under %.1f s | p50 %.2f · p95 %.2f · most %.2f s | %s |"
				% [
					budgets[1],
					_at(per_match, 0.5),
					_at(per_match, 0.95),
					_at(per_match, 1.0),
					"in" if _at(per_match, 0.95) <= budgets[1] else "over",
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"| the longest timeline under %d kB | p50 %.1f · p95 %.1f · most %.1f kB | %s |"
				% [
					budgets[2] / 1000,
					_at(sizes, 0.5) / 1e3,
					_at(sizes, 0.95) / 1e3,
					_at(sizes, 1.0) / 1e3,
					"in" if _at(sizes, 1.0) <= budgets[2] else "over",
				]
			)
		)
	)
	lines.append("")
	(
		lines
		. append(
			(
				(
					"Steps a bake: p50 %d · p95 %d · most %d. The longest sinking (gone at %s) keeps %d of"
					+ " %d states, %.1f kB; with every state kept, %.1f kB."
				)
				% [
					int(_at(steps, 0.5)),
					int(_at(steps, 0.95)),
					int(_at(steps, 1.0)),
					MatchTranscript.physics_clock(longest.timeline.gone_at),
					longest.timeline.count(),
					longest.timeline.states,
					longest.timeline.size() / 1e3,
					every.uncompacted().size() / 1e3,
				]
			)
		)
	)
	return lines


## The OS's 1, 5 and 15 minute load averages at the end of the run, "unknown" where it
## keeps none we can read.
static func _load_average() -> String:
	var text := ""
	if FileAccess.file_exists("/proc/loadavg"):
		text = FileAccess.get_file_as_string("/proc/loadavg")
	else:
		var output: Array = []
		if OS.execute("sysctl", ["-n", "vm.loadavg"], output) == 0 and not output.is_empty():
			text = str(output[0]).replace("{", "").replace("}", "")
	var fields := text.strip_edges().split(" ", false)
	if fields.size() < 3:
		return "unknown"
	return "%s · %s · %s (1 · 5 · 15 min)" % [fields[0], fields[1], fields[2]]


static func _mean(values: PackedFloat64Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / values.size()


## The value [param share] of the way up [param values] sorted: 0 the least, 1 the most.
static func _at(values: PackedFloat64Array, share: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(share * sorted.size()), sorted.size() - 1)]


static func _count_at_least(values: PackedFloat64Array, least: float) -> int:
	var count := 0
	for value: float in values:
		if value >= least:
			count += 1
	return count
