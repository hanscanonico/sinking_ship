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


func test_c_and_y_switch_to_the_free_camera_and_nothing_else() -> void:
	var free := InputMap.action_get_events(&"spectate_free")
	assert_eq(InputPrompts.word_for(free, false), "C")
	assert_eq(InputPrompts.word_for(free, true), "Y")
	for action: StringName in InputMap.get_actions():
		if action == &"spectate_free" or String(action).begins_with("ui_"):
			continue
		for event: InputEvent in free:
			assert_false(
				_binds(InputMap.action_get_events(action), event),
				"%s does not share the free camera's %s" % [action, event.as_text()]
			)


func test_space_jumps_and_the_shove_moves_to_click_f_and_the_triggers() -> void:
	var jump := InputMap.action_get_events(&"jump")
	var shove := InputMap.action_get_events(&"shove")
	var brace := InputMap.action_get_events(&"brace")
	assert_true(_binds(jump, _key(KEY_SPACE)), "Space jumps")
	assert_true(_binds(jump, _pad(JOY_BUTTON_A)), "and A")
	assert_false(_binds(shove, _key(KEY_SPACE)), "Space no longer shoves")
	assert_false(_binds(shove, _pad(JOY_BUTTON_A)), "nor A")
	assert_true(_binds(shove, _key(KEY_F)), "F shoves")
	assert_true(_binds(shove, _pad(JOY_BUTTON_X)), "and X")
	assert_true(_binds(shove, _trigger(JOY_AXIS_TRIGGER_RIGHT)), "and the right trigger")
	assert_true(_binds(brace, _trigger(JOY_AXIS_TRIGGER_LEFT)), "the left trigger braces")
	assert_true(_binds(brace, _pad(JOY_BUTTON_RIGHT_SHOULDER)), "as RB still does")
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right", &"jump"]:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_eq((event as InputEventKey).keycode, KEY_NONE, "%s: by position" % action)


func test_the_controls_hint_reads_the_input_map() -> void:
	# Headless there is no layout to ask, so the keys read as their QWERTY
	# positions; on AZERTY the same physical keys read Z Q S D.
	assert_eq(
		InputPrompts.controls_for(false),
		"W A S D — move   ·   Space — jump   ·   Left click — shove   ·   Shift — brace"
	)
	assert_eq(
		InputPrompts.controls_for(true),
		"Left stick — move   ·   A — jump   ·   RT — shove   ·   RB — brace"
	)


func _trigger(axis: JoyAxis) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = 1.0
	return event


## Whether [param events] hold one that [param probe] would press.
func _binds(events: Array[InputEvent], probe: InputEvent) -> bool:
	for event: InputEvent in events:
		if event.is_match(probe):
			return true
	return false


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
