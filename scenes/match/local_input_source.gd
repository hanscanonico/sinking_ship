class_name LocalInputSource
extends InputSource
## The local player's seat: the input map read as held state, the stick turned
## from screen to ship plane by the camera rig's yaw (D3). Nothing past here knows
## a key or a stick exists.

var _seat: int
var _rig: CameraRig


func _init(seat: int, rig: CameraRig) -> void:
	_seat = seat
	_rig = rig


func next_frame(tick: int) -> InputFrame:
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var buttons := InputFrame.SHOVE if Input.is_action_pressed("shove") else 0
	return InputFrame.new(_seat, tick, InputFrame.from_screen(stick, _rig.yaw()), buttons)
