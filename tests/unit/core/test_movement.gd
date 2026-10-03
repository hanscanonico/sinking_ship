extends GutTest


func _planar_speed(player: PlayerState) -> float:
	return Vector2(player.vel.x, player.vel.z).length()


func test_accelerates_to_walk_speed() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var walk := {0: SimFixtures.frame(0, Vector2.RIGHT)}
	var to_full := ceili(rules.walk_speed / (rules.ground_accel * Ticks.SECONDS_PER_TICK))
	var previous := 0.0
	for _tick in to_full - 1:
		SimFixtures.step(sim, walk)
		var speed := _planar_speed(sim.state.seats[0])
		assert_gt(speed, previous, "still speeding up")
		assert_lt(speed, rules.walk_speed)
		previous = speed
	SimFixtures.step(sim, walk, 10)
	assert_almost_eq(_planar_speed(sim.state.seats[0]), rules.walk_speed, 0.0001)
	assert_gt(sim.state.seats[0].pos.x, 0.0, "toward the bow")


func test_stops_under_friction() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.DOWN)}, 15)
	assert_almost_eq(_planar_speed(sim.state.seats[0]), rules.walk_speed, 0.0001)
	var to_rest := ceili(rules.walk_speed / (rules.ground_friction * Ticks.SECONDS_PER_TICK))
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, to_rest - 1)
	assert_gt(_planar_speed(sim.state.seats[0]), 0.0, "still sliding to a stop")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_eq(_planar_speed(sim.state.seats[0]), 0.0)
	var resting := sim.state.seats[0].pos
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 5)
	assert_eq(sim.state.seats[0].pos, resting)


func test_walking_off_the_deck_falls_into_the_sea() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	# Level with the gap in the starboard railing.
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, 3.0))
	var to_starboard := {0: SimFixtures.frame(0, Vector2.DOWN)}
	var fell_at := -1
	var events: Array[SimEvent] = []
	for tick in 120:
		events.append_array(SimFixtures.step(sim, to_starboard))
		var player := sim.state.seats[0]
		if fell_at == -1 and player.body == PlayerState.Body.AIRBORNE:
			fell_at = tick
			assert_eq(player.surface, Surfaces.NONE)
			assert_gt(player.pos.z, SimFixtures.deck().platforms[0].area.end.y)
		if player.is_out():
			break
	var walker := sim.state.seats[0]
	assert_gt(fell_at, -1, "walked off the edge")
	assert_true(walker.is_out(), "and into the sea")
	assert_eq(walker.out_cause, PlayerState.Cause.WATER)
	assert_lt(walker.pos.y, 0.0, "fell below the deck first")
	assert_gt(walker.out_tick, fell_at)
	assert_eq(events.size(), 2, "seat out, then the last one dry wins")
	assert_eq(events[0].kind, SimEvent.Kind.SEAT_OUT)
	assert_eq(events[0].seat, 0)
