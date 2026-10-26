extends GutTest
## Match choices (GLOSSARY): what a player picks before a match, from the menu or the
## command line, answering for itself against the match rules — its problems, and the
## config it makes. Every choice left unmade is the match data's; the command line fills
## in seed 1701 when none is given, the menu leaves it blank for its next match to draw.

const RunMatch := preload("res://tools/run_match.gd")

const DEFAULT_MATCH := "res://data/match/default.tres"
const SURVIVAL_MATCH := "res://data/match/survival.tres"
const HITS := "res://tests/fixtures/sinking/hits/%s.tres"
const STEAMER := "res://data/ships/steamer.tres"
const STEAMER_SEA := "res://data/sinking/steamer_open_sea.tres"
const TRAWLER := "res://data/ships/trawler.tres"
const BONUS_RULES := "res://data/rules/bonuses.tres"


## The command line's choices: [param flags] as `make match` passes them.
func _cli(flags: Array) -> MatchChoices:
	return RunMatch.choices(MatchArgs.parse(PackedStringArray(flags)))


## The menu's choices, as its Play hands them on: every picker set.
func _menu(
	ship: StringName,
	seats: int,
	seed_text: String,
	fast := false,
	survival := false,
	tier := &"normal"
) -> MatchChoices:
	var choices := MatchChoices.new()
	choices.ship = ship
	choices.seats = seats
	choices.bot_tier = tier
	choices.seed_text = seed_text
	choices.fast = fast
	choices.goal = &"survival" if survival else &"last_standing"
	return choices


## [param choices] with Bonuses unticked: the plain brawl.
func _plain(choices: MatchChoices) -> MatchChoices:
	choices.bonuses = false
	return choices


## [param config]'s [param path]: a field, or a field of its scenario (scenario.clock).
func _read(config: MatchConfig, path: String) -> Variant:
	var value: Variant = config
	for field: String in path.split("."):
		value = (value as Object).get(field)
	return value


