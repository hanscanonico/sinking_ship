extends GutTest
## The input log keeps every frame as received, packed: each comes back field for field,
## a frame that never came comes back as none, and a match replayed from it is the same
## match, digest for digest (D4).

const RunMatch := preload("res://tools/run_match.gd")
const SEED := 1701


func test_every_frame_comes_back_as_it_came() -> void:
	var config := SimFixtures.config(3, load(SimFixtures.FLAT_SINKING), SEED)
	var recorded := InputLog.new(config, 40)
	# As received: a seat that sent nothing, and numbers a frame never validated.
	var sent: Array[InputFrame] = [
		InputFrame.new(0, 40, Vector2i(127, -127), InputFrame.SHOVE | InputFrame.JUMP, 65535),
		null,
		InputFrame.new(5, 39, Vector2i(-300, 900), 0xFF, -12),
	]
	recorded.record(40, sent)
	recorded.record(41, [null, null, null] as Array[InputFrame])
	assert_eq([recorded.first_tick, recorded.last_tick()], [40, 41])
	for seat in 3:
		var back := recorded.frame(40, seat)
		if sent[seat] == null:
			assert_null(back, "seat %d sent nothing" % seat)
			continue
		var given := sent[seat]
		assert_eq(
			[back.seat, back.tick, back.move, back.buttons, back.look_yaw],
			[given.seat, given.tick, given.move, given.buttons, given.look_yaw],
			"seat %d" % seat
		)
	assert_null(recorded.frame(41, 0), "a tick of no frames")
	assert_null(recorded.frame(42, 0), "a tick not yet stepped")
	assert_null(recorded.frame(39, 0), "a tick before the log")
	assert_null(recorded.frame(40, 3), "a seat the match does not have")


func test_a_match_replayed_from_its_log_is_the_same_match() -> void:
	var config := RunMatch.default_config(SEED)
	var played := RunMatch.bots_only(config)
	played.run(30 * Ticks.RATE)
	var replay := MatchRunner.new(MatchSim.create(config), played.input_log.replay_sources())
	replay.run(30 * Ticks.RATE)
	assert_eq(replay.digest.hex(), played.digest.hex(), "digest for digest")
