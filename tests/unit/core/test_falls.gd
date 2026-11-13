extends GutTest
## Falling water and air going free hit bodies (#631, Falls): water pouring down a hole in
## a floor knocks a body under it off its feet, and dunks a swimmer under it and throws it
## outward; air going free out of a pocket blows the swimmers by its way out clear.

## The flat deck's lower room's ceiling, where the upper room's stairwell opens, in metres
## over the deck; and the stairwell's footprint, x then z.
const CEILING := 2.5
const WELL := Vector2(1.0, 2.0)
## The tick the hold's air goes free at.
const VENTS := 5


## A schedule of the test's own: her poses as a calm deck's, every one with
## [member structure]'s cells' water at [member levels] (world heights) and their air at
## [member pockets], [member flows] through the openings [member names]; and, with
## [member vents], the hold's air going free at VENTS.
class Falling:
	extends SinkSchedule
	var structure: ShipStructure
	var levels := PackedFloat64Array()
	var pockets := PackedFloat64Array()
	var names: Array[StringName] = []
	var flows := PackedFloat64Array()
	var vents := false
	var _falling_cells: CellMap
	var _vented: SinkTimeline

	func _posed(tick: int) -> ShipPose:
		var pose := super._posed(tick)
		if _falling_cells == null:
			_falling_cells = CellMap.new(structure)
		pose.cells = _falling_cells
		pose.levels = levels
		pose.pockets = pockets
		pose.passages = names
		pose.flows = flows
		return pose

	func timeline() -> SinkTimeline:
		if not vents:
			return null
		if _vented == null:
			_vented = SinkTimeline.new()
			_vented.events.append(SinkTimeline.Event.new(VENTS, SinkTimeline.Kind.VENTED, &"hold"))
		return _vented

	func physics_tick(seconds: float) -> int:
		return roundi(seconds)

	func passages() -> Array[ShipOpening]:
		return structure.openings


static func _cell(cell_name: StringName, low: Vector3, high: Vector3) -> FloodCell:
	var made := FloodCell.new()
	made.name = cell_name
	made.low = low
	made.high = high
	return made


static func _opening(
	opening_name: StringName,
	kind: ShipOpening.Kind,
	joins: Array[StringName],
	centre: Vector3,
	size: Vector3
) -> ShipOpening:
	var made := ShipOpening.new()
	made.name = opening_name
	made.kind = kind
	made.joins = joins
	made.centre = centre
	made.size = size
	return made


## The flat deck's structure: a room over the deck, CEILING high, with a room over it whose
## stairwell, WELL across, opens in its ceiling at the deck's middle; and a hold under the
## deck's after half, a hatch in its top at x = −5; the lower room [param ceiling] high.
static func _structure(ceiling: float) -> ShipStructure:
	var made := ShipStructure.new()
	var cells: Array[FloodCell] = [
		_cell(&"room", Vector3(-15.0, 0.0, -4.0), Vector3(15.0, ceiling, 4.0)),
		_cell(&"upper", Vector3(-15.0, ceiling, -4.0), Vector3(15.0, ceiling + 3.0, 4.0)),
		_cell(&"hold", Vector3(-15.0, -6.0, -4.0), Vector3(0.0, 0.0, 4.0)),
	]
	made.cells = cells
	var openings: Array[ShipOpening] = [
		_opening(
			&"well",
			ShipOpening.Kind.STAIRWELL,
			[&"room", &"upper"],
			Vector3(0.0, ceiling, 0.0),
			Vector3(WELL.x, 0.0, WELL.y)
		),
		_opening(
			&"hatch",
			ShipOpening.Kind.HATCH,
			[&"hold", &"room"],
			Vector3(-5.0, 0.0, 0.0),
			Vector3(2.0, 0.0, 2.0)
		),
	]
	made.openings = openings
	return made


## A match of [param seats] on the flat deck whose rooms' water stands [param depths] deep
## over their floors (room, upper, hold), [param flow] m³ a second pouring down the
## stairwell [param ceiling] over the deck — and, with [param vents], the hold's air going
## free at VENTS.
func _sim(seats: int, depths: Vector3, flow: float, vents := false, ceiling := CEILING) -> MatchSim:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	layout.structure = _structure(ceiling)
	var config := SimFixtures.config(seats, SimFixtures.calm(), 1, layout)
	var falling: Falling = config.schedule_as(Falling)
	falling.structure = layout.structure
	var deck := layout.freeboard
	falling.levels = PackedFloat64Array(
		[deck + depths.x, deck + ceiling + depths.y, deck - 6.0 + depths.z]
	)
	falling.pockets = PackedFloat64Array([0.0, 0.0, 10.5])
	falling.names = [&"well"]
	falling.flows = PackedFloat64Array([flow])
	falling.vents = vents
	return MatchSim.create(config)


