class_name WireCodec
extends RefCounted
## The wire format (D11), one codec per match: every packet opens with the protocol
## version, the first HASH_BYTES of the match's hash (match_hash) and its kind, and a
## packet of another version or another match's hash is refused. The room protocol's kinds
## (SH12) ride the same opening — the sinking's timeline among them (SH28) —; RoomCodec
## reads what follows it.
##
## An input packet carries a seat's last few frames, the newest last, so a lost
## packet costs nothing while a later one arrives (D3's redundancy). A snapshot
## carries the match quantized, each field at its kind's quantum (SnapshotField) —
## 1 mm, 1 cm/s, 0.01° — with the client's ack: every number an int64, in the order of
## the records' own tables (MatchState.FIELDS and those it nests), the lot compressed.
## The engine packs and compresses, so the GDScript here only walks the fields, once
## each way, every beat — a prop's only when it is not as it was (Kept): a saloon of
## furniture at rest costs a beat next to nothing. Seats are listed by id, so a snapshot
## of only some is valid
## (SH22). A key a record's to_dict() gains and its table does not is pushed as an
## error here and lost on the wire, which test_wire_codec's round trip, walking the
## snapshot's own keys, fails on (R2).

## 7: BEGIN carries the match's pace, so a client of 6 — which would build its match
## paced and play the server's fast one out of step — is refused VERSION at its HELLO.
## 8: a prop's holder rides in the snapshot and a frame may press Grab (#273), so a client
## of 7, whose rules have neither, is refused VERSION at its HELLO.
const PROTOCOL_VERSION := 8
## The build of what plays a match — core/, ai/ and net/ — bumped by hand whenever a
## change there would play the same data differently: part of every match's hash, so
## two builds that would not agree are refused as other data.
const SIM_BUILD := 8
const HASH_BYTES := 8
## How far apart, in quanta, two values within_quantum may be: a rounding on each side,
## and a single-precision Vector3's own error at a few tens of metres.
const QUANTA_APART := 1.01
const COMPRESSION := FileAccess.COMPRESSION_ZSTD
## The most a snapshot unpacks to, so a forged size cannot ask for more.
const MOST_BYTES := 1 << 20
## How many props in a row a codec asks at once whether they are as it last had them
## (Kept): a laid saloon at rest is a few such questions, not one a piece.
const KEPT_RUN := 16

enum Kind {
	INPUT,
	SNAPSHOT,
	HELLO,
	WELCOME,
	REFUSED,
	CREATE,
	JOIN,
	LEAVE,
	START,
	ROSTER,
	BEGIN,
	PING,
	PONG,
	TIMELINE,
}
## Why a packet is not one of this protocol and match: too short to tell or of no kind
## there is, of another protocol version, or of another match's data.
enum Mismatch { NONE, MALFORMED, VERSION, DATA }

## Each section — &"snapshot" and the key of every list of records in it — as the codec
## walks it: per field its key, its kind and, for a list of records, their walk. Built
## once from the records' tables.
static var _walks := {}


## Reads a packet, noting rather than failing when it runs short.
class Reader:
	extends RefCounted
	var ok := true
	var _bytes: PackedByteArray
	var _at := 0

	func _init(bytes: PackedByteArray) -> void:
		_bytes = bytes

	func byte() -> int:
		if _at >= _bytes.size():
			ok = false
			return 0
		_at += 1
		return _bytes[_at - 1]

	func bytes(count: int) -> PackedByteArray:
		if _at + count > _bytes.size():
			ok = false
			return PackedByteArray()
		_at += count
		return _bytes.slice(_at - count, _at)

	## A zigzag varint: any 64-bit int, small ones in a byte.
	func integer() -> int:
		var zigzag := 0
		var shift := 0
		while ok and shift < 64:
			var next := byte()
			zigzag |= (next & 0x7F) << shift
			if next & 0x80 == 0:
				break
			shift += 7
		return ((zigzag >> 1) & 0x7FFFFFFFFFFFFFFF) ^ -(zigzag & 1)

	## Four bytes, the low first.
	func u32() -> int:
		return byte() | byte() << 8 | byte() << 16 | byte() << 24

	func finished() -> bool:
		return ok and _at == _bytes.size()


