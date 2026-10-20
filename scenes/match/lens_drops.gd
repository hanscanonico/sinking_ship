class_name LensDrops
extends CanvasLayer
## The water running off the lens once the eye comes up out of it: for a moment after
## it surfaces, a dozen drops and their short streaks slide down the view, each
## bending what is behind it (lens_drops.gdshader), and dry off over DRY_SECONDS.
## Nothing is drawn under the water — the view there is Underwater's alone — nor once
## the lens is dry. Presentation only (D12): it reads whether Underwater has the eye
## under (Underwater.is_under) frame by frame, and nothing else.

const OVERLAY := preload("res://scenes/match/lens_drops.gdshader")
## How many seconds after surfacing the last of the water is gone off the lens.
const DRY_SECONDS := 2.5

var _drops: ColorRect
var _overlay: ShaderMaterial
## Seconds since the eye last came up out of the water; DRY_SECONDS or more, dry.
var _since := DRY_SECONDS
var _under := false
## Whether a capture holds the lens at _since (--capture-wet), the frame never drying.
var _held := false


## How wet the lens is, 1 to 0, [param seconds_since_surfacing] after the eye came up:
## all of it at once, eased away to none at DRY_SECONDS.
static func wetness(seconds_since_surfacing: float) -> float:
	return 1.0 - smoothstep(0.0, DRY_SECONDS, seconds_since_surfacing)


func _ready() -> void:
	name = "LensDrops"
	# On Underwater's layer (match.tscn), over it as a later sibling, and under the
	# HUD's layer 1: the drops sit on the lens, not on the HUD.
	layer = 0
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	_drops = ColorRect.new()
	_drops.name = "Drops"
	_drops.material = _overlay
	_drops.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drops)
	_show()


## The eye [param under] the water or not, this frame: coming up out of it wets the
## lens afresh; going under dries it at once.
func show_eye(under: bool) -> void:
	if under == _under:
		return
	_under = under
	if not under and not _held:
		_since = 0.0
	_show()


## Holds the lens as it is [param seconds] after surfacing, never drying (a capture's
## --capture-wet, there being no surfacing in a still shot).
func hold_wet(seconds: float) -> void:
	_held = true
	_since = seconds
	_show()


## Whether any water is drawn on the lens.
func is_wet() -> bool:
	return _drops.visible


func _process(delta: float) -> void:
	if _held or _under or _since >= DRY_SECONDS:
		return
	_since += delta
	_show()


func _show() -> void:
	var wet := 0.0 if _under else wetness(_since)
	_drops.visible = wet > 0.0
	if _drops.visible:
		_overlay.set_shader_parameter(&"wet", wet)
		_overlay.set_shader_parameter(&"since", _since)
