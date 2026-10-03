extends GutTest

const SEED := 1701


func _schedule(scenario: SinkScenario, seed_value: int = SEED) -> SinkSchedule:
	return SinkSchedule.new(
		scenario, SimFixtures.deck().freeboard, SeedStreams.derive(seed_value, "sink")
	)


## The first tick at which [param point] is wet, asking Surfaces, or -1.
func _first_wet(schedule: SinkSchedule, point: Vector3, until: int = 400 * Ticks.RATE) -> int:
	var surfaces := Surfaces.new(SimFixtures.deck())
	for tick in until:
		if surfaces.wet(point, schedule.pose_at(tick)):
			return tick
	return -1


func _deck_ends() -> Array[Vector3]:
	var area := SimFixtures.deck().platforms[0].area
	var mid_z := area.get_center().y
	return [Vector3(area.end.x, 0.0, mid_z), Vector3(area.position.x, 0.0, mid_z)]


func test_pose_is_a_pure_function_of_tick() -> void:
	var scenario: SinkScenario = load(SimFixtures.FLAT_SINKING)
	var forward := _schedule(scenario)
	var ticks := [0, 1, 500, 1049, 1050, 2999, 3000, 4800, 9000, 12, 500, 0]
	var expected: Array[Transform3D] = []
	for tick: int in ticks:
		expected.append(forward.pose_at(tick).transform)
	var other := _schedule(scenario)
	for index in range(ticks.size() - 1, -1, -1):
		assert_eq(other.pose_at(ticks[index]).transform, expected[index], "tick %d" % ticks[index])
	assert_eq(forward.pose_at(3000).transform, other.pose_at(3000).transform)


func test_flat_scenario_wets_bow_before_stern() -> void:
	var schedule := _schedule(load(SimFixtures.FLAT_SINKING))
	var ends := _deck_ends()
	var bow := _first_wet(schedule, ends[0])
	var stern := _first_wet(schedule, ends[1])
	assert_gt(bow, -1, "the bow goes under")
	assert_gt(stern, bow, "the stern goes under after the bow")


func test_flat_scenario_meets_timeline() -> void:
	var schedule := _schedule(load(SimFixtures.FLAT_SINKING))
	var area := SimFixtures.deck().platforms[0].area
	var ends := _deck_ends()
	var middle := Vector3(area.get_center().x, 0.0, area.get_center().y)
	var corners: Array[Vector3] = [
		Vector3(area.position.x, 0.0, area.position.y),
		Vector3(area.position.x, 0.0, area.end.y),
		Vector3(area.end.x, 0.0, area.position.y),
		Vector3(area.end.x, 0.0, area.end.y),
	]
	var all_under := 0
	for corner: Vector3 in corners:
		all_under = maxi(all_under, _first_wet(schedule, corner))
	# Each milestone of the timeline lands by its time, and within ten seconds of it.
	var targets := {
		"bow wet": [_first_wet(schedule, ends[0]), 35.0],
		"half the deck under": [_first_wet(schedule, middle), 100.0],
		"all of it under": [all_under, 160.0],
	}
	for label: String in targets:
		var tick: int = targets[label][0]
		var by := Ticks.from_seconds(targets[label][1])
		assert_between(tick, by - Ticks.from_seconds(10.0), by, label)


func test_flat_scenario_lists_to_port_after_one_minute() -> void:
	var schedule := _schedule(load(SimFixtures.FLAT_SINKING))
	var area := SimFixtures.deck().platforms[0].area
	var port := Vector3(area.get_center().x, 0.0, area.position.y)
	var starboard := Vector3(area.get_center().x, 0.0, area.end.y)
	var one_minute := Ticks.from_seconds(60.0)
	for tick in range(0, one_minute + 1, Ticks.RATE):
		assert_eq(schedule.pose_at(tick).heel_deg, 0.0, "upright at tick %d" % tick)
	for tick in range(one_minute + 1, Ticks.from_seconds(200.0), Ticks.RATE):
		var pose := schedule.pose_at(tick)
		assert_lt(pose.heel_deg, 0.0, "listing to port at tick %d" % tick)
		assert_lt(pose.world_height(port), pose.world_height(starboard), "port low, tick %d" % tick)
	# Trim and heel together pass the grip angle by about 1:45, and not long before.
	var grip := SimFixtures.rules().grip_angle_deg
	var steep_from := -1
	for tick in Ticks.from_seconds(200.0):
		if schedule.pose_at(tick).slope_deg() > grip:
			steep_from = tick
			break
	var by := Ticks.from_seconds(105.0)
	assert_between(steep_from, by - Ticks.from_seconds(10.0), by, "past the grip angle")


func test_scenario_sign_decides_which_end_floods() -> void:
	var bow_down := _schedule(SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [60.0, 6.0, 8.0, 0.0]]))
	var stern_down := _schedule(
		SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [60.0, 6.0, -8.0, 0.0]])
	)
	var ends := _deck_ends()
	assert_lt(_first_wet(bow_down, ends[0]), _first_wet(bow_down, ends[1]), "bow first")
	assert_lt(_first_wet(stern_down, ends[1]), _first_wet(stern_down, ends[0]), "stern first")

	var tick := Ticks.from_seconds(30.0)
	var bow_pose := bow_down.pose_at(tick)
	var stern_pose := stern_down.pose_at(tick)
	assert_lt(bow_pose.world_height(ends[0]), bow_pose.world_height(ends[1]))
	assert_gt(stern_pose.world_height(ends[0]), stern_pose.world_height(ends[1]))
	assert_almost_eq(
		bow_pose.world_height(ends[0]), stern_pose.world_height(ends[1]), 0.0001, "mirrored"
	)