## A snapshot's numbers, in the tables' order, put or taken one at a time.
class Values:
	extends RefCounted
	var ints := PackedInt64Array()
	var ok := true
	var _at := 0

	func put(value: int) -> void:
		ints.append(value)

	func take() -> int:
		if _at >= ints.size():
			ok = false
			return 0
		_at += 1
		return ints[_at - 1]

	## The next [param count] numbers, taken at once; none where the snapshot runs short.
	func take_run(count: int) -> PackedInt64Array:
		if _at + count > ints.size():
			ok = false
			return PackedInt64Array()
		_at += count
		return ints.slice(_at - count, _at)

	func finished() -> bool:
		return ok and _at == ints.size()


## A snapshot's props as a codec last put or took them: each entry, and the numbers they
## all came to, prop after prop. A crate at rest is one entry from snapshot to snapshot
## (PropState.to_dict): put, a run of KEPT_RUN props alike — each entry as it was, by
## == — is the numbers it came to then, unwalked; and taken, a prop whose numbers come as
## they came before is the entry made of them then — what a client's history, prediction
## and view pass over by is_same. Both ends compare a run at once, in the engine.
class Kept:
	extends RefCounted
	var entries: Array[Dictionary] = []
	var numbers := PackedInt64Array()


var _hash: PackedByteArray
var _sent_props := Kept.new()
var _taken_props := Kept.new()


## A codec for the match whose match_hash() is [param data_hash].
func _init(data_hash: String) -> void:
	_hash = data_hash.substr(0, HASH_BYTES * 2).hex_decode()


## The hash both ends of [param config]'s match must share to play it alike: its data
## (MatchConfig.data_hash), [param net_rules] and SIM_BUILD.
static func match_hash(config: MatchConfig, net_rules: NetRules) -> String:
	var described := PackedStringArray([str(SIM_BUILD), config.data_hash()])
	for property: Dictionary in net_rules.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var field: String = property["name"]
			described.append("%s=%s" % [field, var_to_str(net_rules.get(field))])
	return "|".join(described).sha256_text()


## The packet carrying [param frames], one seat's, for consecutive ticks, oldest
## first.
func encode_inputs(frames: Array[InputFrame]) -> PackedByteArray:
	var out := header(Kind.INPUT)
	_put_int(out, frames[-1].tick if not frames.is_empty() else 0)
	out.put_u8(frames.size())
	for frame: InputFrame in frames:
		out.put_8(clampi(frame.move.x, -InputFrame.AXIS_MAX, InputFrame.AXIS_MAX))
		out.put_8(clampi(frame.move.y, -InputFrame.AXIS_MAX, InputFrame.AXIS_MAX))
		out.put_u16(posmod(frame.look_yaw, InputFrame.YAW_STEPS))
		out.put_u8(frame.buttons & 0xFF)
	return out.data_array


## The frames an input packet carries, oldest first, for [param seat]; empty when it
## is not an input packet of this match and protocol.
func decode_inputs(bytes: PackedByteArray, seat: int) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	var reader := open(bytes, Kind.INPUT)
	if reader == null:
		return frames
	var newest := reader.integer()
	var count := reader.byte()
	for index in count:
		var move := Vector2i(_signed_byte(reader.byte()), _signed_byte(reader.byte()))
		var look := reader.byte() | reader.byte() << 8
		var buttons := reader.byte()
		frames.append(InputFrame.new(seat, newest - count + 1 + index, move, buttons, look))
	if not reader.finished():
		frames.clear()
	return frames


