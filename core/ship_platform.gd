class_name ShipPlatform
extends Resource
## A flat, standable rectangle in ship space (D6): x toward the bow, z to
## starboard, at a height above the main deck.

## The rectangle in the ship's x/z plane: position is its (x, z) minimum corner.
@export var area: Rect2
@export var height: float


func contains(x: float, z: float) -> bool:
	return x >= area.position.x and x <= area.end.x and z >= area.position.y and z <= area.end.y
