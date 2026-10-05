class_name ShipFitting
extends Resource
## Something the ship carries that the sinking acts on (§5b.2): from SH27 her
## lifeboats — which side they hang on, where along her, and the list past which those
## on the high side cannot be swung out and lowered (15° on old davits, 20° under
## modern rules). That is a label and a sight, never a rule (§5b.1). Ship-local metres
## (D6).

enum Kind { LIFEBOAT }

@export var kind: Kind
@export var name: StringName
## 1 for her starboard side (+z), -1 for her port side.
@export var side: int = 1
@export var x: float
## LIFEBOAT: the list, in degrees, past which the high side's boats are useless.
@export var list_limit_deg: float


## Every reason this fitting cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if name.is_empty() or absi(side) != 1:
		found.append("structure: a fitting needs a name and a side, 1 or -1")
	if kind == Kind.LIFEBOAT and (list_limit_deg <= 0.0 or list_limit_deg >= 90.0):
		found.append("structure: lifeboat %s's list limit must be within 0…90°" % name)
	return found
