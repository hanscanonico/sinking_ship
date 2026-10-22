extends GutTest
## A countdown held for a match's sinking or her ship (Game): Esc over it never opens the
## pause, whose Menu would leave the countdown running to start the match over the menu;
## leaving for the menu gives it up; and what was served on a thread for one held match is
## never handed to another with other settings (MatchServing).

const MATCH_DATA := "res://data/match/default.tres"
const MATCH := preload("res://scenes/match/match.tscn")
const SEED := 1701
## Frames a test waits at most for a serving's task.
const WAIT_FRAMES := 600


## A Game as it holds [param config]'s countdown, its match scene made and standing aside,
## never booted (no menu, no music): only what the hold reads and gives up.
func _holding_game(config: MatchConfig) -> Game:
	var game: Game = autofree(Game.new())
	autofree(game._baker)
	add_child_autofree(game._hold)
	game._match = MATCH.instantiate()
	add_child_autofree(game._match)
	game._match.stand_aside()
	game._holding = config
	game._hold.begin(Ticks.to_seconds(config.countdown_ticks))
	game._dressed_hold = true
	return game


func _config(match_seed: int = SEED) -> MatchConfig:
	return MatchConfig.from_rules(load(MATCH_DATA), match_seed)


## Waits, frame by frame, until [param serving] has no task running.
func _settle(serving: MatchServing) -> void:
	for _frame in WAIT_FRAMES:
		if not serving.busy():
			return
		await get_tree().process_frame


func test_esc_over_a_held_countdown_never_pauses() -> void:
	var game := _holding_game(_config())
	assert_false(game._match.is_over(), "her match not started, nothing says it is over")
	assert_false(game._takes_pause(), "held: Esc is not the pause's")
	game._holding_replay = ReplayFile.new()
	assert_false(game._takes_pause(), "a replay's hold neither")


func test_leaving_for_the_menu_gives_up_the_held_countdown() -> void:
	var config := _config()
	var game := _holding_game(config)
	game._baker.bake(config, 1.0)
	game._hold.advance(BakeHold.GRACE_SECONDS * 2.0, 0.5)
	var dressing := ShipDressing.new(config)
	game._dressing = dressing
	game._held_dressing = dressing
	game._serving.serve(config, func() -> MatchScene.Served: return MatchScene.Served.new())
	game._cancel_hold()
	assert_null(game._holding, "no match held")
	assert_null(game._holding_replay, "nor a replay")
	assert_false(game._dressed_hold, "nor waiting on her ship")
	assert_null(game._held_dressing)
	assert_null(game._dressing, "her ship's dressing let go")
	assert_true(dressing._dropped, "and dropped")
	assert_null(game._baker.baking(), "her sinking's bake stopped")
	assert_false(game._hold.visible, "the hold hidden")
	await _settle(game._serving)
	assert_false(game._serving.ready_for(config), "what was served for it let go")
	game._serving.finish()


func test_what_was_served_is_taken_only_for_its_own_config() -> void:
	var served := MatchScene.Served.new()
	var first := _config()
	var other := _config(SEED + 1)
	var serving := MatchServing.new()
	serving.serve(first, func() -> MatchScene.Served: return served)
	await _settle(serving)
	assert_false(serving.ready_for(other), "not in hand for another config")
	assert_true(serving.ready_for(first), "in hand for its own")
	assert_null(serving.take(other), "another's start never takes it")
	assert_false(serving.ready_for(first), "and it was dropped")
	serving.serve(first, func() -> MatchScene.Served: return served)
	await _settle(serving)
	assert_eq(serving.take(first), served, "its own start takes it")
	serving.finish()


func test_a_serving_given_up_is_never_taken() -> void:
	var config := _config()
	var serving := MatchServing.new()
	serving.serve(config, func() -> MatchScene.Served: return MatchScene.Served.new())
	serving.cancel()
	await _settle(serving)
	assert_false(serving.ready_for(config), "given up as it ran")
	assert_null(serving.take(config))
	serving.finish()
