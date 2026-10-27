extends GutTest
## The Titanic's old voids and empty spaces made places (#148): from every space fitted
## into them the bots' walk graph finds a way up to her forward well deck; a body crawls up
## out of No. 3 hold's double bottom and the turbine room's through a manhole, walks up the
## firemen's passage's stair into No. 2 hold and along the working passage on E deck aft
## through a bulkhead's door; once a space's floor is under, no route goes down into it.

const TANK_TOP := -18.1875
const PASSAGE_TOP := -15.75
const ORLOP := -13.4375
const G_DECK := -11.0
const F_DECK := -8.5625
const E_DECK := -5.9375
const D_DECK := -3.1875
const KEEL := -19.8125
const ENGINE_TANK_TOP := -17.9375
## Each space by name, and a point on its floor clear of its stairs, holes and machinery.
const SPACES := {
	&"boiler room 6": Vector3(55.5, TANK_TOP, 4.0),
	&"coal bunker 6": Vector3(69.3, TANK_TOP, 0.0),
	&"F deck working corridor, boiler room 6": Vector3(58.0, F_DECK, -4.0),
	&"firemen's passage": Vector3(80.0, TANK_TOP, 3.34),
	&"No. 3 hold, port": Vector3(78.9, TANK_TOP, -4.5),
	&"No. 3 hold, starboard": Vector3(78.0, TANK_TOP, 5.0),
	&"No. 2 hold, port": Vector3(95.0, TANK_TOP, -2.5),
	&"No. 3 hold": Vector3(79.0, PASSAGE_TOP, 0.0),
	&"No. 2 hold": Vector3(94.0, PASSAGE_TOP, -2.5),
	&"No. 1 hold": Vector3(102.5, TANK_TOP, 1.5),
	&"No. 1 hold, forward": Vector3(113.0, TANK_TOP, 0.0),
	&"No. 1 hold, orlop": Vector3(109.5, ORLOP, 0.0),
	&"No. 1 hold, orlop, forward": Vector3(113.0, ORLOP, 0.0),
	&"G deck passage, No. 1 hold": Vector3(103.0, G_DECK, 1.0),
	&"G deck passage, No. 1 hold, forward": Vector3(115.0, G_DECK, 1.0),
	&"firemen's quarters": Vector3(106.0, D_DECK, 3.0),
	&"seamen's quarters": Vector3(100.0, 0.0, 0.0),
	&"forecastle stores": Vector3(114.0, 0.0, 0.0),
	&"forecastle stores, forward": Vector3(119.0, 0.0, 0.0),
	&"forepeak tank": Vector3(117.5, TANK_TOP, 0.0),
	&"forepeak stores": Vector3(119.0, ORLOP, 0.0),
	&"boiler room 6 double bottom": Vector3(60.0, KEEL, 0.0),
	&"No. 3 hold double bottom": Vector3(78.9, KEEL, 0.0),
	&"No. 2 hold double bottom": Vector3(90.0, KEEL, 0.0),
	&"No. 1 hold double bottom": Vector3(105.9, KEEL, -0.5),
	&"No. 1 hold double bottom, forward": Vector3(113.0, KEEL, 0.0),
	&"boiler room 1": Vector3(-21.4, TANK_TOP, 0.0),
	&"coal bunker 1": Vector3(-17.5, TANK_TOP, 5.0),
	&"F deck working corridor, boiler room 1": Vector3(-18.0, F_DECK, -6.0),
	&"engine room": Vector3(-47.0, ENGINE_TANK_TOP, 0.0),
	&"turbine engine room": Vector3(-50.0, TANK_TOP, 0.0),
	&"electric engine room": Vector3(-84.3, TANK_TOP, 2.5),
	&"G deck stores, electric room": Vector3(-72.0, G_DECK, 0.0),
	&"after hold, forward": Vector3(-90.0, TANK_TOP, 0.0),
	&"after hold, forward, orlop": Vector3(-96.0, ORLOP, -2.0),
	&"after hold, forward, G deck": Vector3(-89.0, G_DECK, 1.0),
	&"after hold, aft": Vector3(-102.3, TANK_TOP, 2.2),
	&"after hold, aft, orlop": Vector3(-102.4, ORLOP, -2.7),
	&"after hold, aft, G deck": Vector3(-102.5, G_DECK, 1.0),
	&"E deck working passage, engine room": Vector3(-30.0, E_DECK, -6.0),
	&"E deck working passage, turbine room": Vector3(-55.0, E_DECK, -6.0),
	&"E deck working passage, electric room": Vector3(-80.0, E_DECK, -6.0),
	&"E deck working passage, after hold, forward": Vector3(-95.0, E_DECK, -6.0),
	&"E deck working passage, after hold, aft": Vector3(-106.0, E_DECK, -5.0),
	&"boiler room 1 double bottom": Vector3(-24.0, KEEL, 0.0),
	&"engine room double bottom": Vector3(-40.0, KEEL, 0.0),
	&"turbine room double bottom": Vector3(-57.0, KEEL, 0.0),
	&"electric room double bottom": Vector3(-76.0, KEEL, 0.0),
	&"after hold, forward, double bottom": Vector3(-90.0, KEEL, 0.0),
	&"after hold, aft, double bottom": Vector3(-104.0, KEEL, -1.0),
	&"after hold, aft, after end": Vector3(-114.0, TANK_TOP, 0.0),
	&"after hold, aft, orlop, after end": Vector3(-114.0, ORLOP, 0.0),
	&"after hold, aft, G deck, after end": Vector3(-114.0, G_DECK, 0.0),
	&"after peak tank": Vector3(-120.5, TANK_TOP, 0.0),
	&"after peak stores": Vector3(-120.5, G_DECK, 0.0),
	&"coal bunker 2": Vector3(0.5, TANK_TOP, 0.0),
	&"coal bunker 3": Vector3(18.5, TANK_TOP, 0.0),
	&"coal bunker 4": Vector3(35.5, TANK_TOP, 0.0),
	&"coal bunker 5": Vector3(53.3, TANK_TOP, 0.0),
	&"boiler room 2 double bottom": Vector3(-8.0, KEEL, 0.0),
	&"boiler room 3 double bottom": Vector3(8.0, KEEL, 0.0),
	&"boiler room 4 double bottom": Vector3(26.0, KEEL, 0.0),
	&"boiler room 5 double bottom": Vector3(44.0, KEEL, 0.0),
}

