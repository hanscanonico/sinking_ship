class_name FloorClearances
extends RefCounted
## What Surfaces.under reads to stand feet on a floor without looking at the rest of its
## cell (SH18): per cell of a Surfaces' grid, its platforms, and for each the distance
## from its height to the heights every other surface of the cell stands at — a ramp
## anywhere between its ends — less a slack. Every other surface but a ramp stands at
## its top, so the nearest of those is either side of a platform's own height among the
## cell's heights sorted: a ship on her side (Faces) has hundreds over a cell, which all
## against all would take her bots most of a second to set up.

## Per cell, its platforms in the order the cell lists them, and their clearances.
var floors: Array[PackedInt32Array] = []
var clearances: Array[PackedFloat64Array] = []


## The clearances over [param grid]'s cells of surfaces standing at [param tops] —
## platforms numbered below [param first_ramp], ramps from there to [param first_top],
## each reaching down to its [param bottoms] — less [param slack].
func _init(
	grid: SpatialIndex,
	tops: PackedFloat64Array,
	bottoms: PackedFloat64Array,
	first_ramp: int,
	first_top: int,
	slack: float
) -> void:
	for cell in grid.cell_count():
		var near := grid.in_cell(cell)
		var levels := PackedFloat64Array()
		var ramps := PackedInt32Array()
		for surface: int in near:
			if surface >= first_ramp and surface < first_top:
				ramps.append(surface)
			else:
				levels.append(tops[surface])
		levels.sort()
		var on := PackedInt32Array()
		var clear := PackedFloat64Array()
		for surface: int in near:
			if surface >= first_ramp:
				continue
			var height := tops[surface]
			var clearance := _from_the_others(levels, height)
			for ramp: int in ramps:
				clearance = minf(clearance, maxf(bottoms[ramp] - height, height - tops[ramp]))
			on.append(surface)
			clear.append(clearance - slack)
		floors.append(on)
		clearances.append(clear)


## How far [param height] — one of the sorted [param levels], a surface's own — is from
## the nearest of the others: none when another stands level with it.
static func _from_the_others(levels: PackedFloat64Array, height: float) -> float:
	var at := levels.bsearch(height)
	if at + 1 < levels.size() and levels[at + 1] == height:
		return 0.0
	var nearest := INF
	if at > 0:
		nearest = height - levels[at - 1]
	if at + 1 < levels.size():
		nearest = minf(nearest, levels[at + 1] - height)
	return nearest
