class_name FloodedDecks
extends RefCounted
## Which of her platforms the water stands over the middle of (Surfaces.flooded), pose
## by pose, for the planners that ask it of every platform of a step's pose and of the
## pose before it (FxPlanner, CuePlanner): each pose read once, every middle at once
## (StillPoints), the last two kept — so a step reads only its own pose, the one before
## it read the step before. Once she has broken (SH33), each platform is read as the piece
## its middle lies on stands (PieceViews, #478). Presentation, reading the poses it is
## handed (D12).

var _middles: StillPoints
var _pieces: PieceViews
## The poses read last, and per pose, per platform, 1 where it is flooded.
var _poses: Array[ShipPose] = [null, null]
var _flooded: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
var _next := 0


## [param layout]'s platforms, each read at its middle at its height, as Surfaces
## reads it — on the piece of her [param pieces] has it lie on, where she breaks.
func _init(layout: ShipLayout, pieces: PieceViews = null) -> void:
	_pieces = pieces
	var middles := PackedVector3Array()
	for deck: ShipPlatform in layout.platforms:
		var middle := deck.area.get_center()
		middles.append(Vector3(middle.x, deck.height, middle.y))
	_middles = StillPoints.new(middles, StillPoints.native_water())


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
	_poses[slot] = pose
	var views: Array[ShipPose] = [pose]
	if _pieces != null:
		views = _pieces.of(pose)
	if views.size() == 1:
		_middles.read(pose)
		_flooded[slot] = _middles.wet_all()
		return _flooded[slot]
	var flooded := PackedByteArray()
	flooded.resize(_middles.size())
	for place in views.size():
		_middles.read(views[place])
		var wet := _middles.wet_all()
		for platform in flooded.size():
			if _pieces.place_of(views, _middles.point(platform).x) == place:
				flooded[platform] = wet[platform]
	_flooded[slot] = flooded
	return flooded
