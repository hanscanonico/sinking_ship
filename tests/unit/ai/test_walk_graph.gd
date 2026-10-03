extends GutTest
## The bots' walk graph: platforms are nodes, ramps are edges, flooded platforms are
## never on a route.


func _graph(layout: ShipLayout, surfaces: Surfaces) -> WalkGraph:
	return WalkGraph.new(layout, surfaces, SimFixtures.rules().body_radius)


func _pose(layout: ShipLayout, scenario: SinkScenario) -> ShipPose:
	return SinkSchedule.new(scenario, layout.freeboard, SeedStreams.derive(1, "sink")).pose_at(0)


## The platforms a route arrives on, in order.
func _platforms_on(route: Array[Vector2i], surfaces: Surfaces) -> Array[int]:
	var visited: Array[int] = []
	for leg: Vector2i in route:
		visited.append(surfaces.joins(surfaces.ramp_surface(leg.x))[leg.y])
	return visited


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
	var main_deck := SimFixtures.platform_named(layout, &"main deck")
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var calm := _pose(layout, SimFixtures.calm())
	var start := Vector3(-10.5, 0.0, 2.5)
	var route := graph.route(start, main_deck, bridge, calm)
	assert_eq(
		_platforms_on(route, surfaces), [boat_deck, bridge], "up to the boat deck, then on up"
	)
	assert_true(graph.route(start, bridge, bridge, calm).is_empty(), "already there")

	# Walked in the sim, one steer point at a time from the foredeck, where nothing
	# stands between it and the first ramp, the route gets a body there.
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(10.5, 0.0, 3.0))
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 0.0))
	for _tick in 20 * Ticks.RATE:
		var walker := sim.state.seats[0]
		if walker.surface == bridge:
			break
		var toward := graph.steer(walker.pos, walker.surface, bridge, calm)
		var move := Vector2.ZERO
		if not toward.is_empty():
			move = Vector2(toward[0].x - walker.pos.x, toward[0].z - walker.pos.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	assert_eq(sim.state.seats[0].surface, bridge, "the walk reached the bridge")
	assert_almost_eq(sim.state.seats[0].pos.y, layout.platforms[bridge].height, 0.0001)


func test_path_avoids_a_ramp_whose_foot_is_under() -> void:
	var layout := SimFixtures.steamer()
	var main_deck := SimFixtures.platform_named(layout, &"main deck")
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	var poop_deck := SimFixtures.platform_named(layout, &"poop deck")
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	# Down by the head far enough that the sea stands over the feet of the ramps up
	# to the boat deck, while the middles of the main deck and the boat deck are dry.
	var by_the_head := _pose(layout, SimFixtures.scenario([[0.0, 0.2, 8.0, 0.0]]))
	assert_false(surfaces.flooded(main_deck, by_the_head))
	assert_false(surfaces.flooded(boat_deck, by_the_head))
	var feet := 0
	for ramp in layout.ramps.size():
		var joined := surfaces.joins(surfaces.ramp_surface(ramp))
		if boat_deck in joined and main_deck in joined:
			feet += 1
			var foot := layout.ramps[ramp].end_point(joined.find(main_deck))
			assert_true(surfaces.wet(foot, by_the_head), "ramp %d's foot is under" % ramp)
	assert_gt(feet, 0)

	var abaft := Vector3(-10.5, 0.0, 2.5)
	assert_true(graph.route(abaft, main_deck, boat_deck, by_the_head).is_empty(), "no way up")
	assert_eq(
		graph.highest_reachable(abaft, main_deck, by_the_head),
		poop_deck,
		"the high ground it can still reach"
	)


func test_path_avoids_flooded_platforms() -> void:
	var layout := _two_way_layout()
	var ground := SimFixtures.platform_named(layout, &"ground")
	var bow_perch := SimFixtures.platform_named(layout, &"bow perch")
	var stern_perch := SimFixtures.platform_named(layout, &"stern perch")
	var top := SimFixtures.platform_named(layout, &"top")
	var surfaces := Surfaces.new(layout)
	assert_eq(layout.problems(1).size(), 1, "only the missing spawn is wrong with it")
	var graph := _graph(layout, surfaces)
	var calm := _pose(layout, SimFixtures.calm())
	# Down by the head and level otherwise: the bow perch is under at its middle,
	# the stern perch and the top are not.
	var by_the_head := _pose(layout, SimFixtures.scenario([[0.0, 0.0, 10.0, 0.0]]))
	assert_true(surfaces.flooded(bow_perch, by_the_head))
	assert_false(surfaces.flooded(stern_perch, by_the_head))
	assert_false(surfaces.flooded(top, by_the_head))

	var forward := Vector3(12.0, 0.0, 5.5)
	var dry := _platforms_on(graph.route(forward, ground, top, calm), surfaces)
	assert_eq(dry, [bow_perch, top], "dry: the short way, by the bow")
	var flooded := _platforms_on(graph.route(forward, ground, top, by_the_head), surfaces)
	assert_eq(flooded, [stern_perch, top], "flooded: round by the stern")
	assert_true(graph.route(forward, ground, bow_perch, by_the_head).is_empty(), "never onto it")
