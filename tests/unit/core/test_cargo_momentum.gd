extends GutTest
## Cargo keeps its momentum (§6, SH10): a crate running into another hands it its speed
## by their masses — parting with crate_restitution of the speed they met at, from
## crate_impact_speed up, and going on together below it — and its shover with it; a
## staggered body slamming into a crate at crate_impact_speed or more sends it sliding
## the same way, the crate credited to the shove that sent the body. A body on its feet
## leans on a crate as on a wall: a laden crate does not give to a walk.

const SHOVE := InputFrame.SHOVE


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func _crate() -> ShipProp:
	return SimFixtures.steamer().props[0]


## The flat deck on an even keel carrying a crate at each of [param at], with
## [param seats] seats standing well clear astern.
func _crates(seats: int, at: Array[Vector3]) -> MatchSim:
	var crates: Array[ShipProp] = []
	for point: Vector3 in at:
		crates.append(SimFixtures.crate(point))
	var sim := SimFixtures.sim(seats, null, SimFixtures.crated(crates))
	for seat in seats:
		SimFixtures.place(sim, seat, Vector3(-12.0, 0.0, -3.0 + seat * 1.5))
	return sim


## Two crates on the deck toward the bow, the second two centimetres past the first's
## side — met within the tick's move — the first sliding into it at [param speed].
func _crate_into_crate(speed: float) -> MatchSim:
	var touch := _crate().radius * 2.0
	var sim := _crates(1, [Vector3(-2.0, 0.0, 0.0), Vector3(-2.0 + touch + 0.02, 0.0, 0.0)])
	sim.state.props[0].vel = Vector3(speed, 0.0, 0.0)
	return sim


func test_a_crate_running_into_another_hands_it_its_speed() -> void:
	var rules := _rules()
	var speed := 3.0
	var sim := _crate_into_crate(speed)
	SimFixtures.step(sim)
	# The deck's friction takes its share before the move: the speed they meet at.
	var meeting := speed - _crate().friction * Ticks.SECONDS_PER_TICK
	assert_gte(meeting, rules.crate_impact_speed, "an impact")
	var runner := sim.state.props[0].vel
	var struck := sim.state.props[1].vel
	# The two crates weigh the same: what one loses, the other gains.
	assert_almost_eq(runner.x + struck.x, meeting, 0.0001, "the speed is shared, never lost")
	assert_almost_eq(
		struck.x - runner.x, meeting * rules.crate_restitution, 0.0001, "parting at the restitution"
	)
	assert_gt(runner.x, 0.0, "the runner goes on, slower: no dead stop")
	assert_almost_eq(struck.z, 0.0, 0.0001, "along the line between them")


func test_a_slow_crate_pushes_another_on_with_it() -> void:
	var rules := _rules()
	var speed := 1.5
	var sim := _crate_into_crate(speed)
	SimFixtures.step(sim)
	var meeting := speed - _crate().friction * Ticks.SECONDS_PER_TICK
	assert_lt(meeting, rules.crate_impact_speed, "no impact")
	assert_almost_eq(sim.state.props[0].vel.x, meeting * 0.5, 0.0001, "they go on together")
	assert_almost_eq(sim.state.props[1].vel.x, meeting * 0.5, 0.0001)


func test_a_shoved_crate_passes_its_shover_on_to_the_crate_it_hits() -> void:
	var rules := _rules()
	var radius := _crate().radius
	var first := Vector3(rules.body_radius + radius + 0.3, 0.0, 0.0)
	var second := first + Vector3(radius * 2.0 + 0.5, 0.0, 0.0)
	var sim := _crates(1, [first, second])
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	var struck := sim.state.props[1]
	assert_gt(struck.pos.x, second.x, "the second crate is sent sliding")
	assert_eq(struck.shoved_by, 0, "and whoever shoved the first is what sent it")


func test_a_flying_body_slams_a_crate_into_a_slide() -> void:
	var rules := _rules()
	var crate_at := Vector3(-2.0, 0.0, 0.0)
	var sim := _crates(2, [crate_at])
	var speed := rules.knockback
	var body := sim.state.seats[0]
	SimFixtures.place(sim, 0, crate_at - Vector3(rules.body_radius + _crate().radius + 0.05, 0, 0))
	body.vel = Vector3(speed, 0.0, 0.0)
	body.stagger_ticks = Ticks.from_seconds(rules.stagger)
	# Seat 1's shove sent it, a tick ago.
	body.last_hit_by = 1
	body.last_hit_at = 0
	SimFixtures.step(sim)
	var dt := Ticks.SECONDS_PER_TICK
	var meeting := speed - rules.stagger_friction * dt
	var crate := sim.state.props[0]
	var mass := _crate().mass
	var total := mass + rules.body_mass
	var sent := (1.0 + rules.crate_restitution) * rules.body_mass / total * meeting
	# The cargo steps after the bodies: the deck's friction has had its share of the tick.
	var slid := crate.vel.x + _crate().friction * dt
	assert_almost_eq(slid, sent, 0.0001, "the crate takes its share, by the masses")
	var momentum := body.vel.x * rules.body_mass + slid * mass
	assert_almost_eq(momentum, meeting * rules.body_mass, 0.001, "and none is lost")
	assert_eq(crate.shoved_by, 1, "credited to the shove that sent the body")
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_gt(crate.pos.x, crate_at.x + 0.5, "sliding on down the deck")


func test_a_walker_leans_on_a_crate_as_on_a_wall() -> void:
	var rules := _rules()
	var crate_at := Vector3(-2.0, 0.0, 0.0)
	var sim := _crates(1, [crate_at])
	SimFixtures.place(sim, 0, crate_at - Vector3(rules.body_radius + _crate().radius + 1.0, 0, 0))
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE)
	var crate := sim.state.props[0]
	assert_eq(crate.pos, crate_at, "a walk does not move a laden crate")
	assert_eq(crate.vel, Vector3.ZERO)
	var touching := crate_at.x - rules.body_radius - _crate().radius
	assert_almost_eq(sim.state.seats[0].pos.x, touching, 0.0001, "the walker stands against it")
