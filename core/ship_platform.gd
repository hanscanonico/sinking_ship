class_name ShipPlatform
extends Resource
## A flat, standable rectangle in ship space (D6): x toward the bow, z to
## starboard, at a height above the main deck.

## What the deck is called, for people reading the data and the tests; no rule reads it.
@export var name: StringName
## The rectangle in the ship's x/z plane: position is its (x, z) minimum corner.
@export var area: Rect2
@export var height: float


func contains(x: float, z: float) -> bool:
	return x >= area.position.x and x <= area.end.x and z >= area.position.y and z <= area.end.y


## Whether the segment from [param from] to [param to] (x/z) lies along one of
## this platform's four edges.
func edge_holds(from: Vector2, to: Vector2) -> bool:
	if not contains(from.x, from.y) or not contains(to.x, to.y):
		return false
	for x: float in [area.position.x, area.end.x]:
		if is_equal_approx(from.x, x) and is_equal_approx(to.x, x):
			return true
	for z: float in [area.position.y, area.end.y]:
		if is_equal_approx(from.y, z) and is_equal_approx(to.y, z):
			return true
	return false
