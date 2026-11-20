class_name AirVents
extends RefCounted
## The way a pocket's air goes out as it goes free (SinkTimeline.Kind.VENTED, SH29): the
## opening of its cell, not shut, whose top stands highest in the world — the last its
## water reaches. One answer for the match, whose blast blows swimmers clear of it (Falls,
## #631), and for InnerWater, which bursts the air out on the water there (D13). Ship
## space; nothing here is match state (D5).

## The openings water can pass, those shut until they fail after them (SinkSchedule):
## per one, its two sides — a cell, or -1 for the sea or the sky — its box, and 1 where it
## is shut until it fails; and per cell, the openings that touch it, by index.
var _openings: Array[ShipOpening] = []
var _sides := PackedInt32Array()
var _spans: Array[AABB] = []
var _shut := PackedByteArray()
var _touching: Array[PackedInt32Array] = []


## The ways out of [param structure]'s cells: through [param passages], the openings
## water can pass after the hit, and [param failing], those shut until they fail, in that
## order.
func _init(
	structure: ShipStructure, passages: Array[ShipOpening], failing: Array[ShipOpening]
) -> void:
	_openings = passages.duplicate()
	_openings.append_array(failing)
	_touching.resize(structure.cells.size())
	for cell in _touching.size():
		_touching[cell] = PackedInt32Array()
	for index in _openings.size():
		var opening := _openings[index]
		_shut.append(1 if index >= passages.size() else 0)
		_spans.append(AABB(opening.centre - opening.size * 0.5, opening.size))
		for place: StringName in opening.joins:
			var cell := structure.cell_named(place)
			_sides.append(cell)
			if cell != -1 and not index in _touching[cell]:
				_touching[cell].append(index)


## Of [param openings], those of the piece [param structure] whose stretch is
## [param span] (SinkSchedule.span_of): every cell they join its, their middle on it — the
## ways out of a piece of her once she breaks, as ShipPieces draws its water.
static func kept(
	openings: Array[ShipOpening], structure: ShipStructure, span: Vector2
) -> Array[ShipOpening]:
	var found: Array[ShipOpening] = []
	for opening: ShipOpening in openings:
		var ours := opening.centre.x >= span.x and opening.centre.x <= span.y
		for place: StringName in opening.joins:
			if not place in [ShipOpening.SEA, ShipOpening.SKY]:
				ours = ours and structure.cell_named(place) != -1
		if ours:
			found.append(opening)
	return found


## The openings, by index, as way_out names them: the passages', then the failing.
func openings() -> Array[ShipOpening]:
	return _openings


## The way [param cell]'s air goes out under [param pose] — its piece's: the index of the
## opening of the cell, not shut — or given way — whose top stands highest in the world,
## the first of those as high; -1 for none.
func way_out(cell: int, pose: ShipPose) -> int:
	if cell < 0 or cell >= _touching.size():
		return -1
	var best := -1
	var highest := -INF
	for index: int in _touching[cell]:
		var passage := _openings[index].name
		var shut: bool = _shut[index] == 1 or pose.doors_shut.get(passage, 0.0) >= 1.0
		if shut and pose.opened.get(passage, 0) < 2:
			continue
		var top := top_of(pose.transform, _spans[index])
		if top > highest:
			best = index
			highest = top
	return best


## The side of opening [param index] across it from [param cell]: a cell, or -1 for the
## sea or the sky.
func beyond(index: int, cell: int) -> int:
	return _sides[index * 2 + 1] if _sides[index * 2] == cell else _sides[index * 2]


## The world height the highest corner of [param box] stands at on a ship at [param ship]:
## its middle's and how far its half extents reach up.
static func top_of(ship: Transform3D, box: AABB) -> float:
	var basis := ship.basis
	var half := box.size * 0.5
	var spread := absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z
	return (ship * box.get_center()).y + spread
