class_name CellMap
extends RefCounted
## Which of a ship's cells a ship point lies in (§5b.1, D6): inside the cell's box —
## from its low corner up to, not including, its high one, so a deck's top belongs to
## the space over it — and inside her hull there, where the box pokes outside its
## curve. The helper behind ShipPose's water and so behind Surfaces.wet (D13): a point
## in no cell is outside her, in the sea's water. Ship-local metres — or, framed along
## another of her axes as up (Faces), that face's: each box turned with the frame, so
## its floor and ceiling are along that up.

const NONE := -1
## Water this shallow over a cell's floor, in metres, is none: the cell is dry.
const DRY := 0.01

## How long a slot along her is, in metres: a point is tried only against the cells
## whose boxes reach into its slot, in her cells' order, past a box round them all.
const SLOT := 1.0

var _low := PackedVector3Array()
var _high := PackedVector3Array()
var _bounds := AABB()
var _slots: Array[PackedInt32Array] = []
## Per cell, 1 where its box pokes outside her hull, so a point in it is checked
## against her shell — but for one no further out to port or starboard than her shell
## stands anywhere along the box, which is inside it for sure.
var _poking := PackedByteArray()
var _inside_port := PackedFloat64Array()
var _inside_starboard := PackedFloat64Array()
var _structure: ShipStructure
## From the frame's points to ship-local ones, and whether it is any other than hers.
var _to_ship := Basis.IDENTITY
var _framed := false


## [param structure]'s cells, read in the frame [param to_ship] takes to ship space.
func _init(structure: ShipStructure, to_ship := Basis.IDENTITY) -> void:
	_structure = structure
	_to_ship = to_ship
	_framed = to_ship != Basis.IDENTITY
	var to_frame := to_ship.transposed()
	for cell: FloodCell in structure.cells:
		var a := to_frame * cell.low
		var b := to_frame * cell.high
		var low := a.min(b)
		var high := a.max(b)
		_low.append(low)
		_high.append(high)
		_poking.append(1 if cell.shape < 1.0 else 0)
		var box := AABB(low, high - low)
		_bounds = box if _low.size() == 1 else _bounds.merge(box)
		_inside_port.append(_surely_inside(cell, -1))
		_inside_starboard.append(_surely_inside(cell, 1))
	for slot in ceili(_bounds.size.x / SLOT):
		var from := _bounds.position.x + slot * SLOT
		var reaching := PackedInt32Array()
		for index in _low.size():
			if _low[index].x < from + SLOT and _high[index].x > from:
				reaching.append(index)
		_slots.append(reaching)


## How many cells there are.
func count() -> int:
	return _low.size()


## The index of the cell [param ship_point] lies in, or NONE outside every one.
func cell_at(ship_point: Vector3) -> int:
	var from := _bounds.position
	var to := _bounds.end
	if ship_point.x < from.x or ship_point.x >= to.x or ship_point.y < from.y:
		return NONE
	if ship_point.y >= to.y or ship_point.z < from.z or ship_point.z >= to.z:
		return NONE
	var slot := mini(floori((ship_point.x - from.x) / SLOT), _slots.size() - 1)
	for index: int in _slots[slot]:
		var low := _low[index]
		var high := _high[index]
		if ship_point.x < low.x or ship_point.x >= high.x:
			continue
		if ship_point.y < low.y or ship_point.y >= high.y:
			continue
		if ship_point.z < low.z or ship_point.z >= high.z:
			continue
		if _poking[index] == 1:
			var ship := _to_ship * ship_point if _framed else ship_point
			var inside := _inside_starboard[index] if ship.z >= 0.0 else _inside_port[index]
			if absf(ship.z) > inside and not _in_hull(ship):
				continue
		return index
	return NONE


## The height of cell [param cell]'s floor, and of its ceiling.
func floor_of(cell: int) -> float:
	return _low[cell].y


func ceiling_of(cell: int) -> float:
	return _high[cell].y


## These cells framed with [param to_ship] taking the frame's points to ship space.
func framed(to_ship: Basis) -> CellMap:
	return CellMap.new(_structure, to_ship)


## Cell [param cell]'s box.
func box_of(cell: int) -> AABB:
	return AABB(_low[cell], _high[cell] - _low[cell])


## How far to [param side] (-1 port, 1 starboard) of her middle line a point of
## [param cell]'s box is inside her shell wherever along and up the box it stands: the
## least breadth of every section reaching into the box, at the box's foot and top and
## at each corner of its outline between; nothing, where the box leaves the outline.
func _surely_inside(cell: FloodCell, side: int) -> float:
	if cell.shape >= 1.0:
		return INF
	var least := INF
	var spans: Array[Vector2] = []
	for section: HullSection in _structure.sections:
		var half := section.length * 0.5
		if section.x + half <= cell.low.x or section.x - half >= cell.high.x:
			continue
		spans.append(Vector2(section.x - half, section.x + half))
		var heights := PackedFloat64Array([cell.low.y, cell.high.y])
		for corner: Vector2 in section.outline:
			if corner.y > cell.low.y and corner.y < cell.high.y:
				heights.append(corner.y)
		for height: float in heights:
			var shell := section.shell_at(height, side)
			if is_nan(shell):
				return -INF
			least = minf(least, shell * side)
	# Somewhere along the box no section stands: outside her there.
	spans.sort()
	var reached := cell.low.x
	for span: Vector2 in spans:
		if span.x > reached:
			return -INF
		reached = maxf(reached, span.y)
	return least if reached >= cell.high.x else -INF


## Whether [param ship_point] stands inside her shell's outline at its x and height.
func _in_hull(ship_point: Vector3) -> bool:
	var section := _structure.section_at(ship_point.x)
	if section == null:
		return false
	var side := 1 if ship_point.z >= 0.0 else -1
	var shell := section.shell_at(ship_point.y, side)
	return not is_nan(shell) and ship_point.z * side <= shell * side
