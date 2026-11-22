extends GutTest
## A body a crate runs into or presses on is held by her walls as a walking or shoved one
## is: the crate never puts it into a wall, so it never comes out of the wall's far side.

## The wall: a thin bulkhead across the flat deck, its near face at WALL_X.
const WALL_X := 2.0
const WALL_THICK := 0.2
## What no rounding of a contact reaches across.
const TOLERANCE := 0.001


func _rules() -> BrawlRules:
	return SimFixtures.rules()


## The flat deck with the wall across it, one crate at [param crate_at], trimmed
## [param slope_deg] down toward the wall — or heeled [param heel_deg] along it — and
## seat 0 standing against the wall's near face at [param seat_z].
func _against_the_wall(
	crate_at: Vector3, slope_deg: float, heel_deg := 0.0, seat_z := 0.0
) -> MatchSim:
	var wall := ShipBlocker.new()
	wall.area = Rect2(WALL_X, -2.0, WALL_THICK, 4.0)
	wall.top = 2.3
	var layout := SimFixtures.deck().duplicate()
	var blockers: Array[ShipBlocker] = [wall]
	layout.blockers = blockers
	var crates: Array[ShipProp] = [SimFixtures.crate(crate_at)]
	var sim := SimFixtures.sim(
		1, SimFixtures.tilted(slope_deg, heel_deg), SimFixtures.crated(crates, layout)
	)
	SimFixtures.place(sim, 0, Vector3(WALL_X - _rules().body_radius, 0.0, seat_z))
	return sim


## Steps [param sim] [param ticks] ticks, seat 0 idle, asserting after each that the seat
## is on the wall's near side and no further into it than TOLERANCE. Returns the events.
func _held_through(sim: MatchSim, ticks: int) -> Array[SimEvent]:
	var player := sim.state.seats[0]
	var nearest := WALL_X - _rules().body_radius
	var events: Array[SimEvent] = []
	for tick in ticks:
		events.append_array(SimFixtures.step(sim))
		if player.pos.x > nearest + TOLERANCE:
			fail_test(
				(
					"tick %d: the seat at x %.3f is in the wall, or past it (held at %.3f)"
					% [tick, player.pos.x, nearest]
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
