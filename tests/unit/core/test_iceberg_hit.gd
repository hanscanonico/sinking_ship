extends GutTest
## The match's iceberg hit (§5b.1, D4): drawn first off the sinking stream from its
## scenario's bands, a pure function of (ship, scenario, seed); its gash one opening to
## the sea per cell of the steamer it crosses within its bite, where it crosses; and the
## doors that jam and the portholes left open drawn at their rates.

const SEED := 1701
const SPREAD_SEEDS := 200
const RATE_SEEDS := 1000
## How many standard deviations a count of a binomial's successes may stray from its
## mean, at most.
const DEVIATIONS := 4.0
## Metres the gash's openings may stand off what they are checked against: the floats
## of a Vector3.
const EPSILON := 0.001

var _layout: ShipLayout
var _sinking: SinkScenario


func before_all() -> void:
	_layout = SimFixtures.steamer()
	_sinking = load(SimFixtures.STEAMER_SINKING)


func _steamer() -> ShipLayout:
	return _layout


func _scenario() -> SinkScenario:
	return _sinking


## The steamer's schedule on [param seed_value], struck as her match strikes it.
func _schedule(seed_value: int) -> SinkSchedule:
	var layout := _steamer()
	return SinkSchedule.new(
		_scenario(), layout.freeboard, SeedStreams.derive(seed_value, "sink"), layout.structure
	)


## A hit given by hand on the steamer's [param side] side from [param from] to
## [param to] along her, [param depth] under her waterline at both ends — or
## [param depth_end] at its forward end — 50 mm wide, biting [param bite] inboard.
func _hit(
	side: int, from: float, to: float, depth: float, bite: float, depth_end: float = NAN
) -> IcebergHit:
	var hit := IcebergHit.new()
	hit.side = side
	hit.start_x = from
	hit.length = to - from
	hit.depth_start = depth
	hit.depth_end = depth if is_nan(depth_end) else depth_end
	hit.width = 0.05
	hit.bite = bite
	return hit


func _mapped(hit: IcebergHit) -> HitDamage:
	return HitMapper.map(hit, _steamer().structure, _scenario().hit, SeedStreams.derive(1, "sink"))


## The cells [param damage]'s gash opens, in her cells' order.
func _opened(damage: HitDamage) -> Array[StringName]:
	var cells: Array[StringName] = []
	for opening: ShipOpening in damage.openings:
		cells.append(opening.joins[0])
	return cells


## Everything the hit and its damage hold, as one line.
func _told(schedule: SinkSchedule) -> String:
	var hit := schedule.hit()
	var damage := schedule.damage()
	var told := PackedStringArray()
	for value: Variant in [
		schedule.hit_tick(),
		hit.moment,
		hit.side,
		hit.start_x,
		hit.length,
		hit.depth_start,
		hit.depth_end,
		hit.width,
		hit.bite,
		damage.from_x,
		damage.to_x,
		damage.trace,
		damage.weakened,
		damage.jammed,
		damage.left_open,
	]:
		told.append(str(value))
	for opening: ShipOpening in damage.openings:
		told.append("%s %s %s %s" % [opening.name, opening.centre, opening.size, opening.area])
	return " ".join(told)


func test_hit_is_pure_in_ship_scenario_and_seed() -> void:
	var seen := {}
	for seed_value: int in [1, 2, 3, SEED]:
		var first := _told(_schedule(seed_value))
		assert_eq(_told(_schedule(seed_value)), first, "seed %d again" % seed_value)
		var config := SimFixtures.config(8, _scenario(), seed_value, _steamer())
		var sim := MatchSim.create(config)
		assert_eq(_told(sim.schedule), first, "seed %d in its match" % seed_value)
		# Restoring takes the hit as it was; continuing from a snapshot strikes it alike.
		var hit := sim.schedule.hit()
		sim.restore(sim.snapshot())
		assert_same(sim.schedule.hit(), hit, "seed %d: restoring draws nothing" % seed_value)
		var continued := MatchSim.from_snapshot(sim.snapshot(), config)
		assert_eq(_told(continued.schedule), first, "seed %d continued" % seed_value)
		seen[first] = seed_value
	assert_eq(seen.size(), 4, "every seed strikes her somewhere of its own")
	# Without a hit in the scenario, or a ship to strike, nothing is struck.
	var unstruck: SinkScenario = _scenario().duplicate()
	unstruck.hit = null
	var layout := _steamer()
	for schedule: SinkSchedule in [
		SinkSchedule.new(
			unstruck, layout.freeboard, SeedStreams.derive(SEED, "sink"), layout.structure
		),
		SinkSchedule.new(_scenario(), layout.freeboard, SeedStreams.derive(SEED, "sink")),
	]:
		assert_null(schedule.hit())
		assert_null(schedule.damage())
		assert_eq(schedule.hit_tick(), -1)


