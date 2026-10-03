class_name ShipLadder
extends Resource
## A boarding ladder down the side of the ship (D6, SH5): a stretch of one
## platform's edge that a swimmer can climb up onto it from the sea, however high
## the platform stands. Nothing else uses it — a body on deck never climbs down one.

## The platform, by its index in [member ShipLayout.platforms], it climbs up to.
@export var platform: int
## The stretch's ends in the ship's x/z plane, both on that platform's edge.
@export var from: Vector2
@export var to: Vector2
