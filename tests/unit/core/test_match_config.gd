extends GutTest
## MatchConfig: a match from the rules alone (from_rules) — the fixed-config tools'
## and the tests' — its problems, its data hash and its pace. Player choices reach it
## through MatchChoices (test_match_choices).

const RunMatch := preload("res://tools/run_match.gd")

const DEFAULT_MATCH := "res://data/match/default.tres"


func _rules() -> MatchRules:
	return load(DEFAULT_MATCH)


func test_seat_count_bounds() -> void:
	var match_rules := _rules()
	var ship := match_rules.ship
	# The bounds are the ship's data: a match outside them cannot start.
	var narrow: MatchRules = match_rules.duplicate()
	narrow.ship = ship.duplicate()
	narrow.ship.min_seats = 6
	narrow.ship.max_seats = 6
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


func test_every_ship_has_a_spawn_for_every_seat() -> void:
	# SH30 starts SH21's bounds: each ship states the seats she takes.
	for ship_name: String in Fleet.names():
		var ship := Fleet.layout(ship_name)
		assert_gte(ship.min_seats, 1, "%s takes a seat" % ship_name)
		assert_gte(ship.spawns.size(), ship.max_seats, "%s has a spawn for every seat" % ship_name)


func test_a_ship_is_named_and_struck_in_her_own_sea() -> void:
	var match_rules := _rules()
	assert_eq(
		Fleet.names(),
		PackedStringArray(
			["barque", "ferry", "freighter", "small_titanic", "steamer", "titanic", "trawler", "tug"]
		),
		"the fleet is data/ships/"
	)
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


func test_the_weak_hull_plays_by_name_and_is_never_in_the_fleet() -> void:
	# SH33: the steamer's test-only weak hull plays as `--ship=steamer_weak`, struck in her
	# own open sea — and the menu, which offers the fleet, never lists her.
	assert_false(Fleet.names().has("steamer_weak"), "the fleet never lists her")
	var weak := MatchConfig.from_rules(_rules(), 1701, 0, &"steamer_weak")
	assert_eq(weak.ship, load("res://tests/fixtures/ships/steamer_weak.tres"))
	assert_eq(weak.scenario, load("res://data/sinking/steamer_open_sea.tres"), "the steamer's sea")
	assert_eq(weak.problems(), PackedStringArray())
	assert_eq(Fleet.name_of(weak.ship), &"steamer_weak")
	var strength := weak.ship.structure.strength
	var steamer: ShipLayout = load("res://data/ships/steamer.tres")
	assert_lt(strength.hog, steamer.structure.strength.hog, "her strength divided down")
	assert_gt(strength.weak.size(), 0, "with the weak spots she breaks at")
	assert_eq(steamer.structure.strength.weak.size(), 0, "the steamer has none")
	assert_null(Fleet.layout(&"trawler_weak"), "no weak hull of a ship that has none")


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


## The default match on [param seed_value], on the data's fast clock.
func _fast(seed_value: int) -> MatchConfig:
	var config := MatchConfig.from_rules(_rules(), seed_value)
	config.scenario = MatchConfig.quickened(config.scenario, _rules().fast_clock)
	return config


## The steamer's match on [param seed_value], fast when [param fast], struck by the fast
## fixture hit — past the must-sink rule, one cheap bake — on the clock it was given.
func _hit_fast(seed_value: int, fast: bool) -> MatchConfig:
	var config := MatchConfig.from_rules(_rules(), seed_value)
	var struck := config.scenario.duplicate() as SinkScenario
	struck.explicit_hit = load("res://tests/fixtures/sinking/hits/fast.tres")
	config.scenario = MatchConfig.quickened(struck, _rules().fast_clock) if fast else struck
	return config


func test_fast_mode_sinks_her_sooner_on_the_same_seed() -> void:
	var normal := _hit_fast(1701, false).schedule()
	var fast := _hit_fast(1701, true).schedule()
	assert_eq(fast.hit_tick(), normal.hit_tick(), "struck at the same moment")
	var normal_end := normal.end_tick() - normal.hit_tick()
	var fast_end := fast.end_tick() - fast.hit_tick()
	assert_gt(normal_end, 0)
	assert_lt(fast_end, normal_end, "her sinking ends sooner")
	assert_almost_eq(float(fast_end), normal_end / 2.0, 1.0, "on twice the clock, in half the time")
	assert_ne(normal.gone_tick(), -1, "the fast hit sinks her")
	assert_almost_eq(
		float(fast.gone_tick() - fast.hit_tick()),
		(normal.gone_tick() - normal.hit_tick()) / 2.0,
		1.0,
		"and she is gone in half the time"
	)


