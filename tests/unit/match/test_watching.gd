extends GutTest
## A match only watched (GLOSSARY: Watch, MatchChoices.watch): nobody plays it, bots on
## every seat, and the watcher looks through any dry seat's eyes or from the free camera,
## as they switch, the line along the bottom saying which — all of it presentation; and
## it is kept in the replays, which watch it again as it was.

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

	_press(scene, &"spectate_free")
	assert_true(scene._free.active, "into the free camera")
	assert_string_starts_with(_line(scene), "Watching   ·   free camera")
	var framed := FreeCamera.new()
	framed.frame_ship(scene._deck_bounds(scene._config.ship))
	assert_almost_eq(scene._free.position, framed.position, Vector3.ONE * 1e-3, "the ship framed")
	assert_true(
		scene._eyes.global_transform.is_equal_approx(scene._free.transform()), "seen from it"
	)
	_press(scene, &"spectate_follow")
	assert_true(scene._free.following, "following the seat")
	assert_string_starts_with(_line(scene), "Watching   ·   following Bot 2")
	_press(scene, &"spectate_next")
	assert_true(scene._free.active, "following, it trails the next seat")
	assert_string_starts_with(_line(scene), "Watching   ·   following Bot 3")
	_press(scene, &"spectate_follow")
	assert_string_starts_with(_line(scene), "Watching   ·   free camera", "let go")

	_press(scene, &"spectate_free")
	assert_false(scene._free.active, "back into the eyes")
	assert_string_starts_with(_line(scene), "Watching   ·   through Bot 3's eyes")
	_press(scene, &"spectate_free")
	assert_almost_eq(scene._free.position, framed.position, Vector3.ONE * 1e-3, "where it was left")


## An out seat in play flies the free camera and follows from it; a dry one has neither.
func test_a_played_seat_flies_and_follows_only_once_out() -> void:
	var played := _watched()
	played.watch = false
	var scene := _started(played)
	assert_false(scene.watching())
	assert_eq(scene._names[0], "You")
	_press(scene, &"spectate_free")
	_press(scene, &"spectate_follow")
	assert_false(scene._free.active, "no free camera while you are dry")
	assert_false(scene._hud._spectating.visible, "no line while you are dry")

	var seat: Dictionary = scene.current()["seats"][MatchScene.LOCAL_SEAT]
	seat["out"] = true
	seat["place"] = 3
	_press(scene, &"spectate_free")
	assert_true(scene._free.active, "out, into the free camera")
	_press(scene, &"spectate_follow")
	assert_true(scene._free.following, "and following the seat watched")
	assert_string_ends_with(_line(scene), "let go")


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


## An online match whose client has no seat (#611) is watched as a local Watch is: no
## keys play, the first seat's eyes to start, the free camera there for its key.
func test_an_online_match_with_no_seat_is_watched() -> void:
	var config := _watched().config(load(MATCH_DATA))
	var serving := MatchScene.serve(config, null)
	assert_eq(serving.loopback.client.seat, -1, "a client with no seat")
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start_online(serving.loopback, null, PackedStringArray(["Ada", "Bea", "Bot 2"]))
	scene._driver.step()
	scene._process(0.0)
	assert_true(scene.watching())
	assert_true(scene._can_fly(scene.current()), "the free camera is there")
	assert_null(scene._local)
	assert_eq(scene._local_seat, -1, "no seat is the watcher's")
	assert_eq(scene._eye_seat, MatchScene.LOCAL_SEAT, "the eyes a seat's still")
	assert_string_starts_with(_line(scene), "Watching   ·   through Ada's eyes")
