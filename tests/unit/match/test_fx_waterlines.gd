extends GutTest
## FxPlanner's waterlines (#410): it tells the decks clear of the sea from its packed
## arrays alone, and lays its white water where asking every deck finds the sea crosses.

const RunMatch := preload("res://tools/run_match.gd")


func test_the_waterlines_are_those_of_asking_every_deck() -> void:
	# _waterlines tells the decks clear of the sea from its packed arrays alone: the
	# white water it lays is where asking every deck finds the sea crosses one.
	var config := RunMatch.default_config(1701)
	config.scenario = load(SimFixtures.STEAMER_SCRIPT)
	var sim := MatchSim.create(config)
	var planner := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)
	var layout := sim.config.ship
	var washed := 0
	for tick in range(Ticks.RATE, sim.schedule.end_tick(), Ticks.RATE * 4):
		var then := sim.schedule.pose_at(tick - 1)
		var pose := sim.schedule.pose_at(tick)
		var expected := PackedVector3Array()
		for index in layout.platforms.size():
			var platform := layout.platforms[index]
			var area := platform.area
			var low := pose.world_height(Vector3(area.position.x, platform.height, area.position.y))
			if platform.name in pose.collapsed or not planner._crossing(platform, pose, low):
				continue
			var ends := planner._line.duplicate()
			for run: Vector2 in DeckWetness.out_on_deck_along(layout, index, ends[0], ends[1]):
				expected.append(ends[0].lerp(ends[1], run.x))
		var cues: Array[FxCue] = []
		planner._waterlines(then, pose, tick, false, cues)
		var found := PackedVector3Array()
		for cue in FxProbe.of(cues, FxCue.Kind.WASH):
			found.append(cue.position)
		assert_eq(found, expected, "at %d" % tick)
		washed += found.size()
	assert_gt(washed, 0, "white water laid")