func test_fast_mode_changes_the_data_hash() -> void:
	var normal := MatchConfig.from_rules(_rules(), 1701)
	var fast := _fast(1701)
	assert_eq(fast.scenario.clock, _rules().fast_clock, "on the data's fast clock")
	assert_ne(fast.data_hash(), normal.data_hash(), "a replay refuses the other pace")
	assert_false(fast.share_sinking(normal), "nor shares a normal match's sinking")


func test_a_copy_of_her_scenario_shares_her_sinking_and_another_pace_does_not() -> void:
	var played := _hit_fast(1701, true)
	played.bake_some(1)
	var again := _hit_fast(1701, true)
	assert_ne(again.scenario, played.scenario, "each made of the choices is a copy")
	assert_true(again.share_sinking(played), "the same numbers, the same sinking (D7)")
	assert_eq(again.bake_steps(), 1, "taken as far as it was baked")
	assert_false(_hit_fast(1701, false).share_sinking(played), "never at another pace")


func test_a_config_that_took_a_sinking_bakes_the_very_same_one() -> void:
	var played := _hit_fast(1701, true)
	var again := _hit_fast(1701, true)
	assert_false(again.same_sinking(played), "neither has begun its bakes")
	played.bake_some(1)
	assert_true(played.same_sinking(played), "its own")
	assert_false(again.same_sinking(played), "nor another's before it takes it")
	again.share_sinking(played)
	assert_true(again.same_sinking(played), "taken: the very bake")
	assert_true(played.same_sinking(again), "either way round")
	var other := _hit_fast(1702, true)
	other.bake_some(1)
	assert_false(other.same_sinking(played), "another seed's is another")


func test_fast_mode_leaves_the_loaded_scenario_untouched() -> void:
	var loaded: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var fast := _fast(1701)
	assert_ne(fast.scenario, loaded, "a copy")
	assert_eq(loaded.clock, 1.0, "the shared .tres keeps its clock")
	assert_eq(fast.scenario.hit, loaded.hit, "and the copy its bands")
	assert_eq(MatchConfig.quickened(loaded, 1.0), loaded, "her own clock is no copy")


func test_the_fast_clock_must_quicken_her() -> void:
	var slow: MatchRules = _rules().duplicate()
	slow.fast_clock = 1.0
	assert_eq(slow.problems(), PackedStringArray(["match: fast_clock must be over 1"]))


func test_a_fast_match_is_deterministic() -> void:
	var digests: Array[String] = []
	for _run in 2:
		var runner := RunMatch.bots_only(_hit_fast(1701, true))
		runner.run(Ticks.from_seconds(40.0))
		digests.append(runner.digest.hex())
	assert_ne(digests[0], "")
	assert_eq(digests[1], digests[0], "the same seed, inputs and pace, the same digest")


## A SinkSchedule of a tool's own, as a timer subclasses it (FrameMeter).
class OwnSchedule:
	extends SinkSchedule


func test_a_schedule_built_as_a_tools_own_is_the_matchs_sinking() -> void:
	var plain := _hit_fast(1701, false).schedule()
	var config := _hit_fast(1701, false)
	var own := config.schedule_as(OwnSchedule)
	assert_true(own is OwnSchedule, "built as the class asked for")
	assert_same(config.schedule(), own, "and the match's schedule from then on")
	assert_eq(own.hit_tick(), plain.hit_tick())
	assert_eq(own.end_tick(), plain.end_tick())
	assert_eq(own.gone_tick(), plain.gone_tick())
	assert_eq(own.scheduled().size(), plain.scheduled().size(), "its events and falls placed")
	for index in plain.scheduled().size():
		assert_eq(own.scheduled()[index].at, plain.scheduled()[index].at)
		assert_eq(own.scheduled()[index].event.kind, plain.scheduled()[index].event.kind)
	for tick: int in [0, plain.hit_tick(), plain.end_tick() >> 1, plain.end_tick()]:
		assert_eq(own.pose_at(tick).transform, plain.pose_at(tick).transform, "tick %d" % tick)


func test_a_schedule_already_built_is_never_replaced() -> void:
	var config := _hit_fast(1701, false)
	var built := config.schedule()
	assert_null(config.schedule_as(OwnSchedule), "nothing built over it")
	assert_same(config.schedule(), built)


## A prop kind's numbers (#273) are the match's data: a replay recorded with a ring that
## kept the cold at bay longer refuses to play against one that keeps it less.
func test_a_prop_kind_s_numbers_are_in_the_data_hash() -> void:
	var layout := SimFixtures.crated([SimFixtures.lifebuoy(Vector3.ZERO)])
	var config := SimFixtures.config(1, null, 1701, layout)
	var before := config.data_hash()
	var kind := PropKind.named(&"lifebuoy")
	var rate := kind.sea_cold_rate
	kind.sea_cold_rate = rate * 0.5
	var after := config.data_hash()
	kind.sea_cold_rate = rate
	assert_ne(after, before, "another ring, another match")
	assert_eq(config.data_hash(), before, "and its own again")
