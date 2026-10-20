class_name ReplayHud
extends CanvasLayer
## The replay's controls (R4, #212), on a plate along the bottom of the view: play or
## pause, the speed, a seek bar the match clock reads over, whose eyes the view is in
## and which camera, and the keys for each on the device last used (InputPrompts). It
## asks the scene for everything through its signals and shows what the scene says
## (show_state): nothing of the replay is kept here.

signal pause_toggled
## One tick back (-1) or on (1), while paused.
signal step_requested(direction: int)
## Down (-1) or up (1) the speed ladder.
signal speed_requested(direction: int)
signal seek_requested(tick: int)
signal close_requested

## The controls and the words for them, in the order the hint line reads.
const HINTS: Array[Array] = [
	[&"replay_pause", "pause"],
	[&"replay_step_back", "step back"],
	[&"replay_step_forward", "step on"],
	[&"replay_speed_down", "slower"],
	[&"replay_speed_up", "faster"],
	[&"replay_seek_start", "to the start"],
	[&"replay_seek_end", "to the end"],
	[&"ui_cancel", "back"],
]
const PLATE_MARGIN := 12

var _play: Button
var _speed: Label
var _bar: HSlider
var _clock: Label
var _seat: Label
var _camera: Label
var _hint: Label
var _dragging := false
var _last_tick := 1


func _ready() -> void:
	UiTheme.apply_to(self)
	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_left = PLATE_MARGIN
	plate.offset_right = -PLATE_MARGIN
	plate.offset_bottom = -PLATE_MARGIN
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(plate)
	var box := VBoxContainer.new()
	plate.add_child(box)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", PLATE_MARGIN)
	box.add_child(controls)
	_play = Button.new()
	_play.text = "Pause"
	_play.custom_minimum_size.x = 90
	_play.focus_mode = Control.FOCUS_NONE
	_play.pressed.connect(pause_toggled.emit)
	controls.add_child(_play)
	_speed = _label(controls, "1×")
	_speed.custom_minimum_size.x = 48
	_bar = HSlider.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.step = 1.0
	_bar.focus_mode = Control.FOCUS_NONE
	_bar.drag_started.connect(func() -> void: _dragging = true)
	_bar.drag_ended.connect(_on_drag_ended)
	_bar.value_changed.connect(_on_bar_changed)
	controls.add_child(_bar)
	_clock = _label(controls, "00:00 / 00:00")
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", PLATE_MARGIN * 2)
	box.add_child(line)
	_seat = _label(line, "")
	_camera = _label(line, "")
	_hint = _label(box, "")
	_hint.theme_type_variation = UiTheme.HINT_LABEL
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 0


## The replay's span: the seek bar runs from [param first_tick] to [param last_tick].
func setup(first_tick: int, last_tick: int) -> void:
	_last_tick = last_tick
	_bar.min_value = first_tick
	_bar.max_value = last_tick
	_bar.value = first_tick


## Shows where the replay stands: [param tick] of the span, [param paused] or playing
## at [param speed], seen through whose eyes ([param whose], as Hud.whose_view words
## it) from the [param camera] named, the keys worded by [param prompts].
func show_state(
	tick: int, paused: bool, speed: float, whose: String, camera: String, prompts: InputPrompts
) -> void:
	if not _dragging:
		_bar.set_value_no_signal(tick)
	_play.text = "Play" if paused else "Pause"
	_speed.text = "%s×" % String.num(speed, 2).trim_suffix("0").trim_suffix(".")
	_clock.text = "%s / %s" % [MatchTranscript.clock(tick), MatchTranscript.clock(_last_tick)]
	_seat.text = "" if whose.is_empty() else whose[0].to_upper() + whose.substr(1)
	_camera.text = camera
	var words := PackedStringArray()
	for hint: Array in HINTS:
		words.append("%s %s" % [prompts.word(hint[0]), hint[1]])
	_hint.text = "   ·   ".join(words)


func _on_drag_ended(changed: bool) -> void:
	_dragging = false
	if changed:
		seek_requested.emit(int(_bar.value))


## A drag seeks as it goes; the keyboard moves the bar too, once it has focus.
func _on_bar_changed(value: float) -> void:
	if _dragging:
		seek_requested.emit(int(value))


func _label(into: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.HUD_LABEL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	into.add_child(label)
	return label
