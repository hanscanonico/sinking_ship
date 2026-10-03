extends GutTest

const SHOVE := InputFrame.SHOVE


func _shove(seat: int, look_deg: float = NAN) -> InputFrame:
	return SimFixtures.frame(seat, Vector2.ZERO, SHOVE, look_deg)


## Seat 0 at the origin facing the bow, seat 1 at [param target_pos]; seat 0
## shoves and the shove's active window runs out.
func _shove_at(target_pos: Vector3) -> MatchSim:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, target_pos, 180.0)
	SimFixtures.step(sim, {0: _shove(0)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 5)
	return sim


## Where a body stands at [param gap] beyond both bodies' edges, [param angle_deg]
## off seat 0's facing.
func _at(gap: float, angle_deg: float) -> Vector3:
	var rules := SimFixtures.rules()
	var along := Vector2.from_angle(deg_to_rad(angle_deg)) * (rules.body_radius * 2.0 + gap)
	return Vector3(along.x, 0.0, along.y)


func test_shove_goes_where_you_look() -> void:
	# The body stands to starboard of the shover, which looks at it or away from it
	# while walking every which way: the look, not the walk, aims the shove.
	for move: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for look_deg: float in [90.0, -90.0]:
			var sim := SimFixtures.sim(2)
			SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
			SimFixtures.place(sim, 1, _at(0.2, 90.0))
			var press := {
				0: SimFixtures.frame(0, move * 0.3, SHOVE, look_deg), 1: SimFixtures.frame(1)
			}
			SimFixtures.step(sim, press)
			SimFixtures.step(sim, {0: SimFixtures.frame(0, move * 0.3, 0, look_deg)}, 5)
			var hit := sim.state.seats[1].is_staggered()
			if look_deg > 0.0:
				assert_true(hit, "dead ahead of the look, walking %s" % move)
			else:
				assert_false(hit, "behind the look, walking %s" % move)


func test_look_turns_any_amount_in_one_tick() -> void:
	for look_deg: float in [179.0, -120.0, 90.0, 0.5, -179.9]:
		var sim := SimFixtures.sim(1)
		SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
		var look := InputFrame.quantize_yaw(deg_to_rad(look_deg))
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT, 0, look_deg)})
		assert_eq(sim.state.seats[0].facing, InputFrame.yaw_angle(look), "%s° at once" % look_deg)
	# Mid-shove too: the view is free, the shove keeps the facing it started with.
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, _at(0.2, 0.0))
	SimFixtures.step(sim, {0: _shove(0)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3)
	assert_eq(sim.state.seats[0].action, PlayerState.Action.ACTIVE)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, 0, 180.0)})
	var behind := angle_difference(sim.state.seats[0].facing, PI)
	assert_almost_eq(behind, 0.0, 0.0001, "looked behind in one tick")
	assert_almost_eq(sim.state.seats[0].shove_facing, 0.0, 0.0001, "the shove stays aimed")
	assert_true(sim.state.seats[1].is_staggered())


func test_would_hit_matches_the_resolved_shove() -> void:
	var rules := SimFixtures.rules()
	var answers := {}
	for look_deg: float in [0.0, 90.0, -150.0]:
		for off_deg: float in [0.0, 20.0, -29.0, 35.0, 39.0, -41.0, 60.0, 180.0]:
			for gap: float in [0.1, rules.shove_reach - 0.05, rules.shove_reach + 0.05]:
				var sim := SimFixtures.sim(2)
				SimFixtures.place(sim, 0, Vector3.ZERO, look_deg)
				SimFixtures.place(sim, 1, _at(gap, look_deg + off_deg))
				var asked := ShoveResolver.would_hit(sim.snapshot(), 0, rules, sim.surfaces)
				SimFixtures.step(sim, {0: _shove(0, look_deg), 1: SimFixtures.frame(1)})
				SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 5)
				var landed := sim.state.seats[1].is_staggered()
				assert_eq(asked, landed, "look %s°, %s° off, gap %.2f" % [look_deg, off_deg, gap])
				answers[asked] = true
	assert_eq(answers.size(), 2, "both answers came up")
	# Nobody to hit, or a shover already out: no.
	var alone := SimFixtures.sim(1)
	assert_false(ShoveResolver.would_hit(alone.snapshot(), 0, rules, alone.surfaces))


func test_windup_active_recovery_tick_counts() -> void:
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var phases: Array[int] = []
	SimFixtures.step(sim, {0: _shove(0)})
	phases.append(sim.state.seats[0].action)
	for _tick in 20:
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		phases.append(sim.state.seats[0].action)
	assert_eq(phases.count(PlayerState.Action.WINDUP), 3)
	assert_eq(phases.count(PlayerState.Action.ACTIVE), 3)
	assert_eq(phases.count(PlayerState.Action.RECOVERY), 8)
	assert_eq(phases.slice(0, 14), [1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3])
	assert_eq(phases[14], PlayerState.Action.IDLE)