func test_choices_make_configs() -> void:
	var default: MatchRules = load(DEFAULT_MATCH)
	var survival: MatchRules = load(SURVIVAL_MATCH)
	# [what, choices, rules, {config field: expected}]
	var cases: Array = [
		[
			"the command line, nothing named: the data's, on seed 1701",
			_cli([]),
			default,
			{
				"match_seed": 1701,
				"seats": 8,
				"bot_tier": &"normal",
				"humans": 1,
				"ship": load(STEAMER),
				"scenario": load(STEAMER_SEA),
				"goal": MatchRules.Goal.LAST_STANDING,
				"countdown_ticks": Ticks.from_seconds(3.0),
				"bonus_rules": load(BONUS_RULES),
			},
		],
		[
			"the command line's seed, seats and ship",
			_cli(["--seed=7", "--seats=4", "--ship=trawler"]),
			default,
			{
				"match_seed": 7,
				"seats": 4,
				"ship": load(TRAWLER),
				"scenario": load("res://data/sinking/trawler_open_sea.tres"),
			},
		],
		[
			"a scenario names her ship",
			_cli(["--scenario=steamer_coast"]),
			default,
			{"ship": load(STEAMER), "scenario": load("res://data/sinking/steamer_coast.tres")},
		],
		[
			"a test-only hull plays by name in her ship's sea",
			_cli(["--ship=steamer_weak"]),
			default,
			{
				"ship": load("res://tests/fixtures/ships/steamer_weak.tres"),
				"scenario": load(STEAMER_SEA),
			},
		],
		[
			"a hit by path",
			_cli(["--hit=" + HITS % "fast"]),
			default,
			{"scenario.explicit_hit": load(HITS % "fast"), "scenario.clock": 1.0},
		],
		[
			"a hit by name is hers first",
			_cli(["--ship=titanic", "--hit=fast"]),
			default,
			{"scenario.explicit_hit": load(HITS % "titanic_fast")},
		],
		[
			"a test-only hull's own hit",
			_cli(["--ship=titanic_britannic", "--hit=mine"]),
			default,
			{"scenario.explicit_hit": load(HITS % "titanic_britannic_mine")},
		],
		[
			"else her ship's",
			_cli(["--ship=titanic_olympic_1913", "--hit=night"]),
			default,
			{"scenario.explicit_hit": load(HITS % "titanic_night")},
		],
		[
			"else any ship's",
			_cli(["--hit=fast"]),
			default,
			{"scenario.explicit_hit": load(HITS % "fast")},
		],
		[
			"the command line's fast pace, with a hit",
			_cli(["--fast", "--hit=fast"]),
			default,
			{"scenario.clock": 2.0, "scenario.explicit_hit": load(HITS % "fast")},
		],
		[
			"the command line's goal",
			_cli(["--goal=survival"]),
			default,
			{"goal": MatchRules.Goal.SURVIVAL},
		],
		[
			"no goal named plays the data's",
			_cli([]),
			survival,
			{"goal": MatchRules.Goal.SURVIVAL},
		],
		[
			"a goal named over the data's",
			_cli(["--goal=last_standing"]),
			survival,
			{"goal": MatchRules.Goal.LAST_STANDING},
		],
		[
			"the command line's bonuses off, in survival too",
			_cli(["--bonuses=0", "--goal=survival"]),
			default,
			{"bonus_rules": null, "goal": MatchRules.Goal.SURVIVAL},
		],
		[
			"the command line's bonuses named on: the data's",
			_cli(["--bonuses"]),
			default,
			{"bonus_rules": load(BONUS_RULES)},
		],
		[
			"the menu's seed, seats and tier",
			_menu(&"steamer", 5, " 1701 ", false, false, &"hard"),
			default,
			{
				"match_seed": 1701,
				"seats": 5,
				"bot_tier": &"hard",
				"humans": 1,
				"ship": load(STEAMER),
				"scenario": load(STEAMER_SEA),
				"goal": MatchRules.Goal.LAST_STANDING,
			},
		],
		[
			"the menu's lone seat: you alone, no bots",
			_menu(&"steamer", 1, "1"),
			default,
			{"seats": 1, "humans": 1},
		],
		[
			"the menu's Fast sinking on any ship",
			_menu(&"trawler", 6, "1", true),
			default,
			{"scenario.clock": 2.0, "ship": load(TRAWLER)},
		],
		[
			"the menu's Survival",
			_menu(&"steamer", 8, "1", false, true),
			default,
			{"goal": MatchRules.Goal.SURVIVAL},
		],
		[
			"the menu's Survival unticked over the data's",
			_menu(&"steamer", 8, "1"),
			survival,
			{"goal": MatchRules.Goal.LAST_STANDING},
		],
		[
			"the menu's Bonuses ticked: the data's bonus rules",
			_menu(&"trawler", 6, "1"),
			default,
			{"bonus_rules": load(BONUS_RULES)},
		],
		[
			"the menu's Bonuses unticked: none",
			_plain(_menu(&"steamer", 8, "1")),
			default,
			{"bonus_rules": null},
		],
		[
			"the menu's Bonuses unticked in a fast survival",
			_plain(_menu(&"steamer", 8, "1", true, true)),
			survival,
			{"bonus_rules": null, "goal": MatchRules.Goal.SURVIVAL, "scenario.clock": 2.0},
		],
	]
	for ship_name: String in Fleet.names():
		var layout := Fleet.layout(ship_name)
		for seats: int in [layout.min_seats, layout.max_seats]:
			(
				cases
				. append(
					[
						"the menu's %s, %d seats" % [ship_name, seats],
						_menu(StringName(ship_name), seats, ""),
						default,
						{"seats": seats, "ship": layout},
					]
				)
			)
	for case: Array in cases:
		var choices: MatchChoices = case[1]
		assert_eq(choices.problems(case[2]), PackedStringArray(), "%s: no problem" % case[0])
		var drawn := choices if not choices.seed_text.is_empty() else choices.with_seed("1")
		var config := drawn.config(case[2])
		assert_eq(config.problems(), PackedStringArray(), "%s: the match can start" % case[0])
		for field: String in case[3]:
			assert_eq(_read(config, field), case[3][field], "%s: %s" % [case[0], field])


