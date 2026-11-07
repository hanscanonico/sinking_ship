extends GutTest
## `make art-lint`'s check of the sinking's effects (SinkingFxCheck) watches a match that
## runs on through her going down: what it sees of her wreckage is hers, not the luck of
## how soon the bots are out.


func test_the_effects_checks_match_plays_on_until_her_sinking_is_over() -> void:
	# The check watches the sinking's effects through its match: one the bots end by
	# knocking one another out — seed 7's, on Linux, with #504's bots — can be over before
	# her sinking has floated a single piece of wreckage.
	var config := SinkingFxCheck.match_config(SinkingFxCheck.SEED, 2)
	assert_eq(config.scenario.explicit_hit, load(SinkingFxCheck.FAST_HIT), "struck by the fast hit")
	var sim := MatchSim.create(config)
	var tick := config.countdown_ticks + 1
	var lone := sim.state.seats[1]
	lone.body = PlayerState.Body.OUT
	lone.out_tick = tick
	var exits: Array[PlayerState] = [lone]
	var events: Array[SimEvent] = []
	MatchVerdict.place(sim.state, exits, tick, events, config.goal, sim.schedule.end_tick())
	assert_ne(sim.state.phase, MatchState.Phase.ENDED, "one seat left plays on")
	assert_lt(tick, sim.schedule.end_tick(), "before her sinking is over")
