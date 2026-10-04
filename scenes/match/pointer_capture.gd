class_name PointerCapture
extends CanvasLayer
## The local player's hold on the mouse in a match: held while their look turns with it,
## let go otherwise. A browser grants it only in answer to a click — asked at any other
## time it refuses, and the engine logs an error for every frame it is asked — so there
## it is asked for at a click alone, and "Click to play" shows until it is held. The
## browser lets go of it itself at the player's first Esc, which this never hears.

## The browser let go of the mouse while it was held and wanted: its Esc.
signal lost

const HINT := "Click to play"
const HINT_FONT_SIZE := 28
## How far under the middle of the screen the hint sits, clear of the crosshair.
const HINT_DROP := 70.0

## Whether the mouse is asked for at a click alone: in a browser.
var click_to_capture := OS.has_feature("web")
## Where the mouse mode is read and set: Input, or a test's stand-in with a mouse_mode.
var device: Object = Input

var _wanted := false
## Whether the mouse was held when last wanted.
var _held := false
var _hint := Label.new()


func _ready() -> void:
	_hint.text = HINT
	_hint.theme_type_variation = UiTheme.HUD_LABEL
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y += HINT_DROP
	_hint.hide()
	add_child(_hint)
	UiTheme.apply_to(self)


## Holds the mouse while [param wanted] — in a browser, from the next click — and lets
## it go otherwise.
func want(wanted: bool) -> void:
	_wanted = wanted
	var mode := Input.MOUSE_MODE_CAPTURED if wanted else Input.MOUSE_MODE_VISIBLE
	if _mode() != mode and not (wanted and click_to_capture):
		device.set(&"mouse_mode", mode)
	var held := _mode() == Input.MOUSE_MODE_CAPTURED
	_hint.visible = wanted and not held
	var was_held := _held
	_held = wanted and held
	if wanted and was_held and not held:
		lost.emit()


## Whether a browser shows "Click to play": the mouse wanted and not yet held, and the
## keys, the pad and the mouse not yet the match's.
func waiting() -> bool:
	return click_to_capture and _hint.visible


func _unhandled_input(event: InputEvent) -> void:
	if not click_to_capture or not _wanted or _mode() == Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		device.set(&"mouse_mode", Input.MOUSE_MODE_CAPTURED)
		_hint.visible = _mode() != Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _mode() -> Input.MouseMode:
	return device.get(&"mouse_mode")
