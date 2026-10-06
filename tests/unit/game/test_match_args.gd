extends GutTest
## A tool's --hit strikes her with the IcebergHit it names, and a path that names none
## is a problem the match host stops on rather than a match played on its own hit.

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


func test_a_resource_that_is_no_hit_is_a_problem() -> void:
	var problems: PackedStringArray = _struck(SCENARIO)[1]
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "steamer_open_sea.tres is not an IcebergHit")
