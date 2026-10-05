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


## Down by the head, the bridge stands highest now; were she to go on down that way,
## the poop deck would: the end a ship rises by is the last refuge.
func test_the_last_refuge_is_the_end_the_ship_rises_by() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var bridge := graph.deck_of(SimFixtures.platform_named(layout, &"bridge"))
	var poop_deck := graph.deck_of(SimFixtures.platform_named(layout, &"poop deck"))
	var abaft := Vector3(-10.5, 0.0, 2.5)
	var on := surfaces.under(abaft, SimFixtures.rules().step_height)
	var by_the_head := _pose(layout, SimFixtures.scenario([[0.0, 0.0, 4.0, 0.0]]))
	var found := graph.search(abaft, on, by_the_head)
	assert_eq(graph.highest_in(found, by_the_head), bridge, "the bridge stands highest now")
	assert_eq(graph.highest_in(found, by_the_head, 15.0), poop_deck, "leaned on, the poop deck")
	var level := _pose(layout, SimFixtures.calm())
	var all_of_it := graph.search(abaft, on, level)
	assert_eq(
		graph.highest_in(all_of_it, level, 15.0),
		graph.highest_in(all_of_it, level),
		"a level deck leans no way"
	)


## A deck with a perch either side, one height, each up its own stair: the deck leans
## to neither by more than its heel, so which perch it rises by is a coin a heel
## swinging across would flip.
func _two_perch_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for row: Array in [
		[&"deck", Rect2(-8.0, -12.0, 16.0, 24.0), 0.0],
		[&"port perch", Rect2(-2.0, -10.0, 4.0, 4.0), 1.0],
		[&"starboard perch", Rect2(-2.0, 6.0, 4.0, 4.0), 1.0],
	]:
		var platform := ShipPlatform.new()
		platform.name = row[0]
		platform.area = row[1]
		platform.height = row[2]
		platforms.append(platform)
	layout.platforms = platforms
	var ramps: Array[ShipRamp] = []
	for area: Rect2 in [Rect2(2.0, -10.0, 3.0, 4.0), Rect2(2.0, 6.0, 3.0, 4.0)]:
		var ramp := ShipRamp.new()
		ramp.area = area
		ramp.axis = ShipRamp.Axis.X
		ramp.start_height = 1.0
		ramp.end_height = 0.0
		ramps.append(ramp)
	layout.ramps = ramps
	return layout


## A refuge once made for holds while the heel swings across by a little, and through
## a lurch however far: neither is the way she founders.
func test_a_refuge_holds_through_a_heel_swinging_across() -> void:
	var layout := _two_perch_layout()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var normal := BotProfile.for_tier(&"normal")
	var keep := normal.refuge_keep_m
	var start := Vector3(-5.0, 0.0, 0.0)
	var on := surfaces.under(start, SimFixtures.rules().step_height)
	var refuges: Array[int] = []
	for heel_deg: float in [0.3, -0.3]:
		var pose := _pose(layout, SimFixtures.tilted(0.0, heel_deg))
		var tilt := normal.refuge_tilt(pose.slope_deg())
		refuges.append(graph.highest_in(graph.search(start, on, pose), pose, tilt))
	assert_ne(refuges[0], refuges[1], "afresh, each heel has the other perch rise")
	var swung := _pose(layout, SimFixtures.tilted(0.0, -0.3))
	var found := graph.search(start, on, swung)
	var tilt := normal.refuge_tilt(swung.slope_deg())
	assert_eq(graph.highest_in(found, swung, tilt, refuges[0], keep), refuges[0], "kept")
	var lurch := SimFixtures.with_events(
		SimFixtures.tilted(0.0, 0.3), [SimFixtures.lurch(0.0, -15.0, 3.0, 0.0)]
	)
	var lurching := (
		SinkSchedule.new(lurch, layout.freeboard, SeedStreams.derive(1, "sink")).pose_at(45)
	)
	assert_ne(lurching.lurch, 0.0, "a lurch is under way")
	found = graph.search(start, on, lurching)
	tilt = normal.refuge_tilt(lurching.slope_deg())
	assert_eq(
		graph.highest_in(found, lurching, tilt), refuges[1], "the lurch heels it the second way"
	)
	assert_eq(
		graph.highest_in(found, lurching, tilt, refuges[0], keep), refuges[0], "kept through it"
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


func test_routes_never_end_on_a_deck_giving_way() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var bridge := graph.deck_of(SimFixtures.platform_named(layout, &"bridge"))
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	var from := Vector3(-5.0, 2.5, -2.0)
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(4.0, &"bridge", 2.0)]
	)
	var schedule := SinkSchedule.new(scenario, layout.freeboard, SeedStreams.derive(1, "sink"))
	var standing := schedule.pose_at(0)
	assert_eq(graph.highest_reachable(from, boat_deck, standing), bridge, "while it stands")
	assert_false(graph.route(from, boat_deck, bridge, standing).is_empty())
	for tick: int in [Ticks.from_seconds(3.0), Ticks.from_seconds(5.0)]:
		var pose := schedule.pose_at(tick)
		assert_true(graph.doomed(bridge, pose))
		assert_ne(graph.highest_reachable(from, boat_deck, pose), bridge, "tick %d" % tick)
		assert_true(graph.route(from, boat_deck, bridge, pose).is_empty(), "tick %d" % tick)


