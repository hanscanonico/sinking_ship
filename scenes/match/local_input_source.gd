class_name LocalInputSource
extends InputSource
## The local player's seat: the input map read as held state, and the look the
## mouse and the right stick turn. The look is kept here unquantized, so the camera
## turns without lag, and quantized into each frame, whose move is relative to it
## (D3); the pitch never leaves this side (D14). Nothing past here knows a key, a
## mouse or a stick exists.

const PITCH_LIMIT_DEG := 80.0

## Ship-plane radians from the bow toward starboard, as the player turned it.
var yaw: float
## Radians above the horizon: presentation only, never in a frame.
var pitch: float

var _seat: int
var _settings: ViewSettings


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
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var buttons := InputFrame.SHOVE if Input.is_action_pressed("shove") else 0
	var look := InputFrame.quantize_yaw(yaw)
	return InputFrame.new(_seat, tick, InputFrame.from_screen(stick, look), buttons, look)


## Right turns toward starboard when looking at the bow; down looks down unless
## invert-Y says otherwise.
func _turn(by: Vector2) -> void:
	yaw = wrapf(yaw + by.x, -PI, PI)
	var down := -by.y if _settings.invert_y else by.y
	var limit := deg_to_rad(PITCH_LIMIT_DEG)
	pitch = clampf(pitch - down, -limit, limit)
