extends GutTest
## Bodies push bodies (§6): their circles separate, and a body that runs into another
## hands over part of its speed — the two part along the line between them as bodies of
## one mass do, with body_restitution of the speed they closed at — and a staggered body
## closing at body_impact_speed or more bowls the other over: staggered as by a shove,
## and credited to whatever sent the first. Shoving into a crowd is a bowling ball.

const SHOVE := InputFrame.SHOVE
const BRACE := InputFrame.BRACE


func _rules() -> BrawlRules:
	return SimFixtures.rules()


## Seat [param seat] at [param pos] sliding toward the bow at [param speed], staggered
## — as a shove sends a body once its hit-stop is over.
func _sliding(sim: MatchSim, seat: int, pos: Vector3, speed: float) -> void:
	SimFixtures.place(sim, seat, pos)
	var player := sim.state.seats[seat]
	player.vel = Vector3(speed, 0.0, 0.0)
	player.stagger_ticks = Ticks.from_seconds(_rules().stagger)


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


func test_the_rules_part_bodies_between_sticking_and_bouncing() -> void:
	assert_eq(_rules().problems(), PackedStringArray(), "the shipped numbers hold")
	var springy: BrawlRules = _rules().duplicate()
	springy.body_restitution = 1.5
	assert_eq(
		springy.problems(), PackedStringArray(["brawl rules: body_restitution must be within 0…1"])
	)
	var touchy: BrawlRules = _rules().duplicate()
	touchy.body_impact_speed = 0.0
	assert_eq(
		touchy.problems(), PackedStringArray(["brawl rules: body_impact_speed must be positive"])
	)


func test_a_body_running_into_another_hands_over_part_of_its_speed() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	var speed := 6.0
	# Seat 1 stands a hand's width past seat 0's edge: met within the tick's move.
	_sliding(sim, 0, Vector3(-5.0, 0.0, 0.0), speed)
	SimFixtures.place(sim, 1, Vector3(-5.0 + rules.body_radius * 2.0 + 0.05, 0.0, 0.0))
	SimFixtures.step(sim)
	# The slide's friction takes its share before the move: the speed they close at.
	var closing := speed - rules.stagger_friction * Ticks.SECONDS_PER_TICK
	var runner := sim.state.seats[0].vel
	var struck := sim.state.seats[1].vel
	assert_almost_eq(runner.x + struck.x, closing, 0.0001, "the speed is shared, never lost")
	assert_almost_eq(
		struck.x - runner.x, closing * rules.body_restitution, 0.0001, "parting at the restitution"
	)
	assert_gt(runner.x, 0.0, "the runner goes on, slower")
	assert_almost_eq(runner.z, 0.0, 0.0001, "along the line between them")
	assert_almost_eq(struck.z, 0.0, 0.0001)


func test_a_shoved_body_bowls_over_the_body_it_runs_into() -> void:
	var rules := _rules()
	var touch := rules.body_radius * 2.0
	var sim := SimFixtures.sim(3)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(touch + 0.3, 0.0, 0.0), 180.0)
	var pin_from := Vector3(2.0 * touch + 1.3, 0.0, 0.0)
	SimFixtures.place(sim, 2, pin_from, 180.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
	var bowled: Array[SimEvent] = []
	for _tick in Ticks.RATE:
		var events := _of(SimFixtures.step(sim, {0: SimFixtures.frame(0)}), SimEvent.Kind.BOWLED)
		if not events.is_empty() and bowled.is_empty():
			var pin := sim.state.seats[2]
			assert_true(pin.is_staggered(), "knocked off its feet")
			assert_eq(pin.last_hit_by, 0, "by the shove that sent seat 1")
			var runner := SimFixtures.sent(sim.state.seats[1]).x
			assert_gt(SimFixtures.sent(pin).x, runner, "sent on ahead of the one that hit it")
			assert_gt(runner, 0.0, "which goes on, slower")
		bowled.append_array(events)
	assert_eq(bowled.size(), 1, "one impact")
	if bowled.size() != 1:
		return
	assert_eq([bowled[0].seat, bowled[0].target], [2, 1], "seat 1 bowls seat 2 over")
	assert_gt(sim.state.seats[2].pos.x - pin_from.x, 1.0, "sliding on, a bowling pin")


func test_an_exit_a_bowling_causes_is_credited_to_the_shover() -> void:
	var rules := _rules()
	var touch := rules.body_radius * 2.0
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var gap := SimFixtures.rail_gap(edge)
	var sim := SimFixtures.sim(3)
	# Seat 0 shoves seat 1 to starboard, into seat 2 standing in the railing's gap.
	var pin_z := edge - rules.body_radius - 0.1
	var sent_z := pin_z - touch - 1.0
	SimFixtures.place(sim, 2, Vector3(gap.x, 0.0, pin_z), 270.0)
	SimFixtures.place(sim, 1, Vector3(gap.x, 0.0, sent_z), 270.0)
	SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, sent_z - touch - 0.3), 90.0)
	var outs: Array[SimEvent] = []
	for tick in 10 * Ticks.RATE:
		var buttons := SHOVE if tick == 0 else 0
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)})
		outs.append_array(_of(events, SimEvent.Kind.SEAT_OUT))
		if sim.is_over():
			break
	var pin_out: SimEvent = null
	for out: SimEvent in outs:
		if out.seat == 2:
			pin_out = out
	assert_not_null(pin_out, "seat 2 goes over the edge and out")
	if pin_out != null:
		assert_eq(pin_out.credit, 0, "credited to the shover who bowled it")


