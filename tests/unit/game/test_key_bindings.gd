extends GutTest
## The keys of play are the player's to choose (non-QWERTY layouts, one hand): a
## choice outlives the game, heads its action's keys in place of the project's first
## of its kind and leaves the other alternates and the pad's alone, swaps with an
## action shown with the key, and resets to the project's own. The spectate keys
## are of the same set, so a key of play never also switches the view once out.

const PATH := "user://test_key_bindings.json"
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


## Grab (#273) is a key of play like the others: rebound, it takes G's place.
func test_grab_is_rebound_like_every_key_of_play() -> void:
	assert_true(&"grab" in KeyBindings.ACTIONS, "listed on the settings screen")
	var keys := KeyBindings.new()
	assert_true(KeyBindings.same_input(keys.shown(&"grab"), _key(KEY_G)), "G by default")
	assert_true(keys.bind(&"grab", _key(KEY_T)))
	keys.apply()
	var grab := _key_events(&"grab")
	assert_true(KeyBindings.same_input(grab[0], _key(KEY_T)), "T in G's place")


func test_applying_replaces_only_the_keyboard_and_mouse() -> void:
	var pad_before := _pad_events(&"move_up")
	assert_false(pad_before.is_empty())
	var keys := KeyBindings.new()
	keys.bind(&"move_up", _key(KEY_Z))
	keys.apply()

	var on_keyboard := _key_events(&"move_up")
	assert_eq(on_keyboard.size(), 2, "the chosen key in place of W, the arrow kept")
	assert_true(KeyBindings.same_input(on_keyboard[0], _key(KEY_Z)))
	assert_true(KeyBindings.same_input(on_keyboard[1], _key(KEY_UP)))
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


func test_a_key_keeps_the_click_and_a_click_keeps_the_key() -> void:
	var keys := KeyBindings.new()
	keys.bind(&"shove", _key(KEY_H))
	keys.bind(&"brace", _click(MOUSE_BUTTON_MIDDLE))
	keys.apply()
	var shove := _key_events(&"shove")
	assert_eq(shove.size(), 2, "H in F's place")
	assert_true(KeyBindings.same_input(shove[0], _key(KEY_H)), "the hints name it")
	assert_true(KeyBindings.same_input(shove[1], _click(MOUSE_BUTTON_LEFT)), "a click shoves")
	var brace := _key_events(&"brace")
	assert_eq(brace.size(), 2, "the middle button in the right's place")
	assert_true(KeyBindings.same_input(brace[0], _click(MOUSE_BUTTON_MIDDLE)))
	assert_true(KeyBindings.same_input(brace[1], _key(KEY_SHIFT)), "Shift braces")
	assert_eq(InputPrompts.word_for(InputMap.action_get_events(&"shove"), false), "H")


func test_an_alternate_another_action_is_given_leaves_it_without_a_swap() -> void:
	var keys := KeyBindings.new()
	assert_true(keys.bind(&"jump", _key(KEY_UP)))
	assert_false(keys.chosen.has(&"move_up"), "the arrow was not what forward showed")
	keys.apply()
	var forward := _key_events(&"move_up")
	assert_eq(forward.size(), 1, "W, the arrow gone to jump")
	assert_true(KeyBindings.same_input(forward[0], _key(KEY_W)))
	var up := _key(KEY_UP)
	up.pressed = true
	assert_true(up.is_action_pressed(&"jump"))
	assert_false(up.is_action_pressed(&"move_up"), "no key answers to two actions")

	assert_true(keys.bind(&"shove", _click(MOUSE_BUTTON_RIGHT)))
	keys.apply()
	var brace := _key_events(&"brace")
	assert_eq(brace.size(), 1, "Shift, the right click gone to shove")
	assert_true(KeyBindings.same_input(brace[0], _key(KEY_SHIFT)))


