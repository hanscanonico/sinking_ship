extends GutTest
## A seat's place is fixed the tick it goes out: the out plate (OutPlate) tells the
## player theirs at once, the match going on behind it, and gives way to the results
## when it ends.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const NAMES: Array[String] = ["You", "Bot 1", "Bot 2"]


func after_each() -> void:
	Language.use(Language.SOURCE)


## The local seat shoved out third of three by seat 2, the match going on.
func _out_third() -> MatchStats:
	var stats := MatchStats.new(3, 0)
	var out: Array[SimEvent] = [SimEvent.seat_out(90, 0, 3, PlayerState.Cause.COLD, 2)]
	stats.add(out)
	return stats


## The match of [param stats] ended, its other seats placed.
func _end(stats: MatchStats) -> void:
	var ended: Array[SimEvent] = [
		SimEvent.seat_out(120, 1, 2, PlayerState.Cause.COLD, -1), SimEvent.match_ended(120, 2)
	]
	stats.add(ended)


func _plate() -> OutPlate:
	var plate := OutPlate.new()
	add_child_autofree(plate)
	return plate


## A match scene started with three seats, a bot on the local one when [param autoplay].
func _scene(autoplay: bool) -> MatchScene:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(3)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	config.humans = 0 if autoplay else 1
	scene.start(config, autoplay)
	return scene


## The plate's buttons take presses: its press guard run out.
func _past_guard(plate: OutPlate) -> void:
	plate._guard.stop()
	plate._accept_presses()


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_a_result_is_due_once_the_seat_is_out_and_until_the_match_ends() -> void:
	var stats := MatchStats.new(3, 0)
	assert_false(OutPlate.due(stats, 0), "nothing while the seat is in")
	var out: Array[SimEvent] = [SimEvent.seat_out(90, 0, 3, PlayerState.Cause.COLD, -1)]
	stats.add(out)
	assert_true(OutPlate.due(stats, 0), "its place is fixed the tick it goes out")
	assert_false(OutPlate.due(stats, 1), "another seat's going out is not this one's")
	assert_false(OutPlate.due(stats, -1), "nobody plays a seat: a watcher, a bot's match")
	_end(stats)
	assert_false(OutPlate.due(stats, 0), "the match ended: the results tell it")
	assert_false(OutPlate.due(null, 0))


func test_the_plate_says_the_place_and_how_the_seat_went_out() -> void:
	var names := PackedStringArray(NAMES)
	var plate := _plate()
	assert_false(plate.visible, "nothing before the seat is out")
	plate.offer(MatchStats.new(3, 0), 0, names)
	assert_false(plate.visible)
	plate.offer(_out_third(), 0, names)
	assert_true(plate.visible, "the plate shows as the seat goes out")
	var title: Label = plate.get_node("Panel").find_child("Title", true, false)
	assert_eq(title.text, "Overboard — 3rd of 3 — shoved by Bot 2")
	var aboard := _plate()
	aboard.offer(_out_third(), 0, names, false, true)
	assert_eq(aboard._title.text, "Frozen — 3rd of 3 — shoved by Bot 2", "frozen aboard")
	var survival := _plate()
	survival.offer(_out_third(), 0, names, true)
	assert_eq(survival._title.text, "Survived 00:03.0 · 3rd", "as survival's results say it")


func test_a_local_match_offers_watch_rematch_and_menu() -> void:
	var plate := _plate()
	plate.offer(_out_third(), 0, PackedStringArray(NAMES))
	var shown: Array[String] = []
	for button: Button in [plate._watch, plate._rematch, plate._menu]:
		if button.visible:
			shown.append(button.text)
		assert_true(button.disabled, "no press counts until the guard has run")
	assert_eq(shown, ["Watch", "Rematch", "Menu"] as Array[String])
	_past_guard(plate)
	assert_false(plate._watch.disabled)
	assert_true(plate._watch.has_focus(), "Watch is the one a press of accept takes")


func test_online_it_offers_watch_and_leave_and_no_rematch() -> void:
	var plate := _plate()
	plate.offer_room()
	plate.offer(_out_third(), 0, PackedStringArray(NAMES))
	assert_false(plate._rematch.visible, "nothing is played again mid-match on a server")
	assert_true(plate._watch.visible)
	assert_eq(plate._menu.text, "Leave")
	_past_guard(plate)
	watch_signals(plate)
	plate._unhandled_input(_press(&"restart"))
	assert_signal_not_emitted(plate, "rematch_requested", "nor by its key")
	assert_true(plate.visible)


func test_watch_closes_it_for_the_rest_of_the_match() -> void:
	var names := PackedStringArray(NAMES)
	var plate := _plate()
	var stats := _out_third()
	plate.offer(stats, 0, names)
	_past_guard(plate)
	watch_signals(plate)
	plate._watch.pressed.emit()
	assert_false(plate.visible, "Watch closes it")
	assert_signal_not_emitted(plate, "rematch_requested")
	assert_signal_not_emitted(plate, "menu_requested")
	plate.offer(stats, 0, names)
	assert_false(plate.visible, "and it shows once a match")
	plate.offer(_out_third(), 0, names)
	assert_true(plate.visible, "the next match has its own")


func test_esc_watches_and_a_press_inside_the_guard_does_nothing() -> void:
	var plate := _plate()
	plate.offer(_out_third(), 0, PackedStringArray(NAMES))
	plate._unhandled_input(_press(&"pause"))
	assert_true(plate.visible, "a key mashed going over the side leaves it standing")
	_past_guard(plate)
	plate._unhandled_input(_press(&"pause"))
	assert_false(plate.visible, "Esc watches on")


