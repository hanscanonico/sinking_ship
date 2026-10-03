class_name MatchArgs
extends RefCounted
## The user arguments a match host takes after `--`:
##   --seed=N  --seats=N  --seconds=S  --autoplay  --capture=PATH  --capture-at=S

## -1 when not given: the host picks one.
var seed_value: int = -1
## 0 when not given: the match data's seat count.
var seats: int = 0
## How much match time a headless run may take before it stops.
var seconds: float = 300.0
## A bot plays the local seat.
var autoplay: bool = false
var capture_path: String = ""
## Match time to save the capture at; -1 for the end of the match.
var capture_at: float = -1.0


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
			_:
				push_warning("unknown argument %s" % arg)
	return parsed
