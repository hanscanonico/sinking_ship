class_name ShipRailing
extends Resource
## A railing span along one platform's edge, in ship space (D6). A gap in a
## railing is simply where no span runs.

## The platform, by its index in [member ShipLayout.platforms], whose edge this
## span runs along.
@export var platform: int
## The span's ends in the ship's x/z plane, both on that platform's edge.
@export var from: Vector2
@export var to: Vector2
