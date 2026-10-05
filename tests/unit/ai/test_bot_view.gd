extends GutTest
## What a bot perceives (D10, Q16): the snapshot reaction_ticks old, the bodies its
## eyes see through no wall, those within earshot through anything, where it last
## perceived the rest for a while, and the pose now — never the schedule's future.

const SEED := 1701
## A seed whose iceberg strikes the steamer early: 13.3 s in.
const EARLY_HIT_SEED := 37
## Eyes and hearing are a person's: the first-person camera's eye, six metres.
const EYE := 1.6
const HEARING := 6.0


func _profile() -> BotProfile:
	return load(SimFixtures.NORMAL_BOT)


## A deck 30 × 12 m with a wall 2.5 m tall along x = 0, from side to side but for a
## doorway 1.1 m wide across z = 4.45.
func _walled() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var deck := ShipPlatform.new()
	deck.area = Rect2(-15.0, -6.0, 30.0, 12.0)
	layout.platforms = [deck]
	var blockers: Array[ShipBlocker] = []
	for area: Rect2 in [Rect2(-0.1, -6.0, 0.2, 9.9), Rect2(-0.1, 5.0, 0.2, 1.0)]:
		var wall := ShipBlocker.new()
		wall.area = area
		wall.top = 2.5
		blockers.append(wall)
	layout.blockers = blockers
	layout.spawns = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	return layout


func _sim(seats: int) -> MatchSim:
	return MatchSim.create(SimFixtures.config(seats, null, SEED, _walled()))


## Seat 0's view of [param sim], shown its snapshot once.
func _view_of(sim: MatchSim) -> BotView:
	var view := BotView.new(0, _profile(), Surfaces.new(sim.config.ship))
	view.push(sim.snapshot(), sim.pose())
	return view


func _seats_in(view: BotView) -> Array[int]:
	var seats: Array[int] = []
	for entry: Dictionary in view.snapshot()["seats"]:
		seats.append(entry["seat"])
	return seats


func test_view_lags_by_reaction_ticks() -> void:
	var delay := _profile().reaction_ticks
	var sim := _sim(2)
	var view := _view_of(sim)
	var first: int = sim.snapshot()["tick"]
	for _tick in 3 * delay:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)})
		view.push(sim.snapshot(), sim.pose())
		var latest: int = sim.snapshot()["tick"]
		assert_eq(view.snapshot()["tick"], maxi(first, latest - delay), "at %d" % latest)
	var seen_at: Vector3 = view.snapshot()["seats"][0]["pos"]
	assert_lt(seen_at.x, sim.state.seats[0].pos.x, "it sees itself where it was, not is")


func test_view_has_no_future_schedule() -> void:
	# Two steamer matches on one seed, one with a lurch telegraphed at 25 s: until the
	# telegraph, bots that cannot read the schedule's future play them alike.
	var calm: SinkScenario = load(SimFixtures.STEAMER_SCRIPT)
	var lurching: SinkScenario = calm.duplicate()
	var events: Array[SinkEvent] = []
	events.assign(calm.events)
	events.append(SimFixtures.lurch(25.0, -20.0))
	lurching.events = events
	var logs: Array[InputLog] = []
	for scenario: SinkScenario in [calm, lurching]:
		var config := SimFixtures.config(6, scenario, SEED, SimFixtures.steamer())
		var runner := MatchRunner.new(
			MatchSim.create(config), BotInputSource.fill(config, _profile())
		)
		runner.run(Ticks.from_seconds(23.0))
		logs.append(runner.input_log)
		var source := BotInputSource.new(0, _profile(), config)
		source.observe(runner.snapshot, runner.sim.pose())
		assert_eq(source.view.pose().lurch_warning, 0.0, "the warning is not up yet")
	for tick in range(logs[0].first_tick, logs[0].last_tick() + 1):
		for seat in 6:
			var a := logs[0].frame(tick, seat)
			var b := logs[1].frame(tick, seat)
			if [a.move, a.look_yaw, a.buttons] != [b.move, b.look_yaw, b.buttons]:
				fail_test("seat %d acted on the future at tick %d" % [seat, tick])
				return
	# And the view holds nothing that could tell it: no schedule, only a pose.
	var view := BotView.new(0, _profile(), Surfaces.new(SimFixtures.steamer()))
	for property: Dictionary in view.get_property_list():
		assert_ne(property["class_name"], &"SinkSchedule", property["name"])