var _layout: ShipLayout


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")


func _graph(surfaces: Surfaces) -> WalkGraph:
	return WalkGraph.new(_layout, surfaces, SimFixtures.rules())


func _room(room_name: StringName) -> int:
	for index in _layout.rooms.size():
		if _layout.rooms[index].name == room_name:
			return index
	return WalkGraph.NONE


## Seat 0 of [param sim] walks [param graph]'s steer points toward [param goal] for
## up to [param seconds], or until it stands in that zone off any ramp; returns the
## zones it passed through, in order, and whether it crawled on the way.
func _walk(sim: MatchSim, graph: WalkGraph, goal: int, seconds: float) -> Array:
	var calm := sim.pose()
	var rules := SimFixtures.rules()
	var passed: Array[int] = []
	var crawled := false
	for _tick in Ticks.from_seconds(seconds):
		var walker := sim.state.seats[0]
		var zone := graph.zone_at(walker.pos, walker.surface)
		if zone != WalkGraph.NONE and (passed.is_empty() or passed.back() != zone):
			passed.append(zone)
		crawled = crawled or rules.height_at(sim.surfaces, walker.pos) < rules.body_height
		if zone == goal and not sim.surfaces.is_ramp(walker.surface):
			break
		var toward := graph.steer(walker.pos, walker.surface, goal, calm)
		var move := Vector2.ZERO
		if not toward.is_empty():
			move = Vector2(toward[0].x - walker.pos.x, toward[0].z - walker.pos.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	return [passed, crawled]


func test_every_new_space_has_a_way_up_to_the_forward_well_deck() -> void:
	# Level and dry inside her, as the physics has her before the hit.
	var surfaces := Surfaces.new(_layout)
	var graph := _graph(surfaces)
	var step := SimFixtures.rules().step_height
	var deck := graph.deck_of(SimFixtures.platform_named(_layout, &"forward well deck"))
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	for space: StringName in SPACES:
		var start: Vector3 = SPACES[space]
		var on := surfaces.under(start, step)
		assert_ne(_room(space), WalkGraph.NONE, "%s is one of her rooms" % space)
		assert_eq(graph.zone_at(start, on), _room(space), "it starts in the %s" % space)
		var route := graph.route(start, on, deck, dry)
		assert_false(route.is_empty(), "a way up out of the %s" % space)
		if not route.is_empty():
			assert_eq(route.back().to_zone, deck, "from the %s to the forward well" % space)


func test_a_body_crawls_out_of_no_3_hold_s_double_bottom_and_none_goes_into_it_flooded() -> void:
	# Out from under No. 3 hold's tank top on hands and knees and up through a manhole into
	# the hold's port part.
	var surfaces := Surfaces.new(_layout)
	var graph := _graph(surfaces)
	var double_bottom := _room(&"No. 3 hold double bottom")
	var hold := _room(&"No. 3 hold, port")
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 0, SPACES[&"No. 3 hold double bottom"])
	SimFixtures.place(sim, 1, Vector3(60.0, 0.0, 9.0))
	HeldPose.hold(sim, dry)
	var walked := _walk(sim, graph, hold, 30.0)
	var passed: Array[int] = walked[0]
	assert_eq(passed.front(), double_bottom)
	assert_true(walked[1], "it crawled under the tank top")
	assert_eq(passed.back(), hold, "crawled out of it into the hold")

	var step := SimFixtures.rules().step_height
	var start: Vector3 = SPACES[&"No. 3 hold, port"]
	var on := surfaces.under(start, step)
	assert_false(graph.route(start, on, double_bottom, dry).is_empty(), "down into it, dry")
	var flooded := HeldPose.flooded(_layout, -_layout.freeboard, {&"db_hold_3": [-18.5]})
	assert_true(graph.flooded(double_bottom, flooded), "its floor under")
	assert_true(graph.route(start, on, double_bottom, flooded).is_empty(), "never flooded")


