extends GutTest
## The golden match is seed 1701 with eight seats, every one a bot — what
## `make match SEED=1701` prints. Its transcript is recorded per platform (R6):
##   make match SEED=1701 > tests/golden/golden_1701_8.<os>-<arch>.txt

const RunMatch := preload("res://tools/run_match.gd")

const GOLDEN_SEED := 1701
const GOLDEN_SEATS := 8
## `make match`'s STOP (MatchArgs): no match is capped, the tool stops one still on.
const MAX_TICKS := 900 * Ticks.RATE
const RESUME_EVERY := 7

## The golden match, played once for every test that only reads it (_golden).
static var _played: Array = []


## Runs the golden match to its end, served as `make match` serves it; returns the
## runner and its transcript — played afresh when [param fresh], else the one played
## first. From SH26 it lasts minutes (the sinking is the physics'), so it is played once
## for the suite, and once more where a second run is the point.
func _golden(fresh: bool = false) -> Array:
	if fresh or _played.is_empty():
		var host := RunMatch.served(RunMatch.default_config(GOLDEN_SEED, GOLDEN_SEATS))
		var played := [host.runner, RunMatch.transcript(host, MAX_TICKS)]
		if not fresh:
			_played = played
		return played
	return _played


func test_same_seed_twice_in_process() -> void:
	var first := _golden()
	var second := _golden(true)
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
	# On some platforms the golden match has no fall in flight at any tick, so two
	# walks stand in for one: off the flat deck through its railing's gap into the
	# sea, and off the steamer's poop deck down onto its main deck.
	var into_the_sea := SimFixtures.sim(2)
	SimFixtures.place(into_the_sea, 1, Vector3(-10.0, 0.0, 0.0))
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	SimFixtures.place(into_the_sea, 0, Vector3(gap.x, 0.0, 3.0))
	var onto_a_deck := SimFixtures.sim(2, null, SimFixtures.steamer())
	SimFixtures.place(onto_a_deck, 1, Vector3(5.0, 0.0, 4.2))
	SimFixtures.place(onto_a_deck, 0, Vector3(-14.6, 1.2, 1.2))
	var walks := {into_the_sea: Vector2.DOWN, onto_a_deck: Vector2.RIGHT}
	for fall: MatchSim in walks:
		var walk: Array[InputFrame] = [
			SimFixtures.frame(0, walks[fall], 0, 0.0), SimFixtures.frame(1, Vector2.ZERO, 0, 0.0)
		]
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


