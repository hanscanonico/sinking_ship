class_name ClientSeat
extends InputSource
## A client's seat on the server (D10, D11): its frames as they come off the wire
## while the client is there, and a bot's once it has gone (SH12). The bot watches
## every snapshot from the first, so it takes over with the view it would have had.

var buffer: SeatBuffer
## Whether the client has gone and the bot plays the seat.
var handed_over := false

var _bot: InputSource


func _init(seat_buffer: SeatBuffer, bot: InputSource) -> void:
	buffer = seat_buffer
	_bot = bot


func hand_to_bot() -> void:
	handed_over = true


func next_frame(tick: int) -> InputFrame:
	return _bot.next_frame(tick) if handed_over else buffer.next_frame(tick)


func observe(snapshot: Dictionary, pose: ShipPose) -> void:
	_bot.observe(snapshot, pose)
