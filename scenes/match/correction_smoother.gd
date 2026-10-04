class_name CorrectionSmoother
extends RefCounted
## The local seat's share of a correction (D12): when the client's prediction of its
## body jumps — a shove it could not foresee — the body is drawn where it was and
## closes on the prediction at a steady pace, within correction_time. Presentation
## only: the sim and the prediction are never held back or nudged.

## How far the body is drawn from its prediction, in ship space.
var offset := Vector3.ZERO

var _seconds: float
var _speed := 0.0


func _init(correction_time: float) -> void:
	_seconds = correction_time


## The prediction jumped [param by]: drawn away from where the body is drawn now.
func absorb(by: Vector3) -> void:
	if _seconds <= 0.0:
		return
	offset -= by
	_speed = offset.length() / _seconds


## [param delta] seconds of drawing.
func advance(delta: float) -> void:
	offset = offset.move_toward(Vector3.ZERO, _speed * delta)