## An ESDF player's forward on E, or a brace on C, must not throw them out of the
## free camera once they are out: the spectate keys swap like any other (#257).
func test_a_play_key_never_answers_to_a_spectate_action_too() -> void:
	var keys := KeyBindings.new()
	assert_true(keys.bind(&"move_up", _key(KEY_E)))
	assert_true(keys.bind(&"brace", _key(KEY_C)))
	keys.apply()
	var e := _key(KEY_E)
	e.pressed = true
	assert_true(e.is_action_pressed(&"move_up"))
	assert_false(e.is_action_pressed(&"spectate_next"), "no key answers to two actions")
	var c := _key(KEY_C)
	c.pressed = true
	assert_true(c.is_action_pressed(&"brace"))
	assert_false(c.is_action_pressed(&"spectate_free"), "no key answers to two actions")
	var spectating := InputPrompts.pause_controls_for(false, true)
	assert_string_contains(spectating, "Q / W — switch view", "the next view took forward's W")
	assert_string_contains(spectating, "Shift — free camera", "the free camera took brace's")


func test_the_spectate_keys_rebind_and_swap_with_play() -> void:
	var keys := KeyBindings.new()
	assert_true(keys.bind(&"spectate_free", _key(KEY_SPACE)))
	assert_true(KeyBindings.same_input(keys.shown(&"jump"), _key(KEY_C)), "jump takes C")
	assert_true(keys.bind(&"spectate_previous", _key(KEY_Z)))
	assert_true(keys.bind(&"spectate_free", _key(KEY_LEFT)), "the free camera is not a replay's")
	assert_false(keys.chosen.has(&"move_left"), "the arrow was only an alternate")
	keys.apply()
	var left := _key(KEY_LEFT)
	left.pressed = true
	assert_true(left.is_action_pressed(&"spectate_free"))
	assert_false(left.is_action_pressed(&"move_left"), "no key answers to two actions")
	var z := _key(KEY_Z)
	z.pressed = true
	assert_true(z.is_action_pressed(&"spectate_previous"))
	assert_eq(_pad_events(&"spectate_free").size(), 1, "the pad's kept")


## A replay hears its own keys and Esc before the switches of view, which there
## switch the seat: a switch left on one could never be used, and its hint would lie.
func test_a_switch_of_view_never_takes_a_replay_s_key() -> void:
	var keys := KeyBindings.new()
	assert_false(keys.bind(&"spectate_previous", _key(KEY_LEFT)), "a step back")
	assert_false(keys.bind(&"spectate_next", _key(KEY_RIGHT)), "a step forward")
	assert_false(keys.bind(&"spectate_next", _key(KEY_SPACE)), "the replay's pause")
	assert_false(keys.bind(&"spectate_previous", _key(KEY_ESCAPE)), "Esc closes the replay")
	var typed := InputEventKey.new()
	typed.keycode = KEY_ESCAPE
	assert_false(keys.bind(&"spectate_next", typed), "Esc by what it types")
	assert_true(keys.chosen.is_empty(), "nothing moved")
	assert_true(keys.clashes_in_replays(&"spectate_previous", _key(KEY_LEFT)))
	assert_false(keys.clashes_in_replays(&"spectate_previous", _key(KEY_Z)))


## Nor by the swap: jump on E would hand the next view jump's Space — the replay's
## pause — and the pause on E would hand it Esc.
func test_no_swap_leaves_a_switch_of_view_on_a_replay_s_key() -> void:
	var keys := KeyBindings.new()
	assert_false(keys.bind(&"jump", _key(KEY_E)))
	assert_true(KeyBindings.same_input(keys.shown(&"spectate_next"), _key(KEY_E)))
	assert_true(KeyBindings.same_input(keys.shown(&"jump"), _key(KEY_SPACE)))
	assert_false(keys.bind(&"pause", _key(KEY_E)))
	assert_false(keys.bind(&"pause", _key(KEY_Q)))
	assert_true(keys.chosen.is_empty(), "nothing moved")

	assert_true(keys.bind(&"brace", _key(KEY_LEFT)), "a key of play may be a replay's")
	assert_false(keys.bind(&"brace", _key(KEY_Q)), "but not hand it to the previous view")
	assert_true(KeyBindings.same_input(keys.shown(&"spectate_previous"), _key(KEY_Q)))
	assert_true(keys.bind(&"brace", _key(KEY_C)), "the free camera takes it")
	assert_true(KeyBindings.same_input(keys.shown(&"spectate_free"), _key(KEY_LEFT)))


