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
