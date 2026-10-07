extends GutTest
## Every face of the ship's boxes is a surface (§5b.3, SH32): which are floors the
## attitude decides — the axis nearest the world's up, kept through the band — and a
## body is upright to the world on whichever it stands on. One room on test data: a
## floor, the deck over it, a wall at each end, a wall to port and a wall to starboard
## with a doorway in it.

## The room's floor and the deck over it, ship-local.
const FLOOR := 0.0
const DECK := 2.5
## Where its walls' inner faces stand, and the doorway's half width in the starboard
## wall, by the bow's x.
const PORT_FACE := -2.9
const STARBOARD_FACE := 2.9
const DOOR := 0.55


## The room: platforms at FLOOR and DECK, 0.2 m walls between them.
func _room() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	layout.deck_thickness = 0.2
	layout.min_seats = 1
	layout.max_seats = 4
	for height: float in [FLOOR, DECK]:
		var platform := ShipPlatform.new()
		platform.area = Rect2(-5.0, -3.0, 10.0, 6.0)
		platform.height = height
		layout.platforms.append(platform)
	for wall: Rect2 in [
		Rect2(-5.0, PORT_FACE - 0.2, 10.0, 0.2),
		Rect2(-5.0, STARBOARD_FACE, 5.0 - DOOR, 0.2),
		Rect2(DOOR, STARBOARD_FACE, 5.0 - DOOR, 0.2),
		Rect2(-5.1, -3.0, 0.2, 6.0),
		Rect2(4.9, -3.0, 0.2, 6.0),
	]:
		var blocker := ShipBlocker.new()
		blocker.shape = ShipBlocker.Shape.BOX
		blocker.area = wall
		blocker.bottom = FLOOR
		blocker.top = DECK
		layout.blockers.append(blocker)
	layout.spawns.append(Vector3.ZERO)
	return layout


## A match of [param seats] on the room held at [param heel_deg] of list — starboard
## down — and [param trim_deg] of trim, its body placed on the floor at [param at].
func _held(heel_deg: float, at: Vector3, trim_deg: float = 0.0) -> MatchSim:
	var sim := SimFixtures.sim(1, SimFixtures.tilted(trim_deg, heel_deg), _room())
	SimFixtures.place(sim, 0, at)
	return sim


func _faces(layout: ShipLayout) -> Faces:
	return Faces.new(layout, Surfaces.new(layout), null, SimFixtures.rules().brace_holds_to, true)


func test_wall_is_a_floor_past_55_degrees_of_roll() -> void:
	var rules := SimFixtures.rules()
	var faces := _faces(_room())
	var over := SimFixtures.sim(1, SimFixtures.tilted(0.0, 54.0), _room()).pose()
	assert_eq(Faces.up_after(over, Faces.Up.DECK, rules.brace_holds_to), Faces.Up.DECK)
	var past := SimFixtures.sim(1, SimFixtures.tilted(0.0, 56.0), _room()).pose()
	assert_eq(Faces.up_after(past, Faces.Up.DECK, rules.brace_holds_to), Faces.Up.PORT)
	# Port up: the starboard wall's inner face is a floor, at its height along port's up.
	var walls := faces.surfaces(Faces.Up.PORT)
	var above := Faces.to_frame(Faces.Up.PORT) * Vector3(-2.0, 1.2, 0.0)
	var under := walls.landing(above)
	assert_ne(under, Surfaces.NONE, "something to land on")
	assert_almost_eq(walls.height_at(under, above), -STARBOARD_FACE, 1e-6, "the wall's face")
	# A body on her deck as she lies past it stands on that wall, upright to the world.
	var sim := _held(60.0, Vector3(-2.0, FLOOR, 0.0))
	SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	var body := sim.state.seats[0]
	assert_eq(sim.state.up, Faces.Up.PORT, "the match stands on her port-facing faces")
	assert_eq(body.body, PlayerState.Body.GROUNDED, "on its feet")
	assert_almost_eq(body.pos.z, STARBOARD_FACE, 1e-4, "its feet on the starboard wall")
	assert_gt(body.pos.y, FLOOR + rules.body_radius - 1e-4, "off the deck beside it")


