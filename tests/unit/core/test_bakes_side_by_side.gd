extends GutTest
## The must-sink rule's bakes run side by side (MustSink.Choosing's workers) choose the
## very hit, and bake the very timeline, that baking them one after another does.

## A fast steamer seed whose first bake leaves her afloat: the rule bakes two.
const SEED := 4
## A seed whose first draw the quick check throws out: with one throw allowed the rule
## goes straight to the fallback (test_must_sink's SURE_SEED).
const FALLBACK_SEED := 39
const WORKERS := 4
const DEFAULT_MATCH := "res://data/match/default.tres"

var _structure: ShipStructure
var _sea: SeaPhysics


func before_all() -> void:
	_structure = SimFixtures.steamer().structure
	_sea = SeaPhysics.load_default()


## The steamer's scenario on the default match's fast clock.
func _fast() -> SinkScenario:
	var match_rules: MatchRules = load(DEFAULT_MATCH)
	return MatchConfig.quickened(load(SimFixtures.STEAMER_SINKING), match_rules.fast_clock)


## The steamer's scenario with one throw allowed.
func _one_throw() -> SinkScenario:
	var scenario: SinkScenario = (load(SimFixtures.STEAMER_SINKING) as SinkScenario).duplicate()
	scenario.quick_redraws = 1
	return scenario


func _choosing(scenario: SinkScenario, seed_value: int, workers: int) -> MustSink.Choosing:
	var stream := SeedStreams.derive(seed_value, "sink")
	return MustSink.Choosing.new(_structure, scenario, stream, _sea, workers)


## [param choosing] run to its end: its choice, and the steps it counted.
func _chosen(choosing: MustSink.Choosing) -> Array:
	choosing.work(1 << 62)
	return [choosing.choice(), choosing.steps()]


func _assert_same(side: Array, serial: Array, what: String) -> void:
	var one: MustSink.Choice = side[0]
	var other: MustSink.Choice = serial[0]
	assert_eq(one.timeline.to_bytes(), other.timeline.to_bytes(), what + ": the same timeline")
	assert_eq(one.timeline.origin, other.timeline.origin, what + ": come by the same way")
	assert_eq(one.hit.start_x, other.hit.start_x, what + ": the same hit")
	assert_eq(one.hit.width, other.hit.width, what + ": as wide")
	assert_eq(one.damage.jammed, other.damage.jammed, what + ": the same doors jammed")
	assert_eq(side[1], serial[1], what + ": the steps of the bakes it started")


func test_side_by_side_bakes_choose_as_one_after_another_does() -> void:
	var serial := _chosen(_choosing(_fast(), SEED, 1))
	var choice: MustSink.Choice = serial[0]
	assert_gt(choice.bakes, 1, "the rule bakes more than one hit")
	_assert_same(_chosen(_choosing(_fast(), SEED, WORKERS)), serial, "seed %d" % SEED)


func test_side_by_side_bakes_fall_back_as_one_after_another_does() -> void:
	var serial := _chosen(_choosing(_one_throw(), FALLBACK_SEED, 1))
	var choice: MustSink.Choice = serial[0]
	assert_true(choice.rung > 0 or choice.sure, "the rule falls back")
	var side := _chosen(_choosing(_one_throw(), FALLBACK_SEED, WORKERS))
	_assert_same(side, serial, "seed %d" % FALLBACK_SEED)


func test_halted_side_by_side_bakes_go_on_where_they_stood() -> void:
	var serial := _chosen(_choosing(_fast(), SEED, 1))
	var choosing := _choosing(_fast(), SEED, WORKERS)
	var looks := 0
	while not choosing.work(40):
		choosing.halt()
		looks += 1
	assert_gt(looks, 1, "halted on the way")
	_assert_same([choosing.choice(), choosing.steps()], serial, "halted")


func test_a_config_bakes_side_by_side_to_the_same_sinking() -> void:
	var match_rules: MatchRules = load(DEFAULT_MATCH)
	var serial := MatchConfig.from_rules(match_rules, SEED)
	var side := MatchConfig.from_rules(match_rules, SEED)
	side.bake_workers = WORKERS
	var one := serial.sinking().timeline.to_bytes()
	assert_eq(side.sinking().timeline.to_bytes(), one, "the same sinking")
	assert_eq(side.bake_steps(), serial.bake_steps(), "the same steps")
