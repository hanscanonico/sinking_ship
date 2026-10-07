class_name LocalInputSource
extends InputSource
## The local player's seat: the input map read as held state, and the look the
## mouse and the right stick turn. The look is kept here unquantized, so the camera
## turns without lag, and quantized into each frame, whose move is relative to it
## (D3); the pitch never leaves this side (D14). Nothing past here knows a key, a
## mouse or a stick exists.

const PITCH_LIMIT_DEG := 80.0

## Radians in the plane of the face the seat stands on (Faces, D3), from its frame's x
## toward its z — on her decks, from the bow toward starboard — as the player turned it.
var yaw: float
## Radians above the horizon: presentation only, never in a frame.
var pitch: float
## Whether a menu over the match has the keys, the pad and the mouse: the seat stands
## still meanwhile — no move, no button, its look kept — and, once let go, no button
## still down from the menu acts until it has been let go too.
var held := false:
	set(value):
		if held and not value:
			_unreleased = _buttons()
		held = value

var _seat: int
var _settings: ViewSettings
## The buttons down as the hold ended, each until it is let go.
var _unreleased := 0


func _init(seat: int, start_yaw: float, settings: ViewSettings) -> void:
	_seat = seat
	yaw = start_yaw
	_settings = settings


## Turns the look by a mouse motion of [param pixels].
func look_by_mouse(pixels: Vector2) -> void:
	_turn(pixels * deg_to_rad(_settings.mouse_deg_per_pixel))


## Turns the look by the right stick, held for [param delta] seconds.
func look_by_stick(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_turn(stick * deg_to_rad(_settings.stick_deg_per_second) * delta)


func next_frame(tick: int) -> InputFrame:
	var look := InputFrame.quantize_yaw(yaw)
	var buttons := _buttons()
	if held:
		_unreleased = buttons
		return InputFrame.new(_seat, tick, Vector2i.ZERO, 0, look)
	_unreleased &= buttons
	buttons &= ~_unreleased
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return InputFrame.new(_seat, tick, InputFrame.from_screen(stick, look), buttons, look)


func _buttons() -> int:
	var buttons := InputFrame.SHOVE if Input.is_action_pressed("shove") else 0
	if Input.is_action_pressed("brace"):
		buttons |= InputFrame.BRACE
	if Input.is_action_pressed("jump"):
		buttons |= InputFrame.JUMP
	return buttons


## Carries the look from the plane of the faces of [param from] to those of [param to]
## (Faces.Up), the ship turned by [param ship_basis]: it looks the same way across the
## world, in the new face's plane — the one rotation the input source owes as the face
## changes (D3).
func turn_face(from: int, to: int, ship_basis: Basis) -> void:
	var across := ship_basis.orthonormalized()
	var world := across * Faces.to_ship(from) * Vector3(cos(yaw), 0.0, sin(yaw))
	var ahead := Faces.to_frame(to) * (across.transposed() * world)
	yaw = atan2(ahead.z, ahead.x)


## Right turns toward starboard when looking at the bow; down looks down unless
## invert-Y says otherwise.
func _turn(by: Vector2) -> void:
	yaw = wrapf(yaw + by.x, -PI, PI)
	var down := -by.y if _settings.invert_y else by.y
	var limit := deg_to_rad(PITCH_LIMIT_DEG)
	pitch = clampf(pitch - down, -limit, limit)
