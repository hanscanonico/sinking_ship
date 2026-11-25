extends GutTest
## Down to the last seats with none of them in sight, a bot goes looking (#737): a seat
## hiding below decks is found, not left to win by standing still.


## [param bot] plays seat 0 of [param sim]; every other seat stands where it is.
func _runner(sim: MatchSim, bot: BotInputSource) -> MatchRunner:
	var sources: Array[InputSource] = [bot]
	for _seat in range(1, sim.config.seats):
		sources.append(InputSource.new())
	return MatchRunner.new(sim, sources)


## The steamer level, the two last seats: the normal bot on her boat deck and a seat idle
## in the forward starboard cabin below, out of its sight and hearing. The bot comes
## for it within a minute and a half.
func test_the_last_bot_finds_a_seat_hiding_below_decks() -> void:
	var layout := SimFixtures.steamer()
	var level := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0]])
	var sim := SimFixtures.sim(2, level, layout)
	SimFixtures.place(sim, 0, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.place(sim, 1, Vector3(-5.2, -2.6, 1.5))
	var source := BotInputSource.new(0, BotProfile.for_tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var found_at := -1
	for tick in 90 * Ticks.RATE:
		runner.step()
		if source.brain.target == 1:
			found_at = tick
			break
	assert_ne(found_at, -1, "it found the hider: the bot ended at %s" % sim.state.seats[0].pos)
