extends GutTest
## Double life (#307, #310): when the cold meter of a seat holding it runs out in the sea,
## it fills up again, once, and the bonus is spent — whatever rate the meter drains at. An
## unspent spare counts as a full meter more of cold left in the last swim; going down with
## a piece of her that is gone, it saves nobody.

const RunMatch := preload("res://tools/run_match.gd")
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## [param seats] seats on below_decks' hold with Double life and no bonus to come: seat 0
## swimming off her starboard side with [param cold] of its meter left and a Double life,
## the others on deck.
func _swimming_with_a_spare(cold: float, seats := 2) -> MatchSim:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), seats)
	for seat in range(1, seats):
		SimFixtures.place(sim, seat, Vector3(10.0, 0.0, seat - 1.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
	sim.state.seats[0].cold = cold
	sim.state.seats[0].bonus = 0
	return sim


func test_double_life_fills_the_meter_again_once_and_is_spent() -> void:
	var rules := SimFixtures.rules()
	var sim := _swimming_with_a_spare(Ticks.SECONDS_PER_TICK)
	var swimmer := sim.state.seats[0]
	var events := SimFixtures.step(sim)
	assert_false(swimmer.is_out(), "its meter ran out, and it is still in")
	assert_eq(swimmer.cold, rules.cold_meter, "full again")
	assert_eq(swimmer.bonus, -1, "the Double life spent")
	var spent := _of(events, SimEvent.Kind.DOUBLE_LIFE_SPENT)
	assert_eq(spent.size(), 1, "and says so")
	if spent.size() == 1:
		assert_eq([spent[0].seat, spent[0].bonus], [0, 0])
	assert_true(_of(events, SimEvent.Kind.SEAT_OUT).is_empty())
	events = SimFixtures.step(sim, {}, Ticks.from_seconds(rules.cold_meter) - 2)
	assert_false(swimmer.is_out(), "a whole meter more")
	events.append_array(SimFixtures.step(sim, {}, 4))
	assert_true(swimmer.is_out(), "then out for good: once only")
	assert_eq(swimmer.out_cause, PlayerState.Cause.COLD)
	assert_true(_of(events, SimEvent.Kind.DOUBLE_LIFE_SPENT).is_empty())


## The spare drains at whatever rate the meter does: a ring's in its hands, or the trapped
## air's its head is in.
func test_the_spare_drains_at_whatever_rate_the_meter_does() -> void:
	var rules := SimFixtures.rules()
	var ring_rate := PropKind.named(&"lifebuoy").sea_cold_rate
	var ringed := SimFixtures.crated(
		[SimFixtures.lifebuoy(Vector3.ZERO)], SimFixtures.below_decks()
	)
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 2, ringed)
	SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
	SimFixtures.hand(sim, 0, 0)
	var floating := sim.state.seats[0]
	floating.bonus = 0
	floating.cold = Ticks.SECONDS_PER_TICK * ring_rate
	SimFixtures.step(sim)
	assert_eq(floating.cold, rules.cold_meter, "with a ring: full again")
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_almost_eq(rules.cold_meter - floating.cold, ring_rate, 0.0001, "at the ring's rate")

	var steamer := SimFixtures.steamer()
	var config := SimFixtures.config(2, null, 1, steamer)
	config.bonuses = SimFixtures.bonus_rules(600.0)
	var trapped := MatchSim.create(config)
	var full := [1.0]
	var flooded := {
		&"hold": full,
		&"hold_bilge": full,
		&"hold_wing_p": full,
		&"hold_wing_s": full,
		&"forepeak": full,
		&"hold_fwd_top": [0.2, 0.8],
		&"engine_room": [-1.0],
	}
	HeldPose.hold(trapped, HeldPose.flooded(steamer, 1.0, flooded))
	SimFixtures.place(trapped, 1, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.swim(trapped, 0, Vector3(13.5, 0.0, 0.0))
	var in_air := trapped.state.seats[0]
	in_air.bonus = 0
	in_air.cold = Ticks.SECONDS_PER_TICK * rules.pocket_cold_rate
	SimFixtures.step(trapped)
	assert_eq(in_air.cold, rules.cold_meter, "in trapped air: full again")
	SimFixtures.step(trapped, {}, Ticks.RATE)
	var head := in_air.pos + Vector3.UP * rules.head_height()
	assert_true(trapped.pose().in_pocket(head), "its head in the trapped air")
	assert_almost_eq(
		rules.cold_meter - in_air.cold, rules.pocket_cold_rate, 0.0001, "at the air's rate"
	)


## The last swim (MatchVerdict.by_the_cold) goes to the most cold left, and places by it:
## an unspent spare counts as a full meter more. With every deck under, a swimmer on a low
## meter holding Double life outlasts one on a fuller meter without; and where two spares
## tie for the most, all go out, the places by the cold each had left with its spare.
func test_an_unspent_spare_counts_as_a_full_meter_more_in_the_last_swim() -> void:
	var under := SimFixtures.scenario([[0.0, 5.0, 0.0, 0.0], [600.0, 5.0, 0.0, 0.0]])
	var duel := SimFixtures.config(2, under, 1, SimFixtures.below_decks())
	duel.bonuses = SimFixtures.bonus_rules(600.0)
	var sim := MatchSim.create(duel)
	SimFixtures.swim(sim, 0, Vector3(-6.0, 0.0, 0.0))
	SimFixtures.swim(sim, 1, Vector3(6.0, 0.0, 0.0))
	sim.state.seats[0].cold = 3.0
	sim.state.seats[1].cold = 1.0
	sim.state.seats[1].bonus = 0
	var events := SimFixtures.step(sim)
	assert_eq(sim.state.phase, MatchState.Phase.ENDED, "the last swim is over at once")
	assert_eq(sim.state.winner(), 1, "1 s and a spare meter outlast 3 s")
	assert_eq([sim.state.seats[0].place, sim.state.seats[1].place], [2, 1])
	assert_true(_of(events, SimEvent.Kind.DOUBLE_LIFE_SPENT).is_empty(), "never spent")

	var three := SimFixtures.config(3, under, 1, SimFixtures.below_decks())
	three.bonuses = SimFixtures.bonus_rules(600.0)
	var tied := MatchSim.create(three)
	for seat in 3:
		SimFixtures.swim(tied, seat, Vector3(-6.0 + seat * 6.0, 0.0, 0.0))
	tied.state.seats[0].cold = 3.0
	for seat: int in [1, 2]:
		tied.state.seats[seat].cold = 1.0
		tied.state.seats[seat].bonus = 0
	SimFixtures.step(tied)
	assert_eq(tied.state.winner(), -1, "two spares tie for the most: the sea's draw")
	var places := [tied.state.seats[0].place, tied.state.seats[1].place, tied.state.seats[2].place]
	assert_eq(places, [3, 1, 1], "placed by the cold each had left, spares and all")


## Inside a piece of her on the tick it is gone, a seat goes with her: Double life does not
## save it, and is not spent.
func test_double_life_does_not_save_a_seat_going_down_with_her() -> void:
	var config := RunMatch.default_config(2, 3)
	var given: SinkScenario = config.scenario.duplicate()
	given.explicit_hit = load(FAST_HIT)
	config.scenario = given
	var sim := MatchSim.create(config)
	var gone := sim.schedule.gone_tick()
	sim.state.tick = gone - 1
	sim.state.phase = MatchState.Phase.LIVE
	SimFixtures.place(sim, 0, Vector3(1.5, 0.0, 0.0))
	SimFixtures.swim(sim, 1, Vector3(0.0, 0.0, 12.0))
	SimFixtures.swim(sim, 2, Vector3(0.0, 0.0, -12.0))
	assert_ne(sim.pose().cell_at(sim.state.seats[0].pos), CellMap.NONE, "seat 0 is inside her")
	sim.state.seats[0].bonus = 0
	var events := SimFixtures.step(sim, {}, 2)
	var inside := sim.state.seats[0]
	assert_true(inside.is_out(), "it goes with her")
	assert_eq(inside.out_cause, PlayerState.Cause.WITH_HER)
	assert_eq(inside.out_tick, gone)
	assert_eq(inside.bonus, -1, "its bonus with it")
	assert_true(_of(events, SimEvent.Kind.DOUBLE_LIFE_SPENT).is_empty(), "never spent")


## `make match` tells the bonuses (#310): one coming aboard — its kind's title and its
## spot — who took it, and a Double life spent.
func test_the_transcript_tells_a_bonus_coming_taken_and_spent() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(1.0), 2)
	SimFixtures.place(sim, 0, Vector3(-10.4, -2.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
	var told := MatchTranscript.new()
	told.bonuses(sim.config)
	told.add(SimFixtures.step(sim, {}, Ticks.from_seconds(1.5)))
	told.add(SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.GRAB)}))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
	sim.state.seats[0].cold = Ticks.SECONDS_PER_TICK
	told.add(SimFixtures.step(sim))
	var lines := Array(told.text().split("\n"))
	assert_has(lines, "00:01.0 Double life aboard · spot 0", "one came")
	assert_has(lines, "00:01.5 seat 0 takes Double life · spot 0", "who took it")
	assert_has(lines, "00:01.5 seat 0's Double life spent", "and spent it")


## Without one, the same swimmer goes out as its meter runs out, as it always has.
func test_a_seat_without_double_life_goes_out_as_its_meter_runs_out() -> void:
	var sim := _swimming_with_a_spare(Ticks.SECONDS_PER_TICK)
	sim.state.seats[0].bonus = -1
	var events := SimFixtures.step(sim)
	assert_true(sim.state.seats[0].is_out())
	assert_true(_of(events, SimEvent.Kind.DOUBLE_LIFE_SPENT).is_empty())
