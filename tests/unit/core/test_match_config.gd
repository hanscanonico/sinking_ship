extends GutTest
## MatchConfig.from_menu is the UI's only route into a match (D13): the menu's
## ship, seats, tier and seed become a config, a blank seed is drawn once and
## recorded, and a ship the Fleet has not or a seat count she does not take is refused.

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
	var ship := match_rules.ship
	var seeds := _seeds(1)
	for seats in range(ship.min_seats, ship.max_seats + 1):
		var config := MatchConfig.from_menu(match_rules, seats, &"normal", "", seeds)
		assert_eq(config.seats, seats)
		assert_eq(config.problems(), PackedStringArray(), "%d seats can start" % seats)
	assert_null(MatchConfig.from_menu(match_rules, ship.min_seats - 1, &"normal", "", seeds))
	assert_null(MatchConfig.from_menu(match_rules, ship.max_seats + 1, &"normal", "", seeds))

	# The bounds are the ship's data, not the menu's: move them and the refusals move.
	var narrow: MatchRules = match_rules.duplicate()
	narrow.ship = ship.duplicate()
	narrow.ship.min_seats = 6
	narrow.ship.max_seats = 6
	assert_null(MatchConfig.from_menu(narrow, 5, &"normal", "", seeds))
	assert_not_null(MatchConfig.from_menu(narrow, 6, &"normal", "", seeds))
	narrow.seats = 7
	assert_eq(
		narrow.problems(),
		PackedStringArray(["match: seats must be within the ship's min_seats…max_seats"])
	)
	var config := MatchConfig.from_rules(narrow, 1)
	assert_eq(
		config.problems(),
		PackedStringArray(["ship: 7 seats, where she takes 6 to 6"]),
		"a match outside its ship's bounds cannot start"
	)
	narrow.ship.max_seats = 3
	assert_true(
		MatchConfig.from_rules(narrow, 1).problems().has(
			"ship: min_seats must be at least 1 and at most max_seats"
		),
		"inverted bounds are refused"
	)


func test_seat_bounds_follow_the_ship() -> void:
	# SH30 starts SH21's bounds: each ship states the seats she takes, and the menu's
	# choices are hers.
	var match_rules := _rules()
	var seeds := _seeds(1)
	for ship_name: String in Fleet.names():
		var ship := Fleet.layout(ship_name)
		assert_gte(ship.min_seats, 1, "%s takes a seat" % ship_name)
		assert_gte(ship.spawns.size(), ship.max_seats, "%s has a spawn for every seat" % ship_name)
		for seats in range(ship.min_seats, ship.max_seats + 1):
			var config := MatchConfig.from_menu(match_rules, seats, &"normal", "", seeds, ship_name)
			assert_eq(config.ship, ship, "the menu's %s" % ship_name)
			assert_eq(config.problems(), PackedStringArray(), "%s, %d seats" % [ship_name, seats])
		assert_null(
			MatchConfig.from_menu(match_rules, ship.max_seats + 1, &"normal", "", seeds, ship_name)
		)
	assert_null(MatchConfig.from_menu(match_rules, 6, &"normal", "", seeds, &"ark"), "no ark")


func test_a_ship_is_named_and_struck_in_her_own_sea() -> void:
	var match_rules := _rules()
	assert_eq(Fleet.names(), PackedStringArray(["steamer", "trawler"]), "the fleet is data/ships/")
	assert_eq(Fleet.name_of(match_rules.ship), &"steamer", "the steamer stays the default")
	var trawler := MatchConfig.from_rules(match_rules, 1701, 0, &"trawler")
	assert_eq(trawler.ship, load("res://data/ships/trawler.tres"))
	assert_eq(trawler.scenario, load("res://data/sinking/trawler_open_sea.tres"))
	assert_eq(trawler.seats, match_rules.seats, "the rest is the match data's")
	assert_eq(trawler.problems(), PackedStringArray())
	var steamer := MatchConfig.from_rules(match_rules, 1701, 0, &"steamer")
	var default := MatchConfig.from_rules(match_rules, 1701)
	assert_eq(steamer.data_hash(), default.data_hash(), "naming the default is the default")
	assert_ne(trawler.data_hash(), default.data_hash())


func test_the_menu_takes_a_lone_seat() -> void:
	var config := MatchConfig.from_menu(_rules(), 1, &"normal", "1", _seeds(1))
	assert_not_null(config, "one seat can start: you alone, no bots")
	if config != null:
		assert_eq(config.seats, 1)
		assert_eq(config.humans, 1, "and that seat is the local human")
		assert_eq(config.problems(), PackedStringArray())


func test_a_sinking_with_an_iceberg_hit_needs_a_ship_with_a_structure() -> void:
	var struck: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var steamer := MatchConfig.new(1, 4, SimFixtures.rules(), SimFixtures.steamer(), struck)
	assert_eq(steamer.problems(), PackedStringArray(), "her own hit strikes her")
	var flat := MatchConfig.new(1, 2, SimFixtures.rules(), SimFixtures.deck(), struck)
	assert_null(flat.ship.structure, "the flat deck has no structure")
	assert_eq(
		flat.problems(),
		PackedStringArray(["match: the sinking's iceberg hit needs a ship with a structure"]),
		"a hit with nothing to strike is refused, not struck silently nowhere"
	)


func test_a_physical_sinking_needs_a_sea_under_her() -> void:
	# The physics stands her seabed sea_depth under her waterline (Seabed): left at 0,
	# she would bake aground from her first state.
	var struck: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	assert_eq(struck.problems(), PackedStringArray(), "her own sinking has a sea")
	struck.sea_depth = 0.0
	assert_eq(
		struck.problems(), PackedStringArray(["sinking: the physics needs a sea deeper than 0"])
	)
	var authored := SimFixtures.calm()
	assert_eq(authored.sea_depth, 0.0, "an authored sinking has no seabed")
	assert_eq(authored.problems(), PackedStringArray(), "and needs none")
