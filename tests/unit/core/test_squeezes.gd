extends GutTest
## A body goes only where it fits (#591). Blockers and railings each hold it in turn in
## every pass of a tick's contacts, from where the last left it, so in a gap narrower than a
## body between two of them each pushed it back into the other, and the one met last had the
## say: the body walked on through the gap pressed into the other. On the Titanic's C deck a
## body walked the 0.72 m strip between a partition and the railing beside a stair's head,
## 0.08 m into the partition all the way; on E deck it walked into the 0.595 m pocket
## between ramp 38's solid side and a wall, 0.205 m into the stair. A body its contacts
## leave pressed into less room than its width by more than it gives (body_give) goes back
## to where its step began and stops there (Movement._unsqueeze): it stands at the gap's
## mouth, never in it, and never pressed into either. A gap no narrower than its give allows
## it still squeezes through, as down the narrowest flights on her plates, 0.75 m wide.

## C deck's strip drawn small: east of x 0 the deck a body walks in from; west of it the
## strip's floor, its railing along z STRIP from x -4 to 0 beside a stair's well, and a
## partition along its other side, z -0.06 to 0, its end JUT east of the railing's.
const STRIP := 0.72
const JUT := 0.03
## E deck's pocket drawn small: a stair up along -z from its foot at z 0, x -1 to 0, over
## the deck, and a wall POCKET east of its side.
const POCKET := 0.595
const RISE := 2.75
## Ramp 53's well drawn small: a stair down along x from its head at x 0 to its foot at x 3,
## FLIGHT wide between the walls along its sides.
const FLIGHT := 0.75
## How far into a wall a body held against it may read, in metres: what its position rounds
## to, and no more.
const PRESSED := 0.001


func test_a_body_never_squeezes_between_a_railing_and_a_wall() -> void:
	var rules := SimFixtures.rules()
	for z: float in [0.32, 0.36, 0.4]:
		var sim := _sim(_strip())
		SimFixtures.place(sim, 0, Vector3(1.2, 0.0, z))
		var player := sim.state.seats[0]
		for tick in 2 * Ticks.RATE:
			SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.LEFT)})
			var at := "from z %s, tick %d at %s" % [z, tick, player.pos]
			_assert_clear(sim, rules, at)
			assert_gte(player.pos.x, 0.0, "%s: never in the strip" % at)
		assert_eq(player.body, PlayerState.Body.GROUNDED, "from z %s: on its feet" % z)
		assert_eq(player.surface, 0, "from z %s: on the deck at the strip's mouth" % z)


func test_a_body_never_squeezes_between_a_stairs_side_and_a_wall() -> void:
	var rules := SimFixtures.rules()
	for x: float in [0.11, 0.2, 0.3]:
		var sim := _sim(_pocket())
		SimFixtures.place(sim, 0, Vector3(x, 0.0, 0.25))
		var player := sim.state.seats[0]
		var deepest := 0.0
		for tick in 2 * Ticks.RATE:
			SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.UP)})
			_assert_clear(sim, rules, "from x %s, tick %d at %s" % [x, tick, player.pos])
			deepest = minf(deepest, player.pos.z)
		assert_eq(player.body, PlayerState.Body.GROUNDED, "from x %s: on its feet" % x)
		assert_eq(player.surface, 0, "from x %s: on the deck" % x)
		# The stair's solid side stands a step over the deck where its height does.
		var mouth := -rules.step_height / RISE * 3.25
		assert_gt(deepest, mouth, "from x %s: never past the pocket's mouth" % x)


func test_a_body_squeezes_down_a_flight_as_narrow_as_her_narrowest() -> void:
	# Ramp 53 on her E deck drawn small (_flight): 0.75 m between the walls of its well, a
	# body 0.8 m wide, pressed into both, walks down it from the deck at its head to the deck
	# at its foot, and back up — as on main, and as her crew did.
	var rules := SimFixtures.rules()
	assert_gt(rules.body_give, rules.body_radius * 2.0 - FLIGHT, "a body gives that much")
	var sim := _sim(_flight())
	SimFixtures.place(sim, 0, Vector3(-1.0, 0.0, 0.0))
	var player := sim.state.seats[0]
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE * 3 / 2)
	assert_eq(player.surface, 1, "down at its foot: %s" % player.pos)
	assert_gt(player.pos.x, 3.0 + rules.body_radius, "off its foot")
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.LEFT)}, 2 * Ticks.RATE)
	assert_eq(player.surface, 0, "back up at its head: %s" % player.pos)
	assert_lt(player.pos.x, -rules.body_radius, "off its head")


