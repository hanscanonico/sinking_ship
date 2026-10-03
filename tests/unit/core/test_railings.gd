extends GutTest

const SHOVE := InputFrame.SHOVE
## Clear of the railing's gap on either side.
const RAILED_X := -8.0


func _starboard_edge() -> float:
	return SimFixtures.deck().platforms[0].area.end.y


## Where a body's centre stands when it is pressed against the starboard rail.
func _pinned_z() -> float:
	return _starboard_edge() - SimFixtures.rules().body_radius


## Seat 0 at [param shover_z] facing starboard throws one quick shove at seat 1 at
## [param target_z], both at [param x]; steps [param ticks] and returns the events.
func _shove_to_starboard(
	sim: MatchSim, x: float, shover_z: float, target_z: float, ticks: int = 3 * Ticks.RATE
) -> Array[SimEvent]:
	SimFixtures.place(sim, 0, Vector3(x, 0.0, shover_z), 90.0)
	SimFixtures.place(sim, 1, Vector3(x, 0.0, target_z), -90.0)
	var events: Array[SimEvent] = []
	for tick in ticks:
		var buttons := SHOVE if tick == 0 else 0
		var frames := {0: SimFixtures.frame(0, Vector2.ZERO, buttons), 1: SimFixtures.frame(1)}
		events.append_array(SimFixtures.step(sim, frames))
		if sim.is_over():
			break
	return events


## Seat 1, standing [param to_rail] metres short of touching the starboard rail,
## takes a quick shove toward it.
func _shove_from(sim: MatchSim, to_rail: float) -> Array[SimEvent]:
	var rules := SimFixtures.rules()
	var target_z := _pinned_z() - to_rail
	var shover_z := target_z - rules.body_radius * 2.0 - 0.3
	return _shove_to_starboard(sim, RAILED_X, shover_z, target_z)


func _vaults(events: Array[SimEvent]) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.VAULTED)


func test_walking_into_a_railing_is_stopped() -> void:
	var rules := SimFixtures.rules()
	var area := SimFixtures.deck().platforms[0].area
	var walks := {
		Vector2.DOWN: area.end.y - rules.body_radius,
		Vector2.UP: area.position.y + rules.body_radius,
	}
	for direction: Vector2 in walks:
		var sim := SimFixtures.sim(1)
		SimFixtures.place(sim, 0, Vector3(RAILED_X, 0.0, 0.0))
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, direction)}, 2 * Ticks.RATE)
		var player := sim.state.seats[0]
		assert_eq(player.body, PlayerState.Body.GROUNDED, "%s: still on deck" % direction)
		assert_eq(player.surface, 0)
		assert_almost_eq(player.pos.z, walks[direction], 0.0001, "%s: at the rail" % direction)
		assert_almost_eq(player.vel.z, 0.0, 0.0001, "%s: no speed into it" % direction)
		assert_true(_vaults(events).is_empty(), "walking pace never tips you over")


func test_quick_shove_from_mid_deck_is_held_by_the_rail() -> void:
	var rules := SimFixtures.rules()
	# Between the centreline and the rail: far enough that the slide has slowed
	# below vault_speed when it reaches the rail, near enough that it would carry
	# the body over an open edge.
	var target_z := 1.5
	var shover_z := target_z - rules.body_radius * 2.0 - 0.3
	var railed := SimFixtures.sim(2)
	var events := _shove_to_starboard(railed, RAILED_X, shover_z, target_z)
	var target := railed.state.seats[1]
	assert_true(_vaults(events).is_empty(), "no vault")
	assert_false(target.is_out())
	assert_eq(target.body, PlayerState.Body.GROUNDED)
	assert_almost_eq(target.pos.z, _pinned_z(), 0.0001, "it reached the rail, which held it")

	var open := SimFixtures.sim(2)
	var gap := SimFixtures.rail_gap(_starboard_edge())
	_shove_to_starboard(open, gap.x, shover_z, target_z)
	assert_true(open.state.seats[1].is_out(), "the same shove through the gap goes over")