## The packet carrying [param snapshot], whatever seats it lists, to a client whose
## input the host has applied up to [param ack] and heard up to [param heard],
## [param early] ticks ahead of need.
func encode_snapshot(snapshot: Dictionary, ack: int, heard: int, early: int) -> PackedByteArray:
	var values := Values.new()
	values.put(ack)
	values.put(heard)
	values.put(early)
	_put_record(values, snapshot, _walk(&"snapshot"), _sent_props)
	var packed := values.ints.to_byte_array()
	var squeezed := packed.compress(COMPRESSION)
	var out := header(Kind.SNAPSHOT)
	out.put_u32(packed.size())
	out.put_u32(squeezed.size())
	out.put_data(squeezed)
	return out.data_array


## The snapshot packet [param bytes] holds; null when it is not one of this match
## and protocol.
func decode_snapshot(bytes: PackedByteArray) -> SnapshotPacket:
	var reader := open(bytes, Kind.SNAPSHOT)
	if reader == null:
		return null
	var size := reader.u32()
	var squeezed := reader.bytes(reader.u32())
	if not reader.finished() or size % 8 != 0 or size > MOST_BYTES:
		return null
	var packed := squeezed.decompress(size, COMPRESSION)
	if packed.size() != size:
		return null
	var values := Values.new()
	values.ints = packed.to_int64_array()
	var ack := values.take()
	var heard := values.take()
	var early := values.take()
	var snapshot := _record(values, _walk(&"snapshot"), _taken_props)
	if not values.finished():
		return null
	return SnapshotPacket.new(snapshot, ack, heard, early)


## What [param bytes] is, or -1 when it is no packet of this match and protocol.
func kind_of(bytes: PackedByteArray) -> int:
	if mismatch(bytes) != Mismatch.NONE:
		return -1
	return bytes[1 + HASH_BYTES]


## How [param bytes] opens against this protocol and match: NONE when it is one of
## theirs. The version is read first, so any build can tell another's packet apart.
func mismatch(bytes: PackedByteArray) -> Mismatch:
	if bytes.size() < 2 + HASH_BYTES:
		return Mismatch.MALFORMED
	if bytes[0] != PROTOCOL_VERSION:
		return Mismatch.VERSION
	if bytes.slice(1, 1 + HASH_BYTES) != _hash:
		return Mismatch.DATA
	if bytes[1 + HASH_BYTES] >= Kind.size():
		return Mismatch.MALFORMED
	return Mismatch.NONE


## The finest a snapshot's [param key] under [param section] (&"snapshot",
## &"seats", &"props" or &"events") travels at: 0 for one carried exactly, -1 for
## one the wire does not carry at all.
static func quantum(section: StringName, key: String) -> float:
	for field: Array in _walk(section):
		if field[0] == key:
			return SnapshotField.quantum(field[1])
	return -1.0


## Whether two records of [param section] (&"seats" or &"props") are one state as
## far as the wire can tell: every count and flag the same, every number within a
## quantum — one rounding on each side.
static func within_quantum(section: StringName, one: Dictionary, other: Dictionary) -> bool:
	for field: Array in _walk(section):
		if not _within(one[field[0]], other[field[0]], SnapshotField.quantum(field[1])):
			return false
	return true


## Whether [param one] and [param other], two values of a snapshot's [param key] under
## [param section], are one as far as the wire can tell, as within_quantum.
static func field_within_quantum(
	section: StringName, key: String, one: Variant, other: Variant
) -> bool:
	return _within(one, other, quantum(section, key))


static func _within(a: Variant, b: Variant, quantum: float) -> bool:
	if quantum == 0.0:
		return a == b
	if a is Vector3:
		var off: Vector3 = (a as Vector3) - (b as Vector3)
		return maxf(absf(off.x), maxf(absf(off.y), absf(off.z))) <= quantum * QUANTA_APART
	if a is PackedFloat64Array:
		var these: PackedFloat64Array = a
		var those: PackedFloat64Array = b
		if these.size() != those.size():
			return false
		for index in these.size():
			if absf(these[index] - those[index]) > quantum * QUANTA_APART:
				return false
		return true
	return absf(float(a) - float(b)) <= quantum * QUANTA_APART