func test_rematch_and_menu_close_it_and_ask_the_match() -> void:
	for asked: String in ["rematch_requested", "menu_requested"]:
		var plate := _plate()
		plate.offer(_out_third(), 0, PackedStringArray(NAMES))
		_past_guard(plate)
		watch_signals(plate)
		var button := plate._rematch if asked == "rematch_requested" else plate._menu
		button.pressed.emit()
		assert_signal_emitted(plate, asked)
		assert_false(plate.visible, "%s closes the plate" % asked)
	var keyed := _plate()
	keyed.offer(_out_third(), 0, PackedStringArray(NAMES))
	_past_guard(keyed)
	watch_signals(keyed)
	keyed._unhandled_input(_press(&"restart"))
	assert_signal_emitted(keyed, "rematch_requested", "the rematch's key asks it too")


func test_it_gives_way_as_the_match_ends() -> void:
	var plate := _plate()
	var stats := _out_third()
	plate.offer(stats, 0, PackedStringArray(NAMES))
	assert_true(plate.visible)
	_end(stats)
	plate.offer(stats, 0, PackedStringArray(NAMES))
	assert_false(plate.visible, "the results take its place")


func test_the_hint_names_the_keys_of_the_device_last_used() -> void:
	var names := PackedStringArray(NAMES)
	var prompts: InputPrompts = autofree(InputPrompts.new())
	prompts.pad = false
	assert_eq(OutPlate.hint_words(prompts, false), "Esc — watch   ·   R — rematch")
	assert_eq(OutPlate.hint_words(prompts, true), "Esc — watch", "no rematch online")
	prompts.pad = true
	assert_eq(OutPlate.hint_words(prompts, false), "Start — watch", "Start does both: it watches")
	var plate := _plate()
	var stats := _out_third()
	prompts.pad = false
	plate.offer(stats, 0, names, false, false, prompts)
	assert_eq(plate._hint.text, "Esc — watch   ·   R — rematch")
	prompts.pad = true
	plate.offer(stats, 0, names, false, false, prompts)
	assert_eq(plate._hint.text, "Start — watch", "it follows the device as it changes")


func test_it_speaks_the_language_played() -> void:
	Language.use("fr")
	var prompts: InputPrompts = autofree(InputPrompts.new())
	prompts.pad = false
	var plate := _plate()
	plate.offer(_out_third(), 0, PackedStringArray(NAMES), false, false, prompts)
	assert_string_contains(plate._title.text, "3e sur 3")
	assert_string_contains(plate._hint.text, "regarder")
	assert_string_contains(plate._hint.text, "revanche")
	assert_eq(plate._watch.atr(plate._watch.text), "Regarder")
	assert_eq(Language.t(OutPlate.GOES_ON), "La partie continue")
	Language.use("es")
	assert_eq(Language.t(OutPlate.GOES_ON), "La partida sigue")
	assert_eq(Language.t("watch"), "ver")


## In the match scene: a played seat going out shows the plate, lets the mouse go and
## leaves the world playing; the match ending, the results show as ever.
func test_a_played_seat_going_out_shows_it_over_the_match_going_on() -> void:
	var scene := _scene(false)
	assert_not_null(scene._local, "a person plays the local seat")
	var plate: OutPlate = scene.get_node("OutPlate")
	var results: EndOverlay = scene.get_node("EndOverlay")
	scene._process(0.0)
	assert_false(plate.visible, "nothing while the seat is in")
	assert_true(scene._looking(), "and the look is the player's")
	var out: Array[SimEvent] = [SimEvent.seat_out(90, 0, 3, PlayerState.Cause.COLD, 2)]
	scene._stats.add(out)
	scene._process(0.0)
	assert_true(plate.visible, "the plate shows as the seat goes out")
	assert_false(results.visible, "the results wait for the end")
	assert_false(scene._looking(), "the mouse is the plate's while it stands")
	assert_true(scene._driver.is_processing(), "the match plays on behind it")
	_past_guard(plate)
	plate._watch.pressed.emit()
	scene._process(0.0)
	assert_false(plate.visible)
	assert_true(scene._looking(), "watching, the view is the player's again")
	_end(scene._stats)
	scene._process(0.0)
	assert_true(results.visible, "the results show at the end, as ever")
	assert_false(plate.visible)


## Still open as the match ends, the plate gives way to the results.
func test_open_at_the_end_it_gives_way_to_the_results() -> void:
	var scene := _scene(false)
	var plate: OutPlate = scene.get_node("OutPlate")
	var out: Array[SimEvent] = [SimEvent.seat_out(90, 0, 3, PlayerState.Cause.COLD, -1)]
	scene._stats.add(out)
	scene._process(0.0)
	assert_true(plate.visible)
	_end(scene._stats)
	scene._process(0.0)
	assert_false(plate.visible, "the plate gives way")
	assert_true((scene.get_node("EndOverlay") as EndOverlay).visible, "to the results")


## A bot on the local seat — an autoplay, a capture — has nobody to tell: no plate.
func test_a_seat_a_bot_plays_gets_no_plate() -> void:
	var scene := _scene(true)
	var out: Array[SimEvent] = [SimEvent.seat_out(90, 0, 3, PlayerState.Cause.COLD, -1)]
	scene._stats.add(out)
	scene._process(0.0)
	assert_false((scene.get_node("OutPlate") as OutPlate).visible)
