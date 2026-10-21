class_name InputLog
extends RefCounted
## Every frame a match was stepped with, as received, tick by tick — with the seed
## and the data hash it was played under, so a replay refuses changed numbers. Held
## packed, a row of FIELDS integers per seat per tick, never as frame objects: a match
## has no cap, and hours of eight seats' frames as objects run to gigabytes. frame()
## makes the frame again, field for field as it came.

## Per seat per tick: whether a frame came, then its seat, tick, move x and y, buttons
## and look yaw as received.
const FIELDS := 7
## The bytes' first four, and the layout they announce (to_bytes).
const MAGIC := "SSIL"
const FORMAT := 1

var match_seed: int
var seats: int
var data_hash: String
var first_tick: int
var _rows := PackedInt32Array()
var _count := 0


## A log of [param config]'s match from [param from_tick]; [param config] may be null
## for a log about to be filled from bytes (from_bytes).
func _init(config: MatchConfig, from_tick: int = 0) -> void:
	if config != null:
		match_seed = config.match_seed
		seats = config.seats
		data_hash = config.data_hash()
	first_tick = from_tick


## The log as bytes: MAGIC, FORMAT, the seed, the seats, the data hash, the first tick
## and the tick count, then the rows as they are kept.
func to_bytes() -> PackedByteArray:
	var out := ByteCursor.new()
	out.put_bytes(MAGIC.to_ascii_buffer())
	out.put_s32(FORMAT)
	out.put_s64(match_seed)
	out.put_s32(seats)
	out.put_string(data_hash)
	out.put_s32(first_tick)
	out.put_s32(_count)
	out.put_bytes(_rows.to_byte_array())
	return out.bytes()


## The log [param bytes] hold, as to_bytes wrote it; null for a buffer cut short,
## garbled, or of another layout.
static func from_bytes(bytes: PackedByteArray) -> InputLog:
	var read := ByteCursor.new(bytes)
	if read.bytes_next() != MAGIC.to_ascii_buffer() or read.s32() != FORMAT:
		return null
	var seed_value := read.s64()
	var seat_count := read.s32()
	var hash := read.string()
	var from_tick := read.s32()
	var count := read.s32()
	var rows := read.bytes_next()
	if not read.ok or not read.at_end() or seat_count < 1 or count < 0 or from_tick < 0:
		return null
	if rows.size() != count * seat_count * FIELDS * 4:
		return null
	var log := InputLog.new(null, from_tick)
	log.match_seed = seed_value
	log.seats = seat_count
	log.data_hash = hash
	log._rows = rows.to_int32_array()
	log._count = count
	return log


func record(tick: int, frames: Array[InputFrame]) -> void:
	assert(tick == first_tick + _count, "the log records ticks in order")
	for seat in seats:
		var given: InputFrame = frames[seat] if seat < frames.size() else null
		if given == null:
			_rows.append_array(PackedInt32Array([0, 0, 0, 0, 0, 0, 0]))
			continue
		var row := PackedInt32Array([1, given.seat, given.tick, given.move.x, given.move.y])
		row.append(given.buttons)
		row.append(given.look_yaw)
		_rows.append_array(row)
	_count += 1


## The frame [param seat] sent on [param tick], or null.
func frame(tick: int, seat: int) -> InputFrame:
	var index := tick - first_tick
	if index < 0 or index >= _count or seat < 0 or seat >= seats:
		return null
	var at := (index * seats + seat) * FIELDS
	if _rows[at] == 0:
		return null
	return InputFrame.new(
		_rows[at + 1],
		_rows[at + 2],
		Vector2i(_rows[at + 3], _rows[at + 4]),
		_rows[at + 5],
		_rows[at + 6]
	)


func last_tick() -> int:
	return first_tick + _count - 1


## Whether this log was played under [param config]'s seed, seats and data.
func matches(config: MatchConfig) -> bool:
	return (
		config.match_seed == match_seed
		and config.seats == seats
		and config.data_hash() == data_hash
	)


## One source per seat that answers this log's frames.
func replay_sources() -> Array[InputSource]:
	var sources: Array[InputSource] = []
	for seat in seats:
		sources.append(ReplayInputSource.new(self, seat))
	return sources