static func _walk(section: StringName) -> Array:
	if _walks.is_empty():
		_walks[&"snapshot"] = _compiled(MatchState.FIELDS)
	return _walks[section]


## [param fields], a record's table, as the codec walks it; each list of records in it
## is a section of its own, by its key.
static func _compiled(fields: Array) -> Array:
	var walk := []
	for row: Dictionary in fields:
		var key := SnapshotField.key_of(row)
		var nested := []
		if row["kind"] == SnapshotField.Kind.RECORDS:
			nested = _compiled(row["fields"])
			_walks[StringName(key)] = nested
		walk.append([key, row["kind"], nested])
	return walk


## A packet of [param kind], opened: what follows is the caller's to put.
func header(kind: Kind) -> StreamPeerBuffer:
	var out := StreamPeerBuffer.new()
	out.big_endian = false
	out.put_u8(PROTOCOL_VERSION)
	out.put_data(_hash)
	out.put_u8(kind)
	return out


## A reader past the opening of [param bytes]; null when it is not a packet of
## [param kind] of this match and protocol.
func open(bytes: PackedByteArray, kind: Kind) -> Reader:
	if kind_of(bytes) != kind:
		return null
	var reader := Reader.new(bytes)
	reader.bytes(2 + HASH_BYTES)
	return reader


static func _signed_byte(value: int) -> int:
	return value - 256 if value >= 128 else value


static func _put_int(out: StreamPeerBuffer, value: int) -> void:
	var zigzag := (value << 1) ^ (value >> 63)
	while true:
		var low := zigzag & 0x7F
		zigzag = (zigzag >> 7) & 0x01FFFFFFFFFFFFFF
		if zigzag == 0:
			out.put_u8(low)
			return
		out.put_u8(low | 0x80)


## [param record]'s numbers, walked as [param walk]; its props, where it is a snapshot,
## as [param kept] has them.
static func _put_record(values: Values, record: Dictionary, walk: Array, kept: Kept = null) -> void:
	if record.size() != walk.size():
		push_error("wire: a record of %s has keys the codec does not carry" % [record.keys()])
	for field: Array in walk:
		if field[1] == SnapshotField.Kind.INT:
			values.ints.append(record.get(field[0]))
		elif kept != null and field[0] == "props":
			_put_kept(values, record.get(field[0]), field[2], kept)
		else:
			_put_field(values, record.get(field[0]), field)


## [param records], the props, as the numbers [param kept] last put for them: only a prop
## not as it was is walked as [param walk], into them, and kept for the next.
static func _put_kept(values: Values, records: Array, walk: Array, kept: Kept) -> void:
	var count := records.size()
	var width := _width(walk)
	values.put(count)
	if kept.entries.size() != count:
		kept.entries.resize(count)
		kept.numbers.resize(count * width)
	for first in range(0, count, KEPT_RUN):
		var last := mini(first + KEPT_RUN, count)
		if records.slice(first, last) == kept.entries.slice(first, last):
			continue
		for index in range(first, last):
			var record: Dictionary = records[index]
			if record == kept.entries[index]:
				continue
			var walked := Values.new()
			_put_record(walked, record, walk)
			for at in width:
				kept.numbers[index * width + at] = walked.ints[at]
			kept.entries[index] = record
	values.ints.append_array(kept.numbers)


static func _put_field(values: Values, value: Variant, field: Array) -> void:
	var kind: SnapshotField.Kind = field[1]
	match kind:
		SnapshotField.Kind.INT:
			values.put(value)
		SnapshotField.Kind.BOOL:
			values.put(1 if value else 0)
		SnapshotField.Kind.NAME:
			var text := String(value).to_utf8_buffer()
			values.put(text.size())
			for code: int in text:
				values.put(code)
		SnapshotField.Kind.INTS:
			var ints: Array = value
			values.put(ints.size())
			for item: int in ints:
				values.put(item)
		SnapshotField.Kind.RECORDS:
			var records: Array = value
			values.put(records.size())
			for record: Dictionary in records:
				_put_record(values, record, field[2])
		_:
			var quanta := SnapshotField.quanta(kind, value)
			if SnapshotField.quanta_count(kind) < 0:
				values.put(quanta.size())
			for whole: int in quanta:
				values.put(whole)


