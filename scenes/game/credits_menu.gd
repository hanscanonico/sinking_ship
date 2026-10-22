class_name CreditsMenu
extends CanvasLayer
## The credits, on a plate over the menu's backdrop as the replays stand: the game's
## name, the asset register (assets/LICENSES.md, packed into every export by its
## include filter) as plain text, then the engine's licence and the notices of the
## third-party code built into it, as Godot asks a game to carry them. Back, or Esc,
## returns to the menu; up and down scroll it from the Back button.

signal back_requested

const NAME := "Last One Dry"
const LICENSES := "res://assets/LICENSES.md"
const PLATE_SIZE := Vector2(760, 480)
## The plate's inset from the bottom-left corner, as the menu's own plate stands.
const PLATE_INSET := Vector2(64, 48)
## How far one press of up or down scrolls, in pixels.
const SCROLL_STEP := 48.0

var _panel: PanelContainer
var _text: RichTextLabel
var _back: Button


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = PLATE_INSET.x
	_panel.offset_top = -PLATE_INSET.y
	_panel.offset_bottom = -PLATE_INSET.y
	_panel.offset_right = PLATE_INSET.x + PLATE_SIZE.x
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = PLATE_SIZE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Credits"
	title.theme_type_variation = UiTheme.TITLE
	box.add_child(title)
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = false
	_text.selection_enabled = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color", UiTheme.TEXT)
	_text.text = text()
	box.add_child(_text)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 120
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(back_requested.emit)
	_back.gui_input.connect(_scroll_from_back)
	box.add_child(_back)


## The plate, for the backdrop to frame the ship beside.
func panel() -> Control:
	return _panel


func open() -> void:
	_text.scroll_to_line(0)
	show()
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


## Up and down on Back scroll the credits — there is nothing else on the plate to
## move to — so a pad reads them all without leaving the button.
func _scroll_from_back(event: InputEvent) -> void:
	var step := 0.0
	if event.is_action_pressed("ui_up", true):
		step = -SCROLL_STEP
	elif event.is_action_pressed("ui_down", true):
		step = SCROLL_STEP
	else:
		return
	var bar := _text.get_v_scroll_bar()
	bar.value += step
	_back.accept_event()


## Everything the plate shows, as plain text.
static func text() -> String:
	var parts := PackedStringArray([NAME, ""])
	parts.append(plain(FileAccess.get_file_as_string(LICENSES)))
	parts.append("")
	parts.append("Godot Engine")
	parts.append("")
	parts.append("This game uses Godot Engine, available under the following license:")
	parts.append("")
	parts.append(Engine.get_license_text())
	parts.append("")
	parts.append(engine_notices())
	return "\n".join(parts)


## The third-party code built into the engine: each component with its copyright
## holders and licence, then each licence's text once.
static func engine_notices() -> String:
	var lines := PackedStringArray(["Third-party components of Godot Engine", ""])
	for component: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in component["parts"]:
			lines.append("%s — %s" % [component["name"], part["license"]])
			for holder: String in part["copyright"]:
				lines.append("  © %s" % holder)
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for license: String in names:
		lines.append("")
		lines.append(license)
		lines.append("")
		lines.append(String(licenses[license]).strip_edges())
	return "\n".join(lines)


## [param markdown] as plain text: headings without their marks, a table's rows as
## their cells joined by dashes and its rule dropped, code and emphasis marks dropped.
static func plain(markdown: String) -> String:
	var lines := PackedStringArray()
	var rule := RegEx.create_from_string("^\\|(\\s*:?-+:?\\s*\\|)+\\s*$")
	for line: String in markdown.split("\n"):
		line = line.strip_edges(false, true)
		if rule.search(line) != null:
			continue
		if line.begins_with("#"):
			line = line.lstrip("#").strip_edges()
		elif line.begins_with("|") and line.ends_with("|"):
			var cells := PackedStringArray()
			for cell: String in line.substr(1, line.length() - 2).split("|"):
				cells.append(cell.strip_edges())
			line = " — ".join(cells)
		lines.append(line.replace("`", "").replace("**", "").replace("*", ""))
	return "\n".join(lines).strip_edges()
