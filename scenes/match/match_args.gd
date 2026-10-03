class_name MatchArgs
extends RefCounted
## The user arguments a match host takes after `--`:
##   --seed=N  --seats=N  --seconds=S  --autoplay  --capture=PATH  --capture-at=S
##   --observer  --capture-eye=SEAT
## The game reads --seed and --seats as the menu's choices; --autoplay presses its
## Play, and without it --capture saves the menu. A capture is taken from the
## observer camera unless --capture-eye names the seat whose eyes it looks through;
## --observer opens the observer camera for QA. No menu reaches either (D14).

## -1 when not given: the host picks one.
var seed_value: int = -1
## 0 when not given: the match data's seat count.
var seats: int = 0
## How much match time a headless run may take before it stops.
var seconds: float = 300.0
## A bot plays the local seat, and nobody waits at the menu.
var autoplay: bool = false
var capture_path: String = ""
## Match time to save the capture at; -1 for the end of the match.
var capture_at: float = -1.0
## The elevated observer camera instead of the local seat's eyes: a tool, never a
## player's view.
var observer: bool = false
## The seat a capture looks through the eyes of; -1 for the observer camera.
var capture_eye: int = -1


static func parse(args: PackedStringArray) -> MatchArgs:
	var parsed := MatchArgs.new()
	for arg: String in args:
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--seed":
				parsed.seed_value = value.to_int()
			"--seats":
				parsed.seats = value.to_int()
			"--seconds":
				parsed.seconds = value.to_float()
			"--autoplay":
				parsed.autoplay = true
			"--capture":
				parsed.capture_path = value
			"--capture-at":
				parsed.capture_at = value.to_float()
			"--observer":
				parsed.observer = true
			"--capture-eye":
				parsed.capture_eye = value.to_int()
			_:
				push_warning("unknown argument %s" % arg)
	return parsed
