extends GutTest
## Grabbing (#273): one Grab button takes the nearest prop in reach that can be held,
## and pressed again lets it go. A prop's holder is the one truth of who holds what.

const GRAB := InputFrame.GRAB


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## A match of [param seats] on the flat deck carrying [param props] and nothing else.
func _with(seats: int, props: Array[ShipProp]) -> MatchSim:
	return SimFixtures.sim(seats, null, SimFixtures.crated(props))


func _grab(seat: int) -> InputFrame:
	return SimFixtures.frame(seat, Vector2.ZERO, GRAB)


func test_a_grab_press_takes_a_lifebuoy_in_reach() -> void:
	var sim := _with(1, [SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0))])
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	var events := SimFixtures.step(sim, {0: _grab(0)})
	var ring := sim.state.props[0]
	assert_eq(ring.body, PropState.Body.HELD, "in its hands")
	assert_eq(ring.holder, 0)
	var grabbed := _of(events, SimEvent.Kind.PROP_GRABBED)
	assert_eq(grabbed.size(), 1)
	assert_eq([grabbed[0].seat, grabbed[0].prop], [0, 0])


func test_grab_pressed_again_lets_go_at_the_feet() -> void:
	var sim := _with(1, [SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0))])
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.step(sim, {0: _grab(0)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	SimFixtures.place(sim, 0, Vector3(-5.0, 0.0, 1.0), 0.0)
	var events := SimFixtures.step(sim, {0: _grab(0)})
	var ring := sim.state.props[0]
	assert_eq(ring.holder, -1, "out of its hands")
	var let_go := _of(events, SimEvent.Kind.PROP_LET_GO)
	assert_eq(let_go.size(), 1)
	assert_eq([let_go[0].seat, let_go[0].prop], [0, 0])
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3)
	assert_eq(ring.body, PropState.Body.GROUNDED, "on the deck")
	assert_almost_eq(ring.pos, Vector3(-5.0, 0.0, 1.0), Vector3.ONE * 0.001, "where it stood")
	assert_true(_of(events, SimEvent.Kind.PROP_GRABBED).is_empty(), "no grab on a let-go")


## A prop that is not solid is no surface and no blocker, and a shove never lands on it:
## bodies walk through it.
func test_a_lifebuoy_on_the_deck_is_walked_through_and_never_shoved() -> void:
	var sim := _with(1, [SimFixtures.lifebuoy(Vector3(0.0, 0.0, 0.0))])
	SimFixtures.place(sim, 0, Vector3(-2.0, 0.0, 0.0), 0.0)
	var player := sim.state.seats[0]
	var events: Array[SimEvent] = []
	for _tick in Ticks.RATE:
		events.append_array(SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}))
		assert_eq(player.surface, 0, "never on its lid: on the deck")
	assert_gt(player.pos.x, 2.0, "walked on through it")
	assert_true(_of(events, SimEvent.Kind.PROP_HIT).is_empty())
	var ring := sim.state.props[0]
	assert_eq(ring.pos, Vector3.ZERO, "where it lay")
	SimFixtures.place(sim, 0, Vector3(-1.0, 0.0, 0.0), 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_eq(ring.pos, Vector3.ZERO, "a shove never lands on it")
	assert_eq(ring.shoved_by, -1)


## Two seats pressing Grab at one prop on one tick: the nearer takes it, the other
## nothing; of two as near, the lower seat.
func test_the_nearer_brawler_wins_a_tied_grab_then_the_lower_seat() -> void:
	var sim := _with(2, [SimFixtures.lifebuoy(Vector3(0.0, 0.0, 0.0))])
	SimFixtures.place(sim, 0, Vector3(-1.05, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(0.95, 0.0, 0.0), 180.0)
	var events := SimFixtures.step(sim, {0: _grab(0), 1: _grab(1)})
	assert_eq(sim.state.props[0].holder, 1, "the nearer one")
	assert_eq(_of(events, SimEvent.Kind.PROP_GRABBED).size(), 1, "and only it")

	var even := _with(2, [SimFixtures.lifebuoy(Vector3(0.0, 0.0, 0.0))])
	SimFixtures.place(even, 0, Vector3(-1.0, 0.0, 0.0), 0.0)
	SimFixtures.place(even, 1, Vector3(1.0, 0.0, 0.0), 180.0)
	SimFixtures.step(even, {1: _grab(1), 0: _grab(0)})
	assert_eq(even.state.props[0].holder, 0, "as near: the lower seat")


## Of two props as near, a press takes the lower; one is all a body holds.
func test_a_press_takes_the_nearer_prop_then_the_lower_and_only_one() -> void:
	var near := SimFixtures.lifebuoy(Vector3(0.9, 0.0, 0.3))
	var nearer := SimFixtures.lifebuoy(Vector3(0.9, 0.0, -0.1))
	var sim := _with(1, [near, nearer])
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.props[1].holder, 0, "the nearer of two")
	assert_eq(sim.state.props[0].body, PropState.Body.GROUNDED, "and not the other")

	var twin := _with(
		1,
		[
			SimFixtures.lifebuoy(Vector3(0.9, 0.0, 0.2)),
			SimFixtures.lifebuoy(Vector3(0.9, 0.0, -0.2))
		]
	)
	SimFixtures.place(twin, 0, Vector3.ZERO, 0.0)
	SimFixtures.step(twin, {0: _grab(0)})
	assert_eq(twin.state.props[0].holder, 0, "as near: the lower prop")
	assert_eq(twin.state.props[1].holder, -1)


func test_a_grab_needs_the_prop_in_reach_in_front_and_at_hand_height() -> void:
	var rules := SimFixtures.rules()
	var edge := rules.body_radius + PropKind.named(&"lifebuoy").radius + rules.grab_reach
	for case: Array in [
		[Vector3(edge - 0.01, 0.0, 0.0), 0.0, 0, "within grab_reach of both edges"],
		[Vector3(edge + 0.01, 0.0, 0.0), 0.0, -1, "beyond it"],
		[Vector3(-1.0, 0.0, 0.0), 0.0, -1, "behind"],
		[Vector3(1.0, 0.0, 0.0), rules.grab_cone_deg - 1.0, 0, "inside the cone"],
		[Vector3(1.0, 0.0, 0.0), rules.grab_cone_deg + 1.0, -1, "outside it"],
		[Vector3(1.0, rules.body_height + 0.01, 0.0), 0.0, -1, "over its head"],
	]:
		var sim := _with(1, [SimFixtures.lifebuoy(case[0])])
		SimFixtures.place(sim, 0, Vector3.ZERO, case[1])
		sim.state.props[0].body = PropState.Body.HUNG
		SimFixtures.step(sim, {0: _grab(0)})
		assert_eq(sim.state.props[0].holder, case[2], case[3])


## Grabbing is never a way out of a hit, a swim or a shove.
func test_no_grab_while_staggered_frozen_swimming_or_shoving() -> void:
	for what: String in [
		"staggered", "frozen", "in the air", "swimming", "climbing", "winding up", "recovering"
	]:
		var sim := _with(1, [SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0))])
		SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
		var player := sim.state.seats[0]
		match what:
			"staggered":
				player.stagger_ticks = 5
			"frozen":
				player.hitstop = 5
			"in the air":
				player.body = PlayerState.Body.AIRBORNE
			"swimming":
				player.body = PlayerState.Body.SWIMMING
			"climbing":
				player.body = PlayerState.Body.SWIMMING
				player.climb_left = 5
			"winding up":
				player.action = PlayerState.Action.WINDUP
			"recovering":
				player.action = PlayerState.Action.RECOVERY
		SimFixtures.step(sim, {0: _grab(0)})
		assert_eq(sim.state.props[0].holder, -1, what)