func test_nobody_walks_between_35_and_55_degrees() -> void:
	var rules := SimFixtures.rules()
	var uphill := Vector2(0.0, -1.0)
	# Below the stand limit a body walks up the slope; in the band it cannot.
	var walking := _held(rules.stand_limit_deg - 5.0, Vector3(-2.0, FLOOR, 1.0))
	SimFixtures.step(walking, {0: SimFixtures.frame(0, uphill)}, Ticks.RATE)
	assert_lt(walking.state.seats[0].pos.z, 1.0 - 1.0, "up the slope at 30°")
	for heel: float in [rules.stand_limit_deg + 1.0, 45.0, rules.brace_holds_to - 1.0]:
		var sim := _held(heel, Vector3(-2.0, FLOOR, 1.0))
		SimFixtures.step(sim, {0: SimFixtures.frame(0, uphill)}, Ticks.RATE)
		assert_gt(sim.state.seats[0].pos.z, 1.0, "at %s° it slides however it walks" % heel)
	# Along the slope it moves: along the corner it slides into.
	var along := _held(45.0, Vector3(-4.5, FLOOR, 1.0))
	SimFixtures.step(along, {}, Ticks.RATE)
	SimFixtures.step(along, {0: SimFixtures.frame(0, Vector2(1.0, 0.0), 0, 0.0)}, Ticks.RATE / 2)
	var body := along.state.seats[0]
	assert_gt(body.pos.x, -3.5, "toward the bow")
	assert_almost_eq(body.pos.z, STARBOARD_FACE - rules.body_radius, 1e-3, "along the corner")


func test_door_in_a_floor_is_a_hole() -> void:
	var faces := _faces(_room())
	var walls := faces.surfaces(Faces.Up.PORT)
	var turn := Faces.to_frame(Faces.Up.PORT)
	# Feet on the starboard wall's face, beside the doorway and over it.
	var beside := turn * Vector3(-2.0, 1.2, STARBOARD_FACE)
	var over := turn * Vector3(0.0, 1.2, STARBOARD_FACE)
	var step := SimFixtures.rules().step_height
	assert_ne(walls.under(beside, step), Surfaces.NONE, "the wall holds a body beside it")
	assert_eq(walls.under(over, step), Surfaces.NONE, "the doorway holds none")
	# A body walking across it falls through, out of the room.
	var sim := _held(90.0, Vector3(-2.0, 1.2, 0.0))
	SimFixtures.step(sim, {}, 2 * Ticks.RATE)
	var body := sim.state.seats[0]
	assert_almost_eq(body.pos.z, STARBOARD_FACE, 1e-4, "on the wall first")
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(1.0, 0.0), 0, 0.0)}, Ticks.RATE)
	assert_gt(body.pos.z, STARBOARD_FACE + 0.5, "through the doorway, under the wall")


func test_upside_down_deck_underside_is_a_floor() -> void:
	var rules := SimFixtures.rules()
	var faces := _faces(_room())
	var undersides := faces.surfaces(Faces.Up.KEEL)
	var middle := Faces.to_frame(Faces.Up.KEEL) * Vector3(0.0, 1.2, 0.0)
	var under := undersides.landing(middle)
	assert_almost_eq(
		undersides.height_at(under, middle), -(DECK - 0.2), 1e-6, "the deck over it, below"
	)
	var sim := _held(180.0, Vector3(-2.0, FLOOR, 0.0))
	SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	var body := sim.state.seats[0]
	assert_eq(sim.state.up, Faces.Up.KEEL, "she is upside down")
	assert_eq(body.body, PlayerState.Body.GROUNDED, "standing")
	assert_almost_eq(body.pos.y, DECK - 0.2, 1e-4, "on the deck's underside")
	var head := sim.pose().world_height(body.pos + Vector3.DOWN * rules.body_height)
	assert_gt(head, sim.pose().world_height(body.pos), "its head up in the world")


func test_searches_follow_the_axis_nearest_up() -> void:
	var keep := SimFixtures.rules().brace_holds_to
	var layout := _room()
	var faces := _faces(layout)
	# [trim, heel, the face up, the face a body comes down on from the room's middle].
	for row: Array in [
		[0.0, 0.0, Faces.Up.DECK, FLOOR],
		[0.0, 30.0, Faces.Up.DECK, FLOOR],
		[0.0, 60.0, Faces.Up.PORT, -STARBOARD_FACE],
		[0.0, -60.0, Faces.Up.STARBOARD, PORT_FACE],
		[0.0, 90.0, Faces.Up.PORT, -STARBOARD_FACE],
		[0.0, 120.0, Faces.Up.PORT, -STARBOARD_FACE],
		[0.0, 150.0, Faces.Up.KEEL, -(DECK - 0.2)],
		[0.0, 180.0, Faces.Up.KEEL, -(DECK - 0.2)],
		[70.0, 0.0, Faces.Up.STERN, -4.9],
		[-70.0, 0.0, Faces.Up.BOW, -4.9],
	]:
		var told := "trim %s heel %s" % [row[0], row[1]]
		var pose := SimFixtures.sim(1, SimFixtures.tilted(row[0], row[1]), layout).pose()
		var up := Faces.up_after(pose, Faces.Up.DECK, keep)
		assert_eq(up, row[2], told)
		var world_up := (pose.transform.basis.inverse() * Vector3.UP).normalized()
		for other: int in Faces.Up.values():
			assert_gte(world_up.dot(Faces.axis(up)), world_up.dot(Faces.axis(other)), told)
		var here := faces.surfaces(up)
		var middle := Faces.to_frame(up) * Vector3(-2.0, 1.2, 0.0)
		var under := here.landing(middle)
		assert_ne(under, Surfaces.NONE, told)
		assert_almost_eq(here.height_at(under, middle), row[3], 1e-6, told)
		assert_lte(faces.framed(pose, up).slope_deg(), keep, told)


