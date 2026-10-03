class_name Hud
extends CanvasLayer
## Seats left and the match clock, read from the latest snapshot.

@onready var _seats_left: Label = %SeatsLeft
@onready var _clock: Label = %Clock


func show_snapshot(snapshot: Dictionary) -> void:
	var seats: Array = snapshot["seats"]
	var left := 0
	for entry: Dictionary in seats:
		if not entry["out"]:
			left += 1
	_seats_left.text = "Seats left %d / %d" % [left, seats.size()]
	_clock.text = MatchTranscript.clock(snapshot["tick"])