func test_a_body_walks_up_the_firemen_s_passage_s_stair_into_no_2_hold() -> void:
	var graph := _graph(Surfaces.new(_layout))
	var hold := _room(&"No. 2 hold")
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 0, SPACES[&"firemen's passage"])
	SimFixtures.place(sim, 1, Vector3(60.0, 0.0, 9.0))
	HeldPose.hold(sim, dry)
	var passed: Array[int] = _walk(sim, graph, hold, 40.0)[0]
	assert_eq(passed.front(), _room(&"firemen's passage"))
	assert_eq(passed.back(), hold, "up out of the passage")


func test_a_body_crawls_out_of_the_turbine_room_s_double_bottom() -> void:
	var graph := _graph(Surfaces.new(_layout))
	var room := _room(&"turbine engine room")
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 0, SPACES[&"turbine room double bottom"])
	SimFixtures.place(sim, 1, Vector3(60.0, 0.0, 9.0))
	HeldPose.hold(sim, dry)
	var walked := _walk(sim, graph, room, 40.0)
	var passed: Array[int] = walked[0]
	assert_eq(passed.front(), _room(&"turbine room double bottom"))
	assert_true(walked[1], "it crawled under the tank top")
	assert_eq(passed.back(), room, "crawled out of it into the turbine room")


func test_a_body_walks_aft_along_the_working_passage_through_a_bulkhead_s_door() -> void:
	# From over the electric room through bulkhead N's E deck door (wtd_e_n) to over the
	# forward after hold.
	var graph := _graph(Surfaces.new(_layout))
	var goal := _room(&"E deck working passage, after hold, forward")
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 0, SPACES[&"E deck working passage, electric room"])
	SimFixtures.place(sim, 1, Vector3(60.0, 0.0, 9.0))
	HeldPose.hold(sim, dry)
	var passed: Array[int] = _walk(sim, graph, goal, 30.0)[0]
	assert_eq(passed.front(), _room(&"E deck working passage, electric room"))
	assert_eq(passed.back(), goal, "through the bulkhead's door")


## A body standing still in the depth of a door through a bulkhead — floor in no room,
## between the rooms either side, each stopping at its own wall: bulkhead D's and C's on
## F deck (wtd_f_d, wtd_f_c) — stands in the room nearer it, and walks on through the
## door into the other, either way. It once stood on F deck's open floor, whose only
## way out lay at the squash court's gallery: from bulkhead D's door it turned back for
## there at every step aft.
func test_a_body_standing_in_a_bulkhead_door_s_depth_walks_on_through_it() -> void:
	var graph := _graph(Surfaces.new(_layout))
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	for door: Array in [
		[&"wtd_f_d", &"F deck working corridor, boiler room 6", &"third-class berths"],
		[&"wtd_f_c", &"F deck landing corridor", &"squash court gallery"],
	]:
		var aft := _room(door[1])
		var fore := _room(door[2])
		var from_x := _layout.rooms[aft].area.end.x
		var depth := _layout.rooms[fore].area.position.x - from_x
		assert_gt(depth, 0.1, "%s's depth is in neither room" % door[0])
		# A quarter of the way through from each side, bound for the room across.
		for ends: Array in [[aft, fore, 0.25], [fore, aft, 0.75]]:
			var nearer: int = ends[0]
			var across: int = ends[1]
			var at: float = ends[2]
			var start := Vector3(from_x + depth * at, F_DECK, _opening(door[0]).centre.z)
			var sim := SimFixtures.sim(2, null, _layout)
			SimFixtures.place(sim, 0, start)
			SimFixtures.place(sim, 1, Vector3(60.0, 0.0, 9.0))
			HeldPose.hold(sim, dry)
			var passed: Array[int] = _walk(sim, graph, across, 10.0)[0]
			assert_eq(passed.front(), nearer, "in %s's depth at x %s" % [door[0], start.x])
			assert_eq(passed.back(), across, "on through %s from x %s" % [door[0], start.x])


## Her opening named [param opening_name].
func _opening(opening_name: StringName) -> ShipOpening:
	for opening: ShipOpening in _layout.structure.openings:
		if opening.name == opening_name:
			return opening
	return null
