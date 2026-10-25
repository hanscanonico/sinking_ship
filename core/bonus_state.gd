class_name BonusState
extends RefCounted
## A bonus aboard (#307), as the match has it: which of the plan's bonuses it is (BonusPlan),
## its kind and the spot it lies at. It never moves: it lies at its spot until it is taken,
## or lost to the sea (#311). Every field is in the snapshot (D5).

## Its index in the match's bonus plan; -1 for one put aboard by hand.
var planned: int
## Its kind, by its index in the bonus rules' kinds (BonusRules.kinds).
var kind: int
## Where it lies, by its index in [member ShipLayout.bonus_spots].
var spot: int


func _init(plan_index: int = -1, kind_index: int = 0, spot_index: int = 0) -> void:
	planned = plan_index
	kind = kind_index
	spot = spot_index


## What to_dict() carries, one row per key in its order (SnapshotField).
const FIELDS := [
	{"name": "planned", "kind": SnapshotField.Kind.INT},
	{"name": "kind", "kind": SnapshotField.Kind.INT},
	{"name": "spot", "kind": SnapshotField.Kind.INT},
]


func to_dict() -> Dictionary:
	return {"planned": planned, "kind": kind, "spot": spot}


static func from_dict(entry: Dictionary) -> BonusState:
	return BonusState.new(entry["planned"], entry["kind"], entry["spot"])
