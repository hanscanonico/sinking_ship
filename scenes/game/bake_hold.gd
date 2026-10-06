class_name BakeHold
extends CanvasLayer
## The countdown held while a match's sinking is still being made (R20, §5b.4): its
## first number where the match's countdown shows it, in the HUD's style, with a bar
## under it and a line saying why — over the menu's backdrop, the ship at rest. It shows
## only once the bake has run past GRACE_SECONDS, so a bake that finishes sooner never
## flickers it up, and the match's countdown takes over in the same place.

## How long a bake runs before the hold shows.
const GRACE_SECONDS := 0.3
## The bar's size under the number, in pixels, and how far under the number's middle.
const BAR := Vector2(240.0, 6.0)
const BAR_BELOW := 22.0
## The countdown's look (the match's HUD): its size and outline.
const NUMBER_SIZE := 96
const NUMBER_OUTLINE := 12
const LINE_SIZE := 22
const LINE_OUTLINE := 6
const SAYS := "Her sinking is being worked out"

var _waited := 0.0
var _number := Label.new()
var _line := Label.new()
var _track := ColorRect.new()
var _fill := ColorRect.new()
## The room at the left the backdrop frames the ship beside.
var _beside := Control.new()


func _ready() -> void:
	UiTheme.apply_to(self)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_beside.anchor_right = 0.28
	_beside.anchor_bottom = 1.0
	_beside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_beside)
	# Where the HUD's countdown stands (match.tscn), so the match's takes over in place.
	_centre(_number, Rect2(-200.0, -160.0, 400.0, 120.0))
	_number.add_theme_font_size_override("font_size", NUMBER_SIZE)
	_number.add_theme_constant_override("outline_size", NUMBER_OUTLINE)
	_number.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	root.add_child(_number)
	_centre(_track, Rect2(-BAR.x * 0.5, BAR_BELOW - 40.0, BAR.x, BAR.y))
	_track.color = UiTheme.SCRIM
	root.add_child(_track)
	_fill.color = UiTheme.TRIM
	_fill.size = Vector2(0.0, BAR.y)
	_track.add_child(_fill)
	_centre(_line, Rect2(-420.0, BAR_BELOW - 28.0, 840.0, 40.0))
	_line.text = SAYS
	_line.add_theme_font_size_override("font_size", LINE_SIZE)
	_line.add_theme_constant_override("outline_size", LINE_OUTLINE)
	_line.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	root.add_child(_line)
	hide()


## Holds the countdown at [param seconds] — its first number — from now.
func begin(seconds: float) -> void:
	_waited = 0.0
	_number.text = str(ceili(seconds))
	_fill.size.x = 0.0
	hide()


## A frame of the hold, [param delta] seconds on, the bakes [param progress] of the way.
func advance(delta: float, progress: float) -> void:
	_waited += delta
	_fill.size.x = maxf(_fill.size.x, BAR.x * clampf(progress, 0.0, 1.0))
	visible = _waited >= GRACE_SECONDS


## The room at the left of the screen the backdrop frames the ship beside.
func beside() -> Control:
	return _beside


static func _centre(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control is Label:
		var label := control as Label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
