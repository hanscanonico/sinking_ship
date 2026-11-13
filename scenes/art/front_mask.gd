class_name FrontMask
extends RefCounted
## A spreading cell's sheets drawn only inside its water's fronts (WaterFronts, #642), as
## inner_water.gdshader masks them: the sim's own answer of where its floor is wet
## (ShipPose.reached), read the same way here and there (D13).

## The most fronts a cell's sheet is masked by (inner_water.gdshader's front_rects).
const MOST := 8


## Cell [param cell]'s fronts under [param pose] as its sheets' mask takes them: [the
## rectangles they run out from — low x, low z, high x, high z — and how far each has run],
## [param alpha] of the way on from [param then]'s where it spreads then too; at most MOST
## of them, those of its first openings. Empty while the cell is not spreading: drawn whole.
static func of(pose: ShipPose, cell: int, then: ShipPose = null, alpha := 1.0) -> Array:
	var rects := PackedVector4Array()
	var reaches := PackedFloat32Array()
	if pose.spreading.is_empty() or pose.spreading[cell] == 0:
		return [rects, reaches]
	var fronts := pose.fronts
	var span := fronts.of_cell(cell)
	var blend := (
		then != null
		and is_same(then.fronts, fronts)
		and not then.spreading.is_empty()
		and then.spreading[cell] == 1
	)
	for front in range(span.x, span.x + mini(span.y, MOST)):
		var reach := pose.reaches[front]
		if blend and then.reaches[front] >= 0.0 and reach >= 0.0:
			reach = lerpf(then.reaches[front], reach, alpha)
		rects.append(fronts.rect_of(front))
		reaches.append(reach)
	return [rects, reaches]


## How far inside the nearest of [param rects] at [param reaches] (of) ship x/z
## ([param x], [param z]) lies — below 0 beyond them all, where a sheet draws nothing:
## inner_water.gdshader's own reading, and WaterFronts.margin's.
static func margin(
	rects: PackedVector4Array, reaches: PackedFloat32Array, x: float, z: float
) -> float:
	var best := -INF
	for front in rects.size():
		if reaches[front] >= 0.0:
			best = maxf(best, reaches[front] - WaterFronts.apart(rects[front], x, z))
	return best
