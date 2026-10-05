extends GutTest
## Every match ends (§5b.1). There is no cap on a match: it ends by the brawl or, once
## she is gone, by the cold, and every match's hit sinks her. So every match ending
## comes to three things, and none of them plays a match that lasts hours (§5b.4):
## every match hit founders within the bake's cap — bakes alone, 200 seeds, the ones
## test_must_sink.gd reads; a match on an explicit fast hit ends by the brawl or the
## cold; and a body inside her as she goes is out with her.

const RunMatch := preload("res://tools/run_match.gd")
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"

const SEEDS := 200
const SEATS := 8
## Once she is gone and everyone swims, the cold meter (4 s) settles it: well within
## this many seconds.
const SETTLED_WITHIN := 30.0


## The default match on [param seed_value], struck by the explicit fast hit.
func _fast_config(seed_value: int) -> MatchConfig:
	var config := RunMatch.default_config(seed_value, SEATS)
	var given: SinkScenario = config.scenario.duplicate()
	given.explicit_hit = load(FAST_HIT)
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
