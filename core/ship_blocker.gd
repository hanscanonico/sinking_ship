class_name ShipBlocker
extends Resource
## Something solid standing on the ship (D6) — a deckhouse, a funnel, a hatch — as
## an upright box or cylinder between two heights, in ship space. Bodies are pushed
## out of it in the deck plane, and a shove does not pass through it.

enum Shape { BOX, CYLINDER }

@export var shape: Shape
## BOX: the footprint in the ship's x/z plane; position is its (x, z) minimum corner.
@export var area: Rect2
## CYLINDER: the axis, in the ship's x/z plane.
@export var centre: Vector2
## CYLINDER: the radius.
@export var radius: float
## The heights its underside and its top stand at.
@export var bottom: float
@export var top: float