func test_hit_stays_inside_its_bands() -> void:
	var bands := _scenario().hit
	var structure := _steamer().structure
	var zone := Rect2(
		structure.hit_zone_x.x,
		structure.hit_zone_y.x,
		structure.hit_zone_x.y - structure.hit_zone_x.x,
		structure.hit_zone_y.y - structure.hit_zone_y.x
	)
	var starts_at := _scenario().starts_at
	# Every stray, one line each: 200 seeds would be thousands of asserts.
	var strays := PackedStringArray()
	for seed_value in range(1, SPREAD_SEEDS + 1):
		var schedule := _schedule(seed_value)
		var hit := schedule.hit()
		var damage := schedule.damage()
		var drawn := {
			"moment": [hit.moment, bands.moment],
			"start": [hit.start_x, bands.start_x],
			"length": [hit.length, bands.length],
			"depth at its start": [hit.depth_start, bands.depth],
			"depth at its end": [hit.depth_end, bands.depth],
			"width": [hit.width, bands.width],
			"bite": [hit.bite, bands.bite],
		}
		for what: String in drawn:
			var value: float = drawn[what][0]
			var band: Vector2 = drawn[what][1]
			if value < band.x * (1.0 - EPSILON) or value > band.y:
				strays.append("seed %d: %s %f outside %s" % [seed_value, what, value, band])
		if hit.side != 1 and hit.side != -1:
			strays.append("seed %d: side %d" % [seed_value, hit.side])
		if schedule.hit_tick() != Ticks.from_seconds(starts_at + hit.moment):
			strays.append("seed %d: struck at tick %d" % [seed_value, schedule.hit_tick()])
		for point: Vector3 in damage.trace:
			if not zone.grow(EPSILON).has_point(Vector2(point.x, point.y)):
				strays.append("seed %d: the gash runs out of her hit zone" % seed_value)
			if signf(point.z) != hit.side:
				strays.append("seed %d: the gash runs on her other side" % seed_value)
		for opening: ShipOpening in damage.openings:
			var most := hit.width * (opening.size.x + EPSILON) * bands.unevenness.y
			if not zone.has_point(Vector2(opening.centre.x, opening.centre.y)):
				strays.append("seed %d: %s out of her hit zone" % [seed_value, opening.name])
			if opening.area <= 0.0 or opening.area > most:
				strays.append("seed %d: %s more than its share" % [seed_value, opening.name])
			if opening.kind != ShipOpening.Kind.GASH or opening.joins[1] != ShipOpening.SEA:
				strays.append("seed %d: %s is no gash to the sea" % [seed_value, opening.name])
	assert_eq(strays, PackedStringArray())


func test_both_sides_and_both_ends_are_drawn() -> void:
	var sides := {1: 0, -1: 0}
	var opened := {}
	for seed_value in range(1, SPREAD_SEEDS + 1):
		var schedule := _schedule(seed_value)
		sides[schedule.hit().side] += 1
		for cell: StringName in _opened(schedule.damage()):
			opened[cell] = true
	# Even odds on 200 seeds: each side well within 70…130.
	assert_between(sides[1], 70, 130, "starboard")
	assert_between(sides[-1], 70, 130, "port")
	for end: StringName in [&"aft_peak", &"forepeak"]:
		assert_true(opened.has(end), "a gash reaches %s" % end)


func test_gash_opens_only_the_cells_it_crosses() -> void:
	var structure := _steamer().structure
	# Along the starboard side void of the hold, shallow enough in: the void alone.
	assert_eq(_opened(_mapped(_hit(1, 6.0, 10.0, 0.3, 0.3))), [&"hold_wing_s"] as Array[StringName])
	# The port side is the port side's.
	assert_eq(
		_opened(_mapped(_hit(-1, 6.0, 10.0, 0.3, 0.3))), [&"hold_wing_p"] as Array[StringName]
	)
	# Aft, under the cabins' floor: the bilge, never the cabins over it.
	assert_eq(_opened(_mapped(_hit(1, -10.0, -5.0, 1.0, 1.0))), [&"aft_bilge"] as Array[StringName])
	# Across the engine room's after bulkhead: the bilges either side of it.
	var across := _mapped(_hit(1, -6.0, -1.0, 1.0, 1.0))
	assert_eq(_opened(across), [&"aft_bilge", &"engine_bilge"] as Array[StringName])
	assert_eq(across.weakened, [] as Array[StringName], "both its ends stand clear of a wall")
	# Ending just short of the hold's after bulkhead weakens it, and nothing else.
	var short := _mapped(_hit(1, -1.0, 3.5, 1.0, 1.0))
	assert_eq(short.weakened, [&"bulkhead_hold"] as Array[StringName])
	for damage: HitDamage in [across, short]:
		var crossed := 0.0
		for opening: ShipOpening in damage.openings:
			var cell := structure.cells[structure.cell_named(opening.joins[0])]
			var what := "%s within its cell" % opening.name
			assert_between(
				opening.centre.x - opening.size.x * 0.5, cell.low.x - EPSILON, cell.high.x, what
			)
			assert_between(
				opening.centre.x + opening.size.x * 0.5, cell.low.x, cell.high.x + EPSILON, what
			)
			assert_between(opening.centre.y, cell.low.y, cell.high.y, what)
			crossed += opening.size.x
		assert_almost_eq(crossed, damage.to_x - damage.from_x, EPSILON, "the gash's length")