## A replay's orbit drags with the left button and pans with the middle: a switch of
## view on either would switch the seat at every drag.
func test_a_switch_of_view_never_takes_a_button_the_orbit_drags_with() -> void:
	var keys := KeyBindings.new()
	assert_false(keys.bind(&"spectate_next", _click(MOUSE_BUTTON_LEFT)), "the orbit's drag")
	assert_false(keys.bind(&"spectate_previous", _click(MOUSE_BUTTON_MIDDLE)), "the orbit's pan")
	assert_true(keys.chosen.is_empty(), "nothing moved")
	assert_true(keys.bind(&"spectate_next", _click(MOUSE_BUTTON_RIGHT)), "the right is no replay's")
	assert_false(keys.bind(&"shove", _click(MOUSE_BUTTON_RIGHT)), "nor by the swap")
	assert_true(KeyBindings.same_input(keys.shown(&"spectate_next"), _click(MOUSE_BUTTON_RIGHT)))


## Nor does a file edited by hand put one there: such an entry is left out, as one
## the settings screen could never have saved.
func test_a_file_never_puts_a_switch_of_view_on_a_replay_s_key() -> void:
	_write(
		(
			'{"spectate_next": {"keycode": 4194305}, "spectate_previous": {"mouse": 1},'
			+ ' "spectate_free": {"key": 4194319}}'
		)
	)
	var back := KeyBindings.read(PATH)
	assert_eq(back.chosen.keys(), [&"spectate_free"], "only the free camera may take a replay's")
	assert_eq(_unsound(back, "the file"), [] as Array[String])


