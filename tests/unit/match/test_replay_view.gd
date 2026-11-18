extends GutTest
## A replay is watched under its own controls (ReplayHud, R4–R5), which name whose eyes
## it is seen through and the keys that switch them: once the recorded seat is out, the
## match's spectating line — its place, and a played match's keys to switch and fly —
## is not drawn over them, as it is in the match itself. Its free camera opens framing
## the whole ship and follows the seat watched.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const RunMatch := preload("res://tools/run_match.gd")


func _config() -> MatchConfig:
	var config := SimFixtures.config(2)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	return config


## [param scene]'s latest snapshot with its seat 0 out, last of two, its frame drawn.
func _seat_out(scene: MatchScene) -> void:
	var seat: Dictionary = scene.current()["seats"][MatchScene.LOCAL_SEAT]
	seat["out"] = true
	seat["place"] = 2
	scene._process(0.0)


func test_the_match_shows_the_spectating_line_once_its_seat_is_out() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(_config(), true)
	scene._driver.step()
	_seat_out(scene)
	assert_true(scene._hud._spectating.visible, "its place and the keys to switch")


func test_a_replay_draws_no_spectating_line_over_its_controls() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := _config()
	var played := RunMatch.bots_only(config)
	played.run(Ticks.RATE)
	scene.start_replay(ReplayFile.record(MatchChoices.new(), played.input_log, 0), config)
	scene._process(0.0)
	_seat_out(scene)
	assert_false(scene._hud._spectating.visible, "the replay's controls name whose eyes")


## A replay is watched from the free camera too (R5): it opens framing the whole ship,
## follows the seat watched on its key, and the plate names it.
func test_a_replay_is_watched_from_the_free_camera() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := _config()
	var played := RunMatch.bots_only(config)
	played.run(Ticks.RATE)
	scene.start_replay(ReplayFile.record(MatchChoices.new(), played.input_log, 0), config)
	scene._process(0.0)
	var plate: Label = scene._replay_hud._camera
	assert_eq(plate.text, "First person")
	_press(scene, &"spectate_free")
	assert_true(scene._free.active, "into the free camera")
	var framed := FreeCamera.new()
	framed.frame_ship(scene._deck_bounds(config.ship))
	assert_almost_eq(scene._free.position, framed.position, Vector3.ONE * 1e-3, "the ship framed")
	assert_eq(plate.text, "Free camera")
	_press(scene, &"spectate_follow")
	assert_true(scene._free.following)
	assert_eq(plate.text, "Free · following")
	_press(scene, &"spectate_next")
	assert_true(scene._free.active, "following, it trails the next seat")
	_press(scene, &"spectate_free")
	assert_false(scene._free.active, "and back to the eyes")
	assert_eq(plate.text, "First person")


func _press(scene: MatchScene, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene._unhandled_input(event)
	scene._process(0.0)
