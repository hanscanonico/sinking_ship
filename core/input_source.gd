class_name InputSource
extends RefCounted
## One seat's controller, whatever it is — a local player, a bot, a replay, later a
## remote client (D3, D10). MatchRunner asks each for one frame per tick and shows
## each the snapshot the tick produced; the sim never learns which kind it is.


## This seat's frame for [param tick], or null to repeat its last one.
func next_frame(_tick: int) -> InputFrame:
	return null


## The snapshot just produced and the ship's pose at it.
func observe(_snapshot: Dictionary, _pose: ShipPose) -> void:
	pass
