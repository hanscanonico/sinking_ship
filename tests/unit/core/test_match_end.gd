extends GutTest
## Every match ends (§5b.1). There is no cap on a match: it ends by the brawl or, once
## she is gone, by the cold, and every match's hit sinks her. So every match ending
## comes to three things, and none of them plays a match that lasts hours (§5b.4):
## every match hit founders within the bake's cap — bakes alone, the seeds
## test_must_sink.gd reads (`make census` bakes 200 in every PR that changes the
## physics); a match on an explicit fast hit ends by the brawl or the
## cold; a body inside her as she goes is out with her; and a match follows her past any
## attitude (SH32), standing on whichever of her faces turn up.

const RunMatch := preload("res://tools/run_match.gd")
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"
## A wide gash forward: by the head she stands past 45° a minute and more before she
## is gone.
const STEEP_HIT := "res://tests/fixtures/sinking/hits/steep.tres"

const SEEDS := 40
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


func test_the_match_follows_her_onto_another_face() -> void:
	# SH27's interim rule is gone (SH32): past 45° nobody goes out — the match stands on
	# whichever of her faces turn up, and her bodies fall onto them.
	var config := _fast_config(3, STEEP_HIT)
	config.seats = 3
	var sim := MatchSim.create(config)
	var rules := config.rules
	var turned := -1
	for tick in range(sim.schedule.hit_tick(), sim.schedule.gone_tick()):
		var up := Faces.up_after(sim.schedule.pose_at(tick), Faces.Up.DECK, rules.brace_holds_to)
		if up != Faces.Up.DECK:
			turned = tick
			break
	assert_gt(turned, 0, "the steep hit stands her past the band before she is gone")
	sim.state.tick = turned - 1
	sim.state.phase = MatchState.Phase.LIVE
	for seat in 3:
		SimFixtures.place(sim, seat, Vector3(-2.0 + seat * 2.0, 2.5, 0.0))
	var events := SimFixtures.step(sim, {}, 2)
	assert_ne(sim.state.up, Faces.Up.DECK, "the match stands on another face of her")
	for event: SimEvent in events:
		assert_ne(event.kind, SimEvent.Kind.SEAT_OUT, "nobody goes out as she turns")
	for seat in 3:
		var body := sim.state.seats[seat]
		assert_ne(body.body, PlayerState.Body.GROUNDED, "off the deck it stood on, falling")
		# Upright about its middle in the new frame: half a body's height off, at most.
		var stood := Vector3(-2.0 + seat * 2.0, 2.5, 0.0)
		assert_lt(body.pos.distance_to(stood), config.rules.body_height, "where it stood")


func test_a_lone_seat_match_runs_until_it_goes_out() -> void:
	var config := _fast_config(4)
	config.seats = 1
	var sim := MatchSim.create(config)
	var bound := sim.schedule.gone_tick() + Ticks.from_seconds(SETTLED_WITHIN)
	var ended: Array[SimEvent] = []
	var events := SimFixtures.step(sim)
	assert_false(sim.is_over(), "one seat left is not a match won")
	while not sim.is_over() and sim.state.tick <= bound:
		events.append_array(SimFixtures.step(sim))
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.MATCH_ENDED:
			ended.append(event)
	assert_true(sim.is_over(), "the lone seat goes out, at the latest by the cold")
	assert_eq(sim.state.phase, MatchState.Phase.ENDED)
	assert_eq(ended.size(), 1, "the match ends once")
	if ended.size() == 1:
		assert_eq(ended[0].tick, sim.state.seats[0].out_tick, "on the tick it goes out")
		assert_eq(ended[0].seat, -1, "with nobody left to win")
	assert_eq(sim.state.winner(), -1)
