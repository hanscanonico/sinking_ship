class_name SnapshotDigest
extends RefCounted
## The digest of a match (D4): the snapshot, walked through its records' field
## tables (SnapshotField) and each field rounded at its kind's quantum, folded in every
## RATE ticks and at the end. A field is in unless its row leaves it out, with its
## reason. Same seed + same input log on the same build and platform ⇒ the same digest.

var _hash: String = ""


## Folds [param snapshot] in when its tick is on the digest's beat, or when
## [param final] says it is the match's last.
func add(snapshot: Dictionary, final: bool = false) -> void:
	if final or int(snapshot["tick"]) % Ticks.RATE == 0:
		_hash = (_hash + quantized(snapshot)).sha256_text()


func hex() -> String:
	return _hash


## [param snapshot]'s digested fields, each at its quantum, as text.
static func quantized(snapshot: Dictionary) -> String:
	return _record(MatchState.FIELDS, snapshot)


static func _record(fields: Array, record: Dictionary) -> String:
	var parts := PackedStringArray()
	for row: Dictionary in fields:
		if SnapshotField.digested(row):
			parts.append(_field(row, record[SnapshotField.key_of(row)]))
	return "(%s)" % ",".join(parts)


static func _field(row: Dictionary, value: Variant) -> String:
	var kind: SnapshotField.Kind = row["kind"]
	var quantum := SnapshotField.quantum(kind)
	match kind:
		SnapshotField.Kind.BOOL:
			return str(int(value))
		SnapshotField.Kind.LENGTHS, SnapshotField.Kind.SPEEDS:
			var vector: Vector3 = value
			return _list([vector.x, vector.y, vector.z], quantum)
		SnapshotField.Kind.AMOUNTS:
			return _list(Array(value as PackedFloat64Array), quantum)
		SnapshotField.Kind.INTS:
			return _list(value, quantum)
		SnapshotField.Kind.RECORDS:
			var records := PackedStringArray()
			for entry: Dictionary in value:
				records.append(_record(row["fields"], entry))
			return "[%s]" % "".join(records)
	if quantum > 0.0:
		return str(roundi(float(value) / quantum))
	return str(value)


static func _list(values: Array, quantum: float) -> String:
	var text := PackedStringArray()
	for value: Variant in values:
		text.append(str(roundi(float(value) / quantum)) if quantum > 0.0 else str(value))
	return "[%s]" % ",".join(text)
