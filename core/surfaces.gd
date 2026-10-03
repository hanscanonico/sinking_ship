class_name Surfaces
extends RefCounted
## The only door to spatial questions about the ship (D6, D13): what is under a
## body and whether a point is wet. One-platform version (SH1) — no ramps, no
## landing between decks yet.

const NONE := -1

var _platforms: Array[ShipPlatform] = []


func _init(layout: ShipLayout) -> void:
	_platforms = layout.platforms.duplicate()


## The platform whose area holds [param ship_point]'s x/z, or NONE.
func under(ship_point: Vector3) -> int:
	for index in _platforms.size():
		if _platforms[index].contains(ship_point.x, ship_point.z):
			return index
	return NONE


func height(surface: int) -> float:
	return _platforms[surface].height


## Flooded is geometry (D7): below the sea plane under the schedule's pose.
func wet(ship_point: Vector3, pose: ShipPose) -> bool:
	return pose.world_height(ship_point) < 0.0
