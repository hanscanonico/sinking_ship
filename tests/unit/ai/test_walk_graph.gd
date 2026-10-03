extends GutTest
## The bots' walk graph: rooms and open decks are zones, doorways and ramps the
## portals between them; flooded zones are never on a route, and a route crosses a
## wall only through a doorway.


func _graph(layout: ShipLayout, surfaces: Surfaces) -> WalkGraph:
	return WalkGraph.new(layout, surfaces, SimFixtures.rules())


func _pose(layout: ShipLayout, scenario: SinkScenario) -> ShipPose:
	return SinkSchedule.new(scenario, layout.freeboard, SeedStreams.derive(1, "sink")).pose_at(0)


## The zones a route arrives in, in order.
func _zones_on(route: Array[WalkGraph.Portal]) -> Array[int]:
	var visited: Array[int] = []
	for leg: WalkGraph.Portal in route:
		visited.append(leg.to_zone)
	return visited


func _room(layout: ShipLayout, room_name: StringName) -> int:
	for index in layout.rooms.size():
		if layout.rooms[index].name == room_name:
			return index
	return WalkGraph.NONE


## Seat 0 of [param sim] walks [param graph]'s steer points toward [param goal] for
## up to [param seconds], or until it stands in that zone off any ramp; returns the
## zones it passed through, in order.
func _walk(sim: MatchSim, graph: WalkGraph, goal: int, seconds: float) -> Array[int]:
	var calm := sim.pose()
	var passed: Array[int] = []
	for _tick in Ticks.from_seconds(seconds):
		var walker := sim.state.seats[0]
		var zone := graph.zone_at(walker.pos, walker.surface)
		if zone != WalkGraph.NONE and (passed.is_empty() or passed.back() != zone):
			passed.append(zone)
		if zone == goal and not sim.surfaces.is_ramp(walker.surface):
			break
		var toward := graph.steer(walker.pos, walker.surface, goal, calm)
		var move := Vector2.ZERO
		if not toward.is_empty():
			move = Vector2(toward[0].x - walker.pos.x, toward[0].z - walker.pos.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	return passed


## A ground deck with a high platform in the middle, reached two ways: up by the
## bow through one mid-height platform, or up by the stern through another.
func _two_way_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 1.0
	var platforms: Array[ShipPlatform] = []
	for row: Array in [
		[&"ground", Rect2(-16.0, -6.0, 32.0, 12.0), 0.0],
		[&"bow perch", Rect2(10.0, -2.0, 4.0, 4.0), 1.0],
		[&"stern perch", Rect2(-14.0, -2.0, 4.0, 4.0), 1.0],
		[&"top", Rect2(-2.0, -2.0, 4.0, 4.0), 2.0],
	]:
		var platform := ShipPlatform.new()
		platform.name = row[0]
		platform.area = row[1]
		platform.height = row[2]
		platforms.append(platform)
	layout.platforms = platforms
	var ramps: Array[ShipRamp] = []
	for row: Array in [
		[Rect2(11.0, 2.0, 2.0, 3.0), ShipRamp.Axis.Z, 1.0, 0.0],
		[Rect2(2.0, -1.0, 8.0, 2.0), ShipRamp.Axis.X, 2.0, 1.0],
		[Rect2(-13.0, 2.0, 2.0, 3.0), ShipRamp.Axis.Z, 1.0, 0.0],
		[Rect2(-10.0, -1.0, 8.0, 2.0), ShipRamp.Axis.X, 1.0, 2.0],
	]:
		var ramp := ShipRamp.new()
		ramp.area = row[0]
		ramp.axis = row[1]
		ramp.start_height = row[2]
		ramp.end_height = row[3]
		ramps.append(ramp)
	layout.ramps = ramps
	return layout


func test_path_from_main_deck_to_the_bridge() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var boat_deck := graph.deck_of(SimFixtures.platform_named(layout, &"boat deck"))
	var bridge := graph.deck_of(SimFixtures.platform_named(layout, &"bridge"))
	var calm := _pose(layout, SimFixtures.calm())
	var start := Vector3(-10.5, 0.0, 2.5)
	var on := surfaces.under(start, SimFixtures.rules().step_height)
	var route := graph.route(start, on, bridge, calm)
	assert_eq(_zones_on(route), [boat_deck, bridge], "up to the boat deck, then on up")
	var top := Vector3(-2.5, 4.7, 0.0)
	assert_true(
		graph.route(top, surfaces.under(top, 0.1), bridge, calm).is_empty(), "already there"
	)

	# Walked in the sim, one steer point at a time from the foredeck, where nothing
	# stands between it and the first ramp, the route gets a body there.
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(10.5, 0.0, 3.0))
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 0.0))
	_walk(sim, graph, bridge, 20.0)
	var walker := sim.state.seats[0]
	assert_eq(graph.zone_at(walker.pos, walker.surface), bridge, "the walk reached the bridge")
	assert_almost_eq(walker.pos.y, 4.7, 0.0001)


