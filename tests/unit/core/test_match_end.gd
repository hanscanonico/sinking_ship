extends GutTest
## Every match ends (§5b.1). There is no cap on a match: it ends by the brawl or, once
## she is gone, by the cold, and every match's hit sinks her. So every match ending
## comes to three things, and none of them plays a match that lasts hours (§5b.4):
## every match hit founders within the bake's cap — bakes alone, 200 seeds, the ones
## test_must_sink.gd reads; a match on an explicit fast hit ends by the brawl or the
## cold; a body inside her as she goes is out with her; and until SH32 a match does not
## follow her past the attitude it supports (§5b.3's interim rule).

const RunMatch := preload("res://tools/run_match.gd")
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"
## A wide gash forward: by the head she stands past 45° a minute and more before she
## is gone.
const STEEP_HIT := "res://tests/fixtures/sinking/hits/steep.tres"

const SEEDS := 200
const SEATS := 8
## Once she is gone and everyone swims, the cold meter (4 s) settles it: well within
## this many seconds.
const SETTLED_WITHIN := 30.0


## The default match on [param seed_value], struck by the explicit hit at [param path] —
## the fast one unless told.
func _fast_config(seed_value: int, path: String = FAST_HIT) -> MatchConfig:
	var config := RunMatch.default_config(seed_value, SEATS)
	var given: SinkScenario = config.scenario.duplicate()
	given.explicit_hit = load(path)
	config.scenario = given
	return config


func test_match_always_ends() -> void:
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var afloat := 0
	for choice: MustSink.Choice in SimFixtures.match_hits(SEEDS):
		if not choice.timeline.is_gone() or choice.timeline.gone_at > scenario.bake_cap:
			afloat += 1
	assert_eq(afloat, 0, "every match hit of %d founders within the cap" % SEEDS)
	var runner := RunMatch.bots_only(_fast_config(1))
	var gone := runner.sim.schedule.gone_tick()
	assert_between(gone, 0, Ticks.from_seconds(5.0 * 60.0), "the fast hit has her gone in 5 min")
	var ended: SimEvent = null
	var bound := gone + Ticks.from_seconds(SETTLED_WITHIN)
	while not runner.is_over() and runner.tick() <= bound:
		for event: SimEvent in runner.step():
			if event.kind == SimEvent.Kind.MATCH_ENDED:
				ended = event
	assert_not_null(ended, "the match on the fast hit ends")
	if ended != null:
		assert_lte(ended.tick, bound, "by the brawl, or by the cold once she is gone")


func test_a_body_inside_her_as_she_goes_is_out_with_her() -> void:
	var config := _fast_config(2)
	config.seats = 3
	var sim := MatchSim.create(config)
	var gone := sim.schedule.gone_tick()
	var layout := config.ship
	# The tick before she goes: one in the saloon, two swimming clear of her on the sea.
	sim.state.tick = gone - 1
	sim.state.phase = MatchState.Phase.LIVE
	SimFixtures.place(sim, 0, Vector3(1.5, 0.0, 0.0))
	SimFixtures.swim(sim, 1, Vector3(0.0, 0.0, 12.0))
	SimFixtures.swim(sim, 2, Vector3(0.0, 0.0, -12.0))
	assert_ne(sim.pose().cell_at(sim.state.seats[0].pos), CellMap.NONE, "seat 0 is inside her")
	var outs: Array[int] = []
	for event: SimEvent in SimFixtures.step(sim, {}, 2):
		if event.kind == SimEvent.Kind.SEAT_OUT:
			outs.append(event.seat)
	assert_eq(outs, [0] as Array[int], "the one inside goes with her, the swimmers swim on")
	assert_eq(sim.state.seats[0].out_tick, gone, "on the tick she goes")
	assert_eq(layout.structure.cell_named(&"saloon"), sim.pose().cell_at(Vector3(1.5, 0.0, 0.0)))


func test_the_match_settles_once_she_leans_past_what_it_follows() -> void:
	var config := _fast_config(3, STEEP_HIT)
	config.seats = 3
	var sim := MatchSim.create(config)
	var over := sim.schedule.unsupported_tick()
	assert_gt(over, 0, "the steep hit leans her past 45°")
	assert_lt(over, sim.schedule.gone_tick(), "before she is gone")
	# The tick before: three on her decks, each with a different cold left.
	sim.state.tick = over - 1
	sim.state.phase = MatchState.Phase.LIVE
	for seat in 3:
		SimFixtures.place(sim, seat, Vector3(-2.0 + seat * 2.0, 2.5, 0.0))
		sim.state.seats[seat].cold = 1.0 + seat
	var outs: Array[SimEvent] = []
	var ended: SimEvent = null
	for event: SimEvent in SimFixtures.step(sim, {}, 2):
		if event.kind == SimEvent.Kind.SEAT_OUT:
			outs.append(event)
		elif event.kind == SimEvent.Kind.MATCH_ENDED:
			ended = event
	assert_eq(outs.size(), 3, "everyone left goes out together")
	for event: SimEvent in outs:
		assert_eq(event.tick, over, "on the tick she passes it")
		assert_eq(event.place, 3 - event.seat, "the warmest placed first")
	assert_not_null(ended, "and the match is over")
