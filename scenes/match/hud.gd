class_name Hud
extends CanvasLayer
## Seats left, the match clock and the countdown, read from the latest snapshot;
## and, once the local seat is out, whose eyes the view is in. The tilt is the
## first-person HUD's inclinometer.

## How long "Go!" stays up once the countdown is over.
const GO_SECONDS := 0.8

var _countdown_ticks: int

@onready var _seats_left: Label = %SeatsLeft
@onready var _clock: Label = %Clock
@onready var _countdown: Label = %Countdown
@onready var _spectating: Label = %Spectating


func setup(sim: MatchSim) -> void:
	_countdown_ticks = sim.config.countdown_ticks


func show_snapshot(snapshot: Dictionary) -> void:
	var seats: Array = snapshot["seats"]
	var left := 0
	for entry: Dictionary in seats:
		if not entry["out"]:
			left += 1
	_seats_left.text = "Seats left %d / %d" % [left, seats.size()]
	_clock.text = MatchTranscript.clock(snapshot["tick"])
	_show_countdown(snapshot["tick"])


## [param text] along the bottom of the screen; empty hides it.
func show_spectating(text: String) -> void:
	_spectating.text = text
	_spectating.visible = not text.is_empty()


## Whole seconds left while the sim holds the brawl, then "Go!" for a moment.
func _show_countdown(tick: int) -> void:
	var left := _countdown_ticks - tick
	if left > 0:
		_countdown.text = str(ceili(Ticks.to_seconds(left)))
	elif _countdown_ticks > 0 and -left < Ticks.from_seconds(GO_SECONDS):
		_countdown.text = "Go!"
	else:
		_countdown.text = ""
	_countdown.visible = not _countdown.text.is_empty()