func test_shallow_bite_opens_the_side_void_not_the_hold() -> void:
	var shallow := _opened(_mapped(_hit(1, 6.0, 10.0, 0.3, 0.3)))
	assert_eq(shallow, [&"hold_wing_s"] as Array[StringName])
	var deep := _opened(_mapped(_hit(1, 6.0, 10.0, 0.3, 1.5)))
	assert_eq(deep, [&"hold_bilge", &"hold_wing_s"] as Array[StringName], "through the void")


func test_hit_above_the_waterline_opens_nothing_below_it() -> void:
	var waterline := _steamer().structure.waterline_y
	var above := _mapped(_hit(1, -12.0, 12.0, -0.5, 2.0, -0.3))
	assert_false(above.openings.is_empty(), "it opens what it crosses")
	for opening: ShipOpening in above.openings:
		var lowest := opening.centre.y - opening.size.y * 0.5
		assert_gt(lowest, waterline, "%s stands over the sea" % opening.name)


func test_jam_and_open_chances_match_their_rates() -> void:
	var structure := _steamer().structure
	var jammed := {}
	var left_open := {}
	for seed_value in range(1, RATE_SEEDS + 1):
		var damage := _schedule(seed_value).damage()
		for door: StringName in damage.jammed:
			jammed[door] = jammed.get(door, 0) + 1
		for opening: StringName in damage.left_open:
			left_open[opening] = left_open.get(opening, 0) + 1
	# Each door on its own; the portholes together, as one binomial's mean and variance.
	var doors := 0
	var ports := 0
	var ports_open := 0
	var mean := 0.0
	var variance := 0.0
	for opening: ShipOpening in structure.openings:
		var chance := opening.flip_chance
		if opening.shuts_at_hit:
			doors += 1
			var count: int = jammed.get(opening.name, 0)
			var spread := RATE_SEEDS * chance * (1.0 - chance)
			_assert_binomial(count, RATE_SEEDS * chance, spread, "%s jammed" % opening.name)
		elif opening.starts == ShipOpening.Start.SHUT and chance > 0.0:
			ports += 1
			ports_open += left_open.get(opening.name, 0)
			mean += RATE_SEEDS * chance
			variance += RATE_SEEDS * chance * (1.0 - chance)
		else:
			assert_false(left_open.has(opening.name), "%s has no chance to flip" % opening.name)
	assert_gt(doors, 0, "watertight doors are drawn")
	assert_gt(ports, 0, "portholes are drawn")
	_assert_binomial(ports_open, mean, variance, "portholes left open")


func _assert_binomial(count: int, mean: float, variance: float, what: String) -> void:
	var band := DEVIATIONS * sqrt(variance)
	assert_between(
		float(count), mean - band, mean + band, "%s: %d, expected %.1f" % [what, count, mean]
	)


func test_the_transcript_tells_the_hit_first() -> void:
	var schedule := _schedule(SEED)
	var told := MatchTranscript.new()
	told.add([SimEvent.seat_out(Ticks.RATE, 3, 8, PlayerState.Cause.COLD, -1)] as Array[SimEvent])
	told.hit(schedule)
	var lines := told.text().split("\n")
	var expected := (
		"hit %s · %s · x "
		% [MatchTranscript.clock(schedule.hit_tick()), schedule.hit().side_name()]
	)
	assert_string_starts_with(lines[0], expected, "the hit first, whenever it is told")
	assert_string_ends_with(lines[0], "%.3f m²" % schedule.damage().area())
	assert_string_starts_with(lines[1], "00:01.0 seat 3 out")
	var unstruck := MatchTranscript.new()
	unstruck.hit(SinkSchedule.new(_scenario(), _steamer().freeboard, SeedStreams.derive(1, "sink")))
	assert_eq(unstruck.text(), "\n", "a match without a hit tells none")
