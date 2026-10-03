extends GutTest

## Just past the starboard edge of the flat deck: nothing underneath.
const OVERBOARD_Z := 4.5


func _overboard(sim: MatchSim, seat: int, x: float) -> void:
	SimFixtures.place(sim, seat, Vector3(x, 0.0, OVERBOARD_Z))


## Steps until [param seat] is out; returns every exit and verdict on the way.
func _until_out(sim: MatchSim, seat: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _tick in 300:
		events.append_array(_exits(SimFixtures.step(sim)))
		if sim.state.seats[seat].is_out():
			break
	assert_true(sim.state.seats[seat].is_out(), "seat %d went out" % seat)
	return events


## [param events] without the falls: the seats out and the verdict.
func _exits(events: Array[SimEvent]) -> Array[SimEvent]:
	return events.filter(
		func(event: SimEvent) -> bool:
			return event.kind == SimEvent.Kind.SEAT_OUT or event.kind == SimEvent.Kind.MATCH_ENDED
	)


func test_feet_below_the_plane_is_out() -> void:
	var flooding := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [30.0, 2.0, 10.0, 0.0]])
	var sim := SimFixtures.sim(2, flooding)
	var at_the_bow := Vector3(14.0, 0.0, 0.0)
	SimFixtures.place(sim, 0, at_the_bow)
	SimFixtures.place(sim, 1, Vector3(-14.0, 0.0, 0.0))
	var wet_from := -1
	for tick in 30 * Ticks.RATE:
		if sim.surfaces.wet(at_the_bow, sim.schedule.pose_at(tick)):
			wet_from = tick
			break
	assert_gt(wet_from, 0)
	SimFixtures.step(sim, {}, wet_from)
	assert_false(sim.state.seats[0].is_out(), "dry until the water reaches its feet")
	var events := SimFixtures.step(sim)
	var bow := sim.state.seats[0]
	assert_true(bow.is_out(), "out the tick its feet are under")
	assert_eq(bow.out_tick, wet_from)
	assert_eq(bow.out_cause, PlayerState.Cause.WATER)
	assert_eq(bow.place, 2)
	assert_false(sim.state.seats[1].is_out(), "the stern is still dry")
	assert_eq(events[0].kind, SimEvent.Kind.SEAT_OUT)
	assert_eq([events[0].seat, events[0].place, events[0].credit], [0, 2, -1])


func test_last_one_dry_wins() -> void:
	var sim := SimFixtures.sim(3)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.place(sim, 2, Vector3(-8.0, 0.0, 0.0))
	_overboard(sim, 1, 6.0)
	var events := _until_out(sim, 1)
	assert_eq(sim.state.seats[1].place, 3)
	assert_eq(sim.state.phase, MatchState.Phase.LIVE)
	_overboard(sim, 2, -8.0)
	events.append_array(_until_out(sim, 2))
	assert_eq(sim.state.seats[2].place, 2)
	assert_eq(sim.state.phase, MatchState.Phase.ENDED)
	assert_eq(sim.state.winner(), 0)
	assert_eq(sim.state.seats[0].place, 1)
	var last := events.back() as SimEvent
	assert_eq([last.kind, last.seat], [SimEvent.Kind.MATCH_ENDED, 0])

	var ended_at := sim.state.tick
	assert_true(SimFixtures.step(sim, {}, 10).is_empty(), "nothing happens after the end")
	assert_eq(sim.state.tick, ended_at)


func test_same_tick_exits_share_a_place() -> void:
	var sim := SimFixtures.sim(4)
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
	SimFixtures.place(sim, 3, Vector3(8.0, 0.0, 0.0))
	_overboard(sim, 1, -2.0)
	_overboard(sim, 2, 2.0)
	var events := _until_out(sim, 1)
	assert_true(sim.state.seats[2].is_out())
	assert_eq(sim.state.seats[1].out_tick, sim.state.seats[2].out_tick)
	assert_eq(sim.state.seats[1].place, 3)
	assert_eq(sim.state.seats[2].place, 3)
	assert_eq(events.size(), 2, "two exits, no verdict")
	assert_eq(sim.state.phase, MatchState.Phase.LIVE)


func test_shove_credit_outlasts_the_stagger() -> void:
	# Seat 0 shoves seat 1 toward the starboard edge, through the railing's gap, from
	# far enough that the stagger ends on the deck and the leftover slide carries it
	# over: still seat 0's kill.
	var sim := SimFixtures.sim(2)
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, 0.2), 90.0)
	SimFixtures.place(sim, 1, Vector3(gap.x, 0.0, 1.3), -90.0)
	var shove := {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE, 90.0)}
	var events: Array[SimEvent] = []
	var hit := false
	var stagger_ended_on_deck := false
	for _tick in 120:
		events.append_array(_exits(SimFixtures.step(sim, shove)))
		var target := sim.state.seats[1]
		hit = hit or target.is_staggered()
		if hit and not target.is_staggered() and target.body == PlayerState.Body.GROUNDED:
			stagger_ended_on_deck = true
		if target.is_out():
			break
	assert_true(hit, "the shove landed")
	assert_true(stagger_ended_on_deck, "the stagger ran out before the edge")
	assert_true(sim.state.seats[1].is_out(), "and the slide carried it over")
	var outs := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.SEAT_OUT
	)
	assert_eq([outs[0].seat, outs[0].credit], [1, 0], "credited to the shover")


func test_everyone_out_together_is_a_draw() -> void:
	var sim := SimFixtures.sim(3)
	for seat in 3:
		_overboard(sim, seat, -6.0 + 6.0 * seat)
	var events := _until_out(sim, 0)
	for seat in 3:
		assert_true(sim.state.seats[seat].is_out())
		assert_eq(sim.state.seats[seat].place, 1, "seat %d shares the top place" % seat)
	assert_eq(sim.state.phase, MatchState.Phase.ENDED)
	assert_eq(sim.state.winner(), -1)
	var last := events.back() as SimEvent
	assert_eq([last.kind, last.seat], [SimEvent.Kind.MATCH_ENDED, -1])
