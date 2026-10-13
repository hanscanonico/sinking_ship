extends GutTest
## A bot counts every fresh search of the walk graph it takes because it strayed off
## the route it had (make fps SPLIT=1 reports them): on its way, none.


## The normal profile without its lapses: for what a bot does when it does not slip.
func _steady() -> BotProfile:
	var profile: BotProfile = (load(SimFixtures.NORMAL_BOT) as BotProfile).duplicate()
	profile.mistake_rate = 0.0
	return profile


func test_a_bot_put_off_its_route_searches_a_fresh_one() -> void:
	# Abaft the deckhouse, its target on the bridge: on its way, its route stands; set
	# down where the route does not go, it searches the walk graph afresh — and counts it.
	var layout := SimFixtures.steamer()
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(-10.5, 0.0, 2.5))
	SimFixtures.place(sim, 1, Vector3(-2.5, layout.platforms[bridge].height, 0.0))
	var bot := BotInputSource.new(0, _steady(), sim.config)
	var brain := bot.brain
	var sources: Array[InputSource] = [bot, InputSource.new()]
	var runner := MatchRunner.new(sim, sources)
	runner.run(Ticks.from_seconds(1.0))
	var on_route := brain.replans()
	runner.run(Ticks.from_seconds(1.0))
	assert_eq(brain.replans(), on_route, "on its way: no fresh search")
	SimFixtures.place(sim, 0, Vector3(-17.0, 1.2, 0.0))
	runner.run(Ticks.from_seconds(1.0))
	assert_gt(brain.replans(), on_route, "put off its route: a fresh search")
