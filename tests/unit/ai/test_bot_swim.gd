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


## The sea 2.4 m over her main deck, the deckhouse's rooms flooded over their door
## lintels, each holding the air between them and its ceiling (SH29): a bot afloat in the
## saloon's pocket, with nothing to climb onto there, waits — its cold coming at the
## pocket's rate — until its meter is down to what the swim out to the boat deck costs,
## then ducks out under the door's lintel and climbs onto dry footing before the cold
## takes it (§5b.3, Q22).
func test_bot_waits_in_a_pocket_then_swims_on() -> void:
	var layout := SimFixtures.steamer()
	var rules := SimFixtures.rules()
	var sim := MatchSim.create(SimFixtures.config(2, null, SEED, layout))
	var rooms := {}
	for room: StringName in [&"deckhouse_hall", &"saloon", &"deckhouse_cabins"]:
		rooms[room] = [2.25, 0.15]
	HeldPose.hold(sim, HeldPose.flooded(layout, 2.4, rooms))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.swim(sim, 0, Vector3(1.5, 0.0, 1.5))
	var swimmer := sim.state.seats[0]
	# Afloat under the ceiling, its head in the air.
	swimmer.pos.y = 0.79
	var saloon := layout.structure.cell_named(&"saloon")
	var bot := BotInputSource.new(0, BotProfile.for_tier(&"normal"), sim.config)
	var runner := MatchRunner.new(sim, [bot, InputSource.new()] as Array[InputSource])
	var waited := 0
	var left_with := -1.0
	for _tick in Ticks.from_seconds(rules.cold_meter / rules.pocket_cold_rate):
		runner.step()
		var head := swimmer.pos + Vector3.UP * rules.head_height()
		var in_saloon := sim.pose().in_pocket(head) and sim.pose().cell_at(head) == saloon
		if in_saloon and left_with < 0.0:
			waited += 1
		elif left_with < 0.0:
			left_with = swimmer.cold
		if swimmer.body == PlayerState.Body.GROUNDED or swimmer.is_out():
			break
	var waited_s := waited * Ticks.SECONDS_PER_TICK
	assert_gt(
		waited_s, rules.cold_meter, "it waited in the pocket past a whole meter: %.1f s" % waited_s
	)
	assert_between(left_with, 0.0, rules.cold_meter * 0.75, "and left with its meter down")
	assert_false(swimmer.is_out(), "the cold did not take it")
	assert_eq(swimmer.body, PlayerState.Body.GROUNDED, "it climbed out: at %s" % swimmer.pos)
	assert_gte(swimmer.pos.y, 2.4, "onto dry footing over the sea")
