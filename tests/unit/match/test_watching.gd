extends GutTest
## A match only watched (GLOSSARY: Watch, MatchChoices.watch): nobody plays it, bots on
## every seat, and the watcher looks through any dry seat's eyes, from the orbit camera or
## from the free camera, as they switch, the line along the bottom saying which — all of
## it presentation; and it is kept in the replays, which watch it again as it was.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const DIR := "user://replays_watching_test"

var _store := ReplayStore.new(DIR)


func before_each() -> void:
	for path in _store.list():
		_store.delete(path)


func after_all() -> void:
	for path in _store.list():
		_store.delete(path)
	DirAccess.remove_absolute(DIR)


func _watched() -> MatchChoices:
	var chosen := MatchChoices.new()
	chosen.ship = &"tug"
	chosen.seats = 3
	chosen.seed_text = "1701"
	chosen.watch = true
	return chosen


## A watched match on [param chosen], started as Game starts one, a beat stepped and drawn.
func _started(chosen: MatchChoices) -> MatchScene:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.replays = ReplayRecorder.new(_store)
	scene.choices = chosen
	scene.start(chosen.config(load(MATCH_DATA)), false)
	scene._driver.step()
	scene._process(0.0)
	return scene


func _press(scene: MatchScene, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene._unhandled_input(event)
	scene._process(0.0)


func _line(scene: MatchScene) -> String:
	return scene._hud._spectating.text


func test_nobody_plays_a_watched_match() -> void:
	var scene := _started(_watched())
	assert_true(scene.watching())
	assert_null(scene._local, "no keys play a seat")
	assert_eq(scene._local_seat, -1, "no seat is the watcher's")
	assert_eq(scene._names, PackedStringArray(["Bot 1", "Bot 2", "Bot 3"]))
	assert_true(scene.spectating(), "the view is the watcher's to switch from the start")
	assert_string_starts_with(_line(scene), "Watching   ·   through Bot 1's eyes")


func test_the_watcher_switches_seats_and_cameras() -> void:
	var scene := _started(_watched())
	_press(scene, &"spectate_next")
	assert_eq(scene._order.target(scene.current()), 1, "the next seat's eyes")
	assert_string_starts_with(_line(scene), "Watching   ·   through Bot 2's eyes")

	_press(scene, &"replay_camera_toggle")
	assert_true(scene._orbiting(), "into the orbit camera, the whole ship framed")
	assert_string_starts_with(_line(scene), "Watching   ·   orbit camera")
	_press(scene, &"replay_orbit_lock")
	assert_string_starts_with(_line(scene), "Watching   ·   orbiting Bot 2", "locked on the seat")
	assert_true(
		scene._eyes.global_transform.is_equal_approx(scene._orbit.transform()), "seen from it"
	)

	_press(scene, &"spectate_free")
	assert_true(scene._free.active, "into the free camera")
	assert_false(scene._orbiting(), "out of the orbit")
	assert_string_starts_with(_line(scene), "Watching   ·   free camera")

	_press(scene, &"replay_camera_toggle")
	assert_true(scene._orbiting(), "the orbit again")
	assert_false(scene._free.active, "out of the free camera")
	_press(scene, &"replay_camera_toggle")
	assert_false(scene._orbiting(), "and back into the eyes")
	assert_string_starts_with(_line(scene), "Watching   ·   through Bot 2's eyes")


func test_a_played_match_has_no_orbit_camera() -> void:
	var played := _watched()
	played.watch = false
	var scene := _started(played)
	assert_false(scene.watching())
	assert_eq(scene._names[0], "You")
	_press(scene, &"replay_camera_toggle")
	assert_false(scene._orbiting(), "the orbit is a watcher's and a replay's")
	assert_false(scene._hud._spectating.visible, "no line while you are dry")


## A watched match is kept as its results show — a person chose to watch it — and its
## replay names every seat a bot's, none the watcher's own.
func test_a_watched_match_is_kept_and_replayed_as_watched() -> void:
	var chosen := _watched()
	var scene := _started(chosen)
	(
		scene
		. _stats
		. add(
			[
				SimEvent.seat_out(30, 1, 3, PlayerState.Cause.COLD, -1),
				SimEvent.seat_out(30, 2, 2, PlayerState.Cause.COLD, -1),
				SimEvent.match_ended(30, 0),
			]
		)
	)
	scene._process(0.0)
	var results: EndOverlay = scene.get_node("EndOverlay")
	assert_true(results.visible, "the results")
	assert_eq((results.get_node("%Title") as Label).text, "Last one dry: Bot 1")
	assert_eq(_store.list().size(), 1, "written to the player's list")

	scene.start_replay(scene.last_replay, chosen.config(load(MATCH_DATA)))
	scene._process(0.0)
	assert_false(scene.watching(), "a replay, not the match")
	assert_eq(scene._names, PackedStringArray(["Bot 1", "Bot 2", "Bot 3"]))
	assert_eq(scene._local_seat, -1)
