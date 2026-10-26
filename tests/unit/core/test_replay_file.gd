extends GutTest
## A replay file carries a match's choices and its input log through bytes and back,
## and plays the same match again, digest for digest (D4). Garbage is refused, and so
## is a file whose data changed or whose match did not start at tick 0 (R1, #209).

const RunMatch := preload("res://tools/run_match.gd")
const SEED := 1701
const RECORDED_AT := 1_760_000_000
const PLAYED_SECONDS := 20


func _rules() -> MatchRules:
	return load(RunMatch.DEFAULT_MATCH)


func _choices() -> MatchChoices:
	var chosen := MatchChoices.new()
	chosen.seed_text = str(SEED)
	return chosen


## The bots-only match [param chosen] make — _choices() when null — played PLAYED_SECONDS.
func _played(chosen: MatchChoices = null) -> MatchRunner:
	var made := (chosen if chosen != null else _choices()).config(_rules())
	var played := RunMatch.bots_only(made)
	played.run(PLAYED_SECONDS * Ticks.RATE)
	return played


## [param file]'s bytes as a build from before bonuses were a match choice (#314) wrote
## them: every choice but bonuses, which its choices did not have.
static func _bytes_before_bonuses(file: ReplayFile) -> PackedByteArray:
	var out := ByteCursor.new()
	out.put_bytes(ReplayFile.MAGIC.to_ascii_buffer())
	out.put_s32(ReplayFile.FORMAT)
	out.put_s64(file.recorded_at)
	out.put_string(file.ship)
	out.put_s64(file.match_seed)
	out.put_s32(file.seats)
	out.put_s32(file.ticks)
	out.put_s32(file.winner)
	out.put_s32(1 if file.ended else 0)
	var fields := PackedStringArray()
	for property: Dictionary in file.choices.get_property_list():
		var field: String = property["name"]
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and field != "bonuses":
			fields.append(field)
	out.put_s32(fields.size())
	for field: String in fields:
		out.put_string(field)
		out.put_var(file.choices.get(field))
	out.put_bytes(file.log.to_bytes())
	return out.bytes()


func test_a_replay_file_plays_the_same_match_again_from_bytes() -> void:
	var played := _played()
	var file := ReplayFile.record(_choices(), played.input_log, RECORDED_AT, _rules())
	var back := ReplayFile.from_bytes(file.to_bytes())
	assert_not_null(back, "the bytes read back")
	assert_true(back.playable(_rules()), "playable as recorded")
	var replay := MatchRunner.new(MatchSim.create(back.config(_rules())), back.replay_sources())
	replay.run(PLAYED_SECONDS * Ticks.RATE)
	assert_eq(replay.digest.hex(), played.digest.hex(), "digest for digest")
	assert_eq(
		[back.recorded_at, back.ticks, back.seats, back.ship, back.match_seed, back.winner],
		[RECORDED_AT, PLAYED_SECONDS * Ticks.RATE, 8, &"steamer", SEED, -1],
		"the listing summary"
	)


func test_every_choice_comes_back_including_the_hit() -> void:
	var chosen := _choices()
	chosen.ship = &"trawler"
	chosen.seats = 3
	chosen.bot_tier = &"normal"
	chosen.fast = true
	chosen.goal = MatchChoices.SURVIVAL
	chosen.bonuses = false
	chosen.scenario = &"steamer_coast"
	chosen.hit = "bow"
	var file := ReplayFile.new()
	file.choices = chosen
	file.log = InputLog.new(RunMatch.default_config(SEED))
	file.recorded_at = RECORDED_AT
	var back := ReplayFile.from_bytes(file.to_bytes())
	assert_not_null(back)
	for property: Dictionary in chosen.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var field: String = property["name"]
			assert_eq(back.choices.get(field), chosen.get(field), field)


## A match played without bonuses (#314) is replayed without them: the choice comes back
## with the file, and the match it makes is the one recorded, digest for digest — never one
## with bonuses, whose data the log was not played under.
func test_a_replay_without_bonuses_plays_back_without_them() -> void:
	var plain := _choices()
	plain.bonuses = false
	var played := _played(plain)
	var file := ReplayFile.record(plain, played.input_log, RECORDED_AT, _rules())
	var back := ReplayFile.from_bytes(file.to_bytes())
	assert_not_null(back, "the bytes read back")
	assert_false(back.choices.bonuses, "the choice recorded")
	assert_true(back.playable(_rules()), "playable as recorded")
	var config := back.config(_rules())
	assert_null(config.bonus_rules, "no bonus rules: none ever comes")
	var replay := MatchRunner.new(MatchSim.create(config), back.replay_sources())
	replay.run(PLAYED_SECONDS * Ticks.RATE)
	assert_eq(replay.digest.hex(), played.digest.hex(), "digest for digest")
	back.choices.bonuses = true
	assert_false(back.playable(_rules()), "the log refuses a match with bonuses")


## A replay saved before bonuses were a match choice names none: it loads with bonuses on,
## as every match since they came aboard (#310) was played, and plays as it was recorded.
func test_a_replay_from_before_the_choice_plays_with_bonuses() -> void:
	var input_log := InputLog.new(RunMatch.default_config(SEED))
	var file := ReplayFile.record(_choices(), input_log, RECORDED_AT, _rules())
	var back := ReplayFile.from_bytes(_bytes_before_bonuses(file))
	assert_not_null(back, "an older file still reads")
	assert_true(back.choices.bonuses, "with bonuses")
	assert_true(back.playable(_rules()), "and plays as recorded")
	assert_eq(back.config(_rules()).bonus_rules, _rules().bonus_rules)


func test_short_or_garbled_bytes_are_refused_without_a_crash() -> void:
	var file := ReplayFile.new()
	file.choices = _choices()
	file.log = InputLog.new(RunMatch.default_config(SEED))
	file.recorded_at = RECORDED_AT
	var bytes := file.to_bytes()
	assert_null(ReplayFile.from_bytes(PackedByteArray()), "nothing")
	assert_null(ReplayFile.from_bytes(bytes.slice(0, bytes.size() / 2)), "cut short")
	var garbled := bytes.duplicate()
	garbled[1] = garbled[1] ^ 0xFF
	assert_null(ReplayFile.from_bytes(garbled), "a wrong magic")
	var appended := bytes.duplicate()
	appended.append(7)
	assert_null(ReplayFile.from_bytes(appended), "bytes past the end")
	assert_null(InputLog.from_bytes(PackedByteArray([1, 2, 3])), "a log of three bytes")


func test_changed_data_or_a_jump_start_is_not_playable() -> void:
	var played := _played()
	var changed := ReplayFile.record(_choices(), played.input_log, RECORDED_AT, _rules())
	changed.log.data_hash = "not what the match loaded"
	assert_false(changed.playable(_rules()), "a changed data hash")
	var jumped := ReplayFile.new()
	jumped.choices = _choices()
	jumped.log = InputLog.new(RunMatch.default_config(SEED), 40)
	jumped.recorded_at = RECORDED_AT
	assert_false(jumped.playable(_rules()), "a match that started at tick 40")