## The HUD's prompt asks GrabReach.would_take of the snapshot it draws: the prop it names
## is the one the next press takes, and none is named while the hands are full.
func test_the_reach_query_names_what_the_next_press_takes() -> void:
	var props: Array[ShipProp] = [
		SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.6)),
		SimFixtures.lifebuoy(Vector3(1.0, 0.0, -0.4)),
		SimFixtures.lifebuoy(Vector3(-3.0, 0.0, 0.0)),
	]
	var layout := SimFixtures.crated(props)
	var rules := SimFixtures.rules()
	for case: Array in [
		[Vector3.ZERO, 0.0], [Vector3(-2.0, 0.0, 0.0), 180.0], [Vector3.ZERO, 90.0]
	]:
		var sim := SimFixtures.sim(1, null, layout)
		SimFixtures.place(sim, 0, case[0], case[1])
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		var named := GrabReach.would_take(sim.snapshot(), 0, layout, rules, sim.surfaces)
		SimFixtures.step(sim, {0: _grab(0)})
		var taken := -1
		for crate: PropState in sim.state.props:
			if crate.holder == 0:
				taken = crate.prop
		assert_eq(named, taken, "at %s facing %s" % case)
		if taken != -1:
			assert_eq(GrabReach.would_take(sim.snapshot(), 0, layout, rules, sim.surfaces), -1)
