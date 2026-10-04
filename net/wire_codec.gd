class_name WireCodec
extends RefCounted
## The wire format (D11), one codec per match: every packet opens with the protocol
## version, the first HASH_BYTES of the match's hash (match_hash) and its kind, and a
## packet of another version or another match's hash is refused. The room protocol's kinds
## (SH12) ride the same opening; RoomCodec reads what follows it.
##
## An input packet carries a seat's last few frames, the newest last, so a lost
## packet costs nothing while a later one arrives (D3's redundancy). A snapshot
## carries the match quantized — 1 mm, 1 cm/s, 0.01°, the rest of its numbers to
## AMOUNT — with the client's ack: every number an int64, in the tables' order, the
## lot compressed. The engine packs and compresses, so the GDScript here only walks
## the fields, once each way, every beat. Seats are listed by id, so a snapshot of
## only some is valid (SH22). The fields are the tables below: a key the snapshot
## gains and they do not is pushed as an error here and lost on the wire, which
## test_wire_codec's round trip, walking the snapshot's own keys, fails on (R2).

const PROTOCOL_VERSION := 2
## The build of what plays a match — core/, ai/ and net/ — bumped by hand whenever a
## change there would play the same data differently: part of every match's hash, so
## two builds that would not agree are refused as other data.
const SIM_BUILD := 1
const HASH_BYTES := 8
const LENGTH_QUANTUM := 0.001
const SPEED_QUANTUM := 0.01
const ANGLE_QUANTUM := TAU / 36000.0
const DEGREES_QUANTUM := 0.01
const AMOUNT_QUANTUM := 0.001
## How far apart, in quanta, two values within_quantum may be: a rounding on each side,
## and a single-precision Vector3's own error at a few tens of metres.
const QUANTA_APART := 1.01
const COMPRESSION := FileAccess.COMPRESSION_ZSTD
## The most a snapshot unpacks to, so a forged size cannot ask for more.
const MOST_BYTES := 1 << 20

enum Kind {
	INPUT, SNAPSHOT, HELLO, WELCOME, REFUSED, CREATE, JOIN, LEAVE, START, ROSTER, BEGIN, PING, PONG
}
## Why a packet is not one of this protocol and match: too short to tell or of no kind
## there is, of another protocol version, or of another match's data.
enum Mismatch { NONE, MALFORMED, VERSION, DATA }

## How a field travels. LENGTHS and SPEEDS are Vector3s; INTS a list of ints and
## AMOUNTS a PackedFloat64Array; SEATS, PROPS and EVENTS lists of records.
enum Field {
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
	SEATS,
	PROPS,
	EVENTS,
}

## MatchState.to_dict().
const SNAPSHOT_FIELDS := [
	["v", Field.INT],
	["tick", Field.INT],
	["seed", Field.INT],
	["phase", Field.INT],
	["rng", Field.INT],
	["seats", Field.SEATS],
	["props", Field.PROPS],
	["railing_hp", Field.AMOUNTS],
	["events", Field.EVENTS],
]
## PlayerState.to_dict().
const SEAT_FIELDS := [
	["seat", Field.INT],
	["out", Field.BOOL],
	["place", Field.INT],
	["out_tick", Field.INT],
	["out_cause", Field.INT],
	["pos", Field.LENGTHS],
	["vel", Field.SPEEDS],
	["facing", Field.ANGLE],
	["surface", Field.INT],
	["state", Field.INT],
	["fall_from", Field.LENGTH],
	["jumped", Field.BOOL],
	["action", Field.INT],
	["action_ticks", Field.INT],
	["shove_spent", Field.BOOL],
	["shove_facing", Field.ANGLE],
	["charge", Field.INT],
	["bracing", Field.BOOL],
	["stamina", Field.AMOUNT],
	["stamina_wait", Field.INT],
	["exhausted", Field.BOOL],
	["stagger", Field.INT],
	["hitstop", Field.INT],
	["held_vel", Field.SPEEDS],
	["cold", Field.AMOUNT],
	["climb", Field.INT],
	["climb_to", Field.LENGTHS],
	["last_hit_by", Field.INT],
	["last_hit_at", Field.INT],
	["last_hit_crate", Field.INT],
	["prev_buttons", Field.INT],
	["last_input", Field.INTS],
]
## PropState.to_dict().
const PROP_FIELDS := [
	["prop", Field.INT],
	["state", Field.INT],
	["pos", Field.LENGTHS],
	["vel", Field.SPEEDS],
	["surface", Field.INT],
	["shoved_by", Field.INT],
	["shoved_at", Field.INT],
]
## SimEvent.to_dict().
const EVENT_FIELDS := [
	["kind", Field.INT],
	["tick", Field.INT],
	["seat", Field.INT],
	["place", Field.INT],
	["cause", Field.INT],
	["credit", Field.INT],
	["surface", Field.INT],
	["stagger", Field.INT],
	["target", Field.INT],
	["heel", Field.DEGREES],
	["platform", Field.NAME],
	["railing", Field.INT],
	["prop", Field.INT],
]


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

	func finished() -> bool:
		return ok and _at == ints.size()


var _hash: PackedByteArray


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
	_put_record(values, snapshot, SNAPSHOT_FIELDS)
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
	var snapshot := _record(values, SNAPSHOT_FIELDS)
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
	for field: Array in _section(section):
		if field[0] == key:
			return _quantum_of(field[1])
	return -1.0


