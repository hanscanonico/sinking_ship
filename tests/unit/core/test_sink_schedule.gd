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


func test_ship_is_level_until_the_hit() -> void:
	# The physics' sinking: at rest, level and dry inside until the iceberg strikes;
	# after it she settles deeper and leans as her water lies (SH27), with water in the
	# cells the gash opens, and the doors the ship shuts shutting.
	var layout := SimFixtures.steamer()
	var config := SimFixtures.config(2, load(SimFixtures.STEAMER_SINKING), SEED, layout)
	var schedule := config.schedule()
	var hit := schedule.hit_tick()
	assert_gt(hit, 0, "struck after the start")
	var resting := schedule.pose_at(0)
	for tick: int in [0, hit / 2, hit]:
		var pose := schedule.pose_at(tick)
		assert_eq(pose.transform, resting.transform, "tick %d" % tick)
		assert_eq([pose.sink, pose.trim_deg, pose.heel_deg], [0.0, 0.0, 0.0])
		for cell in layout.structure.cells.size():
			var box := layout.structure.cells[cell]
			var floor_point := Vector3((box.low.x + box.high.x) * 0.5, box.low.y, 0.0)
			assert_almost_eq(pose.water_height(floor_point), box.low.y, 1e-6, "%s dry" % box.name)
	assert_almost_eq(resting.transform.origin.y, layout.freeboard, 0.01, "at her freeboard")
	var later := schedule.pose_at(hit + Ticks.from_seconds(120.0))
	assert_gt(later.sink, 0.0, "deeper once holed")
	assert_ne(later.transform.basis, Basis.IDENTITY, "and leaning as her water lies")
	var wet := 0
	for cell in layout.structure.cells.size():
		var box := layout.structure.cells[cell]
		var lowest := INF
		for corner in 4:
			var at := Vector3(
				box.high.x if corner & 1 else box.low.x,
				box.low.y,
				box.high.z if corner & 2 else box.low.z
			)
			lowest = minf(lowest, later.world_height(at))
		if later.levels[cell] > lowest + 0.01:
			wet += 1
	assert_gt(wet, 0, "water in her cells")
	var doors := later.doors_shut.keys()
	assert_false(doors.is_empty(), "the ship shut her watertight doors")
	for door: StringName in doors:
		assert_eq(later.doors_shut[door], 1.0, "%s shut by 2 min" % door)
		assert_almost_eq(
			schedule.pose_at(hit + Ticks.from_seconds(10.0)).doors_shut[door], 0.5, 0.01
		)


func test_highest_surface_migrates() -> void:
	# The steamer's bow-down scenario: the stern rises as the bow goes, so the high
	# ground moves aft from the bridge to the poop deck.
	var layout := SimFixtures.steamer()
	var schedule := SinkSchedule.new(
		load(SimFixtures.STEAMER_SCRIPT), layout.freeboard, SeedStreams.derive(SEED, "sink")
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


func test_phase_is_named_from_where_she_stands() -> void:
	# Struck forward and sinking by the head: holed, then flooding as a cell takes
	# water, then by the head once her trim passes its mark — each from her pose then.
	var layout := SimFixtures.steamer()
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	scenario.explicit_hit = SimFixtures.explicit_hit(1, 4.0, 19.0, 1.0, 0.1, 1.5)
	scenario.explicit_hit.moment = 20.0
	var schedule := SinkSchedule.new(
		scenario, layout.freeboard, SeedStreams.derive(SEED, "sink"), layout.structure
	)
	var named := PackedStringArray()
	var tick := 0
	while tick < schedule.end_tick():
		var phase := schedule.phase_at(tick)
		if named.is_empty() or named[named.size() - 1] != phase:
			named.append(phase)
		var pose := schedule.pose_at(tick)
		if phase == "By the head":
			assert_gte(pose.trim_deg, SinkSchedule.TRIMMED_DEG, "tick %d: trimmed" % tick)
		# Tick by tick round the hit, every second after.
		tick += 1 if tick < schedule.hit_tick() + Ticks.RATE else Ticks.RATE
	assert_eq(named[0], "", "nothing before the hit")
	assert_eq(named[1], "Holed", "then holed")
	assert_eq(named[2], "Flooding", "then flooding")
	assert_true("By the head" in named, "and by the head: %s" % named)
	assert_false("By the stern" in named, "never by the stern")


func test_a_physics_lurch_is_warned_before_it_swings() -> void:
	# Struck forward and sinking by the head, she loses her stability and lurches over
	# as her deck goes under, warned a second or more ahead — the horn players hear, the
	# warning bots read (D10) — and the pose names the lurch while it is telegraphed and
	# while it swings.
	var layout := SimFixtures.steamer()
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	scenario.explicit_hit = SimFixtures.explicit_hit(1, 4.0, 19.0, 1.0, 0.1, 1.5)
	var schedule := SinkSchedule.new(
		scenario, layout.freeboard, SeedStreams.derive(SEED, "sink"), layout.structure
	)
	var warned := -1
	var lurched := -1
	var heel := 0.0
	for tick in schedule.end_tick():
		for event: SimEvent in schedule.events_at(tick):
			if event.kind == SimEvent.Kind.SHIP_LURCHING and warned == -1:
				warned = tick
			elif event.kind == SimEvent.Kind.SHIP_LURCHED and lurched == -1:
				lurched = tick
				heel = event.heel_deg
		if lurched != -1:
			break
	assert_gt(lurched, 0, "she lurches")
	assert_gte(lurched - warned, Ticks.from_seconds(1.0), "warned a second ahead or more")
	assert_ne(heel, 0.0, "by so many degrees")
	assert_eq(schedule.pose_at(lurched - 1).lurch_warning, heel, "the pose telegraphs it")
	assert_eq(schedule.pose_at(lurched).lurch, heel, "and names it as it swings")


func test_the_support_limit_is_read_through_the_series() -> void:
	# §5b.3's interim rule fires on the first kept state whose up component falls below
	# the cosine of the limit as the series sine of its complement (R21): a state on
	# that value is still supported, the next number below it is not.
	var limit := Attitude.sine_of_degrees(90.0 - 45.0)
	var below := limit - 1e-16
	assert_lt(below, limit, "a 64-bit number under the series value")
	var timeline := SinkTimeline.new()
	for up: float in [1.0, 0.9, limit, below, 0.5]:
		timeline.times.append(float(timeline.times.size()) * 10.0)
		var side := sqrt(1.0 - up * up)
		timeline.rotations.append_array([1.0, 0.0, 0.0, 0.0, up, -side, 0.0, side, up])
	assert_eq(timeline.first_past(45.0), 3, "the state just past the series value")
	assert_eq(timeline.first_past(80.0), -1, "never past a wider limit")
	assert_eq(timeline.first_past(5.0), 1, "past a narrower one sooner")