func test_a_body_under_a_pouring_stairwell_is_staggered_and_one_beside_it_is_not() -> void:
	var sim := _sim(2, Vector3(0.0, 1.0, 0.0), 1.0)
	SimFixtures.place(sim, 0, Vector3(0.1, 0.0, 0.2))
	SimFixtures.place(sim, 1, Vector3(WELL.x * 0.5 + 1.0, 0.0, 0.0))
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)})
	var under := sim.state.seats[0]
	var beside := sim.state.seats[1]
	assert_true(under.is_staggered(), "knocked off its feet by the water falling 2.5 m")
	assert_eq(under.body, PlayerState.Body.GROUNDED, "on a dry deck: still on it")
	assert_false(beside.is_staggered(), "a metre beside the footprint: nothing")
	assert_eq(Vector2(beside.pos.x, beside.pos.z), Vector2(WELL.x * 0.5 + 1.0, 0.0))


func test_a_pour_under_the_topple_staggers_no_one() -> void:
	var sim := _sim(1, Vector3(0.0, 1.0, 0.0), 0.1)
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.0))
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3)
	assert_false(sim.state.seats[0].is_staggered(), "0.1 m³ a second: too light to stagger")


func test_a_body_knocked_down_in_water_deep_enough_to_swim_goes_into_it() -> void:
	var sim := _sim(1, Vector3(0.2, 1.0, 0.0), 1.0)
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.0))
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_eq(sim.state.seats[0].body, PlayerState.Body.SWIMMING, "into the water")
	var entered := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.ENTERED_WATER
	)
	assert_eq(entered.size(), 1, "as any fall in")


func test_a_swimmer_under_a_pour_is_dunked_and_thrown_outward() -> void:
	# Water 2.4 m deep under a stairwell 4.5 m over the deck: a swimmer rests afloat in it.
	var poured := _sim(1, Vector3(2.4, 1.0, 0.0), 1.0, false, 4.5)
	var still := _sim(1, Vector3(2.4, 1.0, 0.0), 0.0, false, 4.5)
	for sim: MatchSim in [poured, still]:
		SimFixtures.swim(sim, 0, Vector3(0.2, 0.0, 0.4))
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 6)
	var under := poured.state.seats[0]
	var calm := still.state.seats[0]
	assert_eq(under.body, PlayerState.Body.SWIMMING)
	assert_lt(under.pos.y, calm.pos.y - 0.1, "pushed down under the water")
	assert_gt(under.pos.x, calm.pos.x + 0.05, "thrown out of the footprint's middle")
	assert_gt(under.pos.z, calm.pos.z + 0.05, "away from it")


func test_a_swimmer_by_a_pockets_way_out_is_blown_clear_as_its_air_goes_free() -> void:
	# The room's water 2.4 m deep over the hold, the hold's 5.5 m deep under its 0.5 m of
	# air: by the hatch, a swimmer diving; one 5 m off; one in the hold, under the hatch.
	var blown := _sim(3, Vector3(2.4, 0.0, 5.5), 0.0, true)
	var still := _sim(3, Vector3(2.4, 0.0, 5.5), 0.0, false)
	var places: Array[Vector3] = [
		Vector3(-3.5, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(-5.0, -4.0, 0.0)
	]
	for sim: MatchSim in [blown, still]:
		for seat in places.size():
			SimFixtures.swim(sim, seat, places[seat])
		SimFixtures.step(sim, _idle(3), VENTS)
		sim.state.seats[0].pos = Vector3(-3.5, 0.2, 0.0)
		sim.state.seats[0].vel = Vector3(0.0, -2.0, 0.0)
	SimFixtures.step(blown, _idle(3))
	SimFixtures.step(still, _idle(3))
	var near := blown.state.seats[0]
	assert_gt(near.pos.y, still.state.seats[0].pos.y + 0.05, "blown up")
	assert_gt(near.pos.x, still.state.seats[0].pos.x, "and away from the hatch")
	var blast := Ticks.from_seconds(SimFixtures.rules().blast_time)
	SimFixtures.step(blown, _idle(3), blast - 1)
	SimFixtures.step(still, _idle(3), blast - 1)
	assert_gt(near.pos.x, still.state.seats[0].pos.x + 0.3, "blown clear")
	assert_eq(blown.state.seats[1].pos, still.state.seats[1].pos, "beyond blast_reach: nothing")
	assert_eq(blown.state.seats[2].pos, still.state.seats[2].pos, "inside the hold: nothing")
	var after := near.vel.x
	SimFixtures.step(blown, _idle(3))
	assert_lt(near.vel.x, after, "the blast over, it blows no more")


func test_the_rules_reject_negative_pour_and_blast_values() -> void:
	var rules := SimFixtures.rules()
	assert_eq(rules.problems(), PackedStringArray(), "the shipped numbers hold")
	for field: String in [
		"pour_topple", "blast_time", "blast_reach", "blast_speed", "blast_full_air"
	]:
		var bad: BrawlRules = rules.duplicate()
		bad.set(field, -1.0)
		assert_eq(
			bad.problems(), PackedStringArray(["brawl rules: %s must be positive" % field]), field
		)


## Every seat of [param seats] pressing nothing.
static func _idle(seats: int) -> Dictionary:
	var frames := {}
	for seat in seats:
		frames[seat] = SimFixtures.frame(seat)
	return frames
