class_name SinkOpenings
extends RefCounted
## The openings water can pass in her, as SinkStepper reads them (§5b.1): compiled once
## from her structure and the hit, in her openings' order then the gash's, each added to
## her air (SinkAir) and, once it can fail, watched by her failures (SinkFailures). Ship-
## local metres.

## Per opening: its name and kind, its sides — each a cell or SinkStepper.OUTSIDE; a hole
## in a floor's first side is the one under it — whether it is a hole in a floor, its
## middle and its half extents along x, y and z, the area water passes through, and the
## seconds it takes to shut from the hit — 0 for one that stays as it is, under 0 for one
## shut until it fails.
var names: Array[StringName] = []
var kinds := PackedInt32Array()
var first := PackedInt32Array()
var second := PackedInt32Array()
var in_floor := PackedByteArray()
var middle := PackedFloat64Array()
var half := PackedFloat64Array()
var flow_area := PackedFloat64Array()
var shut_time := PackedFloat64Array()


## Adds [param opening] of [param structure] to the openings water can pass, and to
## [param air] — one [param shut] until it fails, with the failures stage on — watched by
## [param failures] (null without that stage) for failing once it can fail and is shut,
## or is a door the ship shuts and did not jam.
func add(
	structure: ShipStructure,
	opening: ShipOpening,
	damage: HitDamage,
	air: SinkAir,
	failures: SinkFailures,
	shut := false
) -> void:
	var sides := PackedInt32Array()
	for place: StringName in opening.joins:
		sides.append(
			(
				structure.cell_named(place)
				if not place in [ShipOpening.SEA, ShipOpening.SKY]
				else SinkStepper.OUTSIDE
			)
		)
	var floor_hole := opening.facing() == 1
	if floor_hole:
		# The side under the hole first: a cell whose middle stands below it.
		var first_under := _under(structure, sides[0], opening.centre.y)
		if not first_under:
			sides = PackedInt32Array([sides[1], sides[0]])
	for axis in 3:
		middle.append(opening.centre[axis])
		half.append(opening.size[axis] * 0.5)
	flow_area.append(opening.flow_area())
	names.append(opening.name)
	kinds.append(opening.kind)
	first.append(sides[0])
	second.append(sides[1])
	in_floor.append(1 if floor_hole else 0)
	var shuts := opening.shuts_at_hit and not opening.name in damage.jammed
	var shuts_in := -1.0 if shut else (opening.shut_time if shuts else 0.0)
	shut_time.append(shuts_in)
	var axis := opening.facing()
	var facing := _side(structure, sides, axis, opening) if axis >= 0 else 0.0
	air.add_opening(sides[0], sides[1], shuts_in, axis, facing)
	if failures != null and opening.can_fail() and shuts_in != 0.0:
		failures.watch(names.size() - 1, opening, Vector2i(sides[0], sides[1]), shuts_in)


## Which way along ship [param axis] the first of [param sides] lies from
## [param opening]'s plane: 1 or -1, by where its cell's middle stands — or, for the sea
## or the sky, the way the cell on the other side does not.
static func _side(
	structure: ShipStructure, sides: PackedInt32Array, axis: int, opening: ShipOpening
) -> float:
	var plane: float = opening.centre[axis]
	if sides[0] != SinkStepper.OUTSIDE:
		var cell := structure.cells[sides[0]]
		return 1.0 if (float(cell.low[axis]) + cell.high[axis]) * 0.5 > plane else -1.0
	var other := structure.cells[sides[1]]
	return -1.0 if (float(other.low[axis]) + other.high[axis]) * 0.5 > plane else 1.0


## Whether [param side] lies under a hole in a floor at [param height]: a cell whose
## middle is below it; the outside is under a hole only when a cell is over it.
static func _under(structure: ShipStructure, side: int, height: float) -> bool:
	if side == SinkStepper.OUTSIDE:
		return false
	var cell := structure.cells[side]
	return (cell.low.y + cell.high.y) * 0.5 < height
