extends GutTest
## A tool's --hit strikes her with the IcebergHit it names, and a path that names none
## is a problem the match host stops on rather than a match played on its own hit; a
## --ship names a ship of the Fleet, and one it has not is a problem too.

const SCENARIO := "res://data/sinking/steamer_open_sea.tres"
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"


func _struck(hit: String) -> Array:
	var args := MatchArgs.parse(PackedStringArray(["--hit=" + hit]))
	return [args.struck(load(SCENARIO)), args.problems()]


func test_a_named_hit_strikes_her() -> void:
	var struck: Array = _struck(FAST_HIT)
	var scenario: SinkScenario = struck[0]
	assert_eq(scenario.explicit_hit, load(FAST_HIT))
	assert_eq(struck[1], PackedStringArray())


func test_no_hit_named_is_no_problem() -> void:
	var args := MatchArgs.parse(PackedStringArray())
	var scenario: SinkScenario = load(SCENARIO)
	assert_eq(args.struck(scenario), scenario)
	assert_eq(args.problems(), PackedStringArray())


func test_a_missing_hit_is_a_problem() -> void:
	var problems: PackedStringArray = _struck("res://tests/fixtures/sinking/hits/none.tres")[1]
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "none.tres is not an IcebergHit")


func test_a_hit_named_bare_is_her_own_first() -> void:
	# --hit=NAME, no path: the test fixtures' hit of that name — her own (SHIP_NAME), a
	# test-only hull's own or else her fleet ship's, then any ship's (NAME).
	var cases: Array = [
		[["--ship=titanic", "--hit=fast"], "titanic_fast"],
		[["--ship=titanic_britannic", "--hit=mine"], "titanic_britannic_mine"],
		[["--ship=titanic_olympic_1913", "--hit=night"], "titanic_night"],
		[["--ship=steamer", "--hit=fast"], "fast"],
	]
	for case: Array in cases:
		var given := PackedStringArray(case[0])
		var args := MatchArgs.parse(given)
		var scenario: SinkScenario = args.struck(load(SCENARIO))
		assert_eq(scenario.explicit_hit, load(MatchArgs.HITS % case[1]), " ".join(given))
		assert_eq(args.problems(), PackedStringArray(), " ".join(given))
	var problems: PackedStringArray = _struck("iceberg")[1]
	assert_eq(problems.size(), 1, "a name no fixture has is a problem")


func test_a_resource_that_is_no_hit_is_a_problem() -> void:
	var problems: PackedStringArray = _struck(SCENARIO)[1]
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "steamer_open_sea.tres is not an IcebergHit")


func test_a_ship_is_named() -> void:
	var args := MatchArgs.parse(PackedStringArray(["--ship=trawler"]))
	assert_eq(args.ship_name, &"trawler")
	assert_eq(args.problems(), PackedStringArray())
	assert_eq(MatchArgs.parse(PackedStringArray()).ship_name, &"", "the match data's when none")


func test_a_ship_the_fleet_has_not_is_a_problem() -> void:
	var problems := MatchArgs.parse(PackedStringArray(["--ship=ark"])).problems()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "no ship called ark")


func test_fast_is_parsed_and_off_by_default() -> void:
	assert_false(MatchArgs.parse(PackedStringArray()).fast, "normal unless asked")
	var args := MatchArgs.parse(PackedStringArray(["--fast", "--hit=" + FAST_HIT]))
	assert_true(args.fast)
	var scenario: SinkScenario = load(SCENARIO)
	var struck := args.struck(scenario, 2.0)
	assert_eq(struck.explicit_hit, load(FAST_HIT), "--hit and --fast together")
	assert_eq(struck.clock, 2.0, "on the fast clock")
	assert_eq(scenario.clock, 1.0, "the loaded scenario untouched")
	assert_eq(MatchArgs.parse(PackedStringArray()).struck(scenario), scenario)


func test_a_goal_is_named_and_the_battle_royale_by_default() -> void:
	assert_eq(MatchArgs.parse(PackedStringArray()).goal, MatchRules.Goal.LAST_STANDING)
	var args := MatchArgs.parse(PackedStringArray(["--goal=survival", "--fast"]))
	assert_eq(args.goal, MatchRules.Goal.SURVIVAL)
	assert_true(args.fast, "with --fast too")
	assert_eq(args.problems(), PackedStringArray())
	var problems := MatchArgs.parse(PackedStringArray(["--goal=tag"])).problems()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "tag is no goal")
