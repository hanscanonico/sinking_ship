extends GutTest
## The golden match is seed 1701 with six seats, every one a bot — what
## `make match SEED=1701` prints. Its transcript is recorded per platform (R6):
##   make match SEED=1701 > tests/golden/golden_1701_6.<os>-<arch>.txt

const RunMatch := preload("res://tools/run_match.gd")

const GOLDEN_SEED := 1701
const GOLDEN_SEATS := 6
const MAX_TICKS := 300 * Ticks.RATE
const RESUME_EVERY := 7


## Runs the golden match to its end; returns the runner and its transcript.
func _golden() -> Array:
	var runner := RunMatch.bots_only(RunMatch.default_config(GOLDEN_SEED, GOLDEN_SEATS))
	return [runner, RunMatch.transcript(runner, MAX_TICKS)]


func test_same_seed_twice_in_process() -> void:
	var first := _golden()
	var second := _golden()
	var runner: MatchRunner = first[0]
	assert_true(runner.is_over(), "the golden match ends")
	assert_ne(runner.digest.hex(), "")
	assert_eq(second[0].digest.hex(), runner.digest.hex())
	assert_eq(second[1], first[1])
	assert_eq(second[0].snapshot, runner.snapshot)


func test_replay_from_log_matches_digest() -> void:
	var played: MatchRunner = _golden()[0]
	var config := played.sim.config
	assert_true(played.input_log.matches(config))
	var replay := MatchRunner.new(MatchSim.create(config), played.input_log.replay_sources())
	while not replay.is_over() and replay.tick() <= played.input_log.last_tick():
		replay.step()
	assert_eq(replay.tick(), played.tick())
	assert_eq(replay.digest.hex(), played.digest.hex())
	assert_eq(replay.snapshot, played.snapshot)

	var changed := RunMatch.default_config(GOLDEN_SEED, GOLDEN_SEATS)
	changed.rules = changed.rules.duplicate()
	changed.rules.knockback += 1.0
	assert_false(played.input_log.matches(changed), "a log refuses changed numbers")


func test_snapshot_continuation_is_exact() -> void:
	var played: MatchRunner = _golden()[0]
	var input_log := played.input_log
	var config := played.sim.config
	# Re-run the match from its log, keeping every snapshot.
	var replay := MatchRunner.new(MatchSim.create(config), input_log.replay_sources())
	var snapshots: Array[Dictionary] = [replay.snapshot]
	while not replay.is_over():
		replay.step()
		snapshots.append(replay.snapshot)
	# From every RESUME_EVERY-th snapshot, and from the first snapshot with each
	# shove, stagger and fall in flight — a fall can be shorter than the stride,
	# and where it lands differs by platform — a sim rebuilt from it must step to
	# the same next second.
	var golden_frames := func(tick: int) -> Array[InputFrame]:
		var frames: Array[InputFrame] = []
		for seat in config.seats:
			frames.append(input_log.frame(tick, seat))
		return frames
	var covered := {"shove": false, "stagger": false, "airborne": false}
	for start in range(snapshots.size() - 1):
		if not _note_coverage(snapshots[start], covered) and start % RESUME_EVERY != 0:
			continue
		if not _continues(snapshots, start, config, golden_frames):
			return
	# On some platforms the golden match has no fall in flight at any tick, so a
	# walk off the deck through the starboard railing's gap stands in for one.
	var fall := SimFixtures.sim(2)
	SimFixtures.place(fall, 1, Vector3(-10.0, 0.0, 0.0))
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	SimFixtures.place(fall, 0, Vector3(gap.x, 0.0, 3.0))
	var walk: Array[InputFrame] = [SimFixtures.frame(0, Vector2.DOWN), SimFixtures.frame(1)]
	var walked: Array[Dictionary] = [fall.snapshot()]
	for _tick in 4 * Ticks.RATE:
		if fall.is_over():
			break
		fall.step(walk)
		walked.append(fall.snapshot())
	var walk_frames := func(_tick: int) -> Array[InputFrame]: return walk
	for start in range(walked.size() - 1):
		if walked[start]["seats"][0]["state"] != PlayerState.Body.AIRBORNE:
			continue
		covered["airborne"] = true
		if not _continues(walked, start, fall.config, walk_frames):
			return
	for field: String in covered:
		assert_true(covered[field], "the match resumes from a %s in flight" % field)


func test_golden_for_this_platform() -> void:
	var platform := "%s-%s" % [OS.get_name().to_lower(), Engine.get_architecture_name()]
	var path := "res://tests/golden/golden_%d_%d.%s.txt" % [GOLDEN_SEED, GOLDEN_SEATS, platform]
	if not FileAccess.file_exists(path):
		pending("no golden recorded for %s" % platform)
		return
	assert_eq(_golden()[1], FileAccess.get_file_as_string(path))


## Rebuilds a sim from [param snapshots] at [param start] and steps it up to a
## second on, fed [param frames_at] for each tick; false, failing the test, when
## it leaves the recorded snapshots.
func _continues(
	snapshots: Array[Dictionary], start: int, config: MatchConfig, frames_at: Callable
) -> bool:
	var resumed := MatchSim.from_snapshot(snapshots[start], config)
	assert_eq(resumed.snapshot(), _without_events(snapshots[start]), "tick %d" % start)
	for offset in range(1, mini(Ticks.RATE, snapshots.size() - 1 - start) + 1):
		var tick := start + offset - 1
		resumed.step(frames_at.call(tick))
		if resumed.snapshot() != snapshots[start + offset]:
			fail_test("continuation from tick %d diverged at tick %d" % [start, tick])
			return false
	return true


func _without_events(snapshot: Dictionary) -> Dictionary:
	var copy := snapshot.duplicate()
	copy["events"] = []
	return copy


## Marks what the snapshot has in flight; true when that is something not seen before.
func _note_coverage(snapshot: Dictionary, covered: Dictionary) -> bool:
	var seen := {}
	for entry: Dictionary in snapshot["seats"]:
		if entry["action"] != PlayerState.Action.IDLE:
			seen["shove"] = true
		if entry["stagger"] > 0:
			seen["stagger"] = true
		if entry["state"] == PlayerState.Body.AIRBORNE:
			seen["airborne"] = true
	var fresh := false
	for field: String in seen:
		fresh = fresh or not covered[field]
		covered[field] = true
	return fresh
