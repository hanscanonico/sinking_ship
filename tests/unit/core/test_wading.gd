extends GutTest
## Wading graded by depth: a walk on a wet floor is capped at wade_speed in a film of
## water, easing to wade_speed_deep as the water over the floor deepens to wade_depth.


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func test_the_rules_hold_a_deep_wade_no_faster_than_a_shallow_one() -> void:
	assert_eq(_rules().problems(), PackedStringArray(), "the shipped numbers hold")
	assert_lte(_rules().wade_speed_deep, _rules().wade_speed)
	var still: BrawlRules = _rules().duplicate()
	still.wade_speed_deep = 0.0
	assert_eq(
		still.problems(), PackedStringArray(["brawl rules: wade_speed_deep must be positive"])
	)
	var quick: BrawlRules = _rules().duplicate()
	quick.wade_speed_deep = quick.wade_speed + 1.0
	assert_eq(
		quick.problems(),
		PackedStringArray(["brawl rules: wade_speed_deep must not exceed wade_speed"])
	)


## The planar speed of a lone walker after a second walking toward the bow on the flat
## deck standing 0.4 out of the sea, flooded [param depth] deep, under [param rules].
func _wade(rules: BrawlRules, depth: float) -> float:
	var flooded := SimFixtures.scenario([[0.0, 0.4 + depth, 0.0, 0.0]])
	var config := SimFixtures.config(1, flooded, 1, SimFixtures.low_deck(0.4))
	config.rules = rules
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, Vector3(-4.0, 0.0, 0.0))
	var walker := sim.state.seats[0]
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE)
	assert_eq(walker.body, PlayerState.Body.GROUNDED, "wading, not swimming")
	return Vector2(walker.vel.x, walker.vel.z).length()


func test_deeper_water_drags_a_wade_harder() -> void:
	var rules: BrawlRules = _rules().duplicate()
	rules.wade_speed_deep = 1.0
	var film := _wade(rules, 0.02)
	var deep := _wade(rules, 0.25)
	assert_lt(deep, film, "slower in 0.25 m than in 0.02 m")
	var eased := lerpf(rules.wade_speed, rules.wade_speed_deep, 0.25 / rules.wade_depth)
	assert_almost_eq(deep, eased, 0.0001, "eased toward wade_speed_deep by depth")


## The drag on the legs grows with depth (#616): knee-deep, a walk runs at about 60% of a
## dry one.
func test_the_shipped_wade_is_slower_deep_than_in_a_film() -> void:
	var rules := _rules()
	var film := _wade(rules, 0.02)
	var deep := _wade(rules, 0.29)
	assert_lt(deep, film, "slower 0.29 m deep than in a film of water")
	var eased := lerpf(rules.wade_speed, rules.wade_speed_deep, 0.29 / rules.wade_depth)
	assert_almost_eq(deep, eased, 0.0001)


## Shin-deep water is a wade, not a swim (#800): a body standing in 0.45 m of water over
## its floor stays on its feet for longer than a cold meter lasts, and loses no warmth.
func test_a_body_stands_in_shin_deep_water_without_the_cold() -> void:
	var rules := _rules()
	var flooded := SimFixtures.scenario([[0.0, 0.4 + 0.45, 0.0, 0.0]])
	var sim := SimFixtures.sim(1, flooded, SimFixtures.low_deck(0.4))
	SimFixtures.place(sim, 0, Vector3(-4.0, 0.0, 0.0))
	var wader := sim.state.seats[0]
	var seconds := rules.cold_meter + 2.0
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.from_seconds(seconds))
	assert_eq(wader.body, PlayerState.Body.GROUNDED, "on its feet in 0.45 m")
	assert_false(wader.is_out(), "the cold never took it")
	assert_eq(wader.cold, rules.cold_meter, "wading is not swimming")


## Where a heeled deck runs down into the sea, a swimmer walking up out of it stands
## once and stays standing (#777): it finds its feet only where the water is stand_depth
## deep or less, so the first step up the slope never puts it back in.
func test_a_swimmer_walking_up_a_heeled_deck_out_of_the_sea_stays_out() -> void:
	var rules := _rules()
	# Heeled 14° with the waterline across the middle of the deck: one side under, one dry.
	var heeled := SimFixtures.scenario([[0.0, 0.4, 0.0, 14.0]])
	var sim := SimFixtures.sim(1, heeled, SimFixtures.low_deck(0.4))
	var pose := sim.pose()
	var low := (
		1.0 if pose.water_height(Vector3(0, 0, 3)) > pose.water_height(Vector3(0, 0, -3)) else -1.0
	)
	var start := Vector3(-4.0, 0.0, 3.8 * low)
	var deep := pose.water_height(start) - start.y
	assert_gt(deep, rules.wade_depth + 0.1, "it starts where the water over the deck swims")
	SimFixtures.swim(sim, 0, start)
	var swimmer := sim.state.seats[0]
	var up := Vector2(0.0, -low)
	var stood_in := -1.0
	var back_in := 0
	for _tick in 4 * Ticks.RATE:
		for event: SimEvent in SimFixtures.step(sim, {0: SimFixtures.frame(0, up)}):
			if event.kind == SimEvent.Kind.CLIMBED_OUT and stood_in < 0.0:
				stood_in = sim.pose().water_height(swimmer.pos) - swimmer.pos.y
			elif event.kind == SimEvent.Kind.ENTERED_WATER and stood_in >= 0.0:
				back_in += 1
	assert_gte(stood_in, 0.0, "it got out of the water")
	assert_lt(stood_in, rules.stand_depth, "where the water is shallow enough to find its feet")
	assert_eq(back_in, 0, "and never went back in walking up the slope")
	assert_eq(swimmer.body, PlayerState.Body.GROUNDED)


## A swimmer climbing out of the sea onto a deck awash finds its feet only where the
## water is shallower than stand_depth, as one floating over a floor does (#777): never in
## water a hair under wade_depth, which the next rise or the next step would swim it in.
func test_a_swimmer_climbs_out_only_where_the_water_is_stand_depth_shallow() -> void:
	var rules := _rules()
	for depth: float in [rules.stand_depth - 0.05, (rules.stand_depth + rules.wade_depth) * 0.5]:
		var awash := SimFixtures.scenario([[0.0, 0.4 + depth, 0.0, 0.0]])
		var sim := SimFixtures.sim(1, awash, SimFixtures.low_deck(0.4))
		SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 4.6))
		var swimmer := sim.state.seats[0]
		var stood := false
		for _tick in 3 * Ticks.RATE:
			for event: SimEvent in SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.UP)}):
				stood = stood or event.kind == SimEvent.Kind.CLIMBED_OUT
		if depth < rules.stand_depth:
			assert_true(stood, "out onto a deck %.2f m awash" % depth)
		else:
			assert_false(stood, "still swimming over a deck %.2f m awash" % depth)
			assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
