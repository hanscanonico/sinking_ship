extends GutTest
## The keys of play are the player's to choose (non-QWERTY layouts, one hand): a
## choice outlives the game, takes the keyboard's place in the input map and leaves
## the pad's alone, swaps with an action that held the key, and resets to the
## project's own.

const PATH := "user://test_key_bindings.tres"
const SETTINGS_MENU := preload("res://scenes/game/settings_menu.tscn")


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	KeyBindings.new().apply()


func test_bindings_round_trip_through_user_storage() -> void:
	var keys := KeyBindings.new()
	assert_true(keys.bind(&"jump", _key(KEY_J)))
	assert_true(keys.bind(&"shove", _click(MOUSE_BUTTON_MIDDLE)))
	assert_eq(keys.save(PATH), OK)

	var back := KeyBindings.read(PATH)
	assert_ne(back, keys, "read from the file, not the cache")
	assert_eq(back.chosen.size(), 2)
	assert_true(KeyBindings.same_input(back.shown(&"jump"), _key(KEY_J)))
	assert_true(KeyBindings.same_input(back.shown(&"shove"), _click(MOUSE_BUTTON_MIDDLE)))
	assert_true(KeyBindings.same_input(back.shown(&"brace"), _key(KEY_SHIFT)), "unchosen")


func test_applying_replaces_only_the_keyboard_and_mouse() -> void:
	var pad_before := _pad_events(&"move_up")
	assert_false(pad_before.is_empty())
	var keys := KeyBindings.new()
	keys.bind(&"move_up", _key(KEY_Z))
	keys.apply()

	var on_keyboard := _key_events(&"move_up")
	assert_eq(on_keyboard.size(), 1, "the one chosen key in place of W and the arrow")
	assert_true(KeyBindings.same_input(on_keyboard[0], _key(KEY_Z)))
	assert_eq(_pad_events(&"move_up").size(), pad_before.size(), "the pad's kept")
	assert_eq(InputPrompts.word_for(InputMap.action_get_events(&"move_up"), false), "Z")
	assert_eq(_key_events(&"move_down").size(), 2, "an unchosen action keeps its keys")

	var press := _key(KEY_Z)
	press.pressed = true
	assert_true(press.is_action_pressed(&"move_up"), "the new key moves")
	var old := _key(KEY_W)
	old.pressed = true
	assert_false(old.is_action_pressed(&"move_up"), "the old key no longer does")


func test_a_key_another_action_holds_swaps_the_two() -> void:
	var keys := KeyBindings.new()
	assert_true(keys.bind(&"shove", _key(KEY_SPACE)))
	assert_true(KeyBindings.same_input(keys.shown(&"shove"), _key(KEY_SPACE)))
	assert_true(
		KeyBindings.same_input(keys.shown(&"jump"), _click(MOUSE_BUTTON_LEFT)),
		"jump takes shove's old click"
	)
	keys.apply()
	var space := _key(KEY_SPACE)
	space.pressed = true
	assert_true(space.is_action_pressed(&"shove"))
	assert_false(space.is_action_pressed(&"jump"), "no key answers to two actions")


func test_only_keys_and_buttons_of_play_bind() -> void:
	var keys := KeyBindings.new()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	assert_false(keys.bind(&"jump", pad), "the pad is not rebound here")
	assert_false(keys.bind(&"jump", _click(MOUSE_BUTTON_WHEEL_UP)))
	assert_false(keys.bind(&"replay_pause", _key(KEY_P)), "not an action of play")
	assert_true(keys.chosen.is_empty())


func test_the_hints_name_the_keys_as_rebound() -> void:
	var keys := KeyBindings.new()
	keys.bind(&"jump", _key(KEY_J))
	keys.bind(&"move_up", _key(KEY_Z))
	keys.apply()
	assert_string_contains(InputPrompts.controls_for(false), "Z A S D — move")
	assert_string_contains(InputPrompts.controls_for(false), "J — jump")
	assert_string_contains(InputPrompts.pause_controls_for(false), "J — jump")
	assert_string_contains(InputPrompts.pause_controls_for(true), "A — jump", "the pad's own")


func test_reset_restores_the_project_s_keys() -> void:
	var keys := KeyBindings.new()
	keys.bind(&"jump", _key(KEY_J))
	keys.bind(&"brace", _key(KEY_C))
	keys.apply()
	keys.reset()
	keys.apply()
	assert_true(keys.chosen.is_empty())
	for action: StringName in KeyBindings.ACTIONS:
		var project := KeyBindings.defaults_of(action)
		var now := _key_events(action)
		assert_eq(now.size(), project.size(), action)
		for index in project.size():
			assert_true(KeyBindings.same_input(now[index], project[index]), action)


func test_a_missing_or_corrupt_file_reads_as_the_defaults() -> void:
	assert_true(KeyBindings.read(PATH).chosen.is_empty(), "nothing saved yet")

	var wrong := AudioSettings.new()
	assert_eq(wrong.save(PATH), OK)
	assert_true(KeyBindings.read(PATH).chosen.is_empty(), "another resource")

	var odd := KeyBindings.new()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	odd.chosen[&"jump"] = pad
	odd.chosen[&"debug_nonsense"] = _key(KEY_K)
	odd.chosen[&"shove"] = _key(KEY_G)
	assert_eq(odd.save(PATH), OK)
	var back := KeyBindings.read(PATH)
	assert_eq(back.chosen.keys(), [&"shove"], "only a key of play is kept")


func test_the_keys_page_binds_the_next_key_and_esc_cancels() -> void:
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	menu.keys_path = PATH
	menu.audio_path = "user://test_key_bindings_audio.tres"
	menu.view_path = "user://test_key_bindings_view.tres"
	add_child(menu)
	menu.open(SettingsMenu.Page.KEYS)
	var jump: Button = menu.get_node("%KeyRows").find_child("Key_jump", false, false)
	assert_eq(jump.text, "Space")
	jump.pressed.emit()
	assert_eq(jump.text, "Press a key…")
	var escape := _key(KEY_ESCAPE)
	escape.pressed = true
	menu._input(escape)
	assert_eq(jump.text, "Space", "Esc leaves it as it was")

	jump.pressed.emit()
	var j := _key(KEY_J)
	j.pressed = true
	menu._input(j)
	assert_eq(jump.text, "J")
	assert_eq(InputPrompts.word_for(InputMap.action_get_events(&"jump"), false), "J")
	(menu.get_node("%ResetKeys") as Button).pressed.emit()
	assert_eq(jump.text, "Space")
	menu.close()
	assert_true(KeyBindings.read(PATH).chosen.is_empty())
	for path: String in [menu.audio_path, menu.view_path]:
		DirAccess.remove_absolute(path)


func _key(physical: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = physical
	return key


func _click(button: MouseButton) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = button
	return click


func _key_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			events.append(event)
	return events


func _pad_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			events.append(event)
	return events
