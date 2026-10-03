extends GutTest

const SEED := 1701


func _profile() -> BotProfile:
	return load(SimFixtures.NORMAL_BOT)


## A bots-only match on [param config]; the runner is the one loop (D13).
func _bots(config: MatchConfig) -> MatchRunner:
	return MatchRunner.new(MatchSim.create(config), BotInputSource.fill(config, _profile()))


func test_bot_only_emits_input_frames() -> void:
	var config := SimFixtures.config(3, null, SEED)
	var runner := _bots(config)
	runner.run(60)
	var source := BotInputSource.new(1, _profile(), config)
	source.observe(runner.snapshot, runner.sim.pose())
	var seen := runner.snapshot.duplicate(true)
	var before := runner.sim.snapshot()
	var frame := source.next_frame(runner.tick())
	assert_true(frame is InputFrame)
	assert_eq(frame.seat, 1)
	assert_eq(frame.tick, runner.tick())
	assert_true(frame.move.length_squared() <= InputFrame.AXIS_MAX * InputFrame.AXIS_MAX)
	assert_eq(frame.buttons & ~InputFrame.SHOVE, 0, "SH1 bots only ever shove")
	assert_eq(runner.snapshot, seen, "the bot leaves what it saw alone")
	assert_eq(runner.sim.snapshot(), before, "and the match too")


func test_bot_is_deterministic_per_seed() -> void:
	var config := SimFixtures.config(4, load(SimFixtures.FLAT_SINKING), SEED)
	var first := _bots(config)
	var second := _bots(config)
	first.run(40 * Ticks.RATE)
	second.run(40 * Ticks.RATE)
	assert_eq(second.digest.hex(), first.digest.hex())
	for tick in range(first.input_log.first_tick, first.input_log.last_tick() + 1):
		for seat in config.seats:
			var a := first.input_log.frame(tick, seat)
			var b := second.input_log.frame(tick, seat)
			if [a.move, a.buttons] != [b.move, b.buttons]:
				fail_test("seat %d differs at tick %d" % [seat, tick])
				return

	# Each bot rolls only its own stream: another seed moves the headings.
	var reseeded := _bots(SimFixtures.config(4, load(SimFixtures.FLAT_SINKING), SEED + 1))
	reseeded.run(40 * Ticks.RATE)
	assert_ne(reseeded.digest.hex(), first.digest.hex())


## What seat [param seat]'s brain answers to one view of [param sim] as it stands.
func _first_move(sim: MatchSim, seat: int) -> Vector2:
	var source := BotInputSource.new(seat, _profile(), sim.config)
	source.observe(sim.snapshot(), sim.pose())
	return Vector2(source.next_frame(sim.state.tick).move)


func test_bot_gets_uphill_of_its_target_past_the_grip_angle() -> void:
	var grip := SimFixtures.rules().grip_angle_deg
	# Starboard down, so uphill is toward port (-z). The same bot, the same target
	# and the same heading roll each time; only the heel and the bot's side change.
	var moves: Array[Vector2] = []
	for case: Vector2 in [
		Vector2(grip - 4.0, 1.0), Vector2(grip + 4.0, 1.0), Vector2(grip + 4.0, -1.0)
	]:
		var sim := SimFixtures.sim(2, SimFixtures.tilted(0.0, case.x))
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, case.y))
		SimFixtures.place(sim, 1, Vector3(-6.0, 0.0, 0.0))
		moves.append(_first_move(sim, 0))
	var held := moves[0]
	var steep := moves[1]
	var already_uphill := moves[2]
	var aim_error := deg_to_rad(_profile().aim_error_deg + 1.0)
	assert_lt(absf(held.angle_to(Vector2(2.0, -1.0))), aim_error, "gripping: straight at it")
	assert_lt(steep.angle(), held.angle() - deg_to_rad(15.0), "steep: round its uphill side")
	assert_lt(absf(already_uphill.angle_to(Vector2(2.0, 1.0))), aim_error, "uphill: straight")


func test_bot_keeps_off_a_railing_gap_unless_lined_up() -> void:
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var gap := SimFixtures.rail_gap(edge)
	# Inside edge_margin of the starboard edge, and alone, so nothing to walk at.
	var near := edge - _profile().edge_margin_m * 0.8
	var railed := SimFixtures.sim(1)
	SimFixtures.place(railed, 0, Vector3(-8.0, 0.0, near))
	assert_eq(_first_move(railed, 0), Vector2.ZERO, "a railing between it and the sea: safe")

	var open := SimFixtures.sim(1)
	SimFixtures.place(open, 0, Vector3(gap.x, 0.0, near))
	assert_lt(_first_move(open, 0).y, 0.0, "level with the gap: backs off from it")

	# Its target stands between it and the gap: the shove is lined up, so it goes in.
	var lined_up := SimFixtures.sim(2)
	SimFixtures.place(lined_up, 0, Vector3(gap.x, 0.0, near))
	var reach := SimFixtures.rules().body_radius * 2.0
	SimFixtures.place(lined_up, 1, Vector3(gap.x, 0.0, near + reach))
	assert_gt(_first_move(lined_up, 0).y, 0.0, "lined up: walks at the target, toward the gap")


func test_bot_finds_its_way_up_to_its_target() -> void:
	# On the steamer, abaft the deckhouse, its only target standing still on the
	# bridge: round the deckhouse, up to the boat deck, up to the bridge.
	var layout := SimFixtures.steamer()
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var config := SimFixtures.config(2, null, SEED, layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, Vector3(-10.5, 0.0, 2.5))
	SimFixtures.place(sim, 1, Vector3(-2.5, layout.platforms[bridge].height, 0.0))
	var sources: Array[InputSource] = [BotInputSource.new(0, _profile(), config), InputSource.new()]
	var runner := MatchRunner.new(sim, sources)
	var reached := false
	for _tick in 30 * Ticks.RATE:
		runner.step()
		if sim.state.seats[0].surface == bridge:
			reached = true
			break
	assert_true(reached, "the bot climbed to the bridge")


func test_lone_bot_stays_dry_while_it_can() -> void:
	var config := SimFixtures.config(1, load(SimFixtures.FLAT_SINKING), SEED)
	var runner := _bots(config)
	SimFixtures.place(runner.sim, 0, Vector3.ZERO)
	runner.run(300 * Ticks.RATE)
	var bot := runner.sim.state.seats[0]
	assert_true(bot.is_out(), "the sea takes everyone in the end")

	# The last moment any spot edge_margin inside the deck was still dry — over the
	# whole sinking, not just while the bot was in.
	var area := config.ship.platforms[0].area.grow(-_profile().edge_margin_m)
	var surfaces := runner.sim.surfaces
	var last_dry := -1
	for tick in 300 * Ticks.RATE:
		var pose := runner.sim.schedule.pose_at(tick)
		for corner: Vector2 in [area.position, area.end, Vector2(area.position.x, area.end.y)]:
			if not surfaces.wet(Vector3(corner.x, 0.0, corner.y), pose):
				last_dry = tick
	assert_eq(bot.out_cause, PlayerState.Cause.WATER)
	assert_true(bot.surface != Surfaces.NONE, "it went under standing on the deck")
	assert_gt(bot.out_tick, last_dry - Ticks.RATE, "it held out until the deck ran out")
