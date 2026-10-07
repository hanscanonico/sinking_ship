class_name WeakSpot
extends Resource
## A place along her hull where she can break (§5b.2, R27): an expansion joint, a big
## hatch, the end of a long superstructure — a candidate break station. Her hull parts
## there and nowhere else, and her art is cut there (SH33): the bending at it is measured
## against the share of her strength it keeps. Ship-local metres (D6); est. for every ship.

@export var name: StringName
@export var x: float
## The share of her strength (GirderStrength) her hull keeps here, 0…1.
@export var share: float = 1.0
