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
			if (
				platform.name in pose.collapsed
				or not planner._waterline._crossing(platform, pose, low)
			):
				continue
			var ends := planner._waterline._line.duplicate()
			for run: Vector2 in DeckWetness.out_on_deck_along(layout, index, ends[0], ends[1]):
				expected.append(ends[0].lerp(ends[1], run.x))
		var cues: Array[FxCue] = []
		planner._waterline.plan(then, pose, tick, false, cues)
		var found := PackedVector3Array()
		for cue in FxProbe.of(cues, FxCue.Kind.WASH):
			found.append(cue.position)
		assert_eq(found, expected, "at %d" % tick)
		washed += found.size()
	assert_gt(washed, 0, "white water laid")


func test_passing_over_blocks_clear_of_the_sea_changes_nothing() -> void:
	# _whole passes over a block of decks all clear of the sea (#563): tick by tick, the
	# white water, the spray and the spray's memory are those of reading every deck.
	var config := RunMatch.default_config(1701)
	config.scenario = load(SimFixtures.STEAMER_SCRIPT)
	var sim := MatchSim.create(config)
	var blocked := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)._waterline
	var every := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)._waterline
	# Small blocks, so even her few decks make several, some passed over and some not.
	blocked._lay_blocks(2)
	every.blocks = false
	var passed := 0
	var cued := 0
	for tick in range(1, sim.schedule.end_tick()):
		var then := sim.schedule.pose_at(tick - 1)
		var pose := sim.schedule.pose_at(tick)
		var plunging := sim.schedule.plunge_tick() >= 0 and sim.schedule.plunge_tick() <= tick
		var found: Array[FxCue] = []
		var expected: Array[FxCue] = []
		blocked.plan(then, pose, tick, plunging, found)
		every.plan(then, pose, tick, plunging, expected)
		assert_eq(_described(found), _described(expected), "cues at %d" % tick)
		assert_eq(blocked._spray, every._spray, "spray at %d" % tick)
		passed += blocked._sprayed.count(0)
		cued += found.size()
	assert_gt(passed, 0, "blocks passed over")
	assert_gt(cued, 0, "white water and spray laid")


static func _described(cues: Array[FxCue]) -> Array:
	var described := []
	for cue: FxCue in cues:
		described.append([cue.kind, cue.position, cue.end, cue.toward, cue.strength, cue.rise])
	return described


func test_rooms_wide_of_a_line_are_passed_over_as_holding_none_of_it() -> void:
	# DeckWetness.out_of passes over a room wide of the line's box unasked (#563): lines
	# across every deck of hers, some along an axis, cut where asking every room cuts them.
	var layout := RunMatch.default_config(1701).ship
	var rng := RandomNumberGenerator.new()
	rng.seed = 563
	var cut := 0
	for platform in layout.platforms.size():
		var areas := DeckWetness.rooms_grown_on(layout, platform)
		var area := layout.platforms[platform].area
		for line in 40:
			var from := Vector3(
				rng.randf_range(area.position.x, area.end.x),
				0.0,
				rng.randf_range(area.position.y, area.end.y)
			)
			var to := Vector3(
				rng.randf_range(area.position.x, area.end.x),
				0.0,
				rng.randf_range(area.position.y, area.end.y)
			)
			if line % 4 == 1:
				to.x = from.x
			elif line % 4 == 2:
				to.z = from.z
			var found := DeckWetness.out_of(areas, from, to)
			assert_eq(found, _out_asking_every_room(areas, from, to), "deck %d" % platform)
			if found != PackedVector2Array([Vector2(0.0, 1.0)]):
				cut += 1
	assert_gt(cut, 0, "lines cut by rooms")


## out_of as it was, every room asked.
static func _out_asking_every_room(
	areas: Array[Rect2], from: Vector3, to: Vector3
) -> PackedVector2Array:
	var runs := PackedVector2Array([Vector2(0.0, 1.0)])
	var start := Vector2(from.x, from.z)
	var way := Vector2(to.x - from.x, to.z - from.z)
	for area: Rect2 in areas:
		var inside := DeckWetness._within(start, way, area)
		if inside.x >= inside.y:
			continue
		var left := PackedVector2Array()
		for run: Vector2 in runs:
			if run.x < inside.x:
				left.append(Vector2(run.x, minf(run.y, inside.x)))
			if run.y > inside.y:
				left.append(Vector2(maxf(run.x, inside.y), run.y))
		runs = left
	return runs
