extends GutTest
## The steamer's old voids made places (#148): from every space fitted into them the
## bots' walk graph finds a way up to her main deck, and a body crawls up out of her
## double bottom through a manhole and walks on up on deck; once a space's floor is
## under, no route goes down into it; her deck area, by which the bots read how much
## of her is under, is her decks'; and a body walks down every stair into them, ducking
## under the deck its hatch is cut in, and back up every one onto the deck at its head.

## Each space by name, and a point on its floor clear of its stairs and hatches.
const SPACES := {
	&"port double bottom": Vector3(3.0, -5.3125, -1.5),
	&"starboard double bottom": Vector3(3.0, -5.3125, 1.5),
	&"lower hold": Vector3(9.0, -5.3125, 0.0),
	&"shaft tunnel": Vector3(-8.0, -5.3125, -1.5),
	&"stores": Vector3(-8.0, -5.3125, 1.5),
	&"port side passage": Vector3(5.4, -1.0, -4.35),
	&"starboard side passage": Vector3(5.4, -1.0, 4.35),
	&"steering gear": Vector3(-19.0, -1.0, 0.0),
	&"aft stores": Vector3(-13.5, -3.1, -2.0),
	&"lower aft stores": Vector3(-13.5, -5.2, 0.0),
	&"bosun's store": Vector3(19.3, -1.5, 0.0),
	&"chain locker": Vector3(15.5, -4.5, 0.0),
}


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


func test_every_old_void_has_a_way_up_to_the_main_deck() -> void:
	# Level and dry inside her, as the physics has her before the hit.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var step := SimFixtures.rules().step_height
	var main_deck := graph.deck_of(SimFixtures.platform_named(layout, &"main deck"))
	var dry := HeldPose.flooded(layout, -layout.freeboard, {})
	for space: StringName in SPACES:
		var start: Vector3 = SPACES[space]
		var on := surfaces.under(start, step)
		assert_ne(_room(layout, space), WalkGraph.NONE, "%s is one of her rooms" % space)
		assert_eq(graph.zone_at(start, on), _room(layout, space), "it starts in the %s" % space)
		var route := graph.route(start, on, main_deck, dry)
		assert_false(route.is_empty(), "a way up out of the %s" % space)
		if not route.is_empty():
			assert_eq(route.back().to_zone, main_deck, "from the %s to the main deck" % space)


func test_a_body_crawls_out_of_the_double_bottom_and_none_goes_into_it_flooded() -> void:
	# Out from under her tank top on hands and knees, up through a manhole, and on up
	# through her stokehold to her main deck.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var step := SimFixtures.rules().step_height
	var double_bottom := _room(layout, &"port double bottom")
	var main_deck := graph.deck_of(SimFixtures.platform_named(layout, &"main deck"))
	var dry := HeldPose.flooded(layout, -layout.freeboard, {})
	var start: Vector3 = SPACES[&"port double bottom"]
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, start)
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 3.0))
	HeldPose.hold(sim, dry)
	var walked := _walk(sim, graph, main_deck, 40.0)
	var passed: Array[int] = walked[0]
	assert_eq(passed.front(), double_bottom)
	assert_true(walked[1], "it crawled under her tank top")
	assert_eq(passed.back(), main_deck, "crawled out of it and walked up on deck")

	var stokehold := Vector3(-1.5, -4.4, 0.0)
	var on := surfaces.under(stokehold, step)
	assert_false(graph.route(stokehold, on, double_bottom, dry).is_empty(), "down into it, dry")
	var flooded := HeldPose.flooded(layout, -layout.freeboard, {&"engine_bilge_p": [-4.9]})
	assert_true(graph.flooded(double_bottom, flooded), "its floor under")
	assert_true(graph.route(stokehold, on, double_bottom, flooded).is_empty(), "never flooded")


func test_her_deck_area_is_her_decks_not_the_floors_fitted_in_her_voids() -> void:
	# How much of her is under (BotFooting.flooded_share) reads as it did before: a floor
	# fitted in her old voids, under her waterline, is no part of her deck area.
	var layout := SimFixtures.steamer()
	var graph := _graph(layout, Surfaces.new(layout))
	var fitted := 0
	for platform in layout.platforms.size():
		var deck := layout.platforms[platform]
		if deck.fitted:
			fitted += 1
			assert_eq(graph.platform_area(platform), 0.0, "%s: no deck area" % deck.name)
		else:
			assert_eq(graph.platform_area(platform), deck.area.get_area(), "%s" % deck.name)
	assert_gt(fitted, 0, "she has floors fitted in her old voids")


## Seat 0 of the calm, dry steamer [param layout], set down on the deck 0.6 m short of
## [param from] and walked straight on through to [param to] and [param beyond] past it,
## for up to four seconds: whether it came to stand there off the stair at [param to]'s
## height, and whether it crawled.
func _walk_stair(layout: ShipLayout, from: Vector3, to: Vector3, beyond := 0.0) -> Array:
	var rules := SimFixtures.rules()
	var heading := Vector2(to.x - from.x, to.z - from.z).normalized()
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, from - Vector3(heading.x, 0.0, heading.y) * 0.6)
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 3.0))
	HeldPose.hold(sim, HeldPose.flooded(layout, -layout.freeboard, {}))
	var walker := sim.state.seats[0]
	var crawled := false
	for _tick in Ticks.from_seconds(4.0):
		SimFixtures.step(sim, {0: SimFixtures.frame(0, heading)})
		crawled = crawled or rules.height_at(sim.surfaces, walker.pos) < rules.body_height
		var off := walker.surface != Surfaces.NONE and not sim.surfaces.is_ramp(walker.surface)
		var past := Vector2(walker.pos.x - to.x, walker.pos.z - to.z).dot(heading)
		if off and is_equal_approx(walker.pos.y, to.y) and past >= beyond:
			return [true, crawled]
	return [false, crawled]


func test_a_body_walks_down_every_stair_into_her_old_voids_and_back_up() -> void:
	# Past a hatch's far edge the deck it is cut in is too low to stand under: going
	# down, a body ducks under that edge as its stair goes on down under it, crawling on
	# into a crawl space; coming up, it steps off a ladder's 45° pitch onto the deck at
	# its head, or onto a bulkhead's top flush with that deck.
	var layout := SimFixtures.steamer()
	var step := SimFixtures.rules().step_height
	var stairs := 0
	for index in layout.ramps.size():
		var ramp := layout.ramps[index]
		if not ramp.fitted:
			continue
		stairs += 1
		var head := ramp.end_point(0 if ramp.start_height > ramp.end_height else 1)
		var foot := ramp.end_point(1 if ramp.start_height > ramp.end_height else 0)
		var crawl_space := false
		for room: ShipRoom in layout.rooms:
			crawl_space = crawl_space or room.crawl_space and room.holds(foot, step)
		# Into a crawl space, on in under the deck past its hatch.
		var down := _walk_stair(layout, head, foot, 0.3 if crawl_space else 0.0)
		assert_true(down[0], "down stair %d from %.2f to %.2f" % [index, head.y, foot.y])
		assert_eq(down[1], crawl_space, "stair %d: crawled only into a crawl space" % index)
		assert_true(_walk_stair(layout, foot, head)[0], "up stair %d onto %.2f" % [index, head.y])
	assert_eq(stairs, 24, "every stair into her old voids")
