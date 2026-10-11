class_name SnapshotField
extends RefCounted
## How a snapshot record's fields are persisted (D5). Each record — MatchState,
## PlayerState, PropState and SimEvent — declares FIELDS beside its to_dict() and
## from_dict(): one row per key to_dict() gives, in its order, written
## {"name": the variable, "kind": a Kind}, with "key" where the snapshot's key is not
## the variable's name and "fields", the nested record's table, on a RECORDS row. A row
## with no variable of its own (a derived or composite field) names its key.
##
## Every field is in the digest (SnapshotDigest, D4) at its kind's quantum, unless its
## row says "digest": false and gives the reason in "why".
##
## A kind's quantum is the sim's precision for it: the finest a value of that kind is
## told apart, 0 for one kept exactly. The wire (WireCodec) maps each kind to bytes.

## LENGTHS and SPEEDS are Vector3s; AMOUNTS a PackedFloat64Array and INTS a list of
## ints; NAME a StringName; RECORDS a list of the row's "fields" records.
enum Kind {
	INT,
	BOOL,
	LENGTH,
	LENGTHS,
	SPEEDS,
	ANGLE,
	DEGREES,
	AMOUNT,
	AMOUNTS,
	NAME,
	INTS,
	RECORDS,
}

## 1 mm.
const LENGTH_QUANTUM := 0.001
## 1 cm/s.
const SPEED_QUANTUM := 0.01
## 0.01°, in radians.
const ANGLE_QUANTUM := TAU / 36000.0
## 0.01°.
const DEGREES_QUANTUM := 0.01
## Stamina, cold seconds and a railing's hits left.
const AMOUNT_QUANTUM := 0.001


## The finest a field of [param kind] is told apart; 0 for one kept exactly.
static func quantum(kind: Kind) -> float:
	match kind:
		Kind.LENGTH, Kind.LENGTHS:
			return LENGTH_QUANTUM
		Kind.SPEEDS:
			return SPEED_QUANTUM
		Kind.ANGLE:
			return ANGLE_QUANTUM
		Kind.DEGREES:
			return DEGREES_QUANTUM
		Kind.AMOUNT, Kind.AMOUNTS:
			return AMOUNT_QUANTUM
	return 0.0


## The snapshot key of [param row]: its "key", else its variable's name.
static func key_of(row: Dictionary) -> String:
	return row.get("key", row["name"])


## Whether the digest folds in [param row]'s field.
static func digested(row: Dictionary) -> bool:
	return row.get("digest", true)
