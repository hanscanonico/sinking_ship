extends GutTest
## §5b.4 layer 1: SinkStepper against closed forms — two tanks levelling through an
## orifice, a tank filling from the sea, a spill over a sill, a box barge with its
## middle flooded — and the bake's two promises: water is never made or lost, and the
## same hit bakes the same timeline twice.

const SEA_DENSITY := 1025.0
## A barge so broad the water in her tanks barely moves the sea up her.
const BROAD := 1000.0


func _sea() -> SeaPhysics:
	return SeaPhysics.load_default()


## A cell called [param cell_name], a box from [param low] to [param high], all of it
## water's to fill.
func _cell(cell_name: StringName, low: Vector3, high: Vector3) -> FloodCell:
	var cell := FloodCell.new()
	cell.name = cell_name
	cell.low = low
	cell.high = high
	cell.permeability = 1.0
	return cell


## An opening called [param opening_name] of [param kind] joining [param joins],
## a rectangle at [param centre] of [param size].
func _opening(
	opening_name: StringName, joins: Array[StringName], centre: Vector3, size: Vector3
) -> ShipOpening:
	var opening := ShipOpening.new()
	opening.name = opening_name
	opening.kind = ShipOpening.Kind.DOOR if size.y > 0.0 else ShipOpening.Kind.STAIRWELL
	opening.joins = joins
	opening.centre = centre
	opening.size = size
	return opening


## A box barge [param length] long and [param beam] wide from [param keel] to
## [param deck], in [param count] sections, weighing what floats her [param draught]
## deep, with [param cells] and [param openings].
func _barge(
	length: float,
	beam: float,
	keel: float,
	deck: float,
	draught: float,
	cells: Array[FloodCell],
	openings: Array[ShipOpening],
	count: int = 8
) -> ShipStructure:
	var structure := ShipStructure.new()
	for index in count:
		var section := HullSection.new()
		section.x = -length * 0.5 + length * (index + 0.5) / count
		section.length = length / count
		section.outline = PackedVector2Array(
			[
				Vector2(-beam * 0.5, keel),
				Vector2(beam * 0.5, keel),
				Vector2(beam * 0.5, deck),
				Vector2(-beam * 0.5, deck)
			]
		)
		structure.sections.append(section)
	var item := MassItem.new()
	item.name = &"barge"
	item.mass = length * beam * draught * SEA_DENSITY
	item.centre = Vector3(0.0, keel, 0.0)
	item.along = Vector2(-length * 0.5, length * 0.5)
	structure.mass.append(item)
	structure.cells = cells
	structure.openings = openings
	structure.waterline_y = keel + draught
	structure.keel_y = keel
	return structure


## Two tanks in a broad barge, 100 and 50 m², joined low down by 0.5 m² — an orifice
## under both their surfaces — the first's water 4 m over the second's.
func _two_tanks() -> SinkStepper:
	var tanks: Array[FloodCell] = [
		_cell(&"big", Vector3(0.0, 0.0, 0.0), Vector3(10.0, 10.0, 10.0)),
		_cell(&"small", Vector3(10.0, 0.0, 0.0), Vector3(15.0, 10.0, 10.0)),
	]
	var orifice := _opening(
		&"orifice", [&"big", &"small"], Vector3(10.0, 0.5, 5.0), Vector3(0.0, 1.0, 0.5)
	)
	var structure := _barge(BROAD, BROAD, -20.0, 20.0, 10.0, tanks, [orifice])
	return SinkStepper.new(structure, HitDamage.new(), _sea())


func _filled(stepper: SinkStepper, heads: Array[float]) -> FloodState:
	var state := stepper.start()
	for cell in heads.size():
		state.water[cell] = stepper.volume_at(cell, heads[cell])
		state.heads[cell] = heads[cell]
	return state


## [param state] stepped by [param stepper] in [param seconds] until the two tanks
## stand level, failing on any slosh on the way.
func _levelled(stepper: SinkStepper, state: FloodState, seconds: float) -> FloodState:
	var difference := 4.0
	while state.seconds < 1000.0:
		state = stepper.step(state, seconds)
		var now := stepper.head(0, state.water[0]) - stepper.head(1, state.water[1])
		assert_true(now >= -1e-9 and now <= difference + 1e-9, "no slosh at %s s" % state.seconds)
		difference = now
		if now <= 1e-9:
			break
	return state