func test_path_from_the_hold_to_the_poop_deck() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var hold := _room(layout, &"forward hold")
	var poop_deck := graph.deck_of(SimFixtures.platform_named(layout, &"poop deck"))
	var calm := _pose(layout, SimFixtures.calm())
	var start := Vector3(8.0, -2.6, -2.0)
	var on := surfaces.under(start, SimFixtures.rules().step_height)
	assert_eq(graph.zone_at(start, on), hold, "it starts in the hold")
	var route := graph.route(start, on, poop_deck, calm)
	assert_false(route.is_empty(), "there is a way up")
	if route.is_empty():
		return
	assert_eq(route[0].from_zone, hold)
	assert_eq(route.back().to_zone, poop_deck, "it ends on the poop deck")
	var climbs := 0
	for leg: WalkGraph.Portal in route:
		if leg.ramp != WalkGraph.NONE and leg.exit.y > leg.entry.y and leg.entry.y < 0.0:
			climbs += 1
	assert_eq(climbs, 1, "one stair up out of the lower deck")

	# Walked in the sim, the steer points take a body out of the hold, up a stair and
	# onto the main deck. (On deck, going round the deckhouse is local steering — a
	# bot's, not the graph's.)
	var main_deck := graph.deck_of(SimFixtures.platform_named(layout, &"main deck"))
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, start)
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 3.0))
	var passed := _walk(sim, graph, main_deck, 20.0)
	assert_eq(passed, [hold, main_deck], "out of the hold and up on deck")
	assert_eq(sim.state.seats[0].pos.y, 0.0)


func test_paths_cross_walls_only_through_doors() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var doorways := 0
	for portal: WalkGraph.Portal in graph.portals():
		var along := Vector3(portal.along.x, 0.0, portal.along.y)
		var before := portal.entry - along * rules.body_radius * 2.0
		var past := portal.exit + along * rules.body_radius * 2.0
		if portal.ramp == WalkGraph.NONE:
			doorways += 1
			# A doorway is a gap at least a body wide, and nothing stands across the
			# walk straight through its middle.
			assert_gte(portal.half_width * 2.0, rules.body_radius * 2.0)
			assert_false(
				surfaces.blocked(before, past, rules.body_height, rules.step_height),
				"doorway at %s is clear" % portal.entry
			)
		assert_ne(portal.from_zone, portal.to_zone)
	assert_gt(doorways, 0)
	# Rooms that share a wall and no doorway have no way between them: the cabins on
	# the lower deck are entered from the corridor only.
	var cabins := [
		_room(layout, &"aft port cabin"),
		_room(layout, &"middle port cabin"),
		_room(layout, &"forward port cabin"),
	]
	var corridor := _room(layout, &"cabin corridor")
	for portal: WalkGraph.Portal in graph.portals():
		if portal.from_zone in cabins:
			assert_eq(portal.to_zone, corridor, "out of a cabin only into the corridor")
		if portal.to_zone in cabins:
			assert_eq(portal.from_zone, corridor, "into a cabin only from the corridor")
	# And a walk from the engine room to the saloon goes up the inner stair and through
	# doorways — the straight line between them crosses walls and decks.
	var engine_room := _room(layout, &"engine room")
	var saloon := _room(layout, &"saloon")
	var start := Vector3(-2.0, -2.6, -3.5)
	var calm := _pose(layout, SimFixtures.calm())
	var route := graph.route(start, surfaces.under(start, rules.step_height), saloon, calm)
	assert_false(route.is_empty())
	if route.is_empty():
		return
	assert_eq(route[0].from_zone, engine_room)
	assert_eq(route.back().to_zone, saloon)
	assert_eq(route.back().ramp, WalkGraph.NONE, "into the saloon through a doorway")


