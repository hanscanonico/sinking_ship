extends GutTest
## One theme for every screen (art pass III): each kind of control the menus offer
## shows where the keys' or the pad's focus is — a ring, or a slider's lit grabber —
## a disabled control looks it, and a button waiting out a press guard — the
## results' — still reads as a button. The online screens (SH12) are made of the same
## kinds, and the pad's directions alone reach every control on them.

const RINGED: Array[String] = ["Button", "OptionButton", "LineEdit", "CheckButton"]
const FOCUSABLE: Array[String] = ["Button", "OptionButton", "LineEdit", "CheckButton", "HSlider"]
const ONLINE_SCREENS: Array[String] = [
	"res://scenes/online/online_menu.tscn",
	"res://scenes/online/room_screen.tscn",
	"res://scenes/online/online_pause.tscn",
]
const SIDES: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]


func test_every_focusable_kind_shows_its_focus() -> void:
	var theme := UiTheme.shared()
	for type: String in RINGED:
		var focus := theme.get_stylebox("focus", type) as StyleBoxFlat
		assert_not_null(focus, "%s has a focus ring" % type)
		if focus != null:
			assert_gt(focus.border_width_top, 0, "%s: a ring that shows" % type)
			assert_gt(focus.border_color.a, 0.5, "%s: and is not faint" % type)
	assert_ne(
		theme.get_icon("grabber_highlight", "HSlider"),
		theme.get_icon("grabber", "HSlider"),
		"a slider with the focus lights its grabber"
	)
	assert_ne(
		theme.get_stylebox("grabber_area_highlight", "HSlider"),
		theme.get_stylebox("grabber_area", "HSlider"),
		"and its fill"
	)


func test_a_disabled_control_looks_disabled() -> void:
	var theme := UiTheme.shared()
	for type: String in ["Button", "OptionButton"]:
		var disabled := theme.get_stylebox("disabled", type) as StyleBoxFlat
		var normal := theme.get_stylebox("normal", type) as StyleBoxFlat
		assert_ne(disabled, normal, "%s: not the plate of a live one" % type)
		assert_lt(disabled.bg_color.a, normal.bg_color.a, "%s: no teak to press" % type)
		var faint := theme.get_color("font_disabled_color", type).a
		assert_lt(faint, theme.get_color("font_color", type).a * 0.5, "%s: faint type" % type)
	assert_eq(
		theme.get_constant("modulate_arrow", "OptionButton"),
		1,
		"a choice's arrow fades with its type"
	)


func test_a_guarded_button_reads_as_a_button() -> void:
	var theme := UiTheme.shared()
	assert_eq(theme.get_type_variation_base(UiTheme.GUARDED_BUTTON), &"Button")
	assert_eq(
		theme.get_stylebox("disabled", UiTheme.GUARDED_BUTTON),
		theme.get_stylebox("normal", "Button"),
		"the plate of a live button"
	)
	assert_gt(theme.get_color("font_disabled_color", UiTheme.GUARDED_BUTTON).a, 0.7, "legible")
	var guarded := PackedStringArray()
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).get_state()
	for node in scene.get_node_count():
		for property in scene.get_node_property_count(node):
			if scene.get_node_property_name(node, property) != &"theme_type_variation":
				continue
			if scene.get_node_property_value(node, property) == UiTheme.GUARDED_BUTTON:
				guarded.append(scene.get_node_name(node))
	assert_eq(guarded, PackedStringArray(["Rematch", "Menu"]), "the results' two buttons")


func test_the_menus_controls_are_all_in_the_theme() -> void:
	var game: Node = autofree(load("res://scenes/game/game.tscn").instantiate())
	var kinds := {}
	for control: Node in game.find_children("*", "Control"):
		if (control as Control).focus_mode != Control.FOCUS_NONE:
			kinds[control.get_class()] = true
	assert_false(kinds.is_empty(), "the menus offer controls")
	for kind: String in kinds:
		assert_true(kind in FOCUSABLE, "%s is a kind the theme styles" % kind)


## Every focusable control on [param layer] that is showing and can be pressed or typed in.
static func _offered(layer: CanvasLayer) -> Array[Control]:
	var offered: Array[Control] = []
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		offered.append(control)
	return offered


## [param screen] opened as a player first sees it: the Online screen, a room its
## player hosts, the online pause.
func _opened(screen: String) -> CanvasLayer:
	var layer: CanvasLayer = load(screen).instantiate()
	if layer is OnlineMenu:
		(layer as OnlineMenu).settings_path = "user://test_ui_online_settings.json"
	if layer is RoomScreen:
		(layer as RoomScreen).seats = 8
	add_child_autofree(layer)
	if layer is OnlineMenu:
		(layer as OnlineMenu).open()
	elif layer is RoomScreen:
		var roster := RoomRoster.new()
		roster.code = "KXRT"
		roster.you = 0
		roster.players.append(RoomRoster.Player.new("Ada", true, false))
		(layer as RoomScreen).show_room(roster)
	else:
		(layer as OnlinePause).open()
	return layer


func test_the_online_screens_controls_are_all_in_the_theme() -> void:
	for screen: String in ONLINE_SCREENS:
		var layer := _opened(screen)
		var offered := _offered(layer)
		assert_false(offered.is_empty(), "%s offers controls" % screen)
		for control: Control in offered:
			assert_true(
				control.get_class() in FOCUSABLE,
				(
					"%s: %s is a %s, a kind the theme styles"
					% [screen, control.name, control.get_class()]
				)
			)
			assert_eq(
				control.get_theme_stylebox(&"focus"),
				UiTheme.shared().get_stylebox(&"focus", control.get_class()),
				"%s: %s shows its focus as the theme does" % [screen, control.name]
			)


## From where the focus starts, the pad's four directions reach every control a screen
## offers.
func test_every_online_control_is_reachable_with_a_pad() -> void:
	for screen: String in ONLINE_SCREENS:
		var layer := _opened(screen)
		await wait_process_frames(2)
		var start := get_viewport().gui_get_focus_owner()
		assert_not_null(start, "%s gives the focus somewhere" % screen)
		if start == null:
			continue
		var reached := {start: true}
		var waiting: Array[Control] = [start]
		while not waiting.is_empty():
			var from: Control = waiting.pop_back()
			for side: Side in SIDES:
				var next := from.find_valid_focus_neighbor(side)
				if next != null and not reached.has(next):
					reached[next] = true
					waiting.append(next)
		for control: Control in _offered(layer):
			assert_true(reached.has(control), "%s: %s is reached" % [screen, control.name])
