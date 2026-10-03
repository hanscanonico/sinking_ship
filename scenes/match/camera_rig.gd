class_name CameraRig
extends Node3D
## §7's fixed-yaw follow camera: elevated, looking across the beam, never rolling
## with the ship, so the world stays level and the deck visibly tilts. Which side
## it watches from is this setting and nothing else; inputs follow its yaw (D3).

enum Beam { STARBOARD, PORT }

@export var side: Beam = Beam.STARBOARD
@export var pitch_deg: float = 50.0
@export var distance: float = 24.0
## How quickly the rig closes on its target, per second.
@export var follow_rate: float = 4.0

## The ship-plane box the rig's target stays inside.
var _bounds := Rect2()

@onready var _camera: Camera3D = $Camera3D


## The camera's rotation about the world's up axis — what InputFrame.from_screen
## turns a screen direction by.
func yaw() -> float:
	return 0.0 if side == Beam.STARBOARD else PI


## Snaps to [param target], to be followed inside [param bounds] (world x/z).
func reset(target: Vector3, bounds: Rect2) -> void:
	_bounds = bounds
	rotation = Vector3(-deg_to_rad(pitch_deg), yaw(), 0.0)
	_camera.position = Vector3(0.0, 0.0, distance)
	position = _clamped(target)


func follow(target: Vector3, delta: float) -> void:
	position = position.lerp(_clamped(target), clampf(follow_rate * delta, 0.0, 1.0))


func _clamped(target: Vector3) -> Vector3:
	return Vector3(
		clampf(target.x, _bounds.position.x, _bounds.end.x),
		maxf(target.y, 0.0),
		clampf(target.z, _bounds.position.y, _bounds.end.y)
	)