func test_path_avoids_a_ramp_whose_foot_is_under() -> void:
	var layout := SimFixtures.steamer()
	var main_deck := SimFixtures.platform_named(layout, &"main deck")
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	var poop_deck := SimFixtures.platform_named(layout, &"poop deck")
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	# Down by the head far enough that the sea stands over the feet of the ramps up
	# to the boat deck, while the middles of the main deck and the boat deck are dry.
	var by_the_head := _pose(layout, SimFixtures.scenario([[0.0, 2.4, 8.0, 0.0]]))
	assert_false(graph.flooded(graph.deck_of(main_deck), by_the_head))
	assert_false(graph.flooded(graph.deck_of(boat_deck), by_the_head))
	var feet := 0
	for ramp in layout.ramps.size():
		var joined := surfaces.joins(surfaces.ramp_surface(ramp))
		if (
			boat_deck in joined
			and layout.platforms[joined[1 - joined.find(boat_deck)]].height == 0.0
		):
			feet += 1
			var foot := layout.ramps[ramp].end_point(1 - joined.find(boat_deck))
			assert_true(surfaces.wet(foot, by_the_head), "ramp %d's foot is under" % ramp)
	assert_gt(feet, 0)

	var abaft := Vector3(-10.5, 0.0, 2.5)
	var on := surfaces.under(abaft, SimFixtures.rules().step_height)
	assert_true(
		graph.route(abaft, on, graph.deck_of(boat_deck), by_the_head).is_empty(), "no way up"
	)
	assert_eq(
		graph.highest_reachable(abaft, on, by_the_head),
		graph.deck_of(poop_deck),
		"the high ground it can still reach"
	)


func test_path_avoids_flooded_platforms() -> void:
	var layout := _two_way_layout()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var ground := SimFixtures.platform_named(layout, &"ground")
	var bow_perch := graph.deck_of(SimFixtures.platform_named(layout, &"bow perch"))
	var stern_perch := graph.deck_of(SimFixtures.platform_named(layout, &"stern perch"))
	var top := graph.deck_of(SimFixtures.platform_named(layout, &"top"))
	assert_eq(layout.problems(1).size(), 1, "only the missing spawn is wrong with it")
	var calm := _pose(layout, SimFixtures.calm())
	# Down by the head and level otherwise: the bow perch is under at its middle,
	# the stern perch and the top are not.
	var by_the_head := _pose(layout, SimFixtures.scenario([[0.0, 0.0, 10.0, 0.0]]))
	assert_true(graph.flooded(bow_perch, by_the_head))
	assert_false(graph.flooded(stern_perch, by_the_head))
	assert_false(graph.flooded(top, by_the_head))

	var forward := Vector3(12.0, 0.0, 5.5)
	var dry := _zones_on(graph.route(forward, ground, top, calm))
	assert_eq(dry, [bow_perch, top], "dry: the short way, by the bow")
	var flooded := _zones_on(graph.route(forward, ground, top, by_the_head))
	assert_eq(flooded, [stern_perch, top], "flooded: round by the stern")
	assert_true(graph.route(forward, ground, bow_perch, by_the_head).is_empty(), "never onto it")