## Whether two records of [param section] (&"seats" or &"props") are one state as
## far as the wire can tell: every count and flag the same, every number within a
## quantum — one rounding on each side.
static func within_quantum(section: StringName, one: Dictionary, other: Dictionary) -> bool:
	for field: Array in _section(section):
		if not _within(one[field[0]], other[field[0]], _quantum_of(field[1])):
			return false
	return true


## Whether [param one] and [param other], two values of a snapshot's [param key] under
## [param section], are one as far as the wire can tell, as within_quantum.
static func field_within_quantum(
	section: StringName, key: String, one: Variant, other: Variant
) -> bool:
	return _within(one, other, quantum(section, key))


static func _within(a: Variant, b: Variant, step: float) -> bool:
	if step == 0.0:
		return a == b
	if a is Vector3:
		var off: Vector3 = (a as Vector3) - (b as Vector3)
		return maxf(absf(off.x), maxf(absf(off.y), absf(off.z))) <= step * QUANTA_APART
	if a is PackedFloat64Array:
		var these: PackedFloat64Array = a
		var those: PackedFloat64Array = b
		if these.size() != those.size():
			return false
		for index in these.size():
			if absf(these[index] - those[index]) > step * QUANTA_APART:
				return false
		return true
	return absf(float(a) - float(b)) <= step * QUANTA_APART


static func _section(section: StringName) -> Array:
	return {
		&"snapshot": SNAPSHOT_FIELDS,
		&"seats": SEAT_FIELDS,
		&"props": PROP_FIELDS,
		&"events": EVENT_FIELDS,
	}[section]


static func _quantum_of(field: Field) -> float:
	match field:
		Field.LENGTH, Field.LENGTHS:
			return LENGTH_QUANTUM
		Field.SPEEDS:
			return SPEED_QUANTUM
		Field.ANGLE:
			return ANGLE_QUANTUM
		Field.DEGREES:
			return DEGREES_QUANTUM
		Field.AMOUNT, Field.AMOUNTS:
			return AMOUNT_QUANTUM
	return 0.0


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


static func _put_record(values: Values, record: Dictionary, fields: Array) -> void:
	if record.size() != fields.size():
		push_error("wire: a record of %s has keys the codec does not carry" % [record.keys()])
	for field: Array in fields:
		if field[1] == Field.INT:
			values.ints.append(record.get(field[0]))
		else:
			_put_field(values, record.get(field[0]), field[1])


static func _put_field(values: Values, value: Variant, field: Field) -> void:
	match field:
		Field.INT:
			values.put(value)
		Field.BOOL:
			values.put(1 if value else 0)
		Field.LENGTHS, Field.SPEEDS:
			var vector: Vector3 = value
			var step := _quantum_of(field)
			values.put(roundi(vector.x / step))
			values.put(roundi(vector.y / step))
			values.put(roundi(vector.z / step))
		Field.LENGTH, Field.ANGLE, Field.DEGREES, Field.AMOUNT:
			values.put(roundi(float(value) / _quantum_of(field)))
		Field.AMOUNTS:
			var amounts: PackedFloat64Array = value
			values.put(amounts.size())
			for amount: float in amounts:
				values.put(roundi(amount / AMOUNT_QUANTUM))
		Field.NAME:
			var text := String(value).to_utf8_buffer()
			values.put(text.size())
			for code: int in text:
				values.put(code)
		Field.INTS:
			var ints: Array = value
			values.put(ints.size())
			for item: int in ints:
				values.put(item)
		Field.SEATS, Field.PROPS, Field.EVENTS:
			var records: Array = value
			values.put(records.size())
			for record: Dictionary in records:
				_put_record(values, record, _fields_of(field))


static func _record(values: Values, fields: Array) -> Dictionary:
	var record := {}
	for field: Array in fields:
		# Most fields are counts and enums: read here, without a call per field.
		if field[1] == Field.INT:
			record[field[0]] = values.take()
		else:
			record[field[0]] = _field(values, field[1])
	return record


static func _field(values: Values, field: Field) -> Variant:
	match field:
		Field.BOOL:
			return values.take() != 0
		Field.LENGTHS, Field.SPEEDS:
			var step := _quantum_of(field)
			return Vector3(values.take() * step, values.take() * step, values.take() * step)
		Field.LENGTH, Field.ANGLE, Field.DEGREES, Field.AMOUNT:
			return values.take() * _quantum_of(field)
		Field.AMOUNTS:
			var amounts := PackedFloat64Array()
			for index in _count(values):
				amounts.append(values.take() * AMOUNT_QUANTUM)
			return amounts
		Field.NAME:
			var text := PackedByteArray()
			for index in _count(values):
				text.append(values.take())
			return StringName(text.get_string_from_utf8())
		Field.INTS:
			var ints := []
			for index in _count(values):
				ints.append(values.take())
			return ints
		Field.SEATS, Field.PROPS, Field.EVENTS:
			var records: Array[Dictionary] = []
			for index in _count(values):
				records.append(_record(values, _fields_of(field)))
			return records
	return values.take()


## A list's length; a negative or an absurd one breaks the packet.
static func _count(values: Values) -> int:
	var count := values.take()
	if count < 0 or count > 0xFFFF:
		values.ok = false
		return 0
	return count


static func _fields_of(field: Field) -> Array:
	match field:
		Field.SEATS:
			return SEAT_FIELDS
		Field.PROPS:
			return PROP_FIELDS
	return EVENT_FIELDS
