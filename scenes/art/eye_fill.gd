class_name EyeFill
extends OmniLight3D
## The little light the eye's own sight lends a room whose lamps have failed (SH31):
## a faint, cool, shadowless glow round the eye that draws the frame, so the walls,
## the doorways, the stairs and the water of a dark room still read while it stays
## dark. An indoor face keeps only a share of the dusk's dim ambient (ship.gdshaderinc's
## indoor_ambient), and the lamps were what lit a room: without them it went near
## black. It comes up as what powers the eye's cell goes — some on her emergency
## power, whose red lamps still burn, all of it on nothing — fading in and out as a
## lamp does, never under the water (Underwater draws that view), and lights no
## outdoor face, as a lamp lights none. Presentation only: it reads what lights the
## eye's cell off the pose (ShipPose.lit_at, D5), nothing else.

## How bright the fill burns at its fullest, how far it reaches, and how gently it
## falls off toward its reach (OmniLight3D.omni_attenuation): flat enough that the
## wall before the eye is not a glare and the far side of the room still reads.
const ENERGY := 0.32
const RANGE := 6.5
const ATTENUATION := 0.35
## Its share on her emergency power, whose dim red lamps still light the room some.
const EMERGENCY_SHARE := 0.5
## How many seconds it takes to come up or go down.
const FADE := 0.8

## Its share now (0…1), and the share it is coming to.
var _share := 0.0
var _target := 0.0


func _ready() -> void:
	name = "EyeFill"
	light_color = ArtPalette.EYE_FILL
	light_energy = 0.0
	light_specular = 0.0
	omni_range = RANGE
	omni_attenuation = ATTENUATION
	shadow_enabled = false
	light_cull_mask &= ~(1 << (ShipMesh.OUTDOOR_LAYER - 1))
	visible = false


## How much of its light the fill lends, 0…1, an eye whose cell [param power]
## (ShipPower.Power) lights — none on her generator or outside her, EMERGENCY_SHARE
## on her emergency power, all of it on nothing — and none under the water
## ([param under]).
static func share(power: int, under: bool) -> float:
	if under:
		return 0.0
	match power:
		ShipPower.Power.DARK:
			return 1.0
		ShipPower.Power.EMERGENCY:
			return EMERGENCY_SHARE
	return 0.0


## [param from] stepped [param delta] seconds toward [param to], a whole share taking
## FADE seconds.
static func faded(from: float, to: float, delta: float) -> float:
	return move_toward(from, to, delta / FADE)


## Stands the fill at [param eye], in the world, lit as an eye whose cell
## [param power] lights, [param under] the water or not.
func show_eye(eye: Vector3, power: int, under: bool) -> void:
	global_position = eye
	_target = share(power, under)
	# Under the water it goes out at once: the view there is Underwater's alone.
	if under and _share > 0.0:
		_share = 0.0
		light_energy = 0.0
		visible = false


func _process(delta: float) -> void:
	if _share == _target:
		return
	_share = faded(_share, _target, delta)
	# Eased, so it neither snaps on nor off.
	light_energy = ENERGY * smoothstep(0.0, 1.0, _share)
	visible = _share > 0.0
