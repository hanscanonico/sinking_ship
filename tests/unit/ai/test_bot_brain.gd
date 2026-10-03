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
