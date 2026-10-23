extends GutTest
## The pause lists every control of play under "Paused", one to a line, as the input
## map binds them on the device last used — and what switches the view once out.

const GAME := preload("res://scenes/game/game.tscn")


## A pause menu built as game.tscn's: its buttons and its controls' label.
func _pause() -> PauseMenu:
	var pause := PauseMenu.new()
	for part: String in ["Resume", "PauseSettings", "LeaveMatch", "QuitFromPause"]:
		_owned(pause, Button.new(), part)
	_owned(pause, Label.new(), "PauseControls")
	add_child_autofree(pause)
	return pause


func _owned(pause: PauseMenu, node: Control, part: String) -> void:
	node.name = part
	pause.add_child(node)
	node.owner = pause
	node.unique_name_in_owner = true


func test_game_lays_the_controls_under_paused() -> void:
	var game := GAME.instantiate()
	var box := game.get_node("PauseMenu/Panel/Box")
	var controls := box.get_node_or_null("PauseControls")
	assert_not_null(controls, "a controls label in the pause")
	if controls != null:
		assert_eq(controls.get_index(), box.get_node("Title").get_index() + 1, "under Paused")
	game.free()


func test_open_lists_the_controls_on_the_device_last_used() -> void:
	var pause := _pause()
	var prompts: InputPrompts = autofree(InputPrompts.new())
	var label: Label = pause.get_node("%PauseControls")
	for pad: bool in [false, true]:
		prompts.pad = pad
		pause.open(prompts)
		var shove := InputPrompts.word_for(InputMap.action_get_events(&"shove"), pad)
		assert_false(shove.is_empty())
		assert_true(label.visible)
		assert_string_contains(label.text, "%s — shove" % shove)
		var grab := InputPrompts.word_for(InputMap.action_get_events(&"grab"), pad)
		assert_string_contains(label.text, "%s — grab" % grab)
		assert_eq(
			label.text.split("\n").size(), 7, "move, look, jump, shove, brace, grab, pause"
		)
		assert_false(label.text.contains("switch view"), "nothing to switch while in")


func test_open_names_the_spectate_keys_once_out() -> void:
	var pause := _pause()
	var prompts: InputPrompts = autofree(InputPrompts.new())
	pause.open(prompts, true)
	var label: Label = pause.get_node("%PauseControls")
	assert_string_contains(label.text, "Q / E — switch view")
	assert_string_contains(label.text, "C — free camera")


func test_the_keyboard_looks_with_the_mouse_and_the_pad_with_its_stick() -> void:
	assert_string_contains(InputPrompts.pause_controls_for(false), "Mouse — look")
	assert_string_contains(InputPrompts.pause_controls_for(true), "Right stick — look")
	assert_string_contains(InputPrompts.pause_controls_for(false), "Esc — pause")
	assert_string_contains(InputPrompts.pause_controls_for(true), "Start — pause")
