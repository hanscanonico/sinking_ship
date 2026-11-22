extends GutTest
## A body a crate runs into or presses on is held by her walls as a walking or shoved one
## is: the crate never puts it into a wall, so it never comes out of the wall's far side —
## and the crate stops against it as against the wall, given no speed by what the wall
## holds back.

## The wall: a thin bulkhead across the flat deck, its near face at WALL_X.
const WALL_X := 2.0
const WALL_THICK := 0.2
## A second wall, for a corner: along the deck up to the first, its near face at CORNER_Z.
const CORNER_Z := 1.0
## What no rounding of a contact reaches across.
const TOLERANCE := 0.001


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func _wall(area: Rect2) -> ShipBlocker:
	var wall := ShipBlocker.new()
	wall.area = area
	wall.top = 2.3
	return wall


## The flat deck with the wall across it — and, [param cornered], the second wall making a
## corner with it — one crate at [param crate_at], trimmed [param slope_deg] down toward
## the wall and heeled [param heel_deg] along it, and seat 0 standing against the wall's
## near face at [param seat_z].
func _against_the_wall(
	crate_at: Vector3, slope_deg: float, heel_deg := 0.0, seat_z := 0.0, cornered := false
) -> MatchSim:
	var blockers: Array[ShipBlocker] = [_wall(Rect2(WALL_X, -2.0, WALL_THICK, 4.0))]
	if cornered:
		blockers.append(_wall(Rect2(WALL_X - 4.0, CORNER_Z, 4.0, WALL_THICK)))
	var layout := SimFixtures.deck().duplicate()
	layout.blockers = blockers
	var crates: Array[ShipProp] = [SimFixtures.crate(crate_at)]
	var sim := SimFixtures.sim(
		1, SimFixtures.tilted(slope_deg, heel_deg), SimFixtures.crated(crates, layout)
	)
	SimFixtures.place(sim, 0, Vector3(WALL_X - _rules().body_radius, 0.0, seat_z))
	return sim


## Steps [param sim] [param ticks] ticks, seat 0 idle, asserting after each that the seat
## is on the wall's near side and no further into it than TOLERANCE — and, [param cornered],
## the same of the second wall. Returns the events.
func _held_through(sim: MatchSim, ticks: int, cornered := false) -> Array[SimEvent]:
	var player := sim.state.seats[0]
	var nearest := WALL_X - _rules().body_radius
	var nearest_z := CORNER_Z - _rules().body_radius if cornered else INF
	var events: Array[SimEvent] = []
	for tick in ticks:
		events.append_array(SimFixtures.step(sim))
		if player.pos.x > nearest + TOLERANCE or player.pos.z > nearest_z + TOLERANCE:
			fail_test(
				(
					"tick %d: the seat at (%.3f, %.3f) is in a wall, or past it (held at %.3f, %.3f)"
					% [tick, player.pos.x, player.pos.z, nearest, nearest_z]
				)
			)
			break
	return events


func test_a_crate_s_hit_knocks_no_body_through_a_wall() -> void:
	var rules := _rules()
	var sim := _against_the_wall(Vector3(WALL_X - 2.5, 0.0, 0.0), 12.0)
	var crate := sim.state.props[0]
	crate.vel = Vector3(rules.crate_impact_speed + 2.0, 0.0, 0.0)
	var events := _held_through(sim, 4 * Ticks.RATE)
	var hits := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.PROP_HIT
	)
	assert_false(hits.is_empty(), "the crate hits the seat")
	var player := sim.state.seats[0]
	assert_almost_eq(player.pos.x, WALL_X - rules.body_radius, TOLERANCE, "held by the wall")
	assert_lte(
		crate.pos.x,
		player.pos.x - rules.body_radius - SimFixtures.crate(Vector3.ZERO).radius + TOLERANCE,
		"and the crate is held by the seat"
	)


func test_a_crate_s_hit_knocks_no_body_in_the_air_through_a_wall() -> void:
	var rules := _rules()
	var reach := rules.body_radius + SimFixtures.crate(Vector3.ZERO).radius
	var at := WALL_X - rules.body_radius
	var sim := _against_the_wall(Vector3(at - reach - 0.3, 0.0, 0.0), 12.0)
	# The seat falling by the wall, the crate reaching it before it lands.
	SimFixtures.fly(sim, 0, Vector3(at, 0.25, 0.0), Vector3.ZERO)
	sim.state.props[0].vel = Vector3(rules.crate_impact_speed + 2.0, 0.0, 0.0)
	var events := _held_through(sim, 2 * Ticks.RATE)
	var kinds := events.map(func(event: SimEvent) -> int: return event.kind)
	var hit := kinds.find(SimEvent.Kind.PROP_HIT)
	assert_ne(hit, -1, "the crate hits the seat")
	assert_lt(hit, kinds.find(SimEvent.Kind.LANDED), "before it lands")
	assert_almost_eq(sim.state.seats[0].pos.x, at, TOLERANCE, "held by the wall")


