class_name ShipPlatform
extends Resource
## A flat, standable rectangle in ship space (D6): x toward the bow, z to
## starboard, at a height above the main deck.

## How far off an edge a railing's end may lie and still be on it.
const EDGE := 0.001

## What the deck is called, for people reading the data and the tests, and what a
## scenario's collapse names it by (D7).
@export var name: StringName
## The rectangle in the ship's x/z plane: position is its (x, z) minimum corner.
@export var area: Rect2
@export var height: float


func contains(x: float, z: float) -> bool:
	return x >= area.position.x and x <= area.end.x and z >= area.position.y and z <= area.end.y


## Whether the segment from [param from] to [param to] (x/z) lies along one of
## this platform's four edges, to within float precision: an edge's end is its
## corner plus its size, which single precision does not always land exactly.
func edge_holds(from: Vector2, to: Vector2) -> bool:
	var reach := area.grow(EDGE)
	if not reach.has_point(from) or not reach.has_point(to):
		return false
	for x: float in [area.position.x, area.end.x]:
		if is_equal_approx(from.x, x) and is_equal_approx(to.x, x):
			return true
	for z: float in [area.position.y, area.end.y]:
		if is_equal_approx(from.y, z) and is_equal_approx(to.y, z):
			return true
	return false