func test_route_leads_out_from_under_a_stair() -> void:
	# Under the inner stair's head in the engine room, where bots used to stand pressing
	# into it: the steer points take a body out to the stair's side, round to its foot,
	# and up it into the deckhouse hall.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var start := Vector3(-0.7, -2.6, -2.0)
	assert_eq(graph.zone_at(start, surfaces.under(start, 0.1)), _room(layout, &"engine room"))
	var hall := _room(layout, &"deckhouse hall")
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, start)
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 0.0))
	var passed := _walk(sim, graph, hall, 10.0)
	assert_eq(passed.back(), hall, "up in the deckhouse hall")


## The cheapest way to every zone from [param from_pos], by the plainest Dijkstra
## there is — every zone looked at for the cheapest each round — over the same
## portals, rules and pose as the graph's own search.
func _reference_costs(
	graph: WalkGraph, surfaces: Surfaces, from_pos: Vector3, pose: ShipPose
) -> PackedFloat64Array:
	var cost := PackedFloat64Array()
	cost.resize(graph.zone_count())
	cost.fill(INF)
	var arrived := PackedVector3Array()
	arrived.resize(graph.zone_count())
	var done := PackedByteArray()
	done.resize(graph.zone_count())
	var start := graph.zone_at(from_pos, surfaces.under(from_pos, 0.1))
	cost[start] = 0.0
	arrived[start] = from_pos
	while true:
		var zone := -1
		for index in graph.zone_count():
			if done[index] == 0 and cost[index] < INF and (zone == -1 or cost[index] < cost[zone]):
				zone = index
		if zone == -1:
			return cost
		done[zone] = 1
		for portal: WalkGraph.Portal in graph.portals():
			var other := portal.to_zone
			if portal.from_zone != zone or done[other] == 1:
				continue
			if graph.flooded(other, pose) or graph.doomed(other, pose):
				continue
			if surfaces.wet(portal.entry, pose) or surfaces.wet(portal.exit, pose):
				continue
			var through := (
				cost[zone]
				+ arrived[zone].distance_to(portal.entry)
				+ portal.entry.distance_to(portal.exit)
			)
			if through < cost[other]:
				cost[other] = through
				arrived[other] = portal.exit
	return cost


func test_detour_goes_round_through_the_deckhouse() -> void:
	# From the pocket forward of the deckhouse, the starboard strip lies behind the side
	# of the stair up to the boat deck: the way round is in at the deckhouse's forward
	# doorway and out at one on its starboard side — never back out the way it came.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var calm := _pose(layout, SimFixtures.calm())
	var pocket := Vector3(3.4, 0.0, 1.5)
	var strip := Vector3(1.5, 0.0, 4.2)
	var deck := graph.zone_at(pocket, surfaces.under(pocket, SimFixtures.rules().step_height))
	assert_eq(graph.zone_at(strip, surfaces.under(strip, 0.35)), deck, "one open deck")
	var legs := graph.detour(pocket, surfaces.under(pocket, 0.35), strip, calm)
	assert_gt(legs.size(), 1, "a way round")
	if legs.size() < 2:
		return
	assert_eq(legs[0].from_zone, deck, "out of the deck")
	assert_eq(legs[0].to_zone, _room(layout, &"saloon"), "into the saloon")
	assert_eq(legs[-1].to_zone, deck, "back onto the deck")
	assert_gt(legs[-1].exit.z, 3.0, "by a starboard doorway")
	for leg: WalkGraph.Portal in legs:
		assert_eq(leg.ramp, WalkGraph.NONE, "through doorways only")


