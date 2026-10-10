extends GutTest
## Bots under survival (#61): they climb and fight only over the spot they stand on —
## HUNT and LINE_UP score against a target in their refuge or on their highest ground,
## and elsewhere only at the profile's survival_hunt_scale.

const SEED := 1701
const AT_IT := [BotBrain.Intent.HUNT, BotBrain.Intent.LINE_UP]


## [param bot] plays seat 0 of [param sim]; every other seat stands where it is.
func _runner(sim: MatchSim, bot: BotInputSource) -> MatchRunner:
	var sources: Array[InputSource] = [bot]
	for _seat in range(1, sim.config.seats):
		sources.append(InputSource.new())
	return MatchRunner.new(sim, sources)


func _sim(goal: MatchRules.Goal, layout: ShipLayout = null) -> MatchSim:
	var config := SimFixtures.config(2, null, SEED, layout)
	config.goal = goal
	return MatchSim.create(config)


## On a dry, level ship a bot on the main deck hears its target in the cabin under it.
## The battle royale sends it down after it (test_intents); survival leaves it be and
## sends it up.
func test_under_survival_a_bot_leaves_a_target_below_decks_alone() -> void:
	var sim := _sim(MatchRules.Goal.SURVIVAL, SimFixtures.steamer())
	SimFixtures.place(sim, 0, Vector3(-7.0, 0.0, 3.5))
	SimFixtures.place(sim, 1, Vector3(-7.0, -2.6, 2.8))
	var profile: BotProfile = BotProfile.for_tier(&"normal").duplicate()
	profile.survival_hunt_scale = 0.0
	var source := BotInputSource.new(0, profile, sim.config)
	var runner := _runner(sim, source)
	var nearest := INF
	var highest := -INF
	var went_at := false
	for _tick in 20 * Ticks.RATE:
		runner.step()
		var bot := sim.state.seats[0]
		nearest = minf(nearest, bot.pos.distance_to(sim.state.seats[1].pos))
		highest = maxf(highest, bot.pos.y)
		went_at = went_at or source.brain.intent in AT_IT
	assert_false(went_at, "it never set out after the seat below")
	assert_gt(nearest, 2.5, "nor came at it")
	assert_gt(highest, 2.0, "it climbed above the main deck")


## The flat deck is one zone, its highest: a bot fights whoever stands on it with it.
func test_under_survival_a_bot_fights_for_the_spot_it_is_on() -> void:
	var sim := _sim(MatchRules.Goal.SURVIVAL)
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 0.0))
	SimFixtures.place(sim, 1, Vector3(1.0, 0.0, 0.0))
	var profile: BotProfile = BotProfile.for_tier(&"normal").duplicate()
	profile.survival_hunt_scale = 0.0
	var source := BotInputSource.new(0, profile, sim.config)
	var runner := _runner(sim, source)
	var nearest := INF
	var went_at := false
	for _tick in 10 * Ticks.RATE:
		runner.step()
		nearest = minf(nearest, sim.state.seats[0].pos.distance_to(sim.state.seats[1].pos))
		went_at = went_at or source.brain.intent in AT_IT
	assert_true(went_at, "it went at the seat on its perch")
	assert_lt(nearest, 1.5, "and came at it")


func test_every_tier_states_its_survival_hunt_scale() -> void:
	for tier: StringName in [&"easy", &"normal", &"hard"]:
		var profile := BotProfile.for_tier(tier)
		assert_eq(profile.problems(), PackedStringArray(), "%s is a valid profile" % tier)
		assert_between(profile.survival_hunt_scale, 0.0, 0.5, "%s mostly leaves others be" % tier)


## A bot already hunting a target off its perch lets it go at the shipped scale: the
## hysteresis that keeps a chosen intent does not keep a hunt survival has scaled down.
func test_under_survival_a_hunt_off_the_perch_is_let_go() -> void:
	var sim := _sim(MatchRules.Goal.SURVIVAL, SimFixtures.steamer())
	SimFixtures.place(sim, 0, Vector3(-7.0, 0.0, 3.5))
	SimFixtures.place(sim, 1, Vector3(-7.0, -2.6, 2.8))
	var source := BotInputSource.new(0, BotProfile.for_tier(&"normal"), sim.config)
	source.brain.intent = BotBrain.Intent.HUNT
	var runner := _runner(sim, source)
	runner.run(Ticks.RATE)
	assert_false(source.brain.intent in AT_IT, "it no longer goes at the seat below")


## On the boat deck, one seat beside it and one up on the bridge, her highest deck: the
## easy bot goes at whoever is nearest in the battle royale, and at the one on its perch
## under survival.
func test_under_survival_a_bot_picks_its_target_on_its_perch() -> void:
	var targets := {}
	for goal: MatchRules.Goal in [MatchRules.Goal.LAST_STANDING, MatchRules.Goal.SURVIVAL]:
		var config := SimFixtures.config(3, null, SEED, SimFixtures.steamer())
		config.goal = goal
		var sim := MatchSim.create(config)
		SimFixtures.place(sim, 0, Vector3(1.0, 2.5, 2.5))
		SimFixtures.place(sim, 1, Vector3(3.0, 2.5, 2.5))
		SimFixtures.place(sim, 2, Vector3(-2.5, 4.7, 0.0))
		var source := BotInputSource.new(0, BotProfile.for_tier(&"easy"), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		source.next_frame(sim.state.tick)
		targets[goal] = source.brain.target
	assert_eq(targets[MatchRules.Goal.LAST_STANDING], 1, "the nearest in the battle royale")
	assert_eq(targets[MatchRules.Goal.SURVIVAL], 2, "the one on its perch under survival")