func test_two_tanks_level_in_100_s() -> void:
	var stepper := _two_tanks()
	# 2 √4 / (0.6 × 0.5 × √(2g) × (1/100 + 1/50)).
	var expected := 4.0 / (0.6 * 0.5 * sqrt(2.0 * 9.81) * 0.03)
	assert_almost_eq(expected, 100.3, 0.05)
	var at_a_tenth := _levelled(stepper, _filled(stepper, [6.0, 2.0]), 0.1).seconds
	assert_almost_eq(at_a_tenth, expected, expected * 0.01, "levels in 100.3 s ± 1%")
	var at_a_second := _levelled(stepper, _filled(stepper, [6.0, 2.0]), 1.0).seconds
	assert_almost_eq(at_a_second, expected, expected * 0.01, "at the bake's 1 s step too")
	var state := _levelled(stepper, _filled(stepper, [6.0, 2.0]), 30.0)
	for _step in 10:
		state = stepper.step(state, 30.0)
		var heads := [stepper.head(0, state.water[0]), stepper.head(1, state.water[1])]
		assert_almost_eq(heads[0], heads[1], 1e-9, "level and still at a 30 s step")
	assert_almost_eq(stepper.head(0, state.water[0]), 700.0 / 150.0, 1e-9, "at the shared level")


func test_a_doorway_half_under_levels_without_a_slosh_at_a_30_s_step() -> void:
	# The lower side's water stands inside the doorway, so its flow has no closed form
	# over the step (an orifice under it, a weir over it): only the levelling cap keeps
	# a 30 s step from throwing the water past the level and back (R22).
	var tanks: Array[FloodCell] = [
		_cell(&"big", Vector3(0.0, 0.0, 0.0), Vector3(10.0, 10.0, 10.0)),
		_cell(&"small", Vector3(10.0, 0.0, 0.0), Vector3(15.0, 10.0, 10.0)),
	]
	var doorway := _opening(
		&"doorway", [&"big", &"small"], Vector3(10.0, 1.05, 5.0), Vector3(0.0, 2.1, 1.1)
	)
	var structure := _barge(BROAD, BROAD, -20.0, 20.0, 10.0, tanks, [doorway])
	var stepper := SinkStepper.new(structure, HitDamage.new(), _sea())
	var state := _filled(stepper, [6.0, 0.5])
	for _step in 10:
		state = stepper.step(state, 30.0)
		var difference := stepper.head(0, state.water[0]) - stepper.head(1, state.water[1])
		assert_gte(difference, -1e-9, "never past the level, at %s s" % state.seconds)
	var level := (6.0 * 100.0 + 0.5 * 50.0) / 150.0
	assert_almost_eq(stepper.head(0, state.water[0]), level, 1e-9, "level and still")
	assert_almost_eq(stepper.head(1, state.water[1]), level, 1e-9, "on both sides")


func test_tank_fills_from_the_sea_in_the_closed_form_time() -> void:
	var tank: Array[FloodCell] = [_cell(&"tank", Vector3(0.0, 0.0, 0.0), Vector3(10.0, 10.0, 10.0))]
	var hole := _opening(
		&"hole", [&"tank", ShipOpening.SEA], Vector3(0.0, 0.5, 5.0), Vector3(0.0, 1.0, 0.25)
	)
	var structure := _barge(BROAD, BROAD, -2.0, 20.0, 8.0, tank, [hole])
	var stepper := SinkStepper.new(structure, HitDamage.new(), _sea())
	var state := _filled(stepper, [1.0])
	var sea := state.sea
	assert_almost_eq(sea, 6.0, 1e-6, "the sea 5 m over the tank's water")
	# 2 A √Δ / (0.6 a √(2g)), the sea held.
	var expected := 2.0 * 100.0 * sqrt(sea - 1.0) / (0.6 * 0.25 * sqrt(2.0 * 9.81))
	while state.seconds < 2.0 * expected and stepper.head(0, state.water[0]) < state.sea - 1e-9:
		state = stepper.step(state, 1.0)
	assert_almost_eq(state.seconds, expected, expected * 0.01, "filled in the closed-form time")
	assert_almost_eq(stepper.head(0, state.water[0]), state.sea, 1e-6, "to the sea's level")


