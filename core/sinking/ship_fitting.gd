class_name ShipFitting
extends Resource
## Something the ship carries that the sinking acts on (§5b.2): from SH27 her
## lifeboats — which side they hang on, where along her, and the list past which those
## on the high side cannot be swung out and lowered (15° on old davits, 20° under
## modern rules). That is a label and a sight, never a rule (§5b.1). From SH31 the
## fittings the physics can fail (§5b.1, "Things that give way"): a funnel, whose stays
## hold it until she lists or trims past what they take, the sea reaches its foot or —
## from SH33 — a hinge forms beside it; her generator, which lights her while its foot
## is dry enough and she stands within what machinery tolerates, then her emergency
## power for its minutes; and her pumps, which lift water out of their cell while the
## generator runs. Ship-local metres (D6).

enum Kind { LIFEBOAT, FUNNEL, GENERATOR, PUMP }

@export var kind: Kind
@export var name: StringName
## 1 for her starboard side (+z), -1 for her port side.
@export var side: int = 1
@export var x: float
## LIFEBOAT: the list, in degrees, past which the high side's boats are useless.
## FUNNEL: the list past which its stays let it go; GENERATOR: past which it stops.
@export var list_limit_deg: float
## FUNNEL, GENERATOR: the trim, in degrees, past which the same.
@export var trim_limit_deg: float
## FUNNEL, GENERATOR: where its foot stands.
@export var base: Vector3
## FUNNEL: how tall it stands over its foot and how wide round it is, its radius, in
## metres; the seconds it takes to come down once its stays let it go; and the platforms,
## by name, too light to take it — a roof it lands on gives way under it.
@export var height: float
@export var radius: float
@export var fall_time: float
@export var crushes: Array[StringName] = []
## GENERATOR: the water this deep over its foot drowns it, in metres, for good; the
## degrees under its limits she must come back to before it runs again; the minutes its
## emergency power lasts once it stops; and the cells, by name, that power lights.
@export var drowns_at: float
@export var recovers_deg: float
@export var emergency_minutes: float
@export var emergency_cells: Array[StringName] = []
## GENERATOR, PUMP: the cell it stands in, by name. PUMP: the water it lifts out of it
## to the sea, in m³ a second, while the generator runs.
@export var cell: StringName
@export var rate: float


## Every reason this fitting cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if name.is_empty() or absi(side) != 1:
		found.append("structure: a fitting needs a name and a side, 1 or -1")
	if kind == Kind.LIFEBOAT and (list_limit_deg <= 0.0 or list_limit_deg >= 90.0):
		found.append("structure: lifeboat %s's list limit must be within 0…90°" % name)
	if kind == Kind.FUNNEL or kind == Kind.GENERATOR:
		if list_limit_deg <= 0.0 or list_limit_deg >= 90.0 or trim_limit_deg <= 0.0:
			found.append("structure: %s's limits must be within 0…90°" % name)
		elif trim_limit_deg >= 90.0:
			found.append("structure: %s's limits must be within 0…90°" % name)
	if kind == Kind.FUNNEL and (height <= 0.0 or radius <= 0.0 or fall_time <= 0.0):
		found.append("structure: funnel %s needs a height, a radius and a fall" % name)
	if kind == Kind.GENERATOR:
		if drowns_at <= 0.0 or recovers_deg < 0.0 or emergency_minutes < 0.0:
			found.append("structure: generator %s needs a depth, a margin and minutes" % name)
		if cell.is_empty():
			found.append("structure: generator %s stands in no cell" % name)
	if kind == Kind.PUMP and (cell.is_empty() or rate <= 0.0):
		found.append("structure: pump %s needs a cell and a rate" % name)
	return found
