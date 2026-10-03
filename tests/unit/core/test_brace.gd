extends GutTest

const BRACE := InputFrame.BRACE


func _brace(seat: int, move: Vector2 = Vector2.ZERO) -> InputFrame:
	return SimFixtures.frame(seat, move, BRACE)


## Seat 0 at the origin facing the bow taps a quick shove at seat 1, 0.3 m beyond
## its reach's start, facing [param target_facing_deg]; seat 1 sends
## [param target_frame] every tick. Steps through the shove's active window.
func _quick_shove_at(target_facing_deg: float, target_frame: InputFrame) -> MatchSim:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), target_facing_deg)
	SimFixtures.step(
		sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE), 1: target_frame}
	)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.from_seconds(rules.shove_windup))
	return sim


func test_front_brace_cuts_knockback() -> void:
	var rules := SimFixtures.rules()
	var open := _quick_shove_at(180.0, SimFixtures.frame(1))
	var braced := _quick_shove_at(180.0, _brace(1))
	assert_true(open.state.seats[1].is_staggered(), "unbraced, the quick shove staggers")
	var target := braced.state.seats[1]
	assert_eq(open.state.seats[1].last_hit_by, 0)
	assert_eq(target.last_hit_by, 0, "the shove landed")
	assert_almost_eq(SimFixtures.sent(open.state.seats[1]).length(), rules.knockback, 0.0001)
	assert_almost_eq(
		SimFixtures.sent(target).length(), rules.knockback * (1.0 - rules.brace_reduction), 0.0001
	)
	assert_false(target.is_staggered(), "a front brace is not staggered")
	assert_true(target.bracing, "and stays planted")
	# Across the same second, the brace barely moves while the open body slides away.
	SimFixtures.step(open, {}, Ticks.RATE)
	SimFixtures.step(braced, {}, Ticks.RATE)
	var start_x := rules.body_radius * 2.0 + 0.3
	assert_lt(braced.state.seats[1].pos.x - start_x, 0.2, "barely moved")
	assert_gt(open.state.seats[1].pos.x - start_x, 2.0, "the open body slid")


func test_brace_from_behind_does_nothing() -> void:
	var rules := SimFixtures.rules()
	# Facing away from the shover, and just outside the front arc's edge: both full.
	for facing: float in [0.0, 180.0 - rules.brace_arc_deg - 5.0]:
		var sim := _quick_shove_at(facing, _brace(1))
		var target := sim.state.seats[1]
		assert_true(target.is_staggered(), "facing %s: staggered" % facing)
		assert_false(target.bracing, "facing %s: the brace is broken" % facing)
		assert_almost_eq(SimFixtures.sent(target).length(), rules.knockback, 0.0001)


func test_brace_holds_on_a_steep_deck_and_drains() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1, SimFixtures.tilted(0.0, rules.grip_angle_deg + 4.0))
	var start := Vector3(-8.0, 0.0, 0.0)
	SimFixtures.place(sim, 0, start)
	var seconds := 2.0
	SimFixtures.step(sim, {0: _brace(0)}, Ticks.from_seconds(seconds))
	var player := sim.state.seats[0]
	assert_true(player.bracing)
	assert_eq(player.pos, start, "held past the grip angle")
	assert_almost_eq(
		player.stamina, rules.stamina_max - rules.brace_drain * seconds, 0.001, "and draining"
	)
	# Held until the bar empties, the deck takes it.
	var to_empty := rules.stamina_max / rules.brace_drain - seconds
	SimFixtures.step(sim, {0: _brace(0)}, Ticks.from_seconds(to_empty) + 1)
	assert_eq(player.stamina, 0.0, "the bar is empty")
	assert_false(player.bracing, "the brace gives")
	SimFixtures.step(sim, {0: _brace(0)}, Ticks.RATE)
	assert_gt(player.pos.distance_to(start), 0.1, "and it slides")


func test_exhausted_seat_cannot_brace() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var player := sim.state.seats[0]
	SimFixtures.step(
		sim, {0: _brace(0)}, Ticks.from_seconds(rules.stamina_max / rules.brace_drain) + 1
	)
	assert_true(player.exhausted)
	SimFixtures.step(sim, {0: _brace(0)}, Ticks.RATE)
	assert_false(player.bracing, "still held, no brace")
	# Let go and press again once some stamina is back: still nothing.
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_gt(player.stamina, 0.0)
	SimFixtures.step(sim, {0: _brace(0)})
	assert_false(player.bracing, "exhausted until the bar is full")
	# A full bar ends it.
	var refill := (rules.stamina_max - player.stamina) / rules.stamina_regen
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.from_seconds(refill) + 1)
	assert_eq(player.stamina, rules.stamina_max)
	assert_false(player.exhausted)
	SimFixtures.step(sim, {0: _brace(0)})
	assert_true(player.bracing, "rested, it braces again")


func test_braced_seat_cannot_move() -> void:
	var sim := SimFixtures.sim(1)
	var start := Vector3(-4.0, 0.0, 0.0)
	SimFixtures.place(sim, 0, start)
	SimFixtures.step(sim, {0: _brace(0, Vector2.DOWN)}, Ticks.RATE)
	var player := sim.state.seats[0]
	assert_true(player.bracing)
	assert_eq(player.pos, start, "rooted, whatever the stick says")
	assert_eq(player.vel, Vector3.ZERO)

	# Walking when it plants, it stops where it stands.
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE)
	SimFixtures.step(sim, {0: _brace(0, Vector2.RIGHT)}, 2)
	assert_true(player.bracing)
	var planted := player.pos
	SimFixtures.step(sim, {0: _brace(0, Vector2.RIGHT)}, Ticks.RATE)
	assert_eq(player.vel, Vector3.ZERO, "stopped")
	assert_lt(player.pos.distance_to(planted), 0.5, "within a stride of where it planted")
