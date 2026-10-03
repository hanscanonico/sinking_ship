class_name InputFrame
extends RefCounted
## One seat's request for one tick (D3) — the only door into the sim.
##
## Quantized when created: move and aim are ship-plane (x toward the bow, z to
## starboard) integer vectors whose length never exceeds AXIS_MAX, so an offline
## match and the same match over a wire see bit-identical inputs. Buttons are held
## state; the sim derives presses from the previous tick's buttons.

const SHOVE := 1
const BRACE := 2
const RESERVED_3 := 4
const AXIS_MAX := 127

var seat: int
var tick: int
var move: Vector2i
var aim: Vector2i
var buttons: int


func _init(
	frame_seat: int = 0,
	frame_tick: int = 0,
	frame_move: Vector2i = Vector2i.ZERO,
	frame_buttons: int = 0,
	frame_aim: Vector2i = Vector2i.ZERO
) -> void:
	seat = frame_seat
	tick = frame_tick
	move = frame_move
	buttons = frame_buttons
	aim = frame_aim


## A ship-plane vector of length 0…1 (longer is clamped) as integer axes.
static func quantize(direction: Vector2) -> Vector2i:
	var unit := direction.limit_length(1.0)
	return clamp_axes(Vector2i(roundi(unit.x * AXIS_MAX), roundi(unit.y * AXIS_MAX)))


## Shortens an integer vector, one step at a time on its longer axis, until its
## length is at most AXIS_MAX — the same answer on every platform.
static func clamp_axes(axes: Vector2i) -> Vector2i:
	var clamped := Vector2i(
		clampi(axes.x, -AXIS_MAX, AXIS_MAX), clampi(axes.y, -AXIS_MAX, AXIS_MAX)
	)
	while clamped.length_squared() > AXIS_MAX * AXIS_MAX:
		if absi(clamped.x) >= absi(clamped.y):
			clamped.x -= signi(clamped.x)
		else:
			clamped.y -= signi(clamped.y)
	return clamped


## The one place a screen direction becomes a ship-plane move. [param stick] is
## screen-relative (x right, y down, as an input vector reads); [param camera_yaw]
## is the camera's rotation about the world's up axis. The ship never yaws, so
## this rotation is the whole conversion.
static func from_screen(stick: Vector2, camera_yaw: float) -> Vector2i:
	var right := Vector2(cos(camera_yaw), -sin(camera_yaw))
	var toward_camera := Vector2(sin(camera_yaw), cos(camera_yaw))
	return quantize(right * stick.x + toward_camera * stick.y)


## The move as a ship-plane vector of length 0…1.
func move_vector() -> Vector2:
	return Vector2(move) / AXIS_MAX


func is_held(button: int) -> bool:
	return buttons & button != 0


## The frame the sim acts on: axes clamped, nothing trusted (a frame is a request).
func validated(for_seat: int, for_tick: int) -> InputFrame:
	return InputFrame.new(for_seat, for_tick, clamp_axes(move), buttons, clamp_axes(aim))
