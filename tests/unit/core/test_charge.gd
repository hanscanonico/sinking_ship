extends GutTest

const SHOVE := InputFrame.SHOVE


func _planar(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)


func _hold(seat: int, move: Vector2 = Vector2.ZERO) -> InputFrame:
	return SimFixtures.frame(seat, move, SHOVE)


## Seat 0 at the origin facing the bow, seat 1 within reach in front of it, facing
## back at it.
func _duel() -> MatchSim:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 180.0)
	return sim


## Seat 0 holds shove for [param ticks] ticks from the press, then lets go for
## [param after] ticks more; returns seat 0's action on each tick, from the press.
func _held_for(sim: MatchSim, ticks: int, after: int) -> Array[int]:
	var phases: Array[int] = []
	for tick in ticks + after:
		SimFixtures.step(sim, {0: _hold(0) if tick < ticks else SimFixtures.frame(0)})
		phases.append(sim.state.seats[0].action)
	return phases


func test_tap_is_a_quick_shove() -> void:
	var rules := SimFixtures.rules()
	var windup := Ticks.from_seconds(rules.shove_windup)
	# A one-tick tap, and a tap held past the windup but short of the threshold: both
	# are quick shoves, thrown at the windup's end or on release, whichever is later.
	for held: int in [1, Ticks.from_seconds(rules.charge_threshold) - 1]:
		var sim := _duel()
		var fired_at := maxi(held, windup)
		# Stepped to the tick it lands on.
		var phases := _held_for(sim, held, fired_at - held + 1)
		assert_eq(phases.find(PlayerState.Action.ACTIVE), fired_at, "held %d: thrown" % held)
		assert_false(PlayerState.Action.CHARGE in phases, "held %d: never a charge" % held)
		var target := sim.state.seats[1]
		assert_true(target.is_staggered(), "held %d: it landed" % held)
		assert_almost_eq(_planar(target.vel).length(), rules.knockback, 0.0001)
		assert_eq(sim.state.seats[0].stamina, rules.stamina_max, "a quick shove is free")


func test_hold_past_threshold_charges() -> void:
	var rules := SimFixtures.rules()
	var threshold := Ticks.from_seconds(rules.charge_threshold)
	var full := Ticks.from_seconds(rules.charge_full)
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
	var player := sim.state.seats[0]
	SimFixtures.step(sim, {0: _hold(0)}, threshold)
	assert_eq(player.action, PlayerState.Action.WINDUP, "not yet")
	SimFixtures.step(sim, {0: _hold(0)})
	assert_eq(player.action, PlayerState.Action.CHARGE, "past the threshold, a charge")
	assert_eq(player.charge, threshold)
	# A charging body walks slowly, and the charge tops out at full.
	SimFixtures.step(sim, {0: _hold(0, Vector2.RIGHT)}, Ticks.RATE)
	assert_eq(player.action, PlayerState.Action.CHARGE, "held, it stays a charge")
	assert_almost_eq(_planar(player.vel).length(), rules.charge_walk, 0.0001, "slow walk")
	assert_eq(player.charge, full)


