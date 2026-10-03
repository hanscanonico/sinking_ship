class_name EndOverlay
extends CanvasLayer
## The local seat's result — "Last one dry!" or "Overboard — 4th of 6" — with
## restart and quit. Read from the snapshot: shown once the local seat is out or
## the match has ended.

signal restart_requested
signal quit_requested

@onready var _title: Label = %Title


func _ready() -> void:
	hide()
	%Restart.pressed.connect(restart_requested.emit)
	%Quit.pressed.connect(quit_requested.emit)


func show_snapshot(snapshot: Dictionary, local_seat: int) -> void:
	var seats: Array = snapshot["seats"]
	var mine: Dictionary = seats[local_seat]
	var ended: bool = snapshot["phase"] == MatchState.Phase.ENDED
	if not mine["out"] and not ended:
		hide()
		return
	if not mine["out"]:
		_title.text = "Last one dry!"
	elif ended and mine["place"] == 1:
		_title.text = "The sea wins — nobody stays dry"
	else:
		_title.text = "Overboard — %s of %d" % [_ordinal(mine["place"]), seats.size()]
	show()


static func _ordinal(place: int) -> String:
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][place % 10]
	return "%d%s" % [place, suffix]