## The golden match is bots' and may hold no brace or charge on a platform, so a
## scripted duel carries them: seat 1 braces, seat 0 charges and breaks the brace,
## and both spend and wait for stamina, while seat 2, low to start with, braces
## until it is exhausted — a sim rebuilt from any of it must continue.
func test_continuation_through_brace_charge_and_stamina() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(3)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 180.0)
	SimFixtures.place(sim, 2, Vector3(-5.0, 0.0, 0.0))
	sim.state.seats[2].stamina = rules.brace_drain
	var press_at := Ticks.from_seconds(rules.charge_threshold)
	var release_at := press_at + Ticks.from_seconds(rules.charge_full)
	var duel := func(tick: int) -> Array[InputFrame]:
		var shove := InputFrame.SHOVE if tick >= press_at and tick < release_at else 0
		var brace := InputFrame.BRACE if tick < 2 * Ticks.RATE else 0
		return [
			SimFixtures.frame(0, Vector2.ZERO, shove, 0.0),
			SimFixtures.frame(1, Vector2.ZERO, brace, 180.0),
			SimFixtures.frame(2, Vector2.ZERO, InputFrame.BRACE, 0.0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for tick in 4 * Ticks.RATE:
		sim.step(duel.call(tick))
		played.append(sim.snapshot())
	var covered := {
		"brace": false,
		"charge": false,
		"charged shove": false,
		"regen wait": false,
		"exhaustion": false,
	}
	for start in range(played.size() - 1):
		var seen := false
		for entry: Dictionary in played[start]["seats"]:
			var in_flight := {
				"brace": entry["bracing"],
				"charge": entry["action"] == PlayerState.Action.CHARGE,
				"charged shove":
				entry["action"] == PlayerState.Action.ACTIVE and entry["charge"] > 0,
				"regen wait": entry["stamina_wait"] > 0,
				"exhaustion": entry["exhausted"],
			}
			for field: String in in_flight:
				if in_flight[field]:
					covered[field] = true
					seen = true
		if seen and not _continues(played, start, sim.config, duel):
			return
	for field: String in covered:
		assert_true(covered[field], "the duel resumes from a %s in flight" % field)


## The golden match may climb nowhere on a platform, so a scripted scene carries
## the sea: beside a deck 0.4 m out of it, seat 0 swims, climbs, is shoved back
## in by seat 1 — both frozen in the hit-stop — and climbs out again to dry off,
## while seat 2 drops in from 2 m, dunks and floats up, the ship lurches, and a
## roof over the deck collapses under seat 3 — a sim rebuilt from any of it must
## continue.
func test_continuation_through_swimming_and_climbing() -> void:
	var layout := SimFixtures.low_deck(0.4)
	var roof := ShipPlatform.new()
	roof.name = &"roof"
	roof.area = Rect2(6.0, -2.0, 3.0, 4.0)
	roof.height = 1.0
	var platforms := layout.platforms.duplicate()
	platforms.append(roof)
	layout.platforms = platforms
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.lurch(1.0, 5.0), SimFixtures.collapse(2.0, &"roof", 0.5)]
	)
	var sim := MatchSim.create(SimFixtures.config(4, scenario, 1, layout))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 4.6))
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.4), 90.0)
	SimFixtures.place(sim, 2, Vector3(-6.0, 2.0, 5.5))
	SimFixtures.place(sim, 3, Vector3(7.5, 1.0, 0.0))
	var scene := func(tick: int) -> Array[InputFrame]:
		var shove := InputFrame.SHOVE if tick == 4 else 0
		return [
			SimFixtures.frame(0, Vector2(0.0, -1.0), 0, -90.0),
			SimFixtures.frame(1, Vector2.ZERO, shove, 90.0),
			SimFixtures.frame(2, Vector2.ZERO, 0, 0.0),
			SimFixtures.frame(3, Vector2.ZERO, 0, 0.0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for tick in 4 * Ticks.RATE:
		sim.step(scene.call(tick))
		played.append(sim.snapshot())
	var covered := {
		"swim": false,
		"climb": false,
		"dunk": false,
		"knock back": false,
		"drying off": false,
		"hit-stop": false,
		"lurch": false,
		"fall from a collapse": false,
	}
	var rules := sim.config.rules
	for start in range(played.size() - 1):
		var seen := false
		var pose := sim.schedule.pose_at(start)
		for entry: Dictionary in played[start]["seats"]:
			var vel: Vector3 = entry["vel"]
			var swimming: bool = entry["state"] == PlayerState.Body.SWIMMING
			var in_flight := {
				"swim": swimming,
				"climb": entry["climb"] > 0,
				"dunk": swimming and vel.y != 0.0,
				"knock back": swimming and entry["stagger"] > 0,
				"drying off":
				entry["state"] == PlayerState.Body.GROUNDED and entry["cold"] < rules.cold_meter,
				"hit-stop": entry["hitstop"] > 0,
				"lurch": pose.lurch != 0.0,
				"fall from a collapse":
				not pose.collapsed.is_empty() and entry["state"] == PlayerState.Body.AIRBORNE,
			}
			for field: String in in_flight:
				if in_flight[field]:
					covered[field] = true
					seen = true
		if seen and not _continues(played, start, sim.config, scene):
			return
	for field: String in covered:
		assert_true(covered[field], "the scene resumes from a %s in flight" % field)


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


## A client resets one sim to snapshot after snapshot (MatchSim.restore). Restored to
## a snapshot after running well past it — the bridge down, railings broken that the
## snapshot has whole — a sim goes on exactly as the match went on from there: the
## steamer, eight bots, the bridge going early and two railings broken by hand.
func test_restore_on_a_used_sim_continues_exactly() -> void:
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SCRIPT).duplicate()
	var bridge := SimFixtures.collapse(0.0, &"bridge", 1.0)
	SimFixtures.with_events(sinking, [bridge] as Array[SinkEvent])
	var config := SimFixtures.config(8, sinking, GOLDEN_SEED, SimFixtures.steamer())
	var bots := BotInputSource.fill(config, load(SimFixtures.NORMAL_BOT))
	var runner := MatchRunner.new(MatchSim.create(config), bots)
	var truth := {runner.tick(): runner.snapshot}
	var broken_at := 4 * Ticks.RATE
	while runner.tick() < 14 * Ticks.RATE and not runner.is_over():
		if runner.tick() == broken_at:
			runner.sim.state.railing_hp[0] = 0.0
			runner.sim.state.railing_hp[7] = 0.0
		runner.step()
		truth[runner.tick()] = runner.snapshot
	var end := runner.tick()
	var used := MatchSim.create(config)
	var collapse_at := used.schedule.fired(end)[0].at as int
	var differ := ""
	for at: int in [Ticks.RATE, 5 * Ticks.RATE, 8 * Ticks.RATE]:
		# Broken in the used sim alone: restore must mend it.
		used.state.railing_hp[3] = 0.0
		while used.state.tick < at + 5 * Ticks.RATE:
			used.step(_row(runner.input_log, used.state.tick, config.seats))
		assert_true(used.pose().collapsed.has(&"bridge"), "the used sim lost the bridge")
		assert_true(used.state.broken_railings().has(3), "and railing 3")
		var broken := MatchState.broken_in(truth[at]["railing_hp"])
		assert_eq(broken.has(0), at > broken_at, "tick %d: as the match had railing 0" % at)
		used.restore(truth[at])
		for tick in range(at, mini(at + 2 * Ticks.RATE, end)):
			used.step(_row(runner.input_log, tick, config.seats))
			if differ.is_empty() and used.snapshot() != truth[tick + 1]:
				differ = "restored to %d, it left the match at %d" % [at, tick + 1]
	assert_lt(Ticks.RATE, collapse_at, "the first restore is to a ship with its bridge")
	assert_eq(differ, "", "every continuation is the match's")


func _row(log: InputLog, tick: int, seats: int) -> Array[InputFrame]:
	var row: Array[InputFrame] = []
	for seat in seats:
		row.append(log.frame(tick, seat))
	return row
