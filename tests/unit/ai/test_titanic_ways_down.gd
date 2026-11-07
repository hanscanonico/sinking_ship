extends GutTest
## Ways down through the Titanic a body walks (#501). Her after second-class stairway's
## flights alternate the way they rise, so a body off one flight's foot walks round the well
## onto the next one's head, from D deck down to G deck, and the bots' route goes that way.
## No manhole down into her double bottom stands in a passage through her coal or in a
## door's mouth, so every passage opens both ways onto the rooms at its ends.

const TITANIC := "res://data/ships/titanic.tres"
## D deck aft of bulkhead N, stepped up to her sheer there (D_SHEER_AFT).
const D_DECK_AFT := -2.9375
const E_DECK := -5.9375
const F_DECK := -8.5625
const G_DECK := -11.0
const DOUBLE_BOTTOM := -19.8125
## A point in each lane of the after second-class stairway's well: D deck's flight down to E
## comes down to port, E deck's down to F to starboard, F deck's down to G to port.
const D_FLIGHT := Vector2(-92.5, -1.8)
const E_FLIGHT := Vector2(-91.5, 2.1)
const F_FLIGHT := Vector2(-91.0, -1.8)
## On D deck in the after second-class entrance, aft of the stairway's well, and on G deck
## in its entrance.
const ON_D_DECK := Vector3(-94.0, D_DECK_AFT, 0.15625)
const ON_G_DECK := Vector3(-89.0, G_DECK, -1.0)
## How far off a flight's end a body stands on the deck there.
const OFF_THE_END := 0.45

static var _layout: ShipLayout
static var _surfaces: Surfaces
static var _graph: WalkGraph


func before_all() -> void:
	_layout = load(TITANIC)
	_surfaces = Surfaces.new(_layout)
	_graph = WalkGraph.new(_layout, _surfaces, SimFixtures.rules())


func _flight(point: Vector2, base: float) -> int:
	for index in _layout.ramps.size():
		var ramp := _layout.ramps[index]
		if ramp.area.has_point(point) and is_equal_approx(ramp.base(), base):
			return index
	return WalkGraph.NONE


## Where a body stands on the deck off [param ramp]'s high end, or its low end.
func _off(ramp: ShipRamp, high: bool) -> Vector3:
	var end := 1 if (ramp.end_height > ramp.start_height) == high else 0
	var point := ramp.end_point(end)
	var away := (point - ramp.end_point(1 - end)) * Vector3(1.0, 0.0, 1.0)
	return point + away.normalized() * OFF_THE_END


func _zone(at: Vector3) -> int:
	return _graph.zone_at(at, _surfaces.under(at, SimFixtures.rules().step_height))


## The portal along [param ramp] from its high end, or null.
func _down(ramp: int) -> WalkGraph.Portal:
	for portal: WalkGraph.Portal in _graph.portals():
		if portal.ramp == ramp and portal.entry.y > portal.exit.y:
			return portal
	return null


## Walks toward [param leg] from [param from] by the floor as a bot follows it, a quarter
## metre a look: whether it comes within half a metre of the leg's entry.
func _walks_to(leg: WalkGraph.Portal, from: Vector3) -> bool:
	var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
	var step := SimFixtures.rules().step_height
	var at := from
	for _look in 160:
		var surface := _surfaces.under(at, step)
		var aim := way.toward(at, surface, leg, _graph.toward(leg, at, surface))
		var flat := Vector2(aim.x - at.x, aim.z - at.z)
		at += Vector3(flat.x, 0.0, flat.y).limit_length(0.25)
		at.y = _surfaces.height_at(_surfaces.under(at, step), at)
		if Vector2(at.x - leg.entry.x, at.z - leg.entry.z).length() < 0.5:
			return true
	return false


func test_her_after_second_class_flights_alternate_the_way_they_rise() -> void:
	var flights := [_flight(D_FLIGHT, E_DECK), _flight(E_FLIGHT, F_DECK), _flight(F_FLIGHT, G_DECK)]
	for flight: int in flights:
		assert_ne(flight, WalkGraph.NONE, "a flight in each lane of the well")
	for index in 2:
		var upper := _layout.ramps[flights[index]]
		var lower := _layout.ramps[flights[index + 1]]
		assert_eq(upper.axis, ShipRamp.Axis.X, "along her")
		var rises_forward := upper.end_height > upper.start_height
		var next_rises_forward := lower.end_height > lower.start_height
		assert_ne(
			rises_forward, next_rises_forward, "flight %d against flight %d" % [index, index + 1]
		)


func test_a_body_off_each_flight_s_foot_walks_round_onto_the_next_one_s_head() -> void:
	var flights := [_flight(D_FLIGHT, E_DECK), _flight(E_FLIGHT, F_DECK), _flight(F_FLIGHT, G_DECK)]
	for index in 2:
		var leg := _down(flights[index + 1])
		assert_not_null(leg, "a way down flight %d" % (index + 1))
		if leg != null:
			var foot := _off(_layout.ramps[flights[index]], false)
			assert_true(_walks_to(leg, foot), "off flight %d's foot onto the next" % index)


func test_her_bots_route_from_d_deck_to_g_deck_down_the_stairway() -> void:
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	var on := _surfaces.under(ON_D_DECK, SimFixtures.rules().step_height)
	var legs := _graph.route(ON_D_DECK, on, _zone(ON_G_DECK), dry)
	var down: Array[int] = []
	for leg: WalkGraph.Portal in legs:
		if leg.ramp != WalkGraph.NONE:
			down.append(leg.ramp)
	var flights: Array[int] = [
		_flight(D_FLIGHT, E_DECK), _flight(E_FLIGHT, F_DECK), _flight(F_FLIGHT, G_DECK)
	]
	assert_eq(down, flights, "down its three flights and no other")


func test_no_manhole_stands_in_a_passage_through_her_coal() -> void:
	var passages: Array[Rect2] = []
	for room: ShipRoom in _layout.rooms:
		if room.name.begins_with("passage, tank top"):
			passages.append(room.area)
	assert_gt(passages.size(), 0, "her passages through her coal")
	for ramp: ShipRamp in _layout.ramps:
		if is_equal_approx(ramp.base(), DOUBLE_BOTTOM):
			for passage: Rect2 in passages:
				assert_false(ramp.area.intersects(passage), "a manhole at %s" % ramp.area)


func test_every_passage_through_her_coal_opens_both_ways_at_its_ends() -> void:
	var rules := SimFixtures.rules()
	var doors := 0
	for room: ShipRoom in _layout.rooms:
		if not room.name.begins_with("passage, tank top"):
			continue
		for door: ShipRoom.Door in room.doors(_surfaces, rules.crawl_height, rules.step_height):
			doors += 1
			for out: Vector2 in [door.outward, -door.outward]:
				assert_false(
					is_nan(WayThrough.doorway(_surfaces, rules, door, room.floor_height, out)),
					"%s's end at %s, %s" % [room.name, door.middle(), out]
				)
	assert_gt(doors, 0, "their ends")
