class_name CellMap
extends RefCounted
## Which of a ship's cells a ship point lies in (§5b.1, D6): inside the cell's box —
## from its low corner up to, not including, its high one, so a deck's top belongs to
## the space over it — and inside her hull there, where the box pokes outside its
## curve. The helper behind ShipPose's water and so behind Surfaces.wet (D13): a point
## in no cell is outside her, in the sea's water. Ship-local metres.

const NONE := -1
## Water this shallow over a cell's floor, in metres, is none: the cell is dry.
const DRY := 0.01

var _low := PackedVector3Array()
var _high := PackedVector3Array()
## Per cell, 1 where its box pokes outside her hull, so a point in it is checked
## against her shell.
var _poking := PackedByteArray()
var _structure: ShipStructure


func _init(structure: ShipStructure) -> void:
	_structure = structure
	for cell: FloodCell in structure.cells:
		_low.append(cell.low)
		_high.append(cell.high)
		_poking.append(1 if cell.shape < 1.0 else 0)


## How many cells there are.
func count() -> int:
	return _low.size()


## The index of the cell [param ship_point] lies in, or NONE outside every one.
func cell_at(ship_point: Vector3) -> int:
	for index in _low.size():
		var low := _low[index]
		var high := _high[index]
		if ship_point.x < low.x or ship_point.x >= high.x:
			continue
		if ship_point.y < low.y or ship_point.y >= high.y:
			continue
		if ship_point.z < low.z or ship_point.z >= high.z:
			continue
		if _poking[index] == 1 and not _in_hull(ship_point):
			continue
		return index
	return NONE


## The height of cell [param cell]'s floor.
func floor_of(cell: int) -> float:
	return _low[cell].y


## Whether [param ship_point] stands inside her shell's outline at its x and height.
func _in_hull(ship_point: Vector3) -> bool:
	var section := _structure.section_at(ship_point.x)
	if section == null:
		return false
	var side := 1 if ship_point.z >= 0.0 else -1
	var shell := section.shell_at(ship_point.y, side)
	return not is_nan(shell) and ship_point.z * side <= shell * side
