extends GutTest


func test_seconds_convert_once_rounding_half_away() -> void:
	assert_eq(Ticks.from_seconds(0.25), 8, "7.5 ticks rounds up")
	assert_eq(Ticks.from_seconds(-0.25), -8, "-7.5 ticks rounds down")
	assert_eq(Ticks.from_seconds(0.75), 23)
	assert_eq(Ticks.from_seconds(0.0), 0)
	assert_eq(Ticks.from_seconds(0.10), 3, "a shove's windup")
	assert_eq(Ticks.from_seconds(0.27), 8, "a shove's recovery")
	assert_eq(Ticks.from_seconds(0.40), 12, "a stagger")

	# Once per match: the sim converts when it is created, not every time it reads.
	var config := SimFixtures.config(1)
	config.rules = config.rules.duplicate()
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	config.rules.shove_windup = 1.0
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)}, 4)
	assert_eq(sim.state.seats[0].action, PlayerState.Action.ACTIVE)
