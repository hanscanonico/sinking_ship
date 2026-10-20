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


func test_the_shipped_wade_is_the_same_at_any_depth() -> void:
	var rules := _rules()
	assert_eq(_wade(rules, 0.02), _wade(rules, 0.25), "wade_speed_deep is wade_speed")
	assert_almost_eq(_wade(rules, 0.25), rules.wade_speed, 0.0001)