func test_spill_over_a_sill_matches_the_weir_law() -> void:
	var cells: Array[FloodCell] = [
		_cell(&"upstream", Vector3(0.0, 0.0, 0.0), Vector3(400.0, 5.0, 400.0)),
		_cell(&"downstream", Vector3(400.0, 0.0, 0.0), Vector3(410.0, 5.0, 400.0)),
	]
	# A wall 2 m high with a 3 m sill-wide gap over it, up to the deck.
	var gap := _opening(
		&"over_the_wall",
		[&"upstream", &"downstream"],
		Vector3(400.0, 3.5, 200.0),
		Vector3(0.0, 3.0, 3.0)
	)
	gap.kind = ShipOpening.Kind.OVER_WALL
	var structure := _barge(BROAD, BROAD, -20.0, 20.0, 10.0, cells, [gap])
	var stepper := SinkStepper.new(structure, HitDamage.new(), _sea())
	for depth: float in [0.1, 0.4, 1.2]:
		var state := _filled(stepper, [2.0 + depth, 0.0])
		var seconds := 0.01
		var next := stepper.step(state, seconds)
		var weir := 2.0 / 3.0 * 0.6 * 3.0 * sqrt(2.0 * 9.81) * pow(depth, 1.5)
		assert_almost_eq(next.moved[0] / seconds, weir, weir * 1e-3, "%s m over the sill" % depth)


func test_water_is_never_made_or_lost() -> void:
	var structure: ShipStructure = SimFixtures.steamer().structure
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	for seed_value: int in [1701, 5]:
		var stream := SeedStreams.derive(seed_value, "sink")
		var damage := HitMapper.map(
			IcebergHit.draw(scenario.hit, stream), structure, scenario.hit, stream
		)
		var stepper := SinkStepper.new(structure, damage, _sea())
		var state := stepper.start()
		var worst := 0.0
		for _step in 3600:
			state = stepper.step(state, 1.0)
			worst = maxf(worst, absf(state.total() - state.sea_given) / maxf(state.total(), 1.0))
		assert_lt(worst, 1e-9, "seed %d: her water is what the sea gave, to 10⁻⁹" % seed_value)
		assert_gt(state.total(), 0.0, "seed %d took water" % seed_value)


func test_bake_is_pure_in_its_inputs() -> void:
	var structure: ShipStructure = SimFixtures.steamer().structure
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var digests := PackedStringArray()
	for _bake in 2:
		var stream := SeedStreams.derive(1701, "sink")
		var damage := HitMapper.map(
			IcebergHit.draw(scenario.hit, stream), structure, scenario.hit, stream
		)
		var timeline := SinkTimeline.bake(
			SinkStepper.new(structure, damage, _sea()), _sea(), 3600.0
		)
		digests.append(timeline.digest())
	assert_eq(digests[0], digests[1], "the same state hash twice")


func test_box_barge_with_its_middle_flooded_settles_to_6_25_m() -> void:
	# 40 m long, 8 m wide, 10 m deep, floating 5 m deep; the middle 8 m holed at the
	# keel: lost buoyancy puts her 5 × 40 / 32 = 6.25 m deep.
	var middle: Array[FloodCell] = [
		_cell(&"middle", Vector3(-4.0, -10.0, -4.0), Vector3(4.0, 0.0, 4.0))
	]
	var hole := _opening(
		&"hole", [&"middle", ShipOpening.SEA], Vector3(0.0, -10.0, 0.0), Vector3(1.0, 0.0, 1.0)
	)
	var structure := _barge(40.0, 8.0, -10.0, 0.0, 5.0, middle, [hole], 10)
	var stepper := SinkStepper.new(structure, HitDamage.new(), _sea())
	var timeline := SinkTimeline.bake(stepper, _sea(), 3600.0)
	assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "she floats once the water stops")
	var sea := timeline.seas[timeline.count() - 1]
	assert_almost_eq(sea - -10.0, 6.25, 1e-6, "6.25 m deep")
	assert_almost_eq(timeline.heads[timeline.count() - 1], sea, 1e-6, "flooded to the sea")
