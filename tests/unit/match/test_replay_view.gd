extends GutTest
## A replay is watched under its own controls (ReplayHud, R4–R5), which name whose eyes
## it is seen through and the keys that switch them: once the recorded seat is out, the
## match's spectating line — its place, and a played match's keys to switch and fly —
## is not drawn over them, as it is in the match itself. Its free camera opens framing
## the whole ship and follows the seat watched. At its last tick the match's HUD stays,
## no results taking its place, and the controls say who won.

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


## Once the seat a replay is seen through is out, the view moves on to a seat still in,
## as the match's did, and the controls say whose eyes: it stayed "Through your own eyes"
## from wherever the out seat's body was last drawn — its spawn, after a seek. Sought back
## to before it went out, the view is its own again; and the eyes cycle past a seat out.
func test_a_replay_s_eyes_leave_a_seat_that_is_out() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(3)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	var played := RunMatch.bots_only(config)
	played.run(Ticks.RATE)
	scene.start_replay(ReplayFile.record(MatchChoices.new(), played.input_log, 0), config)
	scene._process(0.0)
	var whose: Label = scene._replay_hud._seat
	var first := scene._driver.timeline().first_tick()
	var last := scene._driver.timeline().last_tick()
	assert_eq(scene._viewed(), MatchScene.LOCAL_SEAT)
	assert_eq(whose.text, "Through your own eyes")
	scene.replay_seek(last)
	_seat_out(scene)
	assert_eq(scene._viewed(), 1, "a seat still in")
	assert_eq(whose.text, "Through Bot 1's eyes")
	assert_eq(scene._first_person_hud._seat, 1, "and the HUD is of that seat")
	scene.replay_seek(first)
	scene._process(0.0)
	assert_eq(scene._viewed(), MatchScene.LOCAL_SEAT, "sought back, its own eyes")
	assert_eq(whose.text, "Through your own eyes")
	scene.replay_seek(last)
	_seat_out(scene)
	_press(scene, &"spectate_next")
	assert_eq(scene._viewed(), 2)
	_press(scene, &"spectate_next")
	assert_eq(scene._viewed(), 1, "round the seats still in, past the one out")
	scene.replay_seek(first)
	scene._process(0.0)
	assert_eq(scene._viewed(), 1, "the seat cycled to is kept through a seek")
	_press(scene, &"spectate_previous")
	assert_eq(scene._viewed(), MatchScene.LOCAL_SEAT, "in the match, any seat's eyes")


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
	_press(scene, &"spectate_ghost")
	assert_true(scene._ghost.active, "into the ghost")
	assert_eq(plate.text, "Ghost")
	_press(scene, &"spectate_ghost")
	assert_eq(plate.text, "First person")


## Its free camera climbs on the jump's keys and buttons, as an out seat's does: none of
## them may also be the replay's pause, which would toggle under every climb.
func test_climbing_the_free_camera_never_pauses_the_replay() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := _config()
	var played := RunMatch.bots_only(config)
	played.run(Ticks.RATE)
	scene.start_replay(ReplayFile.record(MatchChoices.new(), played.input_log, 0), config)
	scene._process(0.0)
	_press(scene, &"spectate_free")
	var climbs := InputMap.action_get_events(&"jump")
	assert_false(climbs.is_empty())
	for climb: InputEvent in climbs:
		var pressed := climb.duplicate() as InputEvent
		pressed.set(&"pressed", true)
		scene._unhandled_input(pressed)
		assert_false(scene._driver.clock().paused, "%s climbs, it never pauses" % climb.as_text())
	_press(scene, &"replay_pause")
	assert_true(scene._driver.clock().paused, "the replay's own pause still does")


## A replay of [param seats] bots' first second, watched in a scene of its own.
func _replay(seats := 2) -> MatchScene:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(seats)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	var played := RunMatch.bots_only(config)
	played.run(Ticks.RATE)
	scene.start_replay(ReplayFile.record(MatchChoices.new(), played.input_log, 0), config)
	scene._process(0.0)
	return scene


