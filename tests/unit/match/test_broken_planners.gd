extends GutTest
## Her planners once she has broken (SH33, #563): FloodedDecks reads each platform as the
## piece its middle lies on stands, and FxWaterlines lays its white water on each piece's
## stretch of a deck, as reading every platform on every piece finds them — each piece's
## platforms laid out once, as her cuts never move.

const SEATS := 1


func _sim() -> MatchSim:
	return MatchSim.create(SimFixtures.breaking(SEATS, null))


## The ticks to read her at: from just before she parts on, every half second.
func _ticks(schedule: SinkSchedule) -> Array[int]:
	var parted := SimFixtures.after_parting(schedule, 0.0)
	assert_gt(parted, 0, "the fixture parts")
	var ticks: Array[int] = []
	for tick in range(parted - Ticks.RATE, mini(schedule.end_tick(), parted + Ticks.RATE * 40)):
		if (tick - parted) % (Ticks.RATE / 2) == 0:
			ticks.append(tick)
	return ticks


func test_each_platform_is_flooded_as_its_own_piece_stands() -> void:
	var sim := _sim()
	var layout := sim.config.ship
	var pieces := PieceViews.new(layout, sim.schedule)
	var decks := FloodedDecks.new(layout, pieces)
	var flooded := 0
	for tick: int in _ticks(sim.schedule):
		var pose := sim.schedule.pose_at(tick)
		var found := decks.of(pose)
		for platform in layout.platforms.size():
			var middle := layout.platforms[platform].area.get_center()
			var at := Vector3(middle.x, layout.platforms[platform].height, middle.y)
			var expected := sim.surfaces.flooded(platform, pieces.at(pose, at))
			assert_eq(found[platform] == 1, expected, "platform %d at %d" % [platform, tick])
			flooded += 1 if expected else 0
	assert_gt(flooded, 0, "some of her platforms under")


func test_the_waterlines_of_a_broken_hull_are_those_of_reading_every_platform() -> void:
	var sim := _sim()
	var found_at := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)._waterline
	var every := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)._waterline
	var cued := 0
	var ticks := _ticks(sim.schedule)
	for tick in range(ticks[0], ticks[ticks.size() - 1]):
		var then := sim.schedule.pose_at(tick - 1)
		var pose := sim.schedule.pose_at(tick)
		var found: Array[FxCue] = []
		var expected: Array[FxCue] = []
		found_at.plan(then, pose, tick, false, found)
		_every_platform(every, then, pose, tick, expected)
		assert_eq(_described(found), _described(expected), "cues at %d" % tick)
		cued += found.size()
	assert_gt(cued, 0, "white water laid on her pieces")


## FxWaterlines.plan of [param lines] on a broken hull as it read every platform on every
## piece, every step; whole, as plan.
func _every_platform(
	lines: FxWaterlines, pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[FxCue]
) -> void:
	var views := lines._pieces.of(pose_now)
	if views.size() == 1:
		lines.plan(pose_then, pose_now, tick, false, cues)
		return
	var platforms := lines._layout.platforms.size()
	for place in views.size():
		var view := views[place]
		var then := lines._pieces.of_piece(pose_then, lines._pieces.leaves[place])
		var low_x := -INF if place == 0 else lines._pieces.cuts[place - 1]
		var high_x := INF if place == views.size() - 1 else lines._pieces.cuts[place]
		for index in platforms:
			var slot := (place * platforms + index) * 2
			var platform := lines._layout.platforms[index]
			var area := platform.area
			var from := maxf(area.position.x, low_x)
			var to := minf(area.end.x, high_x)
			var crossed := to > from and not platform.name in pose_now.collapsed
			if crossed:
				area = Rect2(from, area.position.y, to - from, area.size.y)
				var least := Vector3(from, platform.height, area.position.y)
				crossed = lines._crossing_area(
					area, platform.height, view, view.world_height(least)
				)
			if not crossed:
				lines._spray[slot] = 0.0
				lines._spray[slot + 1] = 0.0
				continue
			lines._crossed(index, slot, then, view, tick, false, cues)


static func _described(cues: Array[FxCue]) -> Array:
	var described := []
	for cue: FxCue in cues:
		described.append([cue.kind, cue.position, cue.end, cue.toward, cue.strength, cue.rise])
	return described