func test_one_search_finds_the_cheapest_routes_and_the_high_ground() -> void:
	# One search a think: from it, every route and the highest zone are what a search
	# per question used to give, and its costs are a plain Dijkstra's — dry, and with the
	# lower deck flooding.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var flooding := _pose(layout, SimFixtures.scenario([[0.0, layout.freeboard - 2.0, 4.0, 0.0]]))
	for pose: ShipPose in [_pose(layout, SimFixtures.calm()), flooding]:
		for start: Vector3 in [
			Vector3(-10.5, 0.0, 2.5), Vector3(-2.0, -2.6, -3.5), Vector3(-17.0, 1.2, 0.0)
		]:
			var on := surfaces.under(start, 0.1)
			var found := graph.search(start, on, pose)
			var reference := _reference_costs(graph, surfaces, start, pose)
			for zone in graph.zone_count():
				assert_almost_eq(
					found.cost[zone], reference[zone], 0.0001, "%s to %d" % [start, zone]
				)
				assert_eq(
					graph.route_in(found, zone),
					graph.route(start, on, zone, pose),
					"route %d" % zone
				)
			assert_eq(graph.highest_in(found, pose), graph.highest_reachable(start, on, pose))


func test_flood_answers_are_worked_out_afresh_for_each_pose() -> void:
	# The graph keeps what a pose says of its zones for as long as it is asked about that
	# pose: the next pose is never answered from the last one.
	var layout := _two_way_layout()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var bow_perch := graph.deck_of(SimFixtures.platform_named(layout, &"bow perch"))
	var calm := _pose(layout, SimFixtures.calm())
	var by_the_head := _pose(layout, SimFixtures.scenario([[0.0, 0.0, 10.0, 0.0]]))
	for round in 2:
		assert_false(graph.flooded(bow_perch, calm), "calm, round %d" % round)
		assert_true(graph.flooded(bow_perch, by_the_head), "by the head, round %d" % round)
		assert_gt(graph.world_height(bow_perch, calm), graph.world_height(bow_perch, by_the_head))
		assert_gt(
			graph.lowest_above_water(bow_perch, calm),
			graph.lowest_above_water(bow_perch, by_the_head)
		)


func test_no_zones_meet_within_jump_height_so_bots_never_jump() -> void:
	# A hop would be a portal between two zones whose platforms meet at an edge too high
	# to step and low enough to jump: the steamer has none — its hatch is a perch inside
	# one zone — so the graph has no hop to offer, and bots never press jump.
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var graph := _graph(layout, Surfaces.new(layout))
	for first in layout.platforms.size():
		for second in layout.platforms.size():
			var a := layout.platforms[first]
			var b := layout.platforms[second]
			var rise := b.height - a.height
			if rise <= rules.step_height or rise > rules.jump_height:
				continue
			if graph.deck_of(first) == graph.deck_of(second):
				continue
			assert_false(
				a.area.grow(0.001).intersects(b.area), "%s meets %s a hop up" % [a.name, b.name]
			)
	var config := SimFixtures.config(8, load(SimFixtures.STEAMER_SINKING), 1701, layout)
	var runner := MatchRunner.new(
		MatchSim.create(config), BotInputSource.fill(config, load(SimFixtures.NORMAL_BOT))
	)
	runner.run(20 * Ticks.RATE)
	for tick in range(runner.input_log.first_tick, runner.input_log.last_tick() + 1):
		for seat in config.seats:
			if runner.input_log.frame(tick, seat).is_held(InputFrame.JUMP):
				fail_test("seat %d jumped at tick %d" % [seat, tick])
				return
