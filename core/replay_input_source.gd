class_name ReplayInputSource
extends InputSource
## Plays one seat back from an InputLog.

var _log: InputLog
var _seat: int


func _init(input_log: InputLog, seat: int) -> void:
	_log = input_log
	_seat = seat


func next_frame(tick: int) -> InputFrame:
	return _log.frame(tick, _seat)