func test_view_shows_no_hit_before_it_happens() -> void:
	# Two steamer matches on one seed, one struck by the iceberg and one not: until it
	# strikes, bots play them alike — none acts on a hit to come — and a bot sees the
	# strike only once its delayed snapshot reaches the tick it happened on.
	# Struck by the seed's first draw, given: it strikes early.
	var struck: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	struck.explicit_hit = IcebergHit.draw(struck.hit, SeedStreams.derive(EARLY_HIT_SEED, "sink"))
	var unstruck: SinkScenario = struck.duplicate()
	unstruck.hit = null
	unstruck.explicit_hit = null
	var delay := _profile().reaction_ticks
	var struck_at := -1
	var logs: Array[InputLog] = []
	for scenario: SinkScenario in [struck, unstruck]:
		var config := SimFixtures.config(6, scenario, EARLY_HIT_SEED, SimFixtures.steamer())
		var bots := BotInputSource.fill(config, _profile())
		var runner := MatchRunner.new(MatchSim.create(config), bots)
		if scenario == unstruck:
			runner.run(struck_at)
			logs.append(runner.input_log)
			continue
		struck_at = runner.sim.schedule.hit_tick()
		assert_between(struck_at, 0, 15 * Ticks.RATE, "the seed's iceberg strikes early")
		var view := (bots[0] as BotInputSource).view
		var seen_at := -1
		while seen_at == -1 and runner.tick() <= struck_at + delay + 1:
			runner.step()
			for event: Dictionary in view.snapshot()["events"]:
				if event["kind"] == SimEvent.Kind.HOLED:
					seen_at = runner.tick()
		# The snapshot after the hit's tick carries it; the view is delay ticks behind.
		assert_eq(seen_at, struck_at + 1 + delay, "seen as it happened, reaction_ticks late")
		logs.append(runner.input_log)
	for tick in range(logs[0].first_tick, struck_at):
		for seat in 6:
			var a := logs[0].frame(tick, seat)
			var b := logs[1].frame(tick, seat)
			if [a.move, a.look_yaw, a.buttons] != [b.move, b.look_yaw, b.buttons]:
				fail_test("seat %d acted on the hit to come at tick %d" % [seat, tick])
				return
	# And the view holds nothing that could tell where or when: no hit, no damage.
	var view := BotView.new(0, _profile(), Surfaces.new(SimFixtures.steamer()))
	for property: Dictionary in view.get_property_list():
		assert_false(property["class_name"] in [&"IcebergHit", &"HitDamage"], property["name"])


func test_view_hides_bodies_behind_walls() -> void:
	var sim := _sim(4)
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, -3.0))
	# Behind the wall, out of earshot; on its own side; through the doorway.
	SimFixtures.place(sim, 1, Vector3(8.0, 0.0, -3.0))
	SimFixtures.place(sim, 2, Vector3(-8.0, 0.0, 5.0))
	SimFixtures.place(sim, 3, Vector3(8.0, 0.0, 4.45))
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 4.45))
	assert_eq(_seats_in(_view_of(sim)), [0, 2, 3], "the doorway, and its own side")
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, -3.0))
	assert_eq(_seats_in(_view_of(sim)), [0, 2], "the wall hides seat 1, and seat 3 now")
	# The same three with no wall: every one.
	var open := MatchSim.create(SimFixtures.config(4, null, SEED))
	for seat in 4:
		open.state.seats[seat].pos = sim.state.seats[seat].pos
		open.state.seats[seat].surface = 0
	assert_eq(_seats_in(_view_of(open)), [0, 1, 2, 3])


func test_view_hears_bodies_within_six_metres_through_walls() -> void:
	assert_eq(_profile().hearing_m, HEARING)
	assert_eq(_profile().eye_height_m, EYE)
	var sim := _sim(3)
	SimFixtures.place(sim, 0, Vector3(-1.0, 0.0, -3.0))
	SimFixtures.place(sim, 1, Vector3(HEARING - 1.5, 0.0, -3.0))
	SimFixtures.place(sim, 2, Vector3(HEARING + 0.5, 0.0, -3.0))
	var surfaces := Surfaces.new(sim.config.ship)
	for seat: int in [1, 2]:
		var eye := Vector3.UP * EYE
		var them := sim.state.seats[seat].pos + eye
		assert_false(
			surfaces.line_of_sight(sim.state.seats[0].pos + eye, them, sim.pose()), "walled"
		)
	assert_eq(_seats_in(_view_of(sim)), [0, 1], "it hears seat 1, not seat 2")


func test_view_remembers_last_seen_for_three_seconds() -> void:
	var sim := _sim(2)
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, -3.0))
	var seen_at := Vector3(-8.0, 0.0, 5.0) + Vector3(-HEARING, 0.0, 0.0)
	SimFixtures.place(sim, 1, seen_at)
	var hidden_at := Vector3(8.0, 0.0, -3.0)
	var view := BotView.new(0, _profile(), Surfaces.new(sim.config.ship))
	var moved: int = sim.snapshot()["tick"] + Ticks.RATE
	var memory := Ticks.from_seconds(_profile().memory_seconds)
	var last_fresh := -1
	var last_held := -1
	for _tick in 5 * Ticks.RATE:
		if sim.state.tick == moved:
			sim.state.seats[1].pos = hidden_at
		view.push(sim.snapshot(), sim.pose())
		var seen := view.snapshot()
		for entry: Dictionary in seen["seats"]:
			if entry["seat"] != 1:
				continue
			assert_eq(entry["pos"], seen_at, "only ever where it was seen, at %d" % seen["tick"])
			last_held = seen["tick"]
			if not entry.has(BotView.REMEMBERED):
				last_fresh = seen["tick"]
		SimFixtures.step(sim)
	assert_gt(last_fresh, 0, "it saw seat 1")
	assert_lte(last_fresh, moved, "and stopped seeing it once it went behind the wall")
	assert_eq(last_held - last_fresh, memory, "it remembered for three seconds, and no longer")
