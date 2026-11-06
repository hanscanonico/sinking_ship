class_name PieceViews
extends RefCounted
## Her pose as each piece of her stands in it, for the planners that ask the whole ship's
## pose where the sea and her water are (FxPlanner, CuePlanner; #478). Once she has broken
## (SH33) the whole ship's pose stands where her aft piece does, and its cells' levels are
## offset by that piece's place: asked of a point on another piece, it answers as though
## that piece rode the aft one. A view of a piece is a pose of its own (ShipPose): the
## piece's place in the world, and every one of her cells numbered as her own layout
## numbers them — those on the piece at the piece's own levels, the rest at their own
## piece's — so whatever reads her cells by her numbers reads the piece's view as it read
## the whole ship's pose. While she is whole, or for a hull that never breaks, the one view
## is the pose itself: the same answers to the bit. Presentation only (D12): it reads the
## poses the schedule hands out and makes poses of its own, never edits one.

var _layout: ShipLayout
var _schedule: SinkSchedule
## The pieces she ends in (ShipPieces.leaves_of), and where each past the first begins
## along her: a point's piece is found along them (FxPieces.leaf_along).
var leaves := PackedInt32Array()
var cuts := PackedFloat64Array()
## Her cell count; per piece asked, per cell of hers, its place among the piece's own
## cells, -1 where the piece has none of it; and per cell of hers, the first piece she
## ends in that has it, and its place there.
var _count := 0
var _places: Dictionary[int, PackedInt32Array] = {}
var _home_leaf := PackedInt32Array()
var _home_place := PackedInt32Array()
## The last two poses asked of, and per pose its views made so far, by piece.
var _poses: Array[ShipPose] = [null, null]
var _made: Array[Dictionary] = [{}, {}]
var _next := 0


func _init(layout: ShipLayout, schedule: SinkSchedule) -> void:
	_layout = layout
	_schedule = schedule
	leaves = ShipPieces.leaves_of(schedule)
	for at in range(1, leaves.size()):
		cuts.append(schedule.span_of(leaves[at]).x)
	if leaves.is_empty() or layout.structure == null:
		return
	_count = layout.structure.cells.size()
	_home_leaf.resize(_count)
	_home_leaf.fill(-1)
	_home_place.resize(_count)
	for leaf: int in leaves:
		var places := _places_of(leaf)
		for cell in _count:
			if _home_leaf[cell] == -1 and places[cell] != -1:
				_home_leaf[cell] = leaf
				_home_place[cell] = places[cell]


## Whether [param pose] has her whole: one view, the pose itself.
static func whole(pose: ShipPose) -> bool:
	return pose.pieces.is_empty() or (pose.standing.size() == 1 and pose.standing[0] == 0)


## Per piece she ends in, aft to fore, its view of [param pose]; the pose alone while she
## is whole.
func of(pose: ShipPose) -> Array[ShipPose]:
	if whole(pose) or leaves.is_empty():
		return [pose]
	var views: Array[ShipPose] = []
	for leaf: int in leaves:
		views.append(of_piece(pose, leaf))
	return views


## The place in [param views] (of) of the piece the point [param x] along her lies on.
func place_of(views: Array[ShipPose], x: float) -> int:
	return 0 if views.size() == 1 else FxPieces.leaf_along(cuts, x)


## The view of [param pose] of the piece ship point [param point] lies on.
func at(pose: ShipPose, point: Vector3) -> ShipPose:
	if whole(pose) or leaves.is_empty():
		return pose
	return of_piece(pose, leaves[FxPieces.leaf_along(cuts, point.x)])


## The view of [param pose] of piece [param piece] of her (SinkTimeline.spans): the space
## a seat on that piece lives in (PlayerState.piece). The pose itself while she is whole.
func of_piece(pose: ShipPose, piece: int) -> ShipPose:
	if whole(pose) or piece == 0 or piece >= pose.pieces.size():
		return pose
	var slot := _poses.find(pose)
	if slot == -1:
		slot = _next
		_next = 1 - _next
		_poses[slot] = pose
		_made[slot] = {}
	if not _made[slot].has(piece):
		_made[slot][piece] = _view(pose, piece)
	return _made[slot][piece]


## Whether every deck of [param surfaces] still standing has its middle under the sea,
## each as its own piece stands in [param pose]: the highest of them in the world flooded.
func sunk(surfaces: Surfaces, pose: ShipPose) -> bool:
	var views := of(pose)
	if views.size() == 1:
		var highest := surfaces.highest_platform(pose)
		return highest == Surfaces.NONE or surfaces.flooded(highest, pose)
	var best := Surfaces.NONE
	var best_height := -INF
	var best_view: ShipPose = pose
	for platform in _layout.platforms.size():
		var deck := _layout.platforms[platform]
		if deck.name in pose.collapsed:
			continue
		var view := views[place_of(views, deck.area.get_center().x)]
		var height := surfaces.world_height(platform, view)
		if height > best_height:
			best = platform
			best_height = height
			best_view = view
	return best == Surfaces.NONE or surfaces.flooded(best, best_view)


## Piece [param piece]'s view of [param pose]: where the piece stands, its cells' water as
## its own, the rest of hers at their own pieces', and what has happened to her the whole
## ship's.
func _view(pose: ShipPose, piece: int) -> ShipPose:
	var own := pose.of_piece(piece)
	var made := ShipPose.new(own.sink, own.trim_deg, own.heel_deg, own.transform)
	made.cells = pose.cells
	if pose.levels.size() == _count and _count > 0:
		var places := _places_of(piece)
		made.levels.resize(_count)
		made.pockets.resize(_count)
		made.lit.resize(_count)
		for cell in _count:
			var from := own
			var place := places[cell]
			if place == -1:
				from = pose.of_piece(_home_leaf[cell])
				place = _home_place[cell]
			made.levels[cell] = from.levels[place]
			made.pockets[cell] = from.pockets[place]
			made.lit[cell] = from.lit[place]
	else:
		made.levels = pose.levels
		made.pockets = pose.pockets
		made.lit = pose.lit
	made.passages = pose.passages
	made.flows = pose.flows
	made.doors_shut = pose.doors_shut
	made.opened = pose.opened
	made.falls = pose.falls
	made.felled = pose.felled
	made.collapsed = pose.collapsed
	made.collapsing = pose.collapsing
	made.broken_railings = pose.broken_railings
	made.lurch_warning = pose.lurch_warning
	made.lurch = pose.lurch
	made.standing = pose.standing
	return made


## Per cell of hers, its place among piece [param piece]'s own cells, -1 for none.
func _places_of(piece: int) -> PackedInt32Array:
	if not _places.has(piece):
		var places := PackedInt32Array()
		places.resize(_count)
		places.fill(-1)
		var own := _schedule.structure_of(piece)
		var sources := PieceStructure.sources(_schedule.structure_of(0), own)
		for place in sources.size():
			if sources[place] >= 0 and places[sources[place]] == -1:
				places[sources[place]] = place
		_places[piece] = places
	return _places[piece]
