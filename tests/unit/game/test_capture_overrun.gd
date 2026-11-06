extends GutTest
## A capture whose moment — --capture-at's match time, or --phys's moment of the sinking
## — comes after the match has ended says so, naming when it ended, rather than shooting
## the results in its place (#455); one asking for the results, or a moment the match
## reached, goes ahead.

const MATCH_DATA := "res://data/match/default.tres"
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"


func _args(arguments: PackedStringArray) -> MatchArgs:
	return MatchArgs.parse(arguments)


## The match [param args] set up, on seed 1701, its sinking baked.
func _config(args: MatchArgs) -> MatchConfig:
	var rules: MatchRules = load(MATCH_DATA)
	var config := args.choices.filled(rules).with_seed("1701").config(rules)
	config.sinking()
	return config


func _ended(tick: int) -> Dictionary:
	return {"phase": MatchState.Phase.ENDED, "tick": tick}


func test_an_at_past_the_end_names_the_end() -> void:
	var args := _args(PackedStringArray(["--capture=x.png", "--capture-at=400"]))
	var said := Game.capture_overrun(args, -1, _ended(Ticks.from_seconds(241.6)), null)
	assert_string_contains(said, "the match ended at 04:01.6")
	assert_string_contains(said, "before AT=400")
	assert_string_contains(said, "ask for an AT before 04:01.6")


func test_a_moment_the_match_reached_goes_ahead() -> void:
	var args := _args(PackedStringArray(["--capture=x.png", "--capture-at=200"]))
	var ended := Ticks.from_seconds(241.6)
	assert_eq(Game.capture_overrun(args, -1, _ended(ended), null), "", "ended after AT")
	var playing := {"phase": MatchState.Phase.LIVE, "tick": Ticks.from_seconds(200.0)}
	assert_eq(Game.capture_overrun(args, -1, playing, null), "", "still playing")
	var due := Ticks.from_seconds(200.0)
	assert_eq(Game.capture_overrun(args, -1, _ended(due), null), "", "ended on its tick")


func test_the_results_asked_for_go_ahead() -> void:
	var args := _args(PackedStringArray(["--capture=x.png", "--capture-screen=results"]))
	assert_eq(Game.capture_overrun(args, -1, _ended(30), null), "", "SCREEN=results")
	args = _args(
		PackedStringArray(["--capture=x.png", "--capture-at=400", "--capture-screen=results"])
	)
	assert_eq(Game.capture_overrun(args, -1, _ended(30), null), "", "SCREEN=results at AT")


func test_a_phys_past_the_end_names_its_physics_time() -> void:
	var args := _args(PackedStringArray(["--hit=" + FAST_HIT, "--capture=x.png", "--phys=1:50:00"]))
	var config := _config(args)
	var schedule := config.schedule()
	var due := schedule.physics_tick(args.phys_seconds)
	var ended := due - Ticks.from_seconds(60.0)
	var said := Game.capture_overrun(args, due, _ended(ended), config)
	var physics := Game.phys_clock(schedule.physics_at(ended))
	assert_string_contains(said, "the match ended at %s" % MatchTranscript.clock(ended))
	assert_string_contains(said, "physics %s after the hit" % physics)
	assert_string_contains(said, "before PHYS=1:50:00")
	assert_string_contains(said, "ask for a smaller PHYS")
	assert_eq(Game.capture_overrun(args, due, _ended(due), config), "", "ended at PHYS")


func test_phys_clock_reads_as_phys_takes_it() -> void:
	assert_eq(Game.phys_clock(MatchArgs.clock_seconds("1:50:00")), "1:50:00")
	assert_eq(Game.phys_clock(MatchArgs.clock_seconds("0:04:05")), "0:04:05")
