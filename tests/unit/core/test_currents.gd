extends GutTest
## Moving water moves things (#616, Currents): the flow through an opening draws the water
## on its upstream side in toward it and throws a jet out of it downstream; the sea draws
## toward a hull opening taking water. A swimmer swims relative to the water, a wader is
## pushed by it and swept off its feet once depth times speed reaches topple_hv, and a prop
## afloat drifts with it.

## The doorway between the flat deck's after and fore halves (_structure), in metres.
const DOOR_WIDE := 1.0
const DOOR_TALL := 2.0


## A schedule of the test's own: her poses as a calm deck's, every one with
## [member structure]'s cells' water at [member levels] (world heights) and
## [member flows] through the openings [member names].
class Flowing:
	extends SinkSchedule
	var structure: ShipStructure
	var levels := PackedFloat64Array()
	var names: Array[StringName] = []
	var flows := PackedFloat64Array()
	var _flowing_cells: CellMap

	func _posed(tick: int) -> ShipPose:
		var pose := super._posed(tick)
		if _flowing_cells == null:
			_flowing_cells = CellMap.new(structure)
		pose.cells = _flowing_cells
		pose.levels = levels
		pose.passages = names
		pose.flows = flows
		return pose


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


## The flat deck's structure: its after and fore halves over the deck, joined by a doorway
## at x = 0, and a hold under its after half with a gash to the sea in its port side and,
## in its starboard side, a door its data names to the sky, as a deckhouse's is — under
## the sea here, as her decks' are in the plunge.
static func _structure() -> ShipStructure:
	var made := ShipStructure.new()
	var cells: Array[FloodCell] = [
		_cell(&"aft", Vector3(-15.0, 0.0, -4.0), Vector3(0.0, 3.0, 4.0)),
		_cell(&"fore", Vector3(0.0, 0.0, -4.0), Vector3(15.0, 3.0, 4.0)),
		_cell(&"hold", Vector3(-15.0, -6.0, -4.0), Vector3(0.0, 0.0, 4.0)),
	]
	made.cells = cells
	var openings: Array[ShipOpening] = [
		_opening(
			&"door",
			ShipOpening.Kind.DOOR,
			[&"aft", &"fore"],
			Vector3(0.0, DOOR_TALL * 0.5, 0.0),
			Vector3(0.0, DOOR_TALL, DOOR_WIDE)
		),
		_opening(
			&"gash",
			ShipOpening.Kind.GASH,
			[&"hold", ShipOpening.SEA],
			Vector3(-5.0, -4.0, -4.0),
			Vector3(2.0, 1.0, 0.0)
		),
		_opening(
			&"sky_door",
			ShipOpening.Kind.DOOR,
			[&"hold", ShipOpening.SKY],
			Vector3(-5.0, -4.0, 4.0),
			Vector3(2.0, 1.0, 0.0)
		),
	]
	made.openings = openings
	return made


## A match of [param seats] on the flat deck — with [param props] aboard — whose cells
## stand [param depths] deep over their floors (aft, fore, hold), [param door],
## [param gash] and [param sky] m³ a second passing their openings.
func _sim(
	seats: int, depths: Vector3, door: float, gash := 0.0, props: Array[ShipProp] = [], sky := 0.0
) -> MatchSim:
	var layout := SimFixtures.crated(props) if not props.is_empty() else SimFixtures.deck()
	layout = layout.duplicate()
	layout.structure = _structure()
	var config := SimFixtures.config(seats, SimFixtures.calm(), 1, layout)
	var flowing: Flowing = config.schedule_as(Flowing)
	flowing.structure = layout.structure
	var deck := layout.freeboard
	flowing.levels = PackedFloat64Array([deck + depths.x, deck + depths.y, deck - 6.0 + depths.z])
	flowing.names = [&"door", &"gash", &"sky_door"]
	flowing.flows = PackedFloat64Array([door, gash, sky])
	return MatchSim.create(config)


## Where [param seat] has got to, x/z, after a second of pressing nothing.
func _drift(sim: MatchSim, seat: int) -> Vector2:
	SimFixtures.step(sim, {seat: SimFixtures.frame(seat)}, Ticks.RATE)
	var player := sim.state.seats[seat]
	return Vector2(player.pos.x, player.pos.z)


func test_an_idle_swimmer_upstream_of_a_doorway_drifts_toward_it_faster_nearer() -> void:
	var far := _sim(1, Vector3(1.2, 0.6, 0.0), 2.4)
	_swim(far, 0, Vector3(-3.0, 0.0, 0.0))
	var near := _sim(1, Vector3(1.2, 0.6, 0.0), 2.4)
	_swim(near, 0, Vector3(-1.5, 0.0, 0.0))
	var still := _sim(1, Vector3(1.2, 0.6, 0.0), 0.0)
	_swim(still, 0, Vector3(-1.5, 0.0, 0.0))
	var went_far := _drift(far, 0) - Vector2(-3.0, 0.0)
	var went_near := _drift(near, 0) - Vector2(-1.5, 0.0)
	assert_eq(far.state.seats[0].body, PlayerState.Body.SWIMMING)
	assert_gt(went_far.x, 0.1, "drawn toward the doorway")
	assert_almost_eq(went_far.y, 0.0, 0.001, "straight at it")
	assert_gt(went_near.x, went_far.x, "faster nearer")
	assert_eq(_drift(still, 0), Vector2(-1.5, 0.0), "with no flow it stays put")