## The record [param values] hold next, walked as [param walk]; its props, where it is a
## snapshot, as [param kept] has them.
static func _record(values: Values, walk: Array, kept: Kept = null) -> Dictionary:
	var record := {}
	for field: Array in walk:
		# Most fields are counts and enums: read here, without a call per field.
		if field[1] == SnapshotField.Kind.INT:
			record[field[0]] = values.take()
		elif kept != null and field[0] == "props":
			record[field[0]] = _take_kept(values, field[2], kept)
		else:
			record[field[0]] = _field(values, field)
	return record


## The props [param values] hold next: each whose numbers come as [param kept] last took
## them the entry made of them then, every other walked as [param walk] and kept for the
## next.
static func _take_kept(values: Values, walk: Array, kept: Kept) -> Array[Dictionary]:
	var count := _count(values)
	var width := _width(walk)
	var numbers := values.take_run(count * width)
	if not values.ok:
		var none: Array[Dictionary] = []
		return none
	if kept.entries.size() != count or kept.numbers.size() != numbers.size():
		kept.entries.resize(count)
		kept.numbers = PackedInt64Array()
	var was := kept.numbers
	for first in range(0, count, KEPT_RUN):
		var last := mini(first + KEPT_RUN, count)
		var from := first * width
		var to := last * width
		if not was.is_empty() and numbers.slice(from, to) == was.slice(from, to):
			continue
		for index in range(first, last):
			var run := numbers.slice(index * width, (index + 1) * width)
			if not was.is_empty() and run == was.slice(index * width, (index + 1) * width):
				continue
			var walked := Values.new()
			walked.ints = run
			kept.entries[index] = _record(walked, walk)
	kept.numbers = numbers
	return kept.entries.duplicate()


## How many numbers a record walked as [param walk] comes to: every field of a prop is of
## a size of its own.
static func _width(walk: Array) -> int:
	var width := 0
	for field: Array in walk:
		var kind: SnapshotField.Kind = field[1]
		if kind == SnapshotField.Kind.INT or kind == SnapshotField.Kind.BOOL:
			width += 1
			continue
		assert(
			SnapshotField.quantized(kind) and SnapshotField.quanta_count(kind) > 0,
			"every field of a prop of a size of its own"
		)
		width += SnapshotField.quanta_count(kind)
	return width


static func _field(values: Values, field: Array) -> Variant:
	var kind: SnapshotField.Kind = field[1]
	match kind:
		SnapshotField.Kind.BOOL:
			return values.take() != 0
		SnapshotField.Kind.NAME:
			var text := PackedByteArray()
			for index in _count(values):
				text.append(values.take())
			return StringName(text.get_string_from_utf8())
		SnapshotField.Kind.INTS:
			var ints := []
			for index in _count(values):
				ints.append(values.take())
			return ints
		SnapshotField.Kind.RECORDS:
			var records: Array[Dictionary] = []
			for index in _count(values):
				records.append(_record(values, field[2]))
			return records
		SnapshotField.Kind.INT:
			return values.take()
	var quanta := PackedInt64Array()
	var count := SnapshotField.quanta_count(kind)
	if count < 0:
		count = _count(values)
	for index in count:
		quanta.append(values.take())
	return SnapshotField.from_quanta(kind, quanta)


## A list's length; a negative or an absurd one breaks the packet.
static func _count(values: Values) -> int:
	var count := values.take()
	if count < 0 or count > 0xFFFF:
		values.ok = false
		return 0
	return count
