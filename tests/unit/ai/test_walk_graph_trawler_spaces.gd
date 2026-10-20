extends GutTest
## The trawler's old voids made places (#148): from every space fitted into them the
## bots' walk graph finds a way up to her working deck, and a body crawls up out of her
## fish hold's double bottom through a manhole and walks on up on deck; once a space's
## floor is under, no route goes down into it.

## Each space by name, and a point on its floor clear of its stairs and hatches.
const SPACES := {
	&"engine room double bottom": Vector3(-9.0, -3.5, 0.0),
	&"fish hold double bottom": Vector3(2.0, -3.5, 0.0),
	&"steering gear": Vector3(-12.0, -2.2, -1.0),
	&"fore stores": Vector3(8.5, -2.2, 1.0),
	&"port side passage": Vector3(1.0, -1.875, -2.8),
	&"starboard side passage": Vector3(1.0, -1.875, 2.8),
}


func _trawler() -> ShipLayout:
	return Fleet.layout(&"trawler")


func _graph(layout: ShipLayout, surfaces: Surfaces) -> WalkGraph:
	return WalkGraph.new(layout, surfaces, SimFixtures.rules())


func _room(layout: ShipLayout, room_name: StringName) -> int:
	for index in layout.rooms.size():
		if layout.rooms[index].name == room_name:
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


func test_every_old_void_has_a_way_up_to_the_working_deck() -> void:
	# Level and dry inside her, as the physics has her before the hit.
	var layout := _trawler()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var step := SimFixtures.rules().step_height
	var deck := graph.deck_of(SimFixtures.platform_named(layout, &"working deck"))
	var dry := HeldPose.flooded(layout, -layout.freeboard, {})
	for space: StringName in SPACES:
		var start: Vector3 = SPACES[space]
		var on := surfaces.under(start, step)
		assert_ne(_room(layout, space), WalkGraph.NONE, "%s is one of her rooms" % space)
		assert_eq(graph.zone_at(start, on), _room(layout, space), "it starts in the %s" % space)
		var route := graph.route(start, on, deck, dry)
		assert_false(route.is_empty(), "a way up out of the %s" % space)
		if not route.is_empty():
			assert_eq(route.back().to_zone, deck, "from the %s to the working deck" % space)


func test_a_body_crawls_out_of_the_double_bottom_and_none_goes_into_it_flooded() -> void:
	# Out from under the fish hold's floor on hands and knees, up through a manhole, and
	# on up through her engine room and galley to her working deck.
	var layout := _trawler()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var step := SimFixtures.rules().step_height
	var double_bottom := _room(layout, &"fish hold double bottom")
	var deck := graph.deck_of(SimFixtures.platform_named(layout, &"working deck"))
	var dry := HeldPose.flooded(layout, -layout.freeboard, {})
	var start: Vector3 = SPACES[&"fish hold double bottom"]
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, start)
	SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 2.0))
	HeldPose.hold(sim, dry)
	var walked := _walk(sim, graph, deck, 60.0)
	var passed: Array[int] = walked[0]
	assert_eq(passed.front(), double_bottom)
	assert_true(walked[1], "it crawled under the fish hold's floor")
	assert_eq(passed.back(), deck, "crawled out of it and walked up on deck")

	var hold := Vector3(2.0, -2.2, -1.5)
	var on := surfaces.under(hold, step)
	assert_false(graph.route(hold, on, double_bottom, dry).is_empty(), "down into it, dry")
	var flooded := HeldPose.flooded(layout, -layout.freeboard, {&"hold_bilge": [-3.0]})
	assert_true(graph.flooded(double_bottom, flooded), "its floor under")
	assert_true(graph.route(hold, on, double_bottom, flooded).is_empty(), "never flooded")


func test_a_body_crawls_out_of_the_engine_room_double_bottom_from_its_forward_end() -> void:
	# From its forward end, where the engine room's manhole comes down, past that stair's
	# side clear of the double bottom's wall and up it or the steering gear's, on up to
	# her working deck.
	var layout := _trawler()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var double_bottom := _room(layout, &"engine room double bottom")
	var deck := graph.deck_of(SimFixtures.platform_named(layout, &"working deck"))
	var dry := HeldPose.flooded(layout, -layout.freeboard, {})
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(-3.6, -3.5, 0.6))
	SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 2.0))
	HeldPose.hold(sim, dry)
	var walked := _walk(sim, graph, deck, 90.0)
	var passed: Array[int] = walked[0]
	assert_eq(passed.front(), double_bottom)
	assert_eq(passed.back(), deck, "crawled out of it and walked up on deck")


func test_a_body_walks_up_out_of_either_side_passage() -> void:
	# From between the feet of its two stairs.
	var layout := _trawler()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var deck := graph.deck_of(SimFixtures.platform_named(layout, &"working deck"))
	var dry := HeldPose.flooded(layout, -layout.freeboard, {})
	for space: StringName in [&"port side passage", &"starboard side passage"]:
		var sim := SimFixtures.sim(2, null, layout)
		SimFixtures.place(sim, 0, SPACES[space])
		SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 2.0))
		HeldPose.hold(sim, dry)
		var passed: Array[int] = _walk(sim, graph, deck, 30.0)[0]
		assert_eq(passed.front(), _room(layout, space))
		assert_eq(passed.back(), deck, "up out of the %s" % space)
