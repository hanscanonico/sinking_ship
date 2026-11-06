extends GutTest
## The Titanic's docking bridge (#381), as Plate IV draws it right aft: a deck over her poop,
## across her out to its sides and widened forward about her centre line, on stanchions,
## railed round, its wheel stand on her centre line; a body climbs either of its ladders
## up from the poop — the plate's to starboard, its mirror to port (est.) —, no steeper than
## it walks, and a normal bot goes up by either, from aft of its foot as from forward; an
## easy bot too, most times, holding each ladder's middle (BotStair, #447).

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


## The ramps up from the poop to her docking bridge.
func _ladders() -> Array[ShipRamp]:
	var found: Array[ShipRamp] = []
	for ramp: ShipRamp in _layout.ramps:
		if is_equal_approx(ramp.start_height, POOP) and is_equal_approx(ramp.end_height, BRIDGE):
			found.append(ramp)
	return found


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


func test_its_ladders_climb_from_the_poop_to_its_deck_no_steeper_than_a_body_walks() -> void:
	var ladders := _ladders()
	assert_eq(ladders.size(), 2, "its ladders up from the poop, to starboard and to port")
	if ladders.size() != 2:
		return
	var rules := SimFixtures.rules()
	for ladder in ladders:
		var side := "the ladder at %s" % ladder.area.get_center()
		var run := ladder.area.size.x
		var slope := (BRIDGE - POOP) / run
		assert_lte(slope, rules.step_height / rules.body_radius, "%s: a body climbs it" % side)
		var foot := Vector2(ladder.area.position.x, ladder.area.get_center().y)
		var head := Vector2(ladder.area.end.x, ladder.area.get_center().y)
		assert_true(
			_over(foot - Vector2(0.01, 0.0), &"poop deck"), "%s: its foot on the poop" % side
		)
		assert_true(
			_over(head + Vector2(0.01, 0.0), BRIDGE_NAME), "%s: its head at the bridge" % side
		)
	var starboard := ladders[0] if ladders[0].area.get_center().y > 0.0 else ladders[1]
	var port := ladders[1] if starboard == ladders[0] else ladders[0]
	assert_gt(starboard.area.get_center().y, 0.0, "the plate's to starboard of her centre line")
	var mirrored := Rect2(Vector2(port.area.position.x, -port.area.end.y), port.area.size)
	assert_true(mirrored.is_equal_approx(starboard.area), "the port one its mirror across her")
	assert_eq(_layout.problems(_layout.min_seats), PackedStringArray(), "she lints clean")


## A normal bot on the poop climbs onto the docking bridge by either ladder, from aft of
## its foot — behind the capstan the plate draws on each ladder's line, which the bot
## turns round (BotFooting.clear_heading, #445) — as from forward; the world held dry, and
## a seat standing on the bridge to go for.
func test_a_normal_bot_climbs_either_ladder_from_aft_or_from_forward() -> void:
	var surfaces := Surfaces.new(_layout)
	var rules := SimFixtures.rules()
	var graph := WalkGraph.new(_layout, surfaces, rules)
	var goal := graph.deck_of(_bridge()[0])
	var middle := _layout.platforms[_bridge()[0]].area.get_center()
	var climbed := {}
	# Aft of each ladder's foot on its line, and forward on the poop to either side.
	for start: Vector3 in [
		Vector3(-134.0, POOP, 4.125),
		Vector3(-134.0, POOP, -4.25),
		Vector3(-118.0, POOP, 3.0),
		Vector3(-118.0, POOP, -3.0),
	]:
		var sim := SimFixtures.sim(2, null, _layout)
		SimFixtures.place(sim, 0, start)
		SimFixtures.place(sim, 1, Vector3(middle.x, BRIDGE, middle.y))
		HeldPose.hold(sim, HeldPose.flooded(_layout, -_layout.freeboard, {}))
		var sources: Array[InputSource] = [
			BotInputSource.new(0, load(SimFixtures.NORMAL_BOT), sim.config), InputSource.new()
		]
		var runner := MatchRunner.new(sim, sources)
		var ladder := -1
		var up := false
		for _tick in Ticks.from_seconds(30.0):
			runner.step()
			var bot := sim.state.seats[0]
			if surfaces.is_ramp(bot.surface):
				ladder = bot.surface - surfaces.platform_count()
			elif graph.zone_at(bot.pos, bot.surface) == goal:
				up = true
				break
		var bot := sim.state.seats[0]
		assert_true(up, "from %s: up on the bridge, not at %s" % [start, bot.pos])
		assert_almost_eq(bot.pos.y, BRIDGE, 0.05, "from %s: on its deck" % start)
		if ladder >= 0:
			climbed[signf(_layout.ramps[ladder].area.get_center().y)] = true
	assert_eq(climbed.size(), 2, "up the ladder to starboard and the one to port")


## An easy bot on the poop goes up a ladder to the docking bridge from most places aft of
## either ladder's foot and from forward: it holds the 1 m ladder's middle, rather than
## stepping off its open side near its head, round and round (#447). The world held dry.
func test_an_easy_bot_climbs_a_ladder_from_most_starts() -> void:
	var surfaces := Surfaces.new(_layout)
	var rules := SimFixtures.rules()
	var graph := WalkGraph.new(_layout, surfaces, rules)
	var goal := graph.deck_of(_bridge()[0])
	var middle := _layout.platforms[_bridge()[0]].area.get_center()
	var starts: Array[Vector3] = [Vector3(-118.0, POOP, 0.0)]
	for x: float in [-132.4, -134.0, -136.0]:
		for z: float in [3.0, 4.125, 5.2]:
			starts.append(Vector3(x, POOP, z))
			starts.append(Vector3(x, POOP, -z))
	var up := 0
	var stuck := PackedStringArray()
	for start in starts:
		var sim := SimFixtures.sim(2, null, _layout)
		SimFixtures.place(sim, 0, start)
		SimFixtures.place(sim, 1, Vector3(middle.x, BRIDGE, middle.y))
		HeldPose.hold(sim, HeldPose.flooded(_layout, -_layout.freeboard, {}))
		var sources: Array[InputSource] = [
			BotInputSource.new(0, BotProfile.for_tier(&"easy"), sim.config), InputSource.new()
		]
		var runner := MatchRunner.new(sim, sources)
		var there := false
		for _tick in Ticks.from_seconds(30.0):
			runner.step()
			var bot := sim.state.seats[0]
			if not surfaces.is_ramp(bot.surface) and graph.zone_at(bot.pos, bot.surface) == goal:
				there = true
				break
		if there:
			up += 1
		else:
			stuck.append("%s" % start)
	assert_gte(
		up, ceili(starts.size() * 0.75), "up from most starts; not from %s" % ", ".join(stuck)
	)
