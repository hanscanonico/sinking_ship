class_name FloodedDecks
extends RefCounted
## Which of her platforms the water stands over the middle of (Surfaces.flooded), pose
## by pose, for the planners that ask it of every platform of a step's pose and of the
## pose before it (FxPlanner, CuePlanner): each pose read once, every middle at once
## (StillPoints), the last two kept — so a step reads only its own pose, the one before
## it read the step before. Presentation, reading the poses it is handed (D12).

var _middles: StillPoints
## The poses read last, and per pose, per platform, 1 where it is flooded.
var _poses: Array[ShipPose] = [null, null]
var _flooded: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
var _next := 0


## [param layout]'s platforms, each read at its middle at its height, as Surfaces
## reads it.
func _init(layout: ShipLayout) -> void:
	var middles := PackedVector3Array()
	for deck: ShipPlatform in layout.platforms:
		var middle := deck.area.get_center()
		middles.append(Vector3(middle.x, deck.height, middle.y))
	_middles = StillPoints.new(middles)


## Whether the water stands over the middle of platform [param platform] under
## [param pose].
func flooded(platform: int, pose: ShipPose) -> bool:
	return of(pose)[platform] == 1


## Per platform, 1 where the water stands over its middle under [param pose]: for a
## caller going through every platform, which reads them all at once.
func of(pose: ShipPose) -> PackedByteArray:
	for slot in 2:
		if _poses[slot] == pose:
			return _flooded[slot]
	var slot := _next
	_next = 1 - _next
	_middles.read(pose)
	_poses[slot] = pose
	_flooded[slot] = _middles.wet_all()
	return _flooded[slot]
