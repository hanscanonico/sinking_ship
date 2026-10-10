class_name ObserverCamera
extends Node3D
## The observer camera — a tool, not a feature (D14): SH1's elevated fixed-yaw rig,
## looking across the beam, never rolling with the ship, so the world stays level
## and the deck visibly tilts. Captures, QA (--observer) and the arena tools use
## it; no menu reaches it. Which side it watches from is this setting and nothing
## else.

enum Beam { STARBOARD, PORT }

## A hull longer than this many times the rig's distance is framed whole (SH34): the
## rig watches her middle from far enough back that her length fills its view, this
## share of her length away.
const LONG_HULL := 3.0
const LONG_HULL_DISTANCE := 0.8

@export var side: Beam = Beam.STARBOARD
@export var pitch_deg: float = 50.0
@export var distance: float = 24.0
## How quickly the rig closes on its target, per second.
@export var follow_rate: float = 4.0
## Whether the rig watches the middle of the decks rather than the target it is
## handed: the cut-away's framing, which shows every room at once.
var whole_ship := false

## The ship-plane box the rig's target stays inside.
var _bounds := Rect2()

@onready var _camera: Camera3D = $Camera3D


## The camera's rotation about the world's up axis.
func yaw() -> float:
	return 0.0 if side == Beam.STARBOARD else PI


func make_current() -> void:
	_camera.make_current()


## Snaps to [param target], to be followed inside [param bounds] (world x/z).
func reset(target: Vector3, bounds: Rect2) -> void:
	_bounds = bounds
	rotation = Vector3(-deg_to_rad(pitch_deg), yaw(), 0.0)
	var long_hull := bounds.size.x > distance * LONG_HULL
	_camera.position = Vector3(
		0.0, 0.0, bounds.size.x * LONG_HULL_DISTANCE if long_hull else distance
	)
	whole_ship = whole_ship or long_hull
	position = _aim(target)


func follow(target: Vector3, delta: float) -> void:
	position = position.lerp(_aim(target), clampf(follow_rate * delta, 0.0, 1.0))


## [param target] held inside the bounds, or their middle while it watches the whole
## ship.
func _aim(target: Vector3) -> Vector3:
	if whole_ship:
		var middle := _bounds.get_center()
		return Vector3(middle.x, 0.0, middle.y)
	return Vector3(
		clampf(target.x, _bounds.position.x, _bounds.end.x),
		maxf(target.y, 0.0),
		clampf(target.z, _bounds.position.y, _bounds.end.y)
	)