## [param scene]'s replay at its last tick, the match ended there with only the seats
## [param left] still in, its frame drawn.
func _ended(scene: MatchScene, left: Array[int]) -> void:
	scene.replay_seek(scene._driver.timeline().last_tick())
	var snapshot := scene.current()
	snapshot["phase"] = MatchState.Phase.ENDED
	for entry: Dictionary in snapshot["seats"]:
		entry["out"] = not left.has(entry["seat"])
	scene._process(0.0)


## The match's HUD goes at its end for the results to take its place (EndOverlay). No
## results stand over a replay's last tick: the clock, the seats left, the dials and the
## seat's place went all the same, leaving a bare view under the controls, and came back
## a step before.
func test_a_replay_keeps_the_match_s_hud_at_its_last_tick() -> void:
	var scene := _replay()
	var hud := scene._first_person_hud
	_ended(scene, [0])
	assert_true(scene._hud._clock.visible, "the clock")
	assert_true(scene._hud._seats_left.visible, "the seats left")
	assert_eq(scene._hud._seats_left.text, "Seats left 1 / 2")
	assert_false(hud._over(), "the dials, the banner and the plate are drawn")
	assert_true(hud._answers.is_in, "of a seat still in")
	var pose := scene._driver.sim().schedule.pose_at(scene.current()["tick"])
	assert_same(hud._answers.whole, pose, "at her pose on that tick")


## A played match's HUD still goes as it ends: its results are coming up over it.
func test_the_match_s_hud_goes_as_it_ends() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(_config(), true)
	scene._driver.step()
	scene.current()["phase"] = MatchState.Phase.ENDED
	scene._process(0.0)
	assert_false(scene._hud._clock.visible)
	assert_false(scene._hud._seats_left.visible)
	assert_true(scene._first_person_hud._over())


## At the end of a match that ended, the controls say who won it, as the list of replays
## does: nothing else of a replay does, with no results over it.
func test_a_replay_says_who_won_at_its_end() -> void:
	var scene := _replay(3)
	var result: Label = scene._replay_hud._result
	assert_false(result.visible, "nobody yet, while it plays")
	_ended(scene, [2])
	assert_true(result.visible)
	assert_eq(result.text, "Bot 2 won")
	_ended(scene, [0])
	assert_eq(result.text, "You won")
	_ended(scene, [])
	assert_eq(result.text, "The sea won", "nobody left dry")
	scene.replay_seek(scene._driver.timeline().first_tick())
	scene._process(0.0)
	assert_false(result.visible, "sought back, the match is on again")
	assert_eq(result.text, "")
	var watched := scene.current().duplicate(true)
	watched["phase"] = MatchState.Phase.ENDED
	watched["seats"][1]["out"] = true
	watched["seats"][2]["out"] = true
	assert_eq(MatchScene.replay_result(watched, true), "Bot 1 won", "no seat is the watcher's")
	Language.use("fr")
	assert_eq(MatchScene.replay_result(watched, false), "Vous avez gagné")
	Language.use(Language.SOURCE)


## A replay left before its match ended names no winner at its last tick: nobody won yet.
func test_an_unfinished_replay_names_no_winner_at_its_end() -> void:
	var scene := _replay()
	scene.replay_seek(scene._driver.timeline().last_tick())
	scene._process(0.0)
	assert_true(scene._driver.is_over(), "at its end")
	assert_false(scene._replay_hud._result.visible)


## At its end nothing plays: the button reads Play, as paused, not Pause.
func test_the_play_button_reads_play_at_a_replay_s_end() -> void:
	var scene := _replay()
	var play: Button = scene._replay_hud._play
	assert_eq(play.text, "Pause", "playing")
	scene.replay_seek(scene._driver.timeline().last_tick())
	scene._process(0.0)
	assert_false(scene._driver.clock().paused, "never paused")
	assert_eq(play.text, "Play", "but at its end")
	_press(scene, &"replay_step_back")
	_press(scene, &"replay_pause")
	assert_eq(play.text, "Pause", "a step back and played on, it plays again")


func _press(scene: MatchScene, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene._unhandled_input(event)
	scene._process(0.0)
