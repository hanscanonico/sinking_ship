class_name ShipRamp
extends Resource
## A standable rectangle in ship space whose height runs linearly along one axis
## (D6): the stairs between two platforms. Seen from the side it is a solid wedge.

enum Axis { X, Z }

## The rectangle in the ship's x/z plane: position is its (x, z) minimum corner.
@export var area: Rect2
## The axis the height runs along.
@export var axis: Axis
## The height at the area's minimum along [member axis].
@export var start_height: float
## The height at the area's maximum along [member axis].
@export var end_height: float


func contains(x: float, z: float) -> bool:
	return x >= area.position.x and x <= area.end.x and z >= area.position.y and z <= area.end.y


## The height above the ship-plane point (x, z), held at the end heights beyond
## the ends.
func height_at(x: float, z: float) -> float:
	var along := x if axis == Axis.X else z
	var start := area.position.x if axis == Axis.X else area.position.y
	var length := area.size.x if axis == Axis.X else area.size.y
	return lerpf(start_height, end_height, clampf((along - start) / length, 0.0, 1.0))


## The lower of the two end heights: where the wedge stands.
func base() -> float:
	return minf(start_height, end_height)


## The two corners (x, z) of one end's edge: [param end] 0 is the start, 1 the end.
func end_edge(end: int) -> PackedVector2Array:
	if axis == Axis.X:
		var x := area.position.x if end == 0 else area.end.x
		return PackedVector2Array([Vector2(x, area.position.y), Vector2(x, area.end.y)])
	var z := area.position.y if end == 0 else area.end.y
	return PackedVector2Array([Vector2(area.position.x, z), Vector2(area.end.x, z)])


## The middle of one end's edge, at that end's height.
func end_point(end: int) -> Vector3:
	var edge := end_edge(end)
	var middle := (edge[0] + edge[1]) * 0.5
	return Vector3(middle.x, start_height if end == 0 else end_height, middle.y)