func test_choices_name_their_problems() -> void:
	var default: MatchRules = load(DEFAULT_MATCH)
	var narrow: MatchRules = default.duplicate()
	narrow.ship = default.ship.duplicate()
	narrow.ship.min_seats = 6
	narrow.ship.max_seats = 6
	# [what, choices, rules, every problem, each by what it says]
	var cases: Array = [
		["a ship the fleet has not", _cli(["--ship=ark"]), default, ["no ship called ark"]],
		["the menu's too", _menu(&"ark", 6, ""), default, ["no ship called ark"]],
		[
			"a scenario not hers",
			_cli(["--ship=trawler", "--scenario=steamer_coast"]),
			default,
			["steamer_coast is no scenario of trawler"],
		],
		[
			"a hit that is not there",
			_cli(["--hit=" + HITS % "none"]),
			default,
			["none.tres is not an IcebergHit"],
		],
		["a hit no fixture is called", _cli(["--hit=iceberg"]), default, ["iceberg is not"]],
		[
			"a resource that is no hit",
			_cli(["--hit=" + STEAMER_SEA]),
			default,
			["steamer_open_sea.tres is not an IcebergHit"],
		],
		["a goal there is not", _cli(["--goal=tag"]), default, ["tag is no goal"]],
		["a seed that is no number", _cli(["--seed=abc"]), default, ["abc is not a whole number"]],
		["a negative seed", _cli(["--seed=-3"]), default, ["-3 is not a whole number"]],
		[
			"the menu's seed alike",
			_menu(&"steamer", 5, "sixty"),
			default,
			["sixty is not a whole number"],
		],
		[
			"too many seats for her",
			_cli(["--seats=9"]),
			default,
			["steamer takes 1 to 8 seats, not 9"],
		],
		[
			"the bounds are the ship's data",
			_cli(["--seats=5"]),
			narrow,
			["takes 6 to 6 seats, not 5"],
		],
		[
			"every problem at once",
			_cli(["--ship=ark", "--seed=x", "--goal=tag"]),
			default,
			["no ship called ark", "tag is no goal", "x is not a whole number"],
		],
	]
	for ship_name: String in Fleet.names():
		var layout := Fleet.layout(ship_name)
		(
			cases
			. append(
				[
					"the menu's %s, one seat over" % ship_name,
					_menu(StringName(ship_name), layout.max_seats + 1, ""),
					default,
					["%s takes" % ship_name],
				]
			)
		)
	for case: Array in cases:
		var choices: MatchChoices = case[1]
		var problems := choices.problems(case[2])
		var said: Array = case[3]
		assert_eq(problems.size(), said.size(), "%s: %s" % [case[0], problems])
		for index in mini(problems.size(), said.size()):
			assert_string_contains(problems[index], said[index])


func test_a_blank_seed_is_no_problem_but_makes_no_config() -> void:
	var default: MatchRules = load(DEFAULT_MATCH)
	var blank := _menu(&"steamer", 8, "  ")
	assert_eq(blank.problems(default), PackedStringArray(), "a blank seed is one to draw")
	assert_null(blank.config(default), "it never draws one itself")
	assert_push_error("seed: blank")
	assert_null(_cli(["--seed=abc"]).config(default), "nor makes a config past a problem")
	assert_push_error("abc is not a whole number")


func test_the_same_choices_make_the_same_match() -> void:
	var default: MatchRules = load(DEFAULT_MATCH)
	var choices := _cli(["--ship=trawler", "--fast", "--hit=light", "--seed=12"])
	var first := choices.config(default)
	var again := choices.config(default)
	assert_eq(again.match_seed, first.match_seed)
	assert_eq(again.data_hash(), first.data_hash())
	assert_eq(
		RunMatch.default_config(1701).data_hash(),
		_cli([]).config(default).data_hash(),
		"the command line's default is the rules' own match"
	)


