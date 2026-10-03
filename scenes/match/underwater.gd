class_name Underwater
extends CanvasLayer
## The view from under the sea (SH5): while the eye is below the sea plane — a dunk,
## a wave of the list, the plunge — a blue tint over the view and the fog drawn in
## close. Presentation only (D12): it reads where the eye is drawn and nothing else.
## is_under() is the one answer anything else that changes under the sea asks.

const TINT := Color(0.04, 0.22, 0.36, 0.55)
const FOG := Color(0.03, 0.17, 0.26)
## How far the fog lets the eye see under the sea, in metres.
const FOG_END := 7.0

var _world: WorldEnvironment
var _above: Environment
var _below: Environment
var _tint: ColorRect
var _under := false


func _ready() -> void:
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.color = TINT
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.hide()
	add_child(_tint)


## Takes over [param world]'s environment: a copy of it above the sea, and one with
## the fog closed in below it.
func setup(world: WorldEnvironment) -> void:
	_world = world
	_above = world.environment.duplicate()
	_below = _above.duplicate()
	_below.fog_enabled = true
	_below.fog_light_color = FOG
	_below.fog_depth_begin = 0.0
	_below.fog_depth_end = FOG_END
	_below.fog_density = 1.0
	_below.fog_aerial_perspective = 0.0
	_below.fog_sky_affect = 1.0
	_world.environment = _above
	_under = false
	_tint.hide()


## Under the sea or not, by the eye at [param eye] in the world: the sea is the
## world plane y = 0.
func show_eye(eye: Vector3) -> void:
	var under := eye.y < 0.0
	if under == _under:
		return
	_under = under
	_tint.visible = under
	_world.environment = _below if under else _above


## Whether the eye is under the sea.
func is_under() -> bool:
	return _under
