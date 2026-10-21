extends GutTest
## A replay watched from the results takes the sinking the match just played, made
## already — the same ship, scenario and seed make the same sinking (D7) — so it starts
## at once, its countdown never held for a bake; on her fast clock and under a --hit
## too, whose scenario each config makes a copy of. Another match's sinking is never
## taken.

const MATCH_DATA := "res://data/match/default.tres"
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"


func _rules() -> MatchRules:
	return load(MATCH_DATA)


## The menu's choices as [param arguments] set them up, on [param seed_text].
func _choices(arguments: PackedStringArray, seed_text: String) -> MatchChoices:
	return MatchArgs.parse(arguments).choices.filled(_rules()).with_seed(seed_text)


## The match [param choices] make, played: its sinking baked to the end.
func _played(choices: MatchChoices) -> MatchConfig:
	var played := choices.config(_rules())
	played.sinking()
	return played


func _file(choices: MatchChoices) -> ReplayFile:
	var file := ReplayFile.new()
	file.choices = choices
	return file


func test_a_replay_from_the_results_needs_no_bake() -> void:
	for arguments: PackedStringArray in [
		PackedStringArray(["--hit=" + FAST_HIT]),
		PackedStringArray(["--hit=" + FAST_HIT, "--fast"]),
	]:
		var choices := _choices(arguments, "1701")
		var played := _played(choices)
		var replay := Game.replay_config(_file(choices), _rules(), played)
		assert_ne(replay.scenario, played.scenario, "%s: a copy of her scenario" % [arguments])
		assert_true(replay.bake_some(0), "%s: her sinking is made already" % [arguments])
		assert_eq(replay.bake_steps(), played.bake_steps(), "%s: the played one" % [arguments])


func test_another_match_s_sinking_is_never_taken() -> void:
	var arguments := PackedStringArray(["--hit=" + FAST_HIT])
	var played := _played(_choices(arguments, "1701"))
	var other_seed := Game.replay_config(_file(_choices(arguments, "1702")), _rules(), played)
	assert_false(other_seed.bake_some(0), "another seed bakes her own")
	var fast := PackedStringArray(["--hit=" + FAST_HIT, "--fast"])
	var other_pace := Game.replay_config(_file(_choices(fast, "1701")), _rules(), played)
	assert_false(other_pace.bake_some(0), "another pace bakes her own")


func test_a_replay_from_the_list_bakes_its_own() -> void:
	var choices := _choices(PackedStringArray(["--hit=" + FAST_HIT]), "1701")
	var replay := Game.replay_config(_file(choices), _rules(), null)
	assert_false(replay.bake_some(0), "nothing at hand: her sinking still to bake")
