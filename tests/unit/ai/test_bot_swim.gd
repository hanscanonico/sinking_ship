extends GutTest
## Where a bot in the sea swims (BotSwim): out of a flooded room by the walk graph's
## way to dry ground when no way out stands in sight.

const SEED := 1701


## Settled by the head, the lower deck under the sea and the main deck still dry: a
## bot shoved down the aft stair into the flooded corridor swims back to the stair it
## came down and up it, before the cold takes it. No climb out stands within a swim of
## where it is, so the way out is the walk graph's: along the corridor and up the stair.
func test_a_swimmer_in_a_flooded_corridor_swims_out_up_the_stair() -> void:
	var layout := SimFixtures.steamer()
	var rules := SimFixtures.rules()
	var settled := SimFixtures.scenario([[0.0, 2.4, 5.0, -1.7]])
	var sim := MatchSim.create(SimFixtures.config(2, settled, SEED, layout))
	SimFixtures.place(sim, 1, Vector3(-17.0, 1.2, 0.0))
	SimFixtures.swim(sim, 0, Vector3(-9.0, 0.0, -0.17), 0.0)
	var swimmer := sim.state.seats[0]
	var reach := swimmer.cold * rules.swim_speed
	assert_null(
		sim.surfaces.nearest_climb(swimmer.pos, sim.pose(), rules, reach), "no way out in sight"
	)
	var bot := BotInputSource.new(0, BotProfile.for_tier(&"normal"), sim.config)
	var runner := MatchRunner.new(sim, [bot, InputSource.new()] as Array[InputSource])
	var dry := false
	for _tick in Ticks.from_seconds(rules.cold_meter + 1.0):
		runner.step()
		if swimmer.body == PlayerState.Body.GROUNDED and swimmer.pos.y >= 0.0:
			dry = true
			break
	assert_false(swimmer.is_out(), "the cold did not take it")
	assert_true(dry, "it stood on the main deck: at %s" % swimmer.pos)