## Whatever is bound to whatever, from the project's keys or from a seeded jumble of
## them: no key answers to two actions, and neither switch of view to a replay's key.
func test_no_bind_breaks_the_keys_of_play_or_of_replays() -> void:
	var tried: Array[InputEvent] = []
	for code: Key in [
		KEY_W,
		KEY_A,
		KEY_S,
		KEY_D,
		KEY_UP,
		KEY_DOWN,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_SPACE,
		KEY_ESCAPE,
		KEY_E,
		KEY_Q,
		KEY_C,
		KEY_F,
		KEY_R,
		KEY_J,
		KEY_Z,
		KEY_SHIFT,
		KEY_CTRL,
		KEY_TAB,
		KEY_COMMA,
		KEY_PERIOD,
		KEY_BRACKETLEFT,
		KEY_BRACKETRIGHT,
		KEY_HOME,
		KEY_END,
	]:
		tried.append(_key(code))
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		tried.append(_click(button))
	var jumbled := KeyBindings.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 257
	for step in 40:
		var action: StringName = KeyBindings.ACTIONS[rng.randi_range(
			0, KeyBindings.ACTIONS.size() - 1
		)]
		jumbled.bind(action, tried[rng.randi_range(0, tried.size() - 1)])
	assert_false(jumbled.chosen.is_empty(), "the jumble moved some")
	var unsound: Array[String] = []
	for start: KeyBindings in [KeyBindings.new(), jumbled]:
		unsound.append_array(_unsound(start, "the start"))
		for action: StringName in KeyBindings.ACTIONS:
			for key: InputEvent in tried:
				var keys := KeyBindings.new()
				keys.chosen.assign(start.chosen)
				keys.bind(action, key)
				unsound.append_array(_unsound(keys, "%s on %s" % [action, key.as_text()]))
	assert_eq(unsound, [] as Array[String])


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

	_write(
		(
			'[gd_resource type="Resource" format=3]\n'
			+ '[sub_resource type="GDScript" id="1"]\nscript/source = "extends Resource"\n'
			+ '[resource]\nscript = SubResource("1")\n'
		)
	)
	assert_true(KeyBindings.read(PATH).chosen.is_empty(), "a resource is never loaded")

	_write(
		(
			'{"jump": {"pad": 2}, "debug_nonsense": {"key": 75}, "shove": {"key": 71},'
			+ ' "brace": {"mouse": 4}, "pause": {"key": -1}, "move_up": {"key": 1e30},'
			+ ' "move_down": {"key": 83.5}, "move_left": "A", "move_right": {"key": 68, "mouse": 1}}'
		)
	)
	var back := KeyBindings.read(PATH)
	assert_eq(back.chosen.keys(), [&"shove"], "only a key or button of play is kept")
	assert_true(KeyBindings.same_input(back.chosen[&"shove"], _key(KEY_G)))

	_write("[1, 2]")
	assert_true(KeyBindings.read(PATH).chosen.is_empty(), "not an object")
	_write('{"jump": {"key": 74}}' + " ".repeat(KeyBindings.MAX_BYTES))
	assert_true(KeyBindings.read(PATH).chosen.is_empty(), "too long to be ours")


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

	var previous: Button = menu.get_node("%KeyRows").find_child(
		"Key_spectate_previous", false, false
	)
	previous.pressed.emit()
	var left := _key(KEY_LEFT)
	left.pressed = true
	menu._input(left)
	assert_eq(previous.text, SettingsMenu.REFUSED, "a replay's key is refused, and why said")
	var wheel := _click(MOUSE_BUTTON_WHEEL_UP)
	wheel.pressed = true
	menu._input(wheel)
	assert_eq(previous.text, "Press a key…", "a wheel's turn is no replay's")
	var z := _key(KEY_Z)
	z.pressed = true
	menu._input(z)
	assert_eq(previous.text, "Z", "still waiting, it takes the next")
	(menu.get_node("%ResetKeys") as Button).pressed.emit()
	assert_eq(jump.text, "Space")
	menu.close()
	assert_true(KeyBindings.read(PATH).chosen.is_empty())
	for path: String in [menu.audio_path, menu.view_path]:
		DirAccess.remove_absolute(path)


func test_the_keys_page_fits_its_panel() -> void:
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	menu.keys_path = PATH
	add_child(menu)
	var rows: Node = menu.get_node("%KeyRows")
	assert_not_null(rows.find_child("Key_spectate_free", false, false), "a row to spectate")
	var panel: Control = menu.get_node("Panel")
	var declared := Vector2(
		panel.offset_right - panel.offset_left, panel.offset_bottom - panel.offset_top
	)
	for page: int in SettingsMenu.Page.values():
		menu.open(page)
		await wait_process_frames(2)
		var needed := panel.get_combined_minimum_size()
		assert_lte(needed.x, declared.x, "page %d's width" % page)
		assert_lte(needed.y, declared.y, "page %d's height" % page)
	menu.open(SettingsMenu.Page.KEYS)
	menu._listen(&"spectate_previous")
	var left := _key(KEY_LEFT)
	left.pressed = true
	menu._input(left)
	await wait_process_frames(2)
	assert_lte(panel.get_combined_minimum_size().x, declared.x, "the refusal's width")
	menu.hide()


## Each key of [param keys] that answers to two actions, and each a switch of view
## holds that a replay hears first, said after [param why].
func _unsound(keys: KeyBindings, why: String) -> Array[String]:
	var found: Array[String] = []
	var held: Array[InputEvent] = []
	for action: StringName in KeyBindings.ACTIONS:
		for key: InputEvent in keys.keys_of(action):
			for other: InputEvent in held:
				if KeyBindings.same_input(key, other):
					found.append("%s: %s answers to two actions" % [why, key.as_text()])
			held.append(key)
			if action not in KeyBindings.IN_REPLAYS:
				continue
			for replay: InputEvent in KeyBindings.replay_keys():
				if KeyBindings.same_input(key, replay):
					found.append("%s: %s holds the replay's %s" % [why, action, key.as_text()])
	return found


func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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
