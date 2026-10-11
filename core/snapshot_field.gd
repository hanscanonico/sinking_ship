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
## told apart, 0 for one kept exactly. A field kept at a quantum is its whole quanta
## (quanta) to the digest and the wire alike; the wire (WireCodec) maps them, and every
## other kind, to bytes.

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


## Whether a field of [param kind] is kept at a quantum, as whole quanta (quanta),
## rather than exactly.
static func quantized(kind: Kind) -> bool:
	return quantum(kind) > 0.0


## How many quanta a field of quantized [param kind] comes to: 1 for a number, 3 for a
## vector, -1 for a list of amounts, whose own length says.
static func quanta_count(kind: Kind) -> int:
	match kind:
		Kind.LENGTHS, Kind.SPEEDS:
			return 3
		Kind.AMOUNTS:
			return -1
	return 1


## [param value], a field of quantized [param kind], as whole quanta — what the digest
## folds in and the wire carries: the number, the vector's x, y and z, or each amount.
static func quanta(kind: Kind, value: Variant) -> PackedInt64Array:
	var unit := quantum(kind)
	var whole := PackedInt64Array()
	match kind:
		Kind.LENGTHS, Kind.SPEEDS:
			var vector: Vector3 = value
			whole.append(roundi(vector.x / unit))
			whole.append(roundi(vector.y / unit))
			whole.append(roundi(vector.z / unit))
		Kind.AMOUNTS:
			for amount: float in value as PackedFloat64Array:
				whole.append(roundi(amount / unit))
		_:
			whole.append(roundi(float(value) / unit))
	return whole


## The field of quantized [param kind] that [param whole] quanta make: quanta, undone.
static func from_quanta(kind: Kind, whole: PackedInt64Array) -> Variant:
	var unit := quantum(kind)
	match kind:
		Kind.LENGTHS, Kind.SPEEDS:
			return Vector3(whole[0] * unit, whole[1] * unit, whole[2] * unit)
		Kind.AMOUNTS:
			var amounts := PackedFloat64Array()
			for count: int in whole:
				amounts.append(count * unit)
			return amounts
	return whole[0] * unit


## The snapshot key of [param row]: its "key", else its variable's name.
static func key_of(row: Dictionary) -> String:
	return row.get("key", row["name"])


## Whether the digest folds in [param row]'s field.
static func digested(row: Dictionary) -> bool:
	return row.get("digest", true)
