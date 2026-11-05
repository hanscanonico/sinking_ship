extends GutTest
## The Titanic's docking bridge (#381), as Plate IV draws it right aft: a deck over her poop,
## across her out to its sides and widened forward about her centre line, on stanchions,
## railed round, its wheel stand on her centre line; a body climbs its ladder up from the
## poop, no steeper than it walks, and the bots' walk graph finds the way up it.

const POOP := 3.3125
## Its deck over the poop's (est., Plate III's elevation).
const BRIDGE := POOP + 2.625
const BRIDGE_NAME := &"docking bridge"

var _layout: ShipLayout


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")


## Her docking bridge's platforms, by index.
func _bridge() -> Array[int]:
	var found: Array[int] = []
	for index in _layout.platforms.size():
		if _layout.platforms[index].name == BRIDGE_NAME:
			found.append(index)
	return found


## Whether [param point] in the ship plane stands over a platform called [param named].
func _over(point: Vector2, named: StringName) -> bool:
	for platform: ShipPlatform in _layout.platforms:
		if platform.name == named and platform.area.grow(0.001).has_point(point):
			return true
	return false


## The ramp up from the poop to her docking bridge, or null.
func _ladder() -> ShipRamp:
	for ramp: ShipRamp in _layout.ramps:
		if is_equal_approx(ramp.start_height, POOP) and is_equal_approx(ramp.end_height, BRIDGE):
			return ramp
	return null


func test_her_docking_bridge_stands_over_the_poop_on_stanchions() -> void:
	var bridge := _bridge()
	assert_eq(bridge.size(), 2, "across her, and widened forward")
	for index in bridge:
		var deck := _layout.platforms[index]
		assert_almost_eq(deck.height, BRIDGE, 0.0001, "its deck's height")
		var area := deck.area
		for corner: Vector2 in [area.position, area.end, Vector2(area.position.x, area.end.y)]:
			assert_true(_over(corner, &"poop deck"), "%s over the poop" % corner)
	var stanchions := 0
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.name != &"stanchion":
			continue
		stanchions += 1
		assert_almost_eq(blocker.bottom, POOP, 0.0001, "from the poop")
		assert_almost_eq(blocker.top, BRIDGE, 0.0001, "up to its deck")
		var inside := false
		for index in bridge:
			var area := _layout.platforms[index].area
			inside = inside or area.grow(-blocker.radius + 0.001).has_point(blocker.centre)
		assert_true(inside, "the stanchion at %s under its deck" % blocker.centre)
	assert_gt(stanchions, 3, "at its corners at least")


func test_its_wheel_stand_stands_on_its_deck_on_her_centre_line() -> void:
	var stands := _layout.blockers.filter(
		func(blocker: ShipBlocker) -> bool: return blocker.name == &"wheel stand"
	)
	assert_eq(stands.size(), 1)
	if stands.is_empty():
		return
	var stand: ShipBlocker = stands[0]
	assert_almost_eq(stand.bottom, BRIDGE, 0.0001, "on the bridge's deck")
	assert_almost_eq(stand.area.get_center().y, 0.0, 0.0001, "on her centre line")
	var rules := SimFixtures.rules()
	for corner: Vector2 in [stand.area.position, stand.area.end]:
		assert_true(_over(corner, BRIDGE_NAME), "%s on the bridge" % corner)
	# A body passes it fore and aft.
	for index in _bridge():
		var area := _layout.platforms[index].area
		if area.intersects(stand.area):
			var room := maxf(stand.area.position.x - area.position.x, area.end.x - stand.area.end.x)
			assert_gt(room, 2.0 * rules.body_radius, "a body's way past it")


func test_its_ladder_climbs_from_the_poop_to_its_deck_no_steeper_than_a_body_walks() -> void:
	var ladder := _ladder()
	assert_not_null(ladder, "the ladder up from the poop")
	if ladder == null:
		return
	var rules := SimFixtures.rules()
	var run := ladder.area.size.x
	assert_lte((BRIDGE - POOP) / run, rules.step_height / rules.body_radius, "a body climbs it")
	var foot := Vector2(ladder.area.position.x, ladder.area.get_center().y)
	var head := Vector2(ladder.area.end.x, ladder.area.get_center().y)
	assert_true(_over(foot - Vector2(0.01, 0.0), &"poop deck"), "its foot on the poop")
	assert_true(_over(head + Vector2(0.01, 0.0), BRIDGE_NAME), "its head at the bridge")
	assert_gt(ladder.area.get_center().y, 0.0, "to starboard of her centre line")
	assert_eq(_layout.problems(_layout.min_seats), PackedStringArray(), "she lints clean")


func test_a_body_walks_up_onto_the_docking_bridge_from_the_poop() -> void:
	var surfaces := Surfaces.new(_layout)
	var rules := SimFixtures.rules()
	var graph := WalkGraph.new(_layout, surfaces, rules)
	var goal := graph.deck_of(_bridge()[0])
	var dry := HeldPose.flooded(_layout, -_layout.freeboard, {})
	var sim := SimFixtures.sim(2, null, _layout)
	# Forward on the poop, on her centre line, where her well deck's stairs bring a body up.
	SimFixtures.place(sim, 0, Vector3(-118.0, POOP, 0.0))
	SimFixtures.place(sim, 1, Vector3(-115.0, POOP, -3.0))
	HeldPose.hold(sim, dry)
	var calm := sim.pose()
	var walker := sim.state.seats[0]
	for _tick in Ticks.from_seconds(30.0):
		walker = sim.state.seats[0]
		if (
			graph.zone_at(walker.pos, walker.surface) == goal
			and not surfaces.is_ramp(walker.surface)
		):
			break
		var toward := graph.steer(walker.pos, walker.surface, goal, calm)
		var move := Vector2.ZERO
		if not toward.is_empty():
			move = Vector2(toward[0].x - walker.pos.x, toward[0].z - walker.pos.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	assert_eq(SimFixtures.name_of(_layout, walker.surface), BRIDGE_NAME, "up on the bridge")
	assert_almost_eq(walker.pos.y, BRIDGE, 0.05, "on its deck")