func test_quick_shove_when_pinned_vaults() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	var target_z := _pinned_z()
	SimFixtures.place(
		sim, 0, Vector3(RAILED_X, 0.0, target_z - rules.body_radius * 2.0 - 0.3), 90.0
	)
	SimFixtures.place(sim, 1, Vector3(RAILED_X, 0.0, target_z), -90.0)
	var events: Array[SimEvent] = []
	var vaulted_at := -1
	for tick in 3 * Ticks.RATE:
		var buttons := SHOVE if tick == 0 else 0
		var frames := {0: SimFixtures.frame(0, Vector2.ZERO, buttons), 1: SimFixtures.frame(1)}
		var stepped := SimFixtures.step(sim, frames)
		events.append_array(stepped)
		if vaulted_at == -1 and not _vaults(stepped).is_empty():
			vaulted_at = tick
			# On the vault's tick the body tips over with a small lift.
			var target := sim.state.seats[1]
			assert_eq(target.body, PlayerState.Body.AIRBORNE)
			assert_eq(target.surface, Surfaces.NONE)
			assert_almost_eq(target.vel.y, rules.vault_lift, 0.0001)
			assert_gte(target.vel.z, rules.vault_speed, "going over at vault speed")
		if sim.is_over():
			break
	var vaults := _vaults(events)
	assert_eq(vaults.size(), 1, "one vault")
	assert_eq(vaults[0].seat, 1)
	var outs := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.SEAT_OUT
	)
	assert_eq(outs.size(), 1, "over the rail and into the sea")
	assert_eq([outs[0].seat, outs[0].credit], [1, 0], "credited to the shover")
	assert_gt(outs[0].tick, vaults[0].tick)


func test_downhill_shove_vaults_from_farther() -> void:
	var rules := SimFixtures.rules()
	var to_rail := 1.2
	var level := SimFixtures.sim(2)
	assert_true(_vaults(_shove_from(level, to_rail)).is_empty(), "level: held from %s m" % to_rail)
	assert_false(level.state.seats[1].is_out())

	# Starboard down, still short of the grip angle: shoved starboard is shoved downhill.
	var downhill := SimFixtures.sim(2, SimFixtures.tilted(0.0, rules.grip_angle_deg - 4.0))
	var events := _shove_from(downhill, to_rail)
	assert_eq(_vaults(events).size(), 1, "downhill: over from %s m" % to_rail)
	assert_true(downhill.state.seats[1].is_out())

	# Uphill, the same shove does not even reach the rail at speed.
	var uphill := SimFixtures.sim(2, SimFixtures.tilted(0.0, -(rules.grip_angle_deg - 4.0)))
	assert_true(_vaults(_shove_from(uphill, to_rail)).is_empty(), "uphill: held")


func test_gap_lets_a_body_through() -> void:
	var gap := SimFixtures.rail_gap(_starboard_edge())
	# Just aft of the gap the railing runs again: a centre there is over the span,
	# though its circle hangs into the gap.
	var beside_x := _gap_start(gap) - SimFixtures.rules().body_radius * 0.5
	var sim := SimFixtures.sim(3)
	SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, 0.0))
	SimFixtures.place(sim, 1, Vector3(beside_x, 0.0, 0.0))
	SimFixtures.place(sim, 2, Vector3(-12.0, 0.0, 0.0))
	var to_starboard := {
		0: SimFixtures.frame(0, Vector2.DOWN), 1: SimFixtures.frame(1, Vector2.DOWN)
	}
	var events := SimFixtures.step(sim, to_starboard, 3 * Ticks.RATE)
	var walker := sim.state.seats[0]
	assert_true(walker.is_out(), "walked out through the gap and into the sea")
	assert_gt(walker.pos.z, _starboard_edge(), "past the edge")
	var beside := sim.state.seats[1]
	assert_eq(beside.body, PlayerState.Body.GROUNDED, "beside the gap: still on deck")
	assert_almost_eq(beside.pos.z, _pinned_z(), 0.0001, "beside the gap: held by the rail")
	assert_almost_eq(beside.pos.x, beside_x, 0.0001)
	assert_true(_vaults(events).is_empty(), "no railing to tip over")


## The gap's aft side: where the span aft of [param gap] ends.
func _gap_start(gap: Vector2) -> float:
	var start := -INF
	for railing: ShipRailing in SimFixtures.deck().railings:
		var forward_end := maxf(railing.from.x, railing.to.x)
		if is_equal_approx(railing.from.y, gap.y) and forward_end < gap.x:
			start = maxf(start, forward_end)
	return start
