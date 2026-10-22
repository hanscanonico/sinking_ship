extends GutTest
## A bot below deck whose every dry way out has gone under: it wades out through the
## shallowest water rather than stand pinned until the sea takes it.


## [param bot] plays seat 0 of [param sim]; every other seat stands where it is.
func _runner(sim: MatchSim, bot: BotInputSource) -> MatchRunner:
	var sources: Array[InputSource] = [bot]
	for _seat in range(1, sim.config.seats):
		sources.append(InputSource.new())
	return MatchRunner.new(sim, sources)


## Settled a metre, trimmed two degrees bow up: the engine room's floor is a hand under
## the sea, its doorways and stair foot with it, while the forward hold's middle and
## the stair out of it stand dry. A bot in the narrow strip of the engine room by the
## hold's bulkhead — the room's every way out wet, so nothing it may walk to stands
## higher than where it is — wades through the doorway into the hold and climbs on out
## of it to the main deck (seed 21's seat 7, pinned at the bulkhead until it drowned).
func test_a_bot_trapped_below_deck_wades_out() -> void:
	var layout := SimFixtures.steamer()
	var settled := SimFixtures.scenario([[0.0, 1.04, -2.0, 0.0]])
	var sim := SimFixtures.sim(2, settled, layout)
	SimFixtures.place(sim, 0, Vector3(3.5, -2.6, 2.4))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	var graph := WalkGraph.new(layout, sim.surfaces, SimFixtures.rules())
	var start := graph.zone_at(sim.state.seats[0].pos, sim.state.seats[0].surface)
	var pose := sim.pose()
	var found := graph.search(sim.state.seats[0].pos, sim.state.seats[0].surface, pose)
	assert_eq(graph.highest_in(found, pose), start, "no dry way leads anywhere higher")
	var source := BotInputSource.new(0, BotProfile.for_tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var bot := sim.state.seats[0]
	var highest := -INF
	for _tick in 15 * Ticks.RATE:
		runner.step()
		if bot.is_out():
			break
		highest = maxf(highest, bot.pos.y)
		if highest >= 0.0 and not sim.surfaces.is_ramp(bot.surface):
			break
	assert_false(bot.is_out(), "it was not taken by the sea")
	assert_gte(highest, 0.0, "it got up to the main deck: at %s" % bot.pos)