func test_charged_shove_breaks_a_brace() -> void:
	var rules := SimFixtures.rules()
	var sim := _duel()
	var brace := SimFixtures.frame(1, Vector2.ZERO, InputFrame.BRACE)
	SimFixtures.step(sim, {0: _hold(0), 1: brace}, Ticks.from_seconds(rules.charge_full))
	assert_true(sim.state.seats[1].bracing, "braced, facing the charge")
	assert_eq(sim.state.seats[0].action, PlayerState.Action.CHARGE)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	var target := sim.state.seats[1]
	assert_true(target.is_staggered(), "the brace is broken")
	assert_false(target.bracing)
	assert_almost_eq(_planar(target.vel).length(), rules.charged_knockback, 0.0001, "full force")

	# The shortest charge, let go the tick after it starts, sends one ninth of the way
	# from a quick shove's knockback to a full charge's — and a brace reads it like a
	# quick shove: only the whole charge, glowing the while, breaks one.
	var threshold := Ticks.from_seconds(rules.charge_threshold)
	var full := Ticks.from_seconds(rules.charge_full)
	var short_speed := lerpf(rules.knockback, rules.charged_knockback, 1.0 / (full - threshold))
	for braced: bool in [false, true]:
		var short := _duel()
		var answer := brace if braced else SimFixtures.frame(1)
		SimFixtures.step(short, {0: _hold(0), 1: answer}, threshold + 1)
		assert_eq(short.state.seats[0].action, PlayerState.Action.CHARGE)
		SimFixtures.step(short, {0: SimFixtures.frame(0)})
		var nudged := short.state.seats[1]
		var reduction := rules.brace_reduction if braced else 0.0
		assert_eq(nudged.is_staggered(), not braced, "braced %s: staggered unless braced" % braced)
		assert_almost_eq(
			_planar(nudged.vel).length(),
			short_speed * (1.0 - reduction),
			0.0001,
			"braced %s: a short charge sends less than a full one" % braced
		)