func test_a_swimmer_in_the_jet_is_carried_along_its_normal_and_one_beside_it_is_not() -> void:
	var sim := _sim(2, Vector3(1.2, 0.6, 0.0), 2.4)
	_swim(sim, 0, Vector3(2.0, 0.0, 0.0))
	_swim(sim, 1, Vector3(2.0, 0.0, 2.5))
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)}, Ticks.RATE)
	var jet := sim.state.seats[0]
	var beside := sim.state.seats[1]
	assert_gt(jet.pos.x, 3.0, "carried away from the doorway along its normal")
	assert_almost_eq(jet.pos.z, 0.0, 0.001, "along it")
	assert_eq(Vector2(beside.pos.x, beside.pos.z), Vector2(2.0, 2.5), "beside the jet: still")


func test_a_swimmer_beside_a_gash_taking_water_is_drawn_toward_her_side() -> void:
	var sim := _sim(2, Vector3(0.0, 0.0, 1.0), 0.0, 6.0)
	SimFixtures.swim(sim, 0, Vector3(-5.0, 0.0, -6.0))
	SimFixtures.swim(sim, 1, Vector3(-5.0, 0.0, -14.0))
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)}, Ticks.RATE)
	var near := sim.state.seats[0]
	var far := sim.state.seats[1]
	assert_gt(near.pos.z, -5.9, "drawn toward her side")
	assert_almost_eq(near.pos.x, -5.0, 0.01, "square to the gash")
	assert_eq(Vector2(far.pos.x, far.pos.z), Vector2(-5.0, -14.0), "beyond current_reach: still")


func test_a_swimmer_beside_a_door_named_to_the_sky_under_the_sea_is_drawn_toward_it() -> void:
	var sim := _sim(2, Vector3(0.0, 0.0, 1.0), 0.0, 0.0, [], 6.0)
	SimFixtures.swim(sim, 0, Vector3(-5.0, 0.0, 6.0))
	SimFixtures.swim(sim, 1, Vector3(-5.0, 0.0, 14.0))
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)}, Ticks.RATE)
	var near := sim.state.seats[0]
	var far := sim.state.seats[1]
	assert_lt(near.pos.z, 5.9, "the sea drawn in through her deckhouse door draws it in")
	assert_almost_eq(near.pos.x, -5.0, 0.01, "square to the door")
	assert_eq(Vector2(far.pos.x, far.pos.z), Vector2(-5.0, 14.0), "beyond current_reach: still")


func test_a_wader_in_shallow_flowing_water_is_pushed_downstream() -> void:
	var sim := _sim(1, Vector3(0.1, 0.0, 0.0), 0.3)
	SimFixtures.place(sim, 0, Vector3(-2.0, 0.0, 0.0))
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	var wader := sim.state.seats[0]
	assert_eq(wader.body, PlayerState.Body.GROUNDED, "still on its feet")
	assert_gt(wader.pos.x, -1.97, "pushed toward the doorway the water goes through")
	assert_false(_entered_water(events, 0))


func test_a_wader_where_depth_times_speed_reaches_the_limit_is_swept_off_its_feet() -> void:
	var sim := _sim(1, Vector3(0.29, 0.0, 0.0), 2.0)
	SimFixtures.place(sim, 0, Vector3(-0.8, 0.0, 0.0))
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	var swept := sim.state.seats[0]
	assert_eq(swept.body, PlayerState.Body.SWIMMING, "swept off its feet")
	assert_true(_entered_water(events, 0), "into the water, as any fall in")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_eq(swept.body, PlayerState.Body.SWIMMING, "no footing where it was swept")


func test_a_prop_afloat_drifts_with_the_current() -> void:
	var props: Array[ShipProp] = [SimFixtures.crate(Vector3(-2.0, 0.0, 0.0))]
	var flowing := _sim(1, Vector3(0.6, 0.3, 0.0), 1.0, 0.0, props)
	var still := _sim(1, Vector3(0.6, 0.3, 0.0), 0.0, 0.0, props)
	for sim: MatchSim in [flowing, still]:
		SimFixtures.place(sim, 0, Vector3(10.0, 0.0, 3.0))
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE * 3)
		assert_eq(sim.state.props[0].body, PropState.Body.FLOATING, "afloat")
	var drifted := flowing.state.props[0].pos
	var stayed := still.state.props[0].pos
	assert_gt(drifted.x, stayed.x + 0.1, "carried toward the doorway")
	assert_almost_eq(drifted.z, stayed.z, 0.001, "straight at it")


## Whether [param events] has [param seat] going into the water.
static func _entered_water(events: Array[SimEvent], seat: int) -> bool:
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.ENTERED_WATER and event.seat == seat:
			return true
	return false


func test_the_rules_reject_a_negative_reach_share_or_topple_limit() -> void:
	var rules := SimFixtures.rules()
	assert_eq(rules.problems(), PackedStringArray(), "the shipped numbers hold")
	var checks := {
		"current_reach": "brawl rules: current_reach must be positive",
		"current_wade_share": "brawl rules: current_wade_share must be within 0…1",
		"topple_hv": "brawl rules: topple_hv must be positive",
		"current_least": "brawl rules: current_least must not be negative",
		"current_least_flow": "brawl rules: current_least_flow must not be negative",
	}
	for field: String in checks:
		var bad: BrawlRules = rules.duplicate()
		bad.set(field, -1.0)
		assert_eq(bad.problems(), PackedStringArray([checks[field]]), field)


## Puts [param seat] afloat at [param pos] over her deck: on it, where the water there is
## shallower than a swimmer floats.
static func _swim(sim: MatchSim, seat: int, pos: Vector3) -> void:
	SimFixtures.swim(sim, seat, pos)
	var player := sim.state.seats[seat]
	player.pos.y = maxf(player.pos.y, pos.y)
