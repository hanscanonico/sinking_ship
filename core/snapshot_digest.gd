class_name SnapshotDigest
extends RefCounted
## The digest of a match (D4): the snapshot, walked through its records' field
## tables (SnapshotField) and each field rounded at its kind's quantum, folded in every
## RATE ticks and at the end. A field is in unless its row leaves it out, with its
## reason. Same seed + same input log on the same build and platform ⇒ the same digest.
## A record of a list the last snapshot folded in shared — a crate at rest, the same
## entry from snapshot to snapshot (PropState.to_dict) — is its text again, unwalked.

var _hash: String = ""
## Per list of records, by its key: the records last folded in, and their text.
var _texts := {}


## Folds [param snapshot] in when its tick is on the digest's beat, or when
## [param final] says it is the match's last.
func add(snapshot: Dictionary, final: bool = false) -> void:
	if final or int(snapshot["tick"]) % Ticks.RATE == 0:
		_hash = (_hash + _record(MatchState.FIELDS, snapshot, _texts)).sha256_text()


func hex() -> String:
	return _hash


## [param snapshot]'s digested fields, each at its quantum, as text.
static func quantized(snapshot: Dictionary) -> String:
	return _record(MatchState.FIELDS, snapshot, {})


## [param record]'s digested fields in [param fields]' order, as text; [param texts] the
## lists of records last made text, by key, and where this one's go.
static func _record(fields: Array, record: Dictionary, texts: Dictionary) -> String:
	var parts := PackedStringArray()
	for row: Dictionary in fields:
		if SnapshotField.digested(row):
			parts.append(_field(row, record[SnapshotField.key_of(row)], texts))
	return "(%s)" % ",".join(parts)


static func _field(row: Dictionary, value: Variant, texts: Dictionary) -> String:
	var kind: SnapshotField.Kind = row["kind"]
	match kind:
		SnapshotField.Kind.BOOL:
			return str(int(value))
		SnapshotField.Kind.INTS:
			return _list(value)
		SnapshotField.Kind.RECORDS:
			var key: String = row["name"]
			var last: Array = texts.get(key, [[], PackedStringArray()])
			var were: Array = last[0]
			var was: PackedStringArray = last[1]
			var records := PackedStringArray()
			for index in (value as Array).size():
				var entry: Dictionary = value[index]
				if index < were.size() and is_same(were[index], entry):
					records.append(was[index])
				else:
					records.append(_record(row["fields"], entry, {}))
			texts[key] = [value, records]
			return "[%s]" % "".join(records)
	if not SnapshotField.quantized(kind):
		return str(value)
	var quanta := SnapshotField.quanta(kind, value)
	if SnapshotField.quanta_count(kind) == 1:
		return str(quanta[0])
	return _list(Array(quanta))


static func _list(values: Array) -> String:
	var text := PackedStringArray()
	for value: Variant in values:
		text.append(str(value))
	return "[%s]" % ",".join(text)