func test_quick_shove_cancels_a_charge() -> void:
	var rules := SimFixtures.rules()
	var sim := _duel()
	var charger := sim.state.seats[1]
	SimFixtures.step(
		sim, {0: SimFixtures.frame(0), 1: _hold(1)}, Ticks.from_seconds(rules.charge_threshold) + 1
	)
	assert_eq(charger.action, PlayerState.Action.CHARGE)
	SimFixtures.step(sim, {0: _hold(0)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.from_seconds(rules.shove_windup))
	assert_true(charger.is_staggered(), "the quick shove lands on the charging body")
	assert_eq(charger.action, PlayerState.Action.IDLE, "its charge is gone")
	assert_eq(charger.charge, 0)
	# Letting go now throws nothing, and costs nothing.
	SimFixtures.step(sim, {1: SimFixtures.frame(1)}, Ticks.RATE)
	assert_false(sim.state.seats[0].is_staggered(), "no charged shove comes back")
	assert_eq(charger.stamina, rules.stamina_max)


func test_charge_costs_stamina_on_release() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
	var player := sim.state.seats[0]
	SimFixtures.step(sim, {0: _hold(0)}, Ticks.from_seconds(rules.charge_full))
	assert_eq(player.action, PlayerState.Action.CHARGE)
	assert_eq(player.stamina, rules.stamina_max, "charging is free")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_eq(player.action, PlayerState.Action.ACTIVE, "released, it is thrown")
	assert_eq(player.stamina, rules.stamina_max - rules.charge_cost, "and paid for")

	# Short of the cost, a hold never becomes a charge: the quick shove goes at the
	# threshold, for nothing.
	var tired := SimFixtures.sim(1)
	SimFixtures.place(tired, 0, Vector3(-8.0, 0.0, 0.0))
	# Just spent, so none comes back while it holds.
	tired.state.seats[0].stamina = rules.charge_cost - 1.0
	tired.state.seats[0].stamina_wait = Ticks.from_seconds(rules.stamina_regen_delay)
	var phases := _held_for(tired, Ticks.from_seconds(rules.charge_threshold) + 1, 0)
	assert_false(PlayerState.Action.CHARGE in phases, "no charge")
	assert_eq(phases.find(PlayerState.Action.ACTIVE), Ticks.from_seconds(rules.charge_threshold))
	assert_eq(tired.state.seats[0].stamina, rules.charge_cost - 1.0)

	# Exhausted, the same: the cost in hand is not enough until the bar is full.
	var exhausted := SimFixtures.sim(1)
	SimFixtures.place(exhausted, 0, Vector3(-8.0, 0.0, 0.0))
	exhausted.state.seats[0].stamina = rules.charge_cost
	exhausted.state.seats[0].exhausted = true
	exhausted.state.seats[0].stamina_wait = Ticks.from_seconds(rules.stamina_regen_delay)
	phases = _held_for(exhausted, Ticks.from_seconds(rules.charge_threshold) + 1, 0)
	assert_false(PlayerState.Action.CHARGE in phases, "exhausted, no charge")
	assert_eq(exhausted.state.seats[0].stamina, rules.charge_cost, "and nothing spent")


func test_a_landing_stagger_cancels_a_charge() -> void:
	var rules := SimFixtures.rules()
	# Charging, it walks off the poop deck onto the main deck below: the hard landing
	# staggers it and takes the charge, so letting go throws nothing and costs nothing.
	var sim := SimFixtures.sim(1, null, SimFixtures.steamer())
	SimFixtures.place(sim, 0, Vector3(-16.0, 1.2, 0.0), 0.0)
	var player := sim.state.seats[0]
	var charging_in_the_air := false
	for _tick in 3 * Ticks.RATE:
		SimFixtures.step(sim, {0: _hold(0, Vector2.RIGHT)})
		if player.body == PlayerState.Body.AIRBORNE:
			charging_in_the_air = (
				charging_in_the_air or player.action == PlayerState.Action.CHARGE
			)
		elif player.is_staggered():
			break
	assert_true(charging_in_the_air, "it went over the edge charging")
	assert_true(player.is_staggered(), "and landed hard")
	SimFixtures.step(sim, {0: _hold(0)})
	assert_eq(player.action, PlayerState.Action.IDLE, "the stagger took the charge")
	assert_eq(player.charge, 0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_eq(player.action, PlayerState.Action.IDLE, "letting go throws nothing")
	assert_eq(player.stamina, rules.stamina_max, "and costs nothing")


func test_a_charged_release_bends_once_from_the_look_at_release() -> void:
	var rules := SimFixtures.rules()
	var threshold := Ticks.from_seconds(rules.charge_threshold)
	var active := Ticks.from_seconds(rules.shove_active)
	var starboard := Vector2(0.0, rules.body_radius * 2.0 + 0.3)
	# Seat 1 stands to starboard, in reach. Seat 0 charges looking at the bow, then,
	# still holding, looks 20° short of seat 1 — inside the autoaim cone — or keeps
	# looking at the bow, and lets go.
	for look_deg: float in [70.0, 0.0]:
		var sim := SimFixtures.sim(2)
		SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
		SimFixtures.place(sim, 1, Vector3(starboard.x, 0.0, starboard.y), -90.0)
		var player := sim.state.seats[0]
		SimFixtures.step(sim, {0: _hold(0)}, threshold + 1)
		assert_eq(player.action, PlayerState.Action.CHARGE)
		var look := InputFrame.yaw_angle(InputFrame.quantize_yaw(deg_to_rad(look_deg)))
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE, look_deg)})
		assert_eq(player.facing, look, "looking %s°: charging, the look turns freely" % look_deg)
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, 0, look_deg)})
		assert_eq(player.action, PlayerState.Action.ACTIVE, "looking %s°: let go" % look_deg)
		assert_eq(player.facing, look, "looking %s°: the view is never bent" % look_deg)
		var bent := player.shove_facing
		if look_deg == 0.0:
			assert_eq(bent, look, "out of the cone: straight where it looks")
		else:
			assert_almost_eq(bent, starboard.angle(), 0.0001, "bent from the look onto seat 1")
		# Through the active window the look swings away; the shove stays where it went.
		var away := {0: SimFixtures.frame(0, Vector2.ZERO, 0, -90.0)}
		for _tick in active:
			SimFixtures.step(sim, away)
			assert_eq(player.shove_facing, bent, "looking %s°: bent once" % look_deg)
		assert_eq(
			sim.state.seats[1].is_staggered(), look_deg != 0.0, "looking %s°: lands" % look_deg
		)