func test_body_slides_into_the_corner() -> void:
	var rules := SimFixtures.rules()
	var sim := _held(45.0, Vector3(-2.0, FLOOR, -1.0))
	SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	var body := sim.state.seats[0]
	assert_eq(sim.state.up, Faces.Up.DECK, "still on her deck in the band")
	assert_eq(body.body, PlayerState.Body.GROUNDED, "on its feet")
	assert_almost_eq(body.pos.z, STARBOARD_FACE - rules.body_radius, 1e-3, "in the corner")
	assert_almost_eq(body.vel.length(), 0.0, 1e-3, "at rest there")


func test_brace_holds_up_to_the_band_top() -> void:
	var rules := SimFixtures.rules()
	var brace := SimFixtures.frame(0, Vector2.ZERO, InputFrame.BRACE)
	var start := Vector3(-2.0, FLOOR, -1.0)
	var held := _held(rules.brace_holds_to - 1.0, start)
	SimFixtures.step(held, {0: brace}, Ticks.RATE)
	assert_true(held.state.seats[0].bracing, "braced")
	assert_almost_eq(held.state.seats[0].pos.distance_to(start), 0.0, 1e-3, "it holds there")
	# Its rules holding a brace only to 45°, the same list throws it off.
	var softer := _held(rules.brace_holds_to - 1.0, start)
	var less: BrawlRules = rules.duplicate()
	less.brace_holds_to = 45.0
	softer.config.rules = less
	softer = MatchSim.from_snapshot(softer.snapshot(), softer.config)
	SimFixtures.step(softer, {0: brace}, Ticks.RATE)
	assert_gt(softer.state.seats[0].pos.z, start.z + 0.5, "past its hold it goes")
	# Past the band's top the brace holds nothing: the wall is the floor.
	var past := _held(rules.brace_holds_to + 1.0, start)
	SimFixtures.step(past, {0: brace}, 2 * Ticks.RATE)
	assert_eq(past.state.up, Faces.Up.PORT, "the wall is the floor")
	assert_almost_eq(past.state.seats[0].pos.z, STARBOARD_FACE, 1e-4, "it fell onto it")


func test_a_match_continues_exactly_as_she_turns_onto_another_face() -> void:
	# She rolls from upright onto her side and on over (D5): the frame the match stands in
	# is in its snapshot, so a sim rebuilt from any snapshot on the way goes on exactly as
	# the match did — through the turn from her decks to her wall, and from her wall to
	# the undersides of her decks.
	var rolling := SimFixtures.scenario(
		[[0.0, -10.0, 0.0, 0.0], [2.0, -10.0, 0.0, 90.0], [4.0, -10.0, 0.0, 180.0]]
	)
	var layout := _room()
	layout.spawns.append(Vector3(2.0, FLOOR, 1.0))
	var sim := MatchSim.create(SimFixtures.config(2, rolling, 1, layout))
	SimFixtures.place(sim, 0, Vector3(-2.0, FLOOR, -1.0))
	SimFixtures.place(sim, 1, Vector3(2.0, FLOOR, 1.0))
	var frames := func(tick: int) -> Array[InputFrame]:
		return [
			SimFixtures.frame(0, Vector2(1.0, 0.0), 0, 0.0),
			SimFixtures.frame(1, Vector2.ZERO, InputFrame.BRACE if tick < 45 else 0, 0.0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for tick in 5 * Ticks.RATE:
		sim.step(frames.call(tick))
		played.append(sim.snapshot())
	var ups := {}
	for snapshot: Dictionary in played:
		ups[snapshot["up"]] = true
	assert_eq(ups.keys(), [Faces.Up.DECK, Faces.Up.PORT, Faces.Up.KEEL], "deck, wall, under")
	for start in range(0, played.size() - 1, 3):
		var resumed := MatchSim.from_snapshot(played[start], sim.config)
		for offset in range(1, mini(Ticks.RATE / 2, played.size() - 1 - start) + 1):
			resumed.step(frames.call(start + offset - 1))
			if resumed.snapshot() != played[start + offset]:
				fail_test("from tick %d it left the match at %d" % [start, start + offset])
				return
