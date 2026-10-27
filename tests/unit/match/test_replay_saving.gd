extends GutTest
## A local match is kept as a replay as its results show or it is left (R3, #211), but
## only one a person played: a match bots play on every seat — a tool's autoplay, as
## make capture and make fps run — is recorded for its results' Watch replay and never
## written, so a session of captures never prunes the player's own matches from the list.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const DIR := "user://replays_saving_test"

var _store := ReplayStore.new(DIR)
var _won: Array[SimEvent] = [
	SimEvent.seat_out(30, 1, 2, PlayerState.Cause.COLD, -1),
	SimEvent.match_ended(30, 0),
]


func before_each() -> void:
	for path in _store.list():
		_store.delete(path)


func after_all() -> void:
	for path in _store.list():
		_store.delete(path)
	DirAccess.remove_absolute(DIR)


func _choices() -> MatchChoices:
	var chosen := MatchChoices.new()
	chosen.ship = &"tug"
	chosen.seats = 2
	chosen.seed_text = "1701"
	return chosen


## A match on [param chosen], started as [param autoplay] says, a few beats played and
## then ended, its results shown.
func _ended(chosen: MatchChoices, autoplay: bool) -> MatchScene:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.replays = ReplayRecorder.new(_store)
	scene.choices = chosen
	scene.start(chosen.config(load(MATCH_DATA)), autoplay)
	for _beat in 3:
		scene._driver.step()
	scene._stats.add(_won)
	scene._process(0.0)
	return scene


func test_a_played_match_is_saved_as_its_results_show() -> void:
	var scene := _ended(_choices(), false)
	assert_true((scene.get_node("EndOverlay") as EndOverlay).visible, "the results")
	assert_not_null(scene.last_replay, "recorded")
	assert_true(scene.last_replay.playable(), "a replay that plays")
	assert_eq(_store.list().size(), 1, "and written to the list")


func test_a_match_bots_play_on_every_seat_is_never_written() -> void:
	var scene := _ended(_choices(), true)
	assert_true((scene.get_node("EndOverlay") as EndOverlay).visible, "the results")
	assert_not_null(scene.last_replay, "recorded for the results' Watch replay")
	assert_true(scene.last_replay.playable())
	assert_eq(_store.list(), PackedStringArray(), "nothing written to the player's list")
