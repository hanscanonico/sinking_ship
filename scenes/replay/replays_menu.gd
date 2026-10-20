class_name ReplaysMenu
extends CanvasLayer
## The saved replays (R6, #214), newest first, on a plate over the menu's backdrop:
## when each was played, its ship, seed, seats, length and who won (ReplayListing),
## with Watch and Delete for each — one that can no longer be played greyed, with
## the reason — and Back. Watch hands the ReplayFile on; nothing of it plays here.

signal watch_requested(file: ReplayFile)
signal back_requested

const PLATE_SIZE := Vector2(760, 400)
## The plate's inset from the bottom-left corner, as the menu's own plate stands.
const PLATE_INSET := Vector2(64, 48)
const ROW_GAP := 6

var _store: ReplayStore
var _match_rules: MatchRules
var _panel: PanelContainer
var _rows: VBoxContainer
var _empty: Label
var _back: Button


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	# Where the menu's own plate stands: off the bottom-left corner, growing upward.
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
	title.text = "Replays"
	title.theme_type_variation = UiTheme.TITLE
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(_rows)
	_empty = Label.new()
	_empty.text = "No replays yet: every match played here is kept, the newest 20."
	_empty.theme_type_variation = UiTheme.HINT_LABEL
	box.add_child(_empty)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 120
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(back_requested.emit)
	box.add_child(_back)


## The plate, for the backdrop to frame the ship beside.
func panel() -> Control:
	return _panel


## Lists what [param store] holds, each judged under [param match_rules].
func open(store: ReplayStore, match_rules: MatchRules) -> void:
	_store = store
	_match_rules = match_rules
	_refresh()
	show()
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var paths := _store.list()
	for path in paths:
		var file := _store.load_file(path)
		var reason := ReplayListing.reason(file, _match_rules)
		_add_row(path, file, reason)
	_empty.visible = paths.is_empty()


func _add_row(path: String, file: ReplayFile, reason: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_rows.add_child(row)
	var colour := UiTheme.TEXT if reason.is_empty() else UiTheme.MUTED
	var when := Label.new()
	when.text = _when(file, path)
	when.add_theme_color_override("font_color", colour)
	row.add_child(when)
	var what := Label.new()
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.text = _what(file, reason)
	what.add_theme_color_override("font_color", colour)
	what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(what)
	var watch := Button.new()
	watch.text = "Watch"
	watch.disabled = not reason.is_empty()
	watch.pressed.connect(func() -> void: watch_requested.emit(file))
	row.add_child(watch)
	var delete := Button.new()
	delete.text = "Delete"
	delete.pressed.connect(_on_delete.bind(delete, path))
	row.add_child(delete)


## When [param file] was recorded, in local time — or the file's name when it cannot
## be read.
func _when(file: ReplayFile, path: String) -> String:
	if file == null:
		return path.get_file().get_basename()
	var bias_minutes: int = Time.get_time_zone_from_system()["bias"]
	return Time.get_datetime_string_from_unix_time(file.recorded_at + bias_minutes * 60, true)


static func _what(file: ReplayFile, reason: String) -> String:
	if file == null:
		return reason[0].to_upper() + reason.substr(1)
	var row := ReplayListing.row(file, reason)
	var words := (
		"%s · %s · %s · %s · %s"
		% [row["ship"], row["seed"], row["seats"], row["length"], row["winner"]]
	)
	return words if reason.is_empty() else "%s — %s" % [words, reason]


## Delete asks once: the first press arms it, the second deletes.
func _on_delete(button: Button, path: String) -> void:
	if button.text != "Sure?":
		button.text = "Sure?"
		return
	_store.delete(path)
	_refresh()