func test_ship_is_level_until_the_scenario_starts() -> void:
	var starts_at := 10.0
	var schedule := _schedule(
		SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [20.0, 3.0, 10.0, 5.0]], starts_at)
	)
	var level := schedule.pose_at(0).transform
	var start := Ticks.from_seconds(starts_at)
	for tick in range(0, start + 1):
		var pose := schedule.pose_at(tick)
		assert_eq(pose.transform, level, "tick %d" % tick)
		assert_eq([pose.sink, pose.trim_deg, pose.heel_deg], [0.0, 0.0, 0.0])
	assert_eq(level.origin.y, SimFixtures.deck().freeboard, "unsunk at the freeboard")
	var moving := schedule.pose_at(start + 1)
	assert_gt(moving.sink, 0.0)
	assert_gt(moving.trim_deg, 0.0)
	assert_gt(moving.heel_deg, 0.0)


func test_highest_surface_migrates() -> void:
	# The steamer's bow-down scenario: the stern rises as the bow goes, so the high
	# ground moves aft from the bridge to the poop deck.
	var layout := SimFixtures.steamer()
	var schedule := SinkSchedule.new(
		load(SimFixtures.STEAMER_SINKING), layout.freeboard, SeedStreams.derive(SEED, "sink")
	)
	var surfaces := Surfaces.new(layout)
	var expected := {
		60.0: SimFixtures.platform_named(layout, &"bridge"),
		160.0: SimFixtures.platform_named(layout, &"poop deck"),
	}
	for at: float in expected:
		var pose := schedule.pose_at(Ticks.from_seconds(at))
		var highest := surfaces.highest_platform(pose)
		assert_eq(highest, expected[at], "highest at %s s" % at)
		assert_false(surfaces.flooded(highest, pose), "and dry at %s s" % at)


## Every corner of every one of [param layout]'s platforms whose name is
## [param deck_name], or of every platform below the main deck for &"".
func _corners(layout: ShipLayout, deck_name: StringName) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for platform: ShipPlatform in layout.platforms:
		var below := deck_name == &"" and platform.height < 0.0
		if not below and platform.name != deck_name:
			continue
		var area := platform.area
		for corner: Vector2 in [
			area.position,
			Vector2(area.end.x, area.position.y),
			area.end,
			Vector2(area.position.x, area.end.y)
		]:
			corners.append(Vector3(corner.x, platform.height, corner.y))
	return corners


## The highest world height, under [param pose], of [param points].
func _top(pose: ShipPose, points: Array[Vector3]) -> float:
	var top := -INF
	for point: Vector3 in points:
		top = maxf(top, pose.world_height(point))
	return top


func test_steamer_floods_from_the_bottom_up() -> void:
	# The rev-3 timeline (§5): the lower deck floods first, from its forward end, so
	# the match is a climb; the main deck and the forecastle go after it, and by the
	# cap every surface is well under.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var schedule := SinkSchedule.new(
		load(SimFixtures.STEAMER_SINKING), layout.freeboard, SeedStreams.derive(SEED, "sink")
	)
	var lower := _corners(layout, &"")
	var main_deck := _corners(layout, &"main deck")
	var forecastle := _corners(layout, &"forecastle")
	assert_gt(lower.size(), 0, "the steamer has a lower deck")
	# Its forward end: the middle of the lower deck's forward-most edge.
	var forward_end := Vector3(-INF, 0.0, 0.0)
	for platform: ShipPlatform in layout.platforms:
		if platform.height < 0.0 and platform.area.end.x > forward_end.x:
			var middle := platform.area.get_center().y
			forward_end = Vector3(platform.area.end.x, platform.height, middle)
	var calm_until := Ticks.from_seconds(45.0)
	for tick in range(0, calm_until, Ticks.RATE):
		assert_false(surfaces.wet(forward_end, schedule.pose_at(tick)), "calm at tick %d" % tick)
	assert_true(
		surfaces.wet(forward_end, schedule.pose_at(Ticks.from_seconds(50.0))),
		"the lower deck wet at its forward end by 0:50"
	)
	var flooded_below := schedule.pose_at(Ticks.from_seconds(90.0))
	assert_lt(_top(flooded_below, lower), 0.0, "the whole lower deck under by 1:30")
	var dry_until := Ticks.from_seconds(90.0)
	for tick in range(0, dry_until + 1, Ticks.RATE):
		var pose := schedule.pose_at(tick)
		for point: Vector3 in main_deck + forecastle:
			assert_false(surfaces.wet(point, pose), "%s dry at tick %d" % [point, tick])
	var two_minutes := schedule.pose_at(Ticks.from_seconds(120.0))
	assert_lt(_top(two_minutes, forecastle), 0.0, "the forecastle under by 2:00")
	# By the cap, every surface's every point is at least half a metre under.
	var cap := schedule.pose_at(Ticks.from_seconds(210.0))
	var everything: Array[Vector3] = []
	for platform: ShipPlatform in layout.platforms:
		everything.append_array(_corners(layout, platform.name))
	for ramp: ShipRamp in layout.ramps:
		for end in 2:
			for corner: Vector2 in ramp.end_edge(end):
				everything.append(Vector3(corner.x, ramp.end_point(end).y, corner.y))
	for blocker: ShipBlocker in layout.blockers:
		var reach := Vector2(blocker.radius, blocker.radius)
		var foot := (
			blocker.area
			if blocker.shape == ShipBlocker.Shape.BOX
			else Rect2(blocker.centre - reach, reach * 2.0)
		)
		for corner: Vector2 in [
			foot.position,
			foot.end,
			Vector2(foot.position.x, foot.end.y),
			Vector2(foot.end.x, foot.position.y)
		]:
			everything.append(Vector3(corner.x, blocker.top, corner.y))
	assert_lte(_top(cap, everything), -0.5, "every surface 0.5 m under by 3:30")
