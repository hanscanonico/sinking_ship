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
	for tick in 300:
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
	assert_true(walker.is_out(), "and into the sea, where the cold took it")
	assert_eq(walker.out_cause, PlayerState.Cause.COLD)
	assert_lt(walker.pos.y, 0.0, "fell below the deck first")
	assert_gt(walker.out_tick, fell_at)
	var kinds := events.map(func(event: SimEvent) -> SimEvent.Kind: return event.kind)
	assert_eq(
		kinds,
		[
			SimEvent.Kind.FELL,
			SimEvent.Kind.ENTERED_WATER,
			SimEvent.Kind.SEAT_OUT,
			SimEvent.Kind.MATCH_ENDED
		],
		"it fell, swam, went out, and the last one dry won"
	)
	assert_eq([events[0].tick, events[0].seat], [fell_at, 0])
	assert_eq(events[1].seat, 0)


## The steamer's bridge, a deck standing over her boat deck with no railing round it.
func _steamer_bridge() -> Rect2:
	var layout := SimFixtures.steamer()
	return layout.platforms[SimFixtures.platform_named(layout, &"bridge")].area


## A body falling past the steamer's bridge's aft edge, its feet a little under the deck,
## flying forward into it: held off the edge from outside, its circle against it, every
## tick on — never let in over it with its middle and pushed back out (#472) — and down
## to the boat deck.
func test_a_body_falling_into_a_deck_edge_is_held_off_it() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var edge := _steamer_bridge().position.x
	var deck := layout.platforms[SimFixtures.platform_named(layout, &"bridge")].height
	var below := layout.platforms[SimFixtures.platform_named(layout, &"boat deck")].height
	var sim := SimFixtures.sim(1, null, layout)
	var start := Vector3(edge - 0.6, deck - rules.step_height * 0.4, 0.0)
	SimFixtures.fly(sim, 0, start, Vector3(2.0, 0.0, 0.0))
	var x := start.x
	for tick in 30:
		SimFixtures.step(sim)
		var body := sim.state.seats[0]
		assert_gte(body.pos.x, x, "tick %d: on forward, never back out" % tick)
		assert_lte(body.pos.x, edge - rules.body_radius + 1e-4, "tick %d: off the edge" % tick)
		x = body.pos.x
	var body := sim.state.seats[0]
	assert_eq(body.body, PlayerState.Body.GROUNDED, "landed")
	assert_almost_eq(body.pos.y, below, 0.0001, "on the boat deck, not up on the bridge")
	assert_almost_eq(body.pos.x, edge - rules.body_radius, 0.0001, "against its edge")


## A body dropping straight down past the steamer's bridge's aft edge, its middle off it and
## its circle over it, its feet a little under the deck: pushed out of the edge, only ever
## away from the deck, down to the boat deck (#472).
func test_a_body_dropping_past_a_deck_edge_moves_only_away_from_it() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var edge := _steamer_bridge().position.x
	var deck := layout.platforms[SimFixtures.platform_named(layout, &"bridge")].height
	var below := layout.platforms[SimFixtures.platform_named(layout, &"boat deck")].height
	var sim := SimFixtures.sim(1, null, layout)
	var start := Vector3(edge - rules.body_radius * 0.5, deck - rules.step_height * 0.4, 0.0)
	SimFixtures.fly(sim, 0, start, Vector3.ZERO)
	var x := start.x
	for tick in 30:
		SimFixtures.step(sim)
		var body := sim.state.seats[0]
		assert_lte(body.pos.x, x, "tick %d: out of the edge, never into it" % tick)
		x = body.pos.x
	var body := sim.state.seats[0]
	assert_eq(body.body, PlayerState.Body.GROUNDED, "landed")
	assert_almost_eq(body.pos.y, below, 0.0001, "on the boat deck under it")
	assert_almost_eq(body.pos.x, edge - rules.body_radius, 0.0001, "clear of the bridge")
