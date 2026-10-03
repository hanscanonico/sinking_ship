class_name InputFrame
extends RefCounted
## One seat's request for one tick (D3) — the only door into the sim.
##
## Quantized when created: move is a ship-plane (x toward the bow, z to starboard)
## integer vector whose length never exceeds AXIS_MAX, and look_yaw the facing the
## seat chooses, in YAW_STEPS to one turn from the bow toward starboard — so an
## offline match and the same match over a wire see bit-identical inputs. Buttons
## are held state; the sim derives presses from the previous tick's buttons. Pitch
## is never here: no rule reads it (D14).

## Held; a tap or a charge is the sim's call, from how many ticks it is held.
const SHOVE := 1
## Held; the seat braces for as long as it is.
const BRACE := 2
const RESERVED_3 := 4
const AXIS_MAX := 127
const YAW_STEPS := 65536

var seat: int
var tick: int
var move: Vector2i
var look_yaw: int
var buttons: int


func _init(
	frame_seat: int = 0,
	frame_tick: int = 0,
	frame_move: Vector2i = Vector2i.ZERO,
	frame_buttons: int = 0,
	frame_look_yaw: int = 0
) -> void:
	seat = frame_seat
	tick = frame_tick
	move = frame_move
	buttons = frame_buttons
	look_yaw = frame_look_yaw


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


## A ship-plane angle in radians (from the bow toward starboard) as a look yaw.
static func quantize_yaw(angle: float) -> int:
	return posmod(roundi(angle / TAU * YAW_STEPS), YAW_STEPS)


## [param yaw] as a ship-plane angle in radians, within -PI…PI.
static func yaw_angle(yaw: int) -> float:
	var steps := posmod(yaw, YAW_STEPS)
	if steps * 2 >= YAW_STEPS:
		steps -= YAW_STEPS
	return steps * TAU / YAW_STEPS


## The one place a stick becomes a ship-plane move. [param stick] is screen-relative
## (x right, y down, as an input vector reads) and [param yaw] the look it is
## relative to, already quantized so both ends of a wire turn it alike: stick up
## walks where you look. The ship never yaws, so this rotation is the whole
## conversion.
static func from_screen(stick: Vector2, yaw: int) -> Vector2i:
	var ahead := Vector2.from_angle(yaw_angle(yaw))
	var right := Vector2(-ahead.y, ahead.x)
	return quantize(right * stick.x - ahead * stick.y)


## The move as a ship-plane vector of length 0…1.
func move_vector() -> Vector2:
	return Vector2(move) / AXIS_MAX


func is_held(button: int) -> bool:
	return buttons & button != 0


## The frame the sim acts on: axes clamped, the look wrapped into one turn, nothing
## trusted (a frame is a request).
func validated(for_seat: int, for_tick: int) -> InputFrame:
	return InputFrame.new(
		for_seat, for_tick, clamp_axes(move), buttons, posmod(look_yaw, YAW_STEPS)
	)
