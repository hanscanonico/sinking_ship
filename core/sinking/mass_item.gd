class_name MassItem
extends Resource
## A share of the ship's weight (§5b.2): how heavy, where its centre is, and the
## stretch of hull it bears on. Ship-local metres (D6).

@export var name: StringName
## In kilograms.
@export var mass: float
@export var centre: Vector3
## The x it bears on the hull from and to.
@export var along: Vector2


## Every reason this item cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if mass <= 0.0:
		found.append("structure: mass item %s must weigh something" % name)
	if along.y <= along.x or centre.x < along.x or centre.x > along.y:
		found.append("structure: mass item %s must bear on the hull about its centre" % name)
	return found
