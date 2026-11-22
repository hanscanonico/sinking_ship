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

## Between two hints on one line: a line break takes its place, so no line starts or
## ends on a dot (hint_text).
const SEPARATOR := "   \u00b7   "
## The controls and the words for them, in the order the hint line reads.
const HINTS: Array[Array] = [
	[&"replay_pause", "pause"],
	[&"replay_step_back", "step back"],
	[&"replay_step_forward", "step on"],
	[&"replay_speed_down", "slower"],
	[&"replay_speed_up", "faster"],
	[&"replay_seek_start", "to the start"],
	[&"replay_seek_end", "to the end"],
	[&"spectate_previous", "seat before"],
	[&"spectate_next", "seat after"],
	[&"spectate_free", "free camera"],
	[&"spectate_follow", "follow"],
	[&"spectate_ghost", "ghost"],
	[&"ui_cancel", "back"],
]
const PLATE_MARGIN := 12
## The context the catalogs know the play button's word under (Language.t): to play a
## replay on is not to play a match.
const ON_REPLAY: StringName = &"replay"

var _play: Button
var _speed: Label
var _bar: HSlider
var _clock: Label
var _seat: Label
var _camera: Label
var _hint: Label
## The hints the line was last laid out from, and the width it was laid out in.
var _hints := PackedStringArray()
var _laid_width := -1.0
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
	# Its lines are broken here, between hints (hint_text): it never asks for their width.
	_hint.clip_text = true
	_hint.resized.connect(_lay_out_hints)


## The replay's span: the seek bar runs from [param first_tick] to [param last_tick].
func setup(first_tick: int, last_tick: int) -> void:
	_last_tick = last_tick
	_bar.min_value = first_tick
	# A range of nothing has no ratio to draw: a bar of one tick at the least.
	_bar.max_value = maxi(last_tick, first_tick + 1)
	_bar.value = first_tick


## Shows where the replay stands: [param tick] of the span, [param paused] or playing
## at [param speed], seen through whose eyes ([param whose], as Hud.whose_view words
## it) from the [param camera] named, the keys worded by [param prompts].
func show_state(
	tick: int, paused: bool, speed: float, whose: String, camera: String, prompts: InputPrompts
) -> void:
	if not _dragging:
		_bar.set_value_no_signal(tick)
	_play.text = Language.t("Play", ON_REPLAY) if paused else "Pause"
	_speed.text = "%s×" % String.num(speed, 2)
	_clock.text = "%s / %s" % [MatchTranscript.clock(tick), MatchTranscript.clock(_last_tick)]
	_seat.text = "" if whose.is_empty() else whose[0].to_upper() + whose.substr(1)
	_camera.text = camera
	var said := hints(prompts)
	if said != _hints:
		_hints = said
		_laid_width = -1.0
		_lay_out_hints()


## The keys' hints, worded by [param prompts]: each its key and what it does. What the
## device has no key for is left out: "to the start" with nothing to press says nothing
## to a pad's player.
static func hints(prompts: InputPrompts) -> PackedStringArray:
	var words := PackedStringArray()
	for hint: Array in HINTS:
		var key := prompts.word(hint[0])
		if not key.is_empty():
			words.append("%s %s" % [key, Language.t(hint[1])])
	return words


## How hints [param widths] wide each go onto lines [param width] wide, in their order,
## with [param gap] between two on a line: how many each line takes, as many as fit. A
## hint wider than a line has one to itself.
static func lines_of(widths: PackedFloat32Array, gap: float, width: float) -> PackedInt32Array:
	var lines := PackedInt32Array()
	var taken := 0.0
	for wide: float in widths:
		if lines.is_empty() or taken + gap + wide > width:
			lines.append(1)
			taken = wide
		else:
			lines[-1] += 1
			taken += gap + wide
	return lines


## [param said], the hints, as the text of lines no wider than [param width] in
## [param font] at [param font_size]: a SEPARATOR between two hints on a line and a line
## break in its place between two lines, so no hint is broken and no line starts or ends
## on a dot.
static func hint_text(said: PackedStringArray, font: Font, font_size: int, width: float) -> String:
	var widths := PackedFloat32Array()
	for hint: String in said:
		widths.append(font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var gap := font.get_string_size(SEPARATOR, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lines := PackedStringArray()
	var from := 0
	for count: int in lines_of(widths, gap, width):
		lines.append(SEPARATOR.join(said.slice(from, from + count)))
		from += count
	return "\n".join(lines)


## Lays the hints out again in the width the line has now, once that or they have changed.
func _lay_out_hints() -> void:
	if _hint.size.x == _laid_width:
		return
	_laid_width = _hint.size.x
	var font := _hint.get_theme_font(&"font")
	_hint.text = hint_text(_hints, font, _hint.get_theme_font_size(&"font_size"), _laid_width)


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