func test_hit_needs_reach_and_cone() -> void:
	var reach := SimFixtures.rules().shove_reach
	assert_true(_shove_at(_at(reach - 0.1, 0.0)).state.seats[1].is_staggered(), "in reach")
	assert_false(_shove_at(_at(reach + 0.1, 0.0)).state.seats[1].is_staggered(), "too far")
	assert_true(_shove_at(_at(0.3, 35.0)).state.seats[1].is_staggered(), "inside the cone")
	assert_false(_shove_at(_at(0.3, 50.0)).state.seats[1].is_staggered(), "outside the cone")
	assert_false(_shove_at(_at(0.3, 180.0)).state.seats[1].is_staggered(), "behind")


func test_knockback_follows_shove_direction() -> void:
	var rules := SimFixtures.rules()
	# 35° off the shover's facing: outside autoaim, inside the cone, so the facing
	# the shove started with — not the line between the bodies — is where it sends.
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, _at(0.3, 35.0), 180.0)
	SimFixtures.step(sim, {0: _shove(0)}, 3)
	assert_false(sim.state.seats[1].is_staggered(), "nothing lands during the windup")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	var target := sim.state.seats[1]
	assert_true(target.is_staggered())
	assert_eq(target.last_hit_by, 0)
	var sent := SimFixtures.sent(target)
	assert_almost_eq(sent.length(), rules.knockback, 0.0001)
	assert_almost_eq(sent.angle(), 0.0, 0.0001, "along the shover's facing")
	var shover := sim.state.seats[0]
	assert_almost_eq(SimFixtures.sent(shover).x, -rules.recoil, 0.0001, "the shover rocks back")

	# A body that is still staggered when the shove lands takes more.
	var combo := SimFixtures.sim(2)
	SimFixtures.place(combo, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(combo, 1, _at(0.3, 0.0), 180.0)
	combo.state.seats[1].stagger_ticks = 20
	SimFixtures.step(combo, {0: _shove(0)})
	SimFixtures.step(combo, {0: SimFixtures.frame(0)}, 3)
	var again := SimFixtures.sent(combo.state.seats[1])
	assert_almost_eq(again.length(), rules.knockback * rules.restagger_mult, 0.0001)


func test_simultaneous_shoves_both_land() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-0.6, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(0.6, 0.0, 0.0), 180.0)
	SimFixtures.step(sim, {0: _shove(0), 1: _shove(1)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)}, 3)
	var west := sim.state.seats[0]
	var east := sim.state.seats[1]
	assert_true(west.is_staggered() and east.is_staggered(), "both land")
	assert_eq(west.last_hit_by, 1)
	assert_eq(east.last_hit_by, 0)
	assert_almost_eq(SimFixtures.sent(west).x, -(rules.knockback + rules.recoil), 0.0001)
	assert_almost_eq(SimFixtures.sent(east).x, rules.knockback + rules.recoil, 0.0001)


func test_staggered_seat_cannot_shove() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, _at(0.3, 0.0), 180.0)
	sim.state.seats[0].stagger_ticks = 6
	SimFixtures.step(sim, {0: _shove(0)})
	assert_eq(sim.state.seats[0].action, PlayerState.Action.IDLE, "the press is ignored")
	SimFixtures.step(sim, {0: _shove(0)}, 10)
	assert_eq(sim.state.seats[0].action, PlayerState.Action.IDLE, "and holding is no press")
	assert_false(sim.state.seats[1].is_staggered())

	# Shoved mid-windup, the shove is lost.
	var duel := SimFixtures.sim(2)
	SimFixtures.place(duel, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(duel, 1, _at(0.3, 0.0), 180.0)
	SimFixtures.step(duel, {1: _shove(1)})
	SimFixtures.step(duel, {0: _shove(0), 1: SimFixtures.frame(1)}, 3)
	assert_true(duel.state.seats[0].is_staggered())
	assert_eq(duel.state.seats[0].action, PlayerState.Action.IDLE)
	SimFixtures.step(duel, {0: SimFixtures.frame(0)}, 3)
	assert_false(duel.state.seats[1].is_staggered(), "the cancelled shove never lands")


func test_resolver_reads_candidates_not_live_seats() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0), 180.0)
	var attempt := ShoveResolver.Attempt.new(0, Vector3.ZERO, rules.body_radius, Vector2.RIGHT)
	var attempts: Array[ShoveResolver.Attempt] = [attempt]
	# Seat 1 is 10 m away in the sim; the candidate says where it was — in reach.
	var rewound := ShoveResolver.Candidate.new(
		1, _at(0.2, 0.0), rules.body_radius, rules.body_height
	)
	var candidates: Array[ShoveResolver.Candidate] = [rewound]
	var hits := ShoveResolver.resolve(
		attempts,
		candidates,
		rules.shove_reach,
		rules.shove_cone_deg,
		sim.surfaces,
		rules.step_height
	)
	assert_eq(hits.size(), 1)
	assert_eq([hits[0].shover, hits[0].target, hits[0].direction], [0, 1, Vector2.RIGHT])
	# And the other way round: a live seat in reach that is not a candidate is not hit.
	SimFixtures.place(sim, 1, _at(0.2, 0.0), 180.0)
	var elsewhere := ShoveResolver.Candidate.new(
		1, Vector3(10.0, 0.0, 0.0), rules.body_radius, rules.body_height
	)
	candidates = [elsewhere]
	hits = ShoveResolver.resolve(
		attempts,
		candidates,
		rules.shove_reach,
		rules.shove_cone_deg,
		sim.surfaces,
		rules.step_height
	)
	assert_true(hits.is_empty())