## The data hash covers the bonus rules and their kinds whenever bonuses are on (#314), so
## both ends of a match, and a replay and its log, agree on them; off, the match plays none
## of them and hashes as one did before bonuses came, whatever they are.
func test_the_data_hash_covers_the_bonuses_when_they_are_on() -> void:
	var default: MatchRules = load(DEFAULT_MATCH)
	var changes := {
		"their numbers": func(rules: BonusRules) -> void: rules.interval += 1.0,
		"a kind's": func(rules: BonusRules) -> void: rules.kinds[0].radius += 0.1,
	}
	var on := _cli([])
	var off := _cli(["--bonuses=0"])
	for what: String in changes:
		var changed: MatchRules = default.duplicate()
		changed.bonus_rules = SimFixtures.bonus_rules_copy(default.bonus_rules)
		(changes[what] as Callable).call(changed.bonus_rules)
		var hashed := on.config(changed).data_hash()
		assert_ne(hashed, on.config(default).data_hash(), "on: %s" % what)
		hashed = off.config(changed).data_hash()
		assert_eq(hashed, off.config(default).data_hash(), "off: %s" % what)
	var before := RunMatch.default_config(1701)
	before.bonus_rules = null
	assert_eq(off.config(default).data_hash(), before.data_hash(), "off: as before bonuses came")


## Bonuses are a choice, on by default (#314): off, a match has none at all, in either goal
## — its config carries no bonus rules, so none of those its rules would bring ever comes
## aboard; on, they come as its rules bring them, here three holds' worth.
func test_with_bonuses_off_no_bonus_ever_comes_in_either_goal() -> void:
	var below: MatchRules = (load(DEFAULT_MATCH) as MatchRules).duplicate()
	below.ship = SimFixtures.below_decks(3)
	below.sinking = SimFixtures.calm_until(600.0)
	below.seats = 1
	below.countdown = 0.0
	below.bonus_rules = SimFixtures.bonus_rules(1.0, 2.0, 0.0, 3)
	for goal: StringName in MatchChoices.GOALS:
		for bonuses: bool in [true, false]:
			var chosen := MatchChoices.new()
			chosen.seed_text = "1"
			chosen.goal = goal
			chosen.bonuses = bonuses
			var sim := MatchSim.create(chosen.config(below))
			var events := SimFixtures.step(sim, {}, Ticks.from_seconds(10.0))
			var came := events.filter(
				func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.BONUS_CAME
			)
			var what := "%s, bonuses %s" % [goal, "on" if bonuses else "off"]
			assert_eq(came.size(), 3 if bonuses else 0, what)
			assert_eq(sim.state.bonuses.size(), 3 if bonuses else 0, what + ": aboard")


func test_the_menu_starts_from_the_data() -> void:
	var survival: MatchRules = load(SURVIVAL_MATCH)
	var full := MatchArgs.parse(PackedStringArray()).choices.filled(survival)
	assert_eq(full.ship, &"steamer")
	assert_eq(full.seats, survival.seats)
	assert_eq(full.bot_tier, survival.bot_tier)
	assert_eq(full.goal, &"survival", "the menu's Survival starts ticked")
	assert_eq(full.seed_text, "", "and its seed blank, to be drawn")


func test_a_ship_that_takes_fewer_seats_starts_from_her_most() -> void:
	var default: MatchRules = load(DEFAULT_MATCH)
	var small: MatchRules = default.duplicate()
	small.ship = default.ship.duplicate()
	small.ship.max_seats = default.seats - 2
	var full := MatchArgs.parse(PackedStringArray()).choices.filled(small)
	assert_eq(full.seats, small.ship.max_seats, "the data's seats, as near as she takes")
	var config := _cli(["--seed=3"]).config(small)
	assert_not_null(config, "an unmade seat count is no problem on her")
	assert_eq(config.seats, small.ship.max_seats)
	small.ship.min_seats = default.seats + 2
	small.ship.max_seats = default.seats + 4
	assert_eq(
		MatchArgs.parse(PackedStringArray()).choices.filled(small).seats,
		small.ship.min_seats,
		"and on one that takes more, her fewest"
	)
