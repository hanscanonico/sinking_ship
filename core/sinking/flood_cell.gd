class_name FloodCell
extends Resource
## A box of the ship that holds its own water and its own air (§5b.1): part of a
## compartment, an enclosed room above, or a void nobody walks in. Each room lies in
## exactly one cell. Ship-local metres (D6).

enum Kind { ACCOMMODATION, MACHINERY, CARGO, STORES, VOID, BUNKER, OPEN_WELL }

@export var name: StringName
## The box's least and greatest corners.
@export var low: Vector3
@export var high: Vector3
@export var kind: Kind
## The share of the box water can fill once furniture, machinery or cargo take their
## part; below 0, its kind's (SeaPhysics.permeability).
@export var permeability: float = -1.0
## The share of the box inside the hull, where the box pokes outside its curve.
@export var shape: float = 1.0
## The ShipRooms inside it, by name.
@export var rooms: Array[StringName] = []
## The area its air leaks out through — rivets, seams, vents — in m².
@export var leak_area: float


## The space inside the hull it holds, in m³: its box less what pokes outside.
func volume() -> float:
	return (float(high.x) - low.x) * (float(high.y) - low.y) * (float(high.z) - low.z) * shape


## Its permeability, its kind's from [param sea] when it states none.
func permeability_in(sea: SeaPhysics) -> float:
	return permeability if permeability >= 0.0 else sea.permeability(kind)


## Every reason this cell cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if name.is_empty() or name in [ShipOpening.SEA, ShipOpening.SKY]:
		found.append("structure: a cell needs a name of its own, not %s" % name)
	if high.x <= low.x or high.y <= low.y or high.z <= low.z:
		found.append("structure: cell %s has no volume" % name)
	if permeability == 0.0 or permeability > 1.0:
		found.append("structure: cell %s's permeability must be within 0…1" % name)
	if shape <= 0.0 or shape > 1.0:
		found.append("structure: cell %s's shape must be within 0…1" % name)
	if leak_area < 0.0:
		found.append("structure: cell %s's leak area must not be negative" % name)
	return found
