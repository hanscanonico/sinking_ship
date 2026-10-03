extends GutTest


func _key(physical: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = physical
	return key


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func test_a_prompt_names_the_device_last_used() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	var shove: Array[InputEvent] = [_key(KEY_SPACE), click, _pad(JOY_BUTTON_A)]
	assert_eq(InputPrompts.word_for(shove, false), "Space")
	assert_eq(InputPrompts.word_for(shove, true), "A")
	var clicked: Array[InputEvent] = [click]
	assert_eq(InputPrompts.word_for(clicked, false), "Left click")
	assert_eq(InputPrompts.word_for(clicked, true), "", "nothing on the pad")


func test_the_hints_read_the_input_map() -> void:
	var words := {}
	for action: StringName in [&"restart", &"pause", &"spectate_previous", &"spectate_next"]:
		var events := InputMap.action_get_events(action)
		words[action] = [InputPrompts.word_for(events, false), InputPrompts.word_for(events, true)]
	assert_eq(words[&"restart"], ["R", "Start"])
	assert_eq(words[&"pause"], ["Esc", "Start"])
	assert_eq(words[&"spectate_previous"], ["Q", "d-pad left"])
	assert_eq(words[&"spectate_next"], ["E", "d-pad right"])


func test_the_last_device_used_wins() -> void:
	var prompts := InputPrompts.new()
	prompts._input(_pad(JOY_BUTTON_A))
	assert_true(prompts.pad)
	var drift := InputEventJoypadMotion.new()
	drift.axis_value = 0.1
	prompts._input(_key(KEY_R))
	prompts._input(drift)
	assert_false(prompts.pad, "a drifting stick is not the pad picked up")
	drift.axis_value = -0.9
	prompts._input(drift)
	assert_true(prompts.pad, "a stick pushed over is")
	prompts._input(InputEventMouseMotion.new())
	assert_false(prompts.pad, "and the mouse takes it back")
	prompts.free()