func test_a_crate_pressing_a_body_on_a_wall_puts_it_into_none() -> void:
	var rules := _rules()
	var reach := rules.body_radius + SimFixtures.crate(Vector3.ZERO).radius
	# The crate starts touching the seat, and her heel leans it on: a push, never a hit.
	var sim := _against_the_wall(Vector3(WALL_X - rules.body_radius - reach, 0.0, 0.0), 12.0)
	var events := _held_through(sim, 4 * Ticks.RATE)
	var hits := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.PROP_HIT
	)
	assert_true(hits.is_empty(), "a push, no hit")
	var player := sim.state.seats[0]
	var crate := sim.state.props[0]
	assert_almost_eq(player.pos.x, WALL_X - rules.body_radius, TOLERANCE, "held by the wall")
	assert_lte(crate.pos.x, player.pos.x - reach + TOLERANCE, "the crate held by the seat")
	assert_almost_eq(crate.vel.x, 0.0, TOLERANCE, "and stopped, as against the wall")


func test_a_crate_pressing_a_body_into_a_corner_puts_it_through_neither_wall() -> void:
	var rules := _rules()
	var reach := rules.body_radius + SimFixtures.crate(Vector3.ZERO).radius
	var corner := Vector3(WALL_X - rules.body_radius, 0.0, CORNER_Z - rules.body_radius)
	# The crate touching the seat from the open quarter, her trim and her heel leaning it on.
	var crate_at := corner - Vector3(1.0, 0.0, 1.0).normalized() * reach
	var sim := _against_the_wall(crate_at, 12.0, 12.0, corner.z, true)
	_held_through(sim, 4 * Ticks.RATE, true)
	var player := sim.state.seats[0]
	assert_almost_eq(player.pos.x, corner.x, TOLERANCE, "held by the one wall")
	assert_almost_eq(player.pos.z, corner.z, TOLERANCE, "and by the other")


func test_a_crate_still_pushes_a_body_along_a_wall() -> void:
	var rules := _rules()
	var reach := rules.body_radius + SimFixtures.crate(Vector3.ZERO).radius
	var at := WALL_X - rules.body_radius
	# The crate behind the seat along the wall, her heel leaning it on, the seat's side
	# touching the wall all the way.
	var sim := _against_the_wall(Vector3(at, 0.0, -1.0 - reach), 0.0, 12.0, -1.0)
	_held_through(sim, 2 * Ticks.RATE)
	var player := sim.state.seats[0]
	var crate := sim.state.props[0]
	assert_gt(player.pos.z, -1.0 + 0.2, "pushed on along the wall")
	assert_gt(crate.pos.z, -1.0 - reach + 0.2, "the crate going on behind it")


## What the wall takes of a body's speed is no speed of the crate's: the seat is sent as a
## shove sends it (MatchSim) — staggered, its speed held through the hit-stop — along the
## wall toward the side the crate leans on it from, and into the wall.
func test_a_body_sent_along_the_wall_at_the_crate_pressing_it_throws_no_crate() -> void:
	var rules := _rules()
	var reach := rules.body_radius + SimFixtures.crate(Vector3.ZERO).radius
	var from := Vector3(cos(deg_to_rad(35.0)), 0.0, sin(deg_to_rad(35.0)))
	var seat_at := Vector3(WALL_X - rules.body_radius, 0.0, 0.0)
	var sim := _against_the_wall(seat_at - from * reach, 12.0)
	_held_through(sim, 3)
	var player := sim.state.seats[0]
	var crate := sim.state.props[0]
	player.stagger_ticks = Ticks.from_seconds(rules.stagger)
	var along := Vector3(sin(deg_to_rad(30.0)), 0.0, -cos(deg_to_rad(30.0)))
	player.freeze(along * rules.knockback, Ticks.from_seconds(rules.hitstop))
	var fastest := 0.0
	for tick in Ticks.RATE:
		_held_through(sim, 1)
		fastest = maxf(fastest, Vector2(crate.vel.x, crate.vel.z).length())
		if is_failing():
			break
	assert_lt(fastest, rules.crate_impact_speed, "the crate is thrown at nobody")
