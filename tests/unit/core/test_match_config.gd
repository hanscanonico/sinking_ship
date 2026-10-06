extends GutTest
## MatchConfig.from_menu is the UI's only route into a match (D13): the menu's
## seats, tier and seed become a config, a blank seed is drawn once and recorded,
## and a seat count the match data does not offer is refused.

const RunMatch := preload("res://tools/run_match.gd")

const DEFAULT_MATCH := "res://data/match/default.tres"
## Seconds of match time a match is played for at most: a match has no cap, and the
## drawn one below ends at 15:28.7, two bots sparring a long while.
const PLAYED_FOR := 1200.0


func _rules() -> MatchRules:
	return load(DEFAULT_MATCH)


func _seeds(seed_value: int) -> RandomNumberGenerator:
	var seeds := RandomNumberGenerator.new()
	seeds.seed = seed_value
	return seeds


## [param config]'s match played out by bots, as the headless tools play it — for at
## most PLAYED_FOR of match time: a match has no cap, and two bots can spar a while.
func _played(config: MatchConfig) -> MatchRunner:
	var runner := RunMatch.bots_only(config)
	for _tick in Ticks.from_seconds(PLAYED_FOR):
		if runner.is_over():
			break
		runner.step()
	return runner


func test_menu_values_build_a_config() -> void:
	var match_rules := _rules()
	assert_eq(match_rules.problems(), PackedStringArray(), "the default match data is valid")
	var config := MatchConfig.from_menu(match_rules, 5, &"normal", " 1701 ", _seeds(1))
	assert_not_null(config)
	assert_eq(config.match_seed, 1701)
	assert_eq(config.seats, 5)
	assert_eq(config.bot_tier, &"normal")
	assert_eq(config.humans, match_rules.humans)
	assert_eq(config.countdown_ticks, Ticks.from_seconds(match_rules.countdown))
	assert_eq(config.problems(), PackedStringArray())
	var from_data := MatchConfig.from_rules(match_rules, 1701, 5)
	assert_eq(config.data_hash(), from_data.data_hash(), "the same match the data states")
	assert_true(BotProfile.tiers().has("normal"), "the menu's tiers are data/bots/")
	var other_default: MatchRules = match_rules.duplicate()
	other_default.bot_tier = &"hard"
	assert_eq(
		MatchConfig.from_menu(other_default, 5, &"normal", "", _seeds(1)).bot_tier,
		&"normal",
		"the menu's tier, not the data's default"
	)
	assert_null(
		MatchConfig.from_menu(match_rules, 5, &"normal", "sixty", _seeds(1)),
		"a seed that is not a whole number is refused"
	)
	assert_null(MatchConfig.from_menu(match_rules, 5, &"normal", "-3", _seeds(1)))


func test_blank_seed_is_random_and_recorded() -> void:
	var match_rules := _rules()
	var config := MatchConfig.from_menu(match_rules, 6, &"normal", "", _seeds(42))
	assert_eq(config.match_seed, _seeds(42).randi(), "drawn from the caller's stream, once")
	var other := MatchConfig.from_menu(match_rules, 6, &"normal", "  ", _seeds(43))
	assert_ne(other.match_seed, config.match_seed, "a blank seed is a fresh one")

	# Recorded: typing the drawn seed back in plays the same match, to the end.
	var replayed := MatchConfig.from_menu(
		match_rules, 6, &"normal", str(config.match_seed), _seeds(7)
	)
	assert_eq(replayed.match_seed, config.match_seed)
	var first := _played(config)
	var second := _played(replayed)
	assert_true(first.is_over(), "the drawn match ends")
	assert_eq(second.digest.hex(), first.digest.hex())
	assert_eq(second.snapshot, first.snapshot)


func test_seat_count_bounds() -> void:
	var match_rules := _rules()
	var seeds := _seeds(1)
	for seats in range(match_rules.min_seats, match_rules.max_seats + 1):
		var config := MatchConfig.from_menu(match_rules, seats, &"normal", "", seeds)
		assert_eq(config.seats, seats)
		assert_eq(config.problems(), PackedStringArray(), "%d seats can start" % seats)
	assert_null(MatchConfig.from_menu(match_rules, match_rules.min_seats - 1, &"normal", "", seeds))
	assert_null(MatchConfig.from_menu(match_rules, match_rules.max_seats + 1, &"normal", "", seeds))

	# The bounds are the data's, not the menu's: move them and the refusals move.
	var narrow: MatchRules = match_rules.duplicate()
	narrow.min_seats = 6
	narrow.max_seats = 6
	assert_null(MatchConfig.from_menu(narrow, 5, &"normal", "", seeds))
	assert_not_null(MatchConfig.from_menu(narrow, 6, &"normal", "", seeds))
	narrow.seats = 7
	assert_eq(
		narrow.problems(), PackedStringArray(["match: seats must be within min_seats…max_seats"])
	)
	narrow.max_seats = 3
	assert_eq(narrow.problems().size(), 1, "inverted bounds are refused")


func test_a_sinking_with_an_iceberg_hit_needs_a_ship_with_a_structure() -> void:
	var struck: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var steamer := MatchConfig.new(1, 2, SimFixtures.rules(), SimFixtures.steamer(), struck)
	assert_eq(steamer.problems(), PackedStringArray(), "her own hit strikes her")
	var flat := MatchConfig.new(1, 2, SimFixtures.rules(), SimFixtures.deck(), struck)
	assert_null(flat.ship.structure, "the flat deck has no structure")
	assert_eq(
		flat.problems(),
		PackedStringArray(["match: the sinking's iceberg hit needs a ship with a structure"]),
		"a hit with nothing to strike is refused, not struck silently nowhere"
	)