## Asserts that seat 0 of [param sim] is pressed into no blocker and no railing by more
## than PRESSED, [param at] naming where.
func _assert_clear(sim: MatchSim, rules: BrawlRules, at: String) -> void:
	var player := sim.state.seats[0]
	var held := sim.surfaces.obstacle_contacts(
		player.pos,
		rules.body_radius,
		rules.body_height,
		rules.step_height,
		Surfaces.NONE,
		rules.crawl_height
	)
	held.append_array(
		sim.surfaces.rail_contacts(
			player.pos, rules.body_radius, player.surface, rules.step_height, rules.railing_height
		)
	)
	var deepest := 0.0
	for contact: Surfaces.Contact in held:
		deepest = maxf(deepest, contact.depth)
	assert_lte(deepest, PRESSED, "%s: pressed %.3f m in" % [at, deepest])


## A sim of [param layout] with one seat, calm.
func _sim(layout: ShipLayout) -> MatchSim:
	return MatchSim.create(MatchConfig.new(1, 1, SimFixtures.rules(), layout, SimFixtures.calm()))


## C deck's strip drawn small (STRIP): platform 0 the deck east of x 0, platform 1 the
## strip's floor west of it, out to the railing.
func _strip() -> ShipLayout:
	var layout := _layout(
		[Rect2(0.0, -3.0, 4.0, 6.0), Rect2(-4.0, -3.0, 4.0, 3.0 + STRIP)],
		[0.0, 0.0],
		[Rect2(-4.0, -0.06, 4.0 + JUT, 0.06)]
	)
	var railing := ShipRailing.new()
	railing.platform = 1
	railing.from = Vector2(-4.0, STRIP)
	railing.to = Vector2(0.0, STRIP)
	var railings: Array[ShipRailing] = [railing]
	layout.railings = railings
	return layout


## E deck's pocket drawn small (POCKET): platform 0 the deck, the stair over it from its
## foot at z 0 up to platform 1 at its head, and the wall.
func _pocket() -> ShipLayout:
	var layout := _layout(
		[Rect2(-2.0, -4.0, 5.0, 7.0), Rect2(-1.0, -5.0, 1.0, 1.75)],
		[0.0, RISE],
		[Rect2(POCKET, -4.0, 0.06, 4.5)]
	)
	var ramp := ShipRamp.new()
	ramp.area = Rect2(-1.0, -3.25, 1.0, 3.25)
	ramp.axis = ShipRamp.Axis.Z
	ramp.start_height = RISE
	ramp.end_height = 0.0
	var ramps: Array[ShipRamp] = [ramp]
	layout.ramps = ramps
	return layout


## Ramp 53's well drawn small (FLIGHT): platform 0 the deck at its head, west of x 0;
## platform 1 the deck at its foot, a storey down, east of x 3; and the well's walls, from
## the lower deck up past the upper.
func _flight() -> ShipLayout:
	var layout := _layout(
		[Rect2(-5.0, -2.0, 5.0, 4.0), Rect2(3.0, -2.0, 7.0, 4.0)], [0.0, -RISE], []
	)
	var ramp := ShipRamp.new()
	ramp.area = Rect2(0.0, -FLIGHT * 0.5, 3.0, FLIGHT)
	ramp.axis = ShipRamp.Axis.X
	ramp.start_height = 0.0
	ramp.end_height = -RISE
	var ramps: Array[ShipRamp] = [ramp]
	layout.ramps = ramps
	var blockers: Array[ShipBlocker] = []
	for z: float in [-FLIGHT * 0.5 - 0.06, FLIGHT * 0.5]:
		var wall := ShipBlocker.new()
		wall.shape = ShipBlocker.Shape.BOX
		wall.area = Rect2(0.0, z, 3.0, 0.06)
		wall.bottom = -RISE
		wall.top = RISE
		blockers.append(wall)
	layout.blockers = blockers
	return layout


## A layout of the platforms over [param areas] at [param heights], and box blockers over
## [param walls] from the first platform's height up a storey.
func _layout(areas: Array[Rect2], heights: Array[float], walls: Array[Rect2]) -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for index in areas.size():
		var platform := ShipPlatform.new()
		platform.area = areas[index]
		platform.height = heights[index]
		platforms.append(platform)
	layout.platforms = platforms
	var blockers: Array[ShipBlocker] = []
	for area: Rect2 in walls:
		var wall := ShipBlocker.new()
		wall.shape = ShipBlocker.Shape.BOX
		wall.area = area
		wall.bottom = heights[0]
		wall.top = heights[0] + RISE
		blockers.append(wall)
	layout.blockers = blockers
	layout.spawns = [Vector3(2.0, 0.0, 2.0)]
	return layout
