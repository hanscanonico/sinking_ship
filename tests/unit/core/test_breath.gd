extends GutTest
## The breath (#861): a swimmer's runs out with its head under the water — held down by a
## deck with no air under it, or dunked on the way in — and comes back with its head in
## the air; the cold is the water's on its body, whatever its head is in. A seat whose
## breath runs out drowns.


## The steamer held with her forward hold flooded to the deck over it, and the 'tween deck
## over that [param over] full — 1 for none of its air left: seat 1 on deck, seat 0
## swimming in the hold, under the 'tween deck.
func _in_the_flooded_hold(over: Array) -> MatchSim:
	var steamer := SimFixtures.steamer()
	var config := SimFixtures.config(2, null, 1, steamer)
	config.bonus_rules = SimFixtures.bonus_rules(600.0)
	var sim := MatchSim.create(config)
	var full := [1.0]
	var flooded := {
		&"hold": full,
		&"hold_bilge": full,
		&"hold_wing_p": full,
		&"hold_wing_s": full,
		&"forepeak": full,
		&"hold_fwd_top": over,
		&"engine_room": [-1.0],
	}
	HeldPose.hold(sim, HeldPose.flooded(steamer, 1.0, flooded))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	return sim


## Seat 0 of _in_the_flooded_hold, the hold full to the 'tween deck's planks: come to rest
## with its head against them, no air over it.
func _held_under() -> MatchSim:
	var sim := _in_the_flooded_hold([1.0])
	SimFixtures.swim(sim, 0, Vector3(9.0, 0.0, 0.0))
	var swimmer := sim.state.seats[0]
	swimmer.pos.y = -2.0
	SimFixtures.step(sim, {}, Ticks.RATE)
	swimmer.cold = sim.config.rules.cold_meter
	swimmer.breath = sim.config.rules.breath_meter
	return sim


func test_a_match_starts_on_a_full_breath() -> void:
	var sim := SimFixtures.sim(2)
	assert_eq(sim.state.seats[0].breath, SimFixtures.rules().breath_meter)


func test_afloat_the_cold_drains_and_the_breath_does_not() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
	var swimmer := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_eq(swimmer.breath, rules.breath_meter, "its head rides above the sea")
	assert_almost_eq(rules.cold_meter - swimmer.cold, 1.0, 0.0001, "a second colder")


func test_a_fall_into_the_sea_takes_a_breath_that_comes_back() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.place(sim, 0, Vector3(6.0, 0.0, 4.5))
	var swimmer := sim.state.seats[0]
	var least := INF
	for _tick in 4 * Ticks.RATE:
		SimFixtures.step(sim)
		least = minf(least, swimmer.breath)
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING, "in the sea")
	assert_lt(least, rules.breath_meter, "dunked on the way in, its head went under")
	assert_gt(least, 0.0, "not for long")
	assert_eq(swimmer.breath, rules.breath_meter, "afloat again, it has its breath back")


func test_held_under_a_deck_the_breath_runs_out() -> void:
	var rules := SimFixtures.rules()
	var sim := _held_under()
	var swimmer := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_almost_eq(rules.breath_meter - swimmer.breath, 1.0, 0.0001, "a second of it gone")
	assert_almost_eq(rules.cold_meter - swimmer.cold, 1.0, 0.0001, "and a second colder")


func test_a_seat_out_of_breath_drowns() -> void:
	var sim := _held_under()
	var swimmer := sim.state.seats[0]
	swimmer.breath = Ticks.SECONDS_PER_TICK
	var events := SimFixtures.step(sim)
	assert_true(swimmer.is_out(), "out")
	assert_eq(swimmer.out_cause, PlayerState.Cause.DROWNED, "drowned, with cold to spare")
	var outs := events.filter(
		func(event: SimEvent) -> bool: return event.cause == PlayerState.Cause.DROWNED
	)
	assert_eq(outs.size(), 1, "and the event says so")
	assert_eq(MatchTranscript.CAUSES[PlayerState.Cause.DROWNED], "drowned")


func test_out_of_both_on_one_tick_the_cold_has_it() -> void:
	var sim := _held_under()
	var swimmer := sim.state.seats[0]
	swimmer.breath = Ticks.SECONDS_PER_TICK
	swimmer.cold = Ticks.SECONDS_PER_TICK
	SimFixtures.step(sim)
	assert_eq(swimmer.out_cause, PlayerState.Cause.COLD)


func test_in_a_pocket_the_breath_holds() -> void:
	var rules := SimFixtures.rules()
	var sim := _in_the_flooded_hold([0.2, 0.8])
	SimFixtures.swim(sim, 0, Vector3(13.5, 0.0, 0.0))
	var swimmer := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.RATE)
	var head := swimmer.pos + Vector3.UP * rules.head_height()
	assert_true(sim.pose().in_pocket(head), "its head in the trapped air")
	assert_eq(swimmer.breath, rules.breath_meter, "air to breathe")
	assert_lt(swimmer.cold, rules.cold_meter, "though the water is as cold")


func test_the_breath_comes_back_at_its_own_rate_on_deck() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	var standing := sim.state.seats[0]
	standing.breath = 0.5
	SimFixtures.step(sim, {}, Ticks.RATE / 2)
	assert_almost_eq(standing.breath, 0.5 + rules.breath_regen * 0.5, 0.0001)
	SimFixtures.step(sim, {}, Ticks.from_seconds(rules.breath_meter / rules.breath_regen))
	assert_eq(standing.breath, rules.breath_meter, "and no fuller than full")


func test_double_life_fills_the_breath_again() -> void:
	var rules := SimFixtures.rules()
	var sim := _held_under()
	var swimmer := sim.state.seats[0]
	swimmer.bonuses = PackedInt32Array([0])
	swimmer.breath = Ticks.SECONDS_PER_TICK
	swimmer.cold = 1.0
	SimFixtures.step(sim)
	assert_false(swimmer.is_out(), "its spare life had it")
	assert_eq(swimmer.breath, rules.breath_meter, "a full breath")
	assert_eq(swimmer.cold, rules.cold_meter, "and a full meter of cold")
	assert_true(swimmer.bonuses.is_empty(), "spent")


func test_a_snapshot_keeps_the_breath() -> void:
	var sim := _held_under()
	SimFixtures.step(sim, {}, Ticks.RATE)
	var breath := sim.state.seats[0].breath
	var again := PlayerState.from_dict(sim.state.seats[0].to_dict())
	assert_eq(again.breath, breath)
