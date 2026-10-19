class_name DrawWatch
extends RefCounted
## Whether a window has stopped being drawn. A window the system cannot see — covered
## whole, minimised, on another Space, the display asleep — is not drawn on a Mac: its
## frames still run, the match still plays, but RenderingServer.frame_post_draw never
## comes, so a capture waiting on it waits forever, holding the window lock (#105).
## Read the engine's frames drawn and the wall clock each frame; once no frame has
## been drawn for the limit, the window has stalled, and the capture is to fail.

## How long a capture may go without a frame drawn, in milliseconds: well past the
## slowest frame a loaded machine draws, well short of a sibling's patience.
const LIMIT_MS := 60000

var _limit_ms: int
## The frames drawn when last looked at, and when the count last moved; -1 before the
## first look.
var _drawn := -1
var _since_ms := -1


func _init(limit_ms := LIMIT_MS) -> void:
	_limit_ms = limit_ms


## Whether no frame past [param frames_drawn] has been drawn for the limit, at
## [param now_ms] on the wall clock.
func stalled(frames_drawn: int, now_ms: int) -> bool:
	if frames_drawn != _drawn:
		_drawn = frames_drawn
		_since_ms = now_ms
	return now_ms - _since_ms >= _limit_ms


## What a stalled capture says as it fails.
func stall_message() -> String:
	return (
		(
			"no frame drawn for %d s: the window is not being drawn — covered, minimised, on"
			+ " another Space or the display asleep; keep it in sight and run again"
		)
		% roundi(_limit_ms / 1000.0)
	)
