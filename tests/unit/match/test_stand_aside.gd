extends GutTest
## A rematch, or a replay watched from the results, held for its sinking (R20) shows its
## countdown over the menu's backdrop as a held Play does: the ended match it was asked
## from stands aside — its world, HUDs and results drawn no more, however many frames
## the hold runs — until the next start brings it back.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"


func test_the_results_stand_aside_for_a_held_start() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(2)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	scene.start(config, true)
	var ended: Array[SimEvent] = [
		SimEvent.seat_out(90, 1, 2, PlayerState.Cause.COLD, -1),
		SimEvent.match_ended(90, 0),
	]
	scene._stats.add(ended)
	scene._process(0.0)
	var results: EndOverlay = scene.get_node("EndOverlay")
	var hud: CanvasLayer = scene.get_node("Hud")
	var eyes_hud: CanvasLayer = scene.get_node("FirstPersonHud")
	assert_true(results.visible, "the results show once it has ended")
	scene.stand_aside()
	for _frame in 3:
		scene._process(0.0)
	assert_false(results.visible, "the results stand aside for the hold, frame after frame")
	assert_false(hud.visible, "the HUD with them")
	assert_false(eyes_hud.visible, "and the eyes' readouts")
	assert_false(scene.visible, "her world is drawn no more")
	scene.start(config, true)
	assert_true(scene.visible, "the next start draws her again")
	assert_true(hud.visible and eyes_hud.visible, "its HUDs back")
	assert_false(results.visible, "and no results")
