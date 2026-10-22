extends GutTest
## A local match counts in the session once, as its results first show, and the results
## show the session's standings beside the table from its second match on (EndOverlay,
## SessionTally). A replay of the match neither counts nor changes them.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const RunMatch := preload("res://tools/run_match.gd")

var _won: Array[SimEvent] = [
	SimEvent.seat_out(90, 1, 2, PlayerState.Cause.COLD, -1),
	SimEvent.match_ended(90, 0),
]


func _config() -> MatchConfig:
	var config := SimFixtures.config(2)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	return config


func test_the_session_shows_from_the_second_match() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var session := SessionTally.new()
	scene.session = session
	var config := _config()
	var results: EndOverlay = scene.get_node("EndOverlay")
	var column: Control = results.get_node("%Session")
	scene.start(config, true)
	scene._stats.add(_won)
	scene._process(0.0)
	scene._process(0.0)
	assert_true(results.visible, "the first match's results")
	assert_eq(session.matches, 1, "counted the once, however many frames they show")
	assert_false(column.visible, "no session column after one match")
	scene.start(config, true)
	scene._stats.add(_won)
	scene._process(0.0)
	assert_eq(session.matches, 2)
	assert_true(column.visible, "the session column from the second match")
	assert_eq((results.get_node("%SessionTitle") as Label).text, "Session · match 2")
	var table: GridContainer = results.get_node("%SessionTable")
	var you := table.get_child(table.columns + 1) as Label
	assert_eq(you.text, "You", "the winner of both on top")
	assert_eq((table.get_child(table.columns + 2) as Label).text, "20")
	assert_eq(
		you.get_theme_color(&"font_color"), EndOverlay.LOCAL_COLOUR, "the player's row picked out"
	)
	assert_eq((table.get_child(table.columns * 2 + 2) as Label).text, "0")


func test_a_replay_counts_nothing() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var session := SessionTally.new()
	scene.session = session
	var config := _config()
	scene.start(config, true)
	scene._stats.add(_won)
	scene._process(0.0)
	assert_eq(session.matches, 1)
	scene._last_stats = scene._stats
	var played := RunMatch.bots_only(config)
	played.run(Ticks.RATE)
	var file := ReplayFile.record(MatchChoices.new(), played.input_log, 0)
	scene.start_replay(file, config)
	scene._stats.add(_won)
	for _frame in 3:
		scene._process(0.0)
	assert_eq(session.matches, 1, "the replay's end adds nothing")
	scene.show_results_again()
	assert_true((scene.get_node("EndOverlay") as EndOverlay).visible, "back to the results")
	assert_eq(session.matches, 1, "nor does going back to the results")


## Online, the match has no session: its results lead back to the room.
func test_no_session_without_one() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(_config(), true)
	scene._stats.add(_won)
	scene._process(0.0)
	var results: EndOverlay = scene.get_node("EndOverlay")
	assert_true(results.visible)
	assert_false((results.get_node("%Session") as Control).visible)