func test_walking_into_a_body_pushes_it_on_without_bowling_it_over() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 0.0))
	var idle_from := Vector3(-3.0 + rules.body_radius * 2.0 + 0.5, 0.0, 0.0)
	SimFixtures.place(sim, 1, idle_from)
	var bowled: Array[SimEvent] = []
	for _tick in Ticks.RATE:
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)})
		bowled.append_array(_of(events, SimEvent.Kind.BOWLED))
		assert_false(sim.state.seats[1].is_staggered(), "a walk is no impact")
	assert_true(bowled.is_empty())
	var walker := sim.state.seats[0]
	var idler := sim.state.seats[1]
	assert_gt(idler.pos.x - idle_from.x, 1.0, "pushed on ahead of the walker")
	assert_almost_eq(idler.pos.x - walker.pos.x, rules.body_radius * 2.0, 0.0001, "touching")


func test_a_front_brace_takes_the_speed_but_keeps_its_feet() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 1, Vector3(-5.0 + rules.body_radius * 2.0 + 0.05, 0.0, 0.0), 180.0)
	var planted := {1: SimFixtures.frame(1, Vector2.ZERO, BRACE)}
	SimFixtures.step(sim, planted)
	assert_true(sim.state.seats[1].bracing, "planted, facing the one coming")
	_sliding(sim, 0, Vector3(-5.0, 0.0, 0.0), rules.knockback)
	var events := SimFixtures.step(sim, planted)
	var braced := sim.state.seats[1]
	assert_true(_of(events, SimEvent.Kind.BOWLED).is_empty(), "not bowled over")
	assert_false(braced.is_staggered())
	assert_true(braced.bracing, "still planted")
	assert_gt(braced.vel.x, 0.0, "though it takes its share of the speed")


func test_a_body_frozen_in_a_hit_stop_takes_no_part() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	var speed := 6.0
	_sliding(sim, 0, Vector3(-5.0, 0.0, 0.0), speed)
	SimFixtures.place(sim, 1, Vector3(-5.0 + rules.body_radius * 2.0 + 0.05, 0.0, 0.0))
	sim.state.seats[1].freeze(Vector3(-1.0, 0.0, 0.0), 3)
	var events := SimFixtures.step(sim)
	var frozen := sim.state.seats[1]
	assert_true(frozen.is_frozen())
	assert_almost_eq(SimFixtures.sent(frozen).x, -1.0, 0.0001, "the stop holds what it held")
	assert_false(frozen.is_staggered(), "nor is it bowled over")
	assert_true(_of(events, SimEvent.Kind.BOWLED).is_empty())
	var kept := speed - rules.stagger_friction * Ticks.SECONDS_PER_TICK
	assert_almost_eq(sim.state.seats[0].vel.x, kept, 0.0001, "the runner keeps its speed")
