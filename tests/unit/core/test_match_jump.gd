extends GutTest
## A match jumped to a moment of its sinking (MatchJump, §5b.4's `make capture … JUMP=1`):
## a snapshot at that tick, live, every seat on footing the sea has not reached — and a
## match like any other from there, continued exactly from its own snapshot (D5).

const RunMatch := preload("res://tools/run_match.gd")
const SEED := 1701
## Physics seconds after the hit: well into her slow sinking, her bow low.
const PHYS := 7560.0


func test_seats_stand_dry_at_the_moment_jumped_to() -> void:
	var config := RunMatch.default_config(SEED)
	var schedule := config.schedule()
	var tick := schedule.physics_tick(PHYS)
	assert_eq(tick, schedule.hit_tick() + Ticks.from_seconds(PHYS), "by the scenario's clock")
	var snapshot := MatchJump.snapshot(config, tick)
	assert_eq(snapshot["tick"], tick)
	assert_eq(snapshot["phase"], MatchState.Phase.LIVE)
	var sim := MatchSim.from_snapshot(snapshot, config)
	var pose := sim.pose()
	assert_gt(absf(pose.trim_deg), 2.0, "she leans by then")
	var dry := 0
	for player: PlayerState in sim.state.seats:
		assert_ne(player.surface, Surfaces.NONE, "seat %d stands on something" % player.seat)
		if not sim.surfaces.wet(player.pos, pose):
			dry += 1
	assert_eq(dry, config.seats, "every seat out of the water")


func test_a_jumped_match_continues_exactly() -> void:
	var config := RunMatch.default_config(SEED)
	var tick := config.schedule().physics_tick(PHYS)
	var jumped := MatchSim.from_snapshot(MatchJump.snapshot(config, tick), config)
	var bots := BotInputSource.fill(config, BotProfile.for_tier(config.bot_tier))
	var played := MatchRunner.new(jumped, bots)
	var start := played.sim.snapshot()
	played.run(Ticks.RATE * 3)
	var midway := played.sim.snapshot()
	played.run(Ticks.RATE * 3)
	var resumed := MatchSim.from_snapshot(midway, config)
	var frames := func(at: int) -> Array[InputFrame]:
		var row: Array[InputFrame] = []
		for seat in config.seats:
			row.append(played.input_log.frame(at, seat))
		return row
	while resumed.state.tick < played.sim.state.tick:
		resumed.step(frames.call(resumed.state.tick))
	assert_eq(resumed.snapshot(), played.sim.snapshot(), "from its own snapshot, the same")
	assert_eq(start["tick"], tick)
