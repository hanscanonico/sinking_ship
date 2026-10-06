class_name SinkTimeline
extends RefCounted
## The baked sinking (§5b.4, D7): what SinkBake made of the stepper's run from the hit to
## the end — states where the sinking needs them, each its physics second, where the sea
## stands up her, her attitude and the head of every cell's water — and every event at
## its exact second, a lurch with its warning. Kept compact: a state its neighbours,
## read between (blend), reproduce within keep_level of water and keep_turn_deg of
## attitude (SeaPhysics, est.) is dropped, but never one an event happens at. What stays
## is held as integers — microseconds, millimetres, and millionths of a unit
## quaternion's components (about a ten-thousandth of a degree) — each a difference from
## the one before, in pages compressed one by one behind a header, so a client can play
## the first page while the rest is coming (D11); digest() pins every byte. Match data
## like the ship's: baked from (ship, scenario, seed), or received from the host with
## its digest, and never in a snapshot (D5). SinkSchedule reads it.

## How a bake ends (§5b.1): she is gone — wholly under the sea and still going down;
## the water has stopped coming in and she floats still; or the cap came first.
enum End { GONE, AFLOAT, CAPPED }
## What the physics announces: a cell takes its first water, a cell is full, water
## first passes over a low wall or down a stair or hatch, she is gone, her main deck
## goes under the sea — the plunge begins, her last minutes —, a lurch is coming, she
## lurches (§5b.4's lurch rule), and one side's lifeboats are useless (§5b.1).
enum Kind { FLOODING, FULL, SPILLING, GONE, PLUNGING, LURCHING, LURCHED, BOATS_USELESS }
## A cell's water this far over its floor, in metres, is its first.
const FIRST_WATER := 0.01
## Her main deck's height: ship space's origin stands on it (D6).
const MAIN_DECK := 0.0
## The integers it is held as: microseconds, millimetres, millionths of a quaternion's
## component, millionths of a degree. A page holds PAGE_STATES states. FORMAT changes
## with the bytes' layout; a section unpacks to no more than MOST_BYTES.
const PER_SECOND := 1e6
const PER_METRE := 1e3
const PER_UNIT := 1e6
const PER_DEGREE := 1e6
const PAGE_STATES := 256
const FORMAT := 1
const MOST_BYTES := 1 << 24
const COMPRESSION := FileAccess.COMPRESSION_ZSTD
## How the four quaternion components and a state's other numbers lie in a page.
const QUATERNION := 4


## One thing the physics did, at its second.
class Event:
	var seconds: float
	var kind: Kind
	## The cell, or for SPILLING the opening, it names; for BOATS_USELESS the side,
	## &"port" or &"starboard"; nothing else names one.
	var name: StringName
	## LURCHING, LURCHED: the list the lurch swings her by, in degrees, positive
	## starboard down; LURCHED: the seconds it lasts.
	var heel_deg: float
	var lasts: float
	## The second it was warned of: its own for what nothing warns of.
	var warned: float

	func _init(
		at: float, event_kind: Kind, event_name: StringName, heel: float = 0.0, length := 0.0
	) -> void:
		seconds = at
		kind = event_kind
		name = event_name
		heel_deg = heel
		lasts = length
		warned = at


## How many cells each state has.
var cells := 0
## Per state kept, from the hit on: its physics second; the sea's height up her; her
## rotation (Attitude), nine numbers; then every cell's head in her cells' order. While
## a timeline's pages are still coming, only those that came.
var times := PackedFloat64Array()
var seas := PackedFloat64Array()
var rotations := PackedFloat64Array()
var heads := PackedFloat64Array()
## In the order they happen.
var events: Array[Event] = []
var end := End.CAPPED
## The physics second she was wholly under, or -1 for never.
var gone_at := -1.0
## Where the sea stands up her at rest, with no water in her: her level ship.
var rest := 0.0
## The steps the bake took, and the states it had before any was dropped.
var steps := 0
var states := 0
## How the hit it was baked from was chosen, for a client to draw it again (MustSink):
## empty until the must-sink rule or a given hit says.
var origin := PackedInt64Array()

## Per state kept, its rotation as a unit quaternion, w x y z.
var _quaternions := PackedFloat64Array()
## The integers: per state its microsecond, millimetres of sea, quaternion and heads.
var _held := PackedInt64Array()
var _length := 0.0
var _total := 0
var _sections: Array[PackedByteArray] = []
## A timeline whose pages are coming: each page's digest as its header claims it.
var _claims: Array[PackedByteArray] = []


## The timeline of [param stepper] baked straight through under [param sea], to the end
## or [param cap] physics seconds (SinkBake).
static func bake(stepper: SinkStepper, sea: SeaPhysics, cap: float) -> SinkTimeline:
	return SinkBake.new(stepper, sea, cap).timeline()


## The timeline [param bake] made, a state dropped where its neighbours reproduce it
## within [param level] metres and [param turn_deg] degrees — none dropped at 0.
static func made(bake: SinkBake, level: float, turn_deg: float) -> SinkTimeline:
	var timeline := SinkTimeline.new()
	timeline.cells = bake.cells()
	timeline.events = bake.events()
	timeline.end = bake.end()
	timeline.gone_at = _seconds_of(_microseconds(bake.gone_at())) if bake.gone_at() >= 0.0 else -1.0
	timeline.rest = roundi(bake.rest() * PER_METRE) / PER_METRE
	timeline.steps = bake.steps()
	timeline.states = bake.times().size()
	# Every number as its integers say it, so the timeline baked here and the one a
	# client reads back from its bytes are one (D11).
	for event: Event in timeline.events:
		event.seconds = _seconds_of(_microseconds(event.seconds))
		event.warned = _seconds_of(_microseconds(event.warned))
		event.lasts = _seconds_of(_microseconds(event.lasts))
		event.heel_deg = roundi(event.heel_deg * PER_DEGREE) / PER_DEGREE
	var held := _held_states(bake)
	var kept := _kept(bake, held, timeline.events, level, turn_deg)
	var width := timeline._width()
	for state: int in kept:
		timeline._held.append_array(held.slice(state * width, state * width + width))
	timeline._total = kept.size()
	timeline._length = _seconds_of(held[(held.size() / width - 1) * width])
	timeline._decode(0)
	return timeline


## A timeline from [param bytes] (to_bytes), or null when they are not one whole.
static func from_bytes(bytes: PackedByteArray) -> SinkTimeline:
	var sections := _split(bytes)
	if sections.is_empty():
		return null
	var timeline := opened(sections[0])
	if timeline == null or timeline._claims.size() != sections.size() - 1:
		return null
	for page in range(1, sections.size()):
		if not timeline.add_page(sections[page]):
			return null
	return timeline


## A timeline from its [param header] alone (sections()[0]), its pages to come
## (add_page); null when it is not one.
static func opened(header: PackedByteArray) -> SinkTimeline:
	var reader := Reader.new(_unpacked(header))
	var timeline := SinkTimeline.new()
	if reader.integer() != FORMAT:
		return null
	timeline.cells = reader.count()
	timeline.end = reader.integer() as End
	var gone := reader.integer()
	timeline.gone_at = _seconds_of(gone) if gone >= 0 else -1.0
	timeline.rest = reader.integer() / PER_METRE
	timeline.steps = reader.integer()
	timeline.states = reader.integer()
	timeline._length = _seconds_of(reader.integer())
	timeline._total = reader.integer()
	for _value in reader.count():
		timeline.origin.append(reader.integer())
	var names: Array[StringName] = []
	for _name in reader.count():
		names.append(StringName(reader.text()))
	var at := 0
	for _event in reader.count():
		at += reader.integer()
		var kind := reader.integer()
		var named := reader.integer()
		if kind < 0 or kind >= Kind.size() or named < 0 or named >= names.size():
			return null
		var event := Event.new(_seconds_of(at), kind as Kind, names[named])
		event.warned = _seconds_of(at - reader.integer())
		event.heel_deg = reader.integer() / PER_DEGREE
		event.lasts = _seconds_of(reader.integer())
		timeline.events.append(event)
	for _page in reader.count():
		timeline._claims.append(reader.bytes(32))
	timeline._sections.append(header)
	if not reader.finished() or timeline.end < 0 or timeline.end >= End.size():
		return null
	return timeline


## The digest of a timeline's [param sections]: SHA-256 of its header, then of each
## page's own SHA-256 — so a byte changed anywhere changes it, and a client holding the
## header checks each page as it comes against the digest the header claims for it.
static func digest_of(sections: Array[PackedByteArray]) -> String:
	if sections.is_empty():
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(sections[0])
	for page in range(1, sections.size()):
		hashing.update(_sha256(sections[page]))
	return hashing.finish().hex_encode()


## The digest [param header] — a timeline's first section — claims for its timeline:
## of the header, then of the digests it claims for its pages; "" when it is no
## header. A client holding only the header checks it against the digest it was given.
static func digest_claimed(header: PackedByteArray) -> String:
	var timeline := opened(header)
	if timeline == null:
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(header)
	for claim: PackedByteArray in timeline._claims:
		hashing.update(claim)
	return hashing.finish().hex_encode()


## The digest of [param bytes] as to_bytes lays a timeline out; of the bytes as they
## are, where they cannot be cut into its sections.
static func digest_of_bytes(bytes: PackedByteArray) -> String:
	var sections := _split(bytes)
	if sections.is_empty():
		return _sha256(bytes).hex_encode()
	return digest_of(sections)


## How many states it keeps, the hit's first — those that came, of one still coming.
func count() -> int:
	return times.size()


## How many it keeps in all, when every page has come.
func total() -> int:
	return _total


## The physics seconds it runs for.
func length() -> float:
	return _length


## The last kept state at or before [param seconds] of physics.
func frame_at(seconds: float) -> int:
	var low := 0
	var high := times.size() - 1
	if seconds >= times[high]:
		return high
	while high - low > 1:
		var middle := (low + high) >> 1
		if times[middle] <= seconds:
			low = middle
		else:
			high = middle
	return low


## The up component of her up — the cosine of how far she stands from upright —
## [param weight] of the way from kept state [param frame] to [param next], read
## between them as blend reads them, in 64 bits and with square roots alone (R21).
func up_between(frame: int, next: int, weight: float) -> float:
	return _rotation(blended(frame, next, weight))[4]


## Whether she was wholly under before it ended.
func is_gone() -> bool:
	return end == End.GONE


## Her rotation [param weight] of the way from kept state [param frame] to
## [param next]: the two quaternions blended and made a unit again — what the
## compaction holds every dropped state to, so the one way of reading between states.
func blend(frame: int, next: int, weight: float) -> Quaternion:
	var q := blended(frame, next, weight)
	return Quaternion(q[1], q[2], q[3], q[0])


## The same blend, as four 64-bit numbers, w x y z.
func blended(frame: int, next: int, weight: float) -> PackedFloat64Array:
	return _blended(_quaternions, frame, _quaternions, next, weight)


## The SHA-256 of every byte it is made of (digest_of).
func digest() -> String:
	return digest_of(sections())


## What travels: the header, then the pages in order, each compressed.
func sections() -> Array[PackedByteArray]:
	if _sections.is_empty():
		var pages: Array[PackedByteArray] = []
		var page_count := ceili(float(_total) / PAGE_STATES)
		for page in page_count:
			pages.append(_page_bytes(page))
		_sections.append(_header_bytes(pages))
		_sections.append_array(pages)
	return _sections


## Every section behind its length, as four bytes, the low first.
func to_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	for section: PackedByteArray in sections():
		var at := bytes.size()
		bytes.resize(at + 4)
		bytes.encode_u32(at, section.size())
		bytes.append_array(section)
	return bytes


## How many bytes to_bytes is.
func size() -> int:
	var bytes := 0
	for section: PackedByteArray in sections():
		bytes += 4 + section.size()
	return bytes


## The digests the header claims for its pages, in order.
func claims() -> Array[PackedByteArray]:
	return _claims


## Whether every page has come.
func is_whole() -> bool:
	return count() == _total


## Takes the next page of a timeline opened from its header: false, and nothing taken,
## when it is not the next page or not what the header claims.
func add_page(bytes: PackedByteArray) -> bool:
	var page := _sections.size() - 1
	if page >= _claims.size() or _sha256(bytes) != _claims[page]:
		return false
	var reader := Reader.new(_unpacked(bytes))
	if reader.integer() != page:
		return false
	var count_in := reader.count()
	var width := _width()
	var values := PackedInt64Array()
	values.resize(count_in * width)
	for column in width:
		var value := 0
		for state in count_in:
			value += reader.integer()
			values[state * width + column] = value
	if not reader.finished() or count() + count_in > _total:
		return false
	var from := count()
	_held.append_array(values)
	_decode(from)
	_sections.append(bytes)
	return true


func _width() -> int:
	return 2 + QUATERNION + cells


## Fills the readable numbers from the integers, from state [param from] on.
func _decode(from: int) -> void:
	var width := _width()
	for state in range(from, _held.size() / width):
		var at := state * width
		times.append(_seconds_of(_held[at]))
		seas.append(_held[at + 1] / PER_METRE)
		var q := PackedFloat64Array()
		for part in QUATERNION:
			q.append(_held[at + 2 + part] / PER_UNIT)
		q = _unit(q)
		_quaternions.append_array(q)
		rotations.append_array(_rotation(q))
		for cell in cells:
			heads.append(_held[at + 2 + QUATERNION + cell] / PER_METRE)


func _header_bytes(pages: Array[PackedByteArray]) -> PackedByteArray:
	var writer := Writer.new()
	writer.integer(FORMAT)
	writer.integer(cells)
	writer.integer(end)
	writer.integer(_microseconds(gone_at) if gone_at >= 0.0 else -1)
	writer.integer(roundi(rest * PER_METRE))
	writer.integer(steps)
	writer.integer(states)
	writer.integer(_microseconds(_length))
	writer.integer(_total)
	writer.integer(origin.size())
	for value: int in origin:
		writer.integer(value)
	var names: Array[StringName] = []
	for event: Event in events:
		if not event.name in names:
			names.append(event.name)
	writer.integer(names.size())
	for named: StringName in names:
		writer.text(String(named))
	writer.integer(events.size())
	var at := 0
	for event: Event in events:
		var seconds := _microseconds(event.seconds)
		writer.integer(seconds - at)
		at = seconds
		writer.integer(event.kind)
		writer.integer(names.find(event.name))
		writer.integer(seconds - _microseconds(event.warned))
		writer.integer(roundi(event.heel_deg * PER_DEGREE))
		writer.integer(_microseconds(event.lasts))
	writer.integer(pages.size())
	for page: PackedByteArray in pages:
		writer.raw(_sha256(page))
	return _packed(writer.bytes)


func _page_bytes(page: int) -> PackedByteArray:
	var width := _width()
	var first := page * PAGE_STATES
	var last := mini(first + PAGE_STATES, _total)
	var writer := Writer.new()
	writer.integer(page)
	writer.integer(last - first)
	for column in width:
		var before := 0
		for state in range(first, last):
			var value := _held[state * width + column]
			writer.integer(value - before)
			before = value
	return _packed(writer.bytes)


## Every state of [param bake] as the integers it is kept as, its quaternion turned
## the same way round as the one before it.
static func _held_states(bake: SinkBake) -> PackedInt64Array:
	var held := PackedInt64Array()
	var times := bake.times()
	var seas := bake.seas()
	var rotations := bake.rotations()
	var all_heads := bake.heads()
	var cells_in := bake.cells()
	var before := PackedFloat64Array([1.0, 0.0, 0.0, 0.0])
	for state in times.size():
		held.append(_microseconds(times[state]))
		held.append(roundi(seas[state] * PER_METRE))
		var q := quaternion_of(rotations.slice(state * 9, state * 9 + 9))
		if q[0] * before[0] + q[1] * before[1] + q[2] * before[2] + q[3] * before[3] < 0.0:
			for part in QUATERNION:
				q[part] = -q[part]
		before = q
		for part in QUATERNION:
			held.append(roundi(q[part] * PER_UNIT))
		for cell in cells_in:
			held.append(roundi(all_heads[state * cells_in + cell] * PER_METRE))
	return held


## The states of [param bake] to keep, in order: the first, the last, every one an event
## happens at, and in between as few as reproduce the rest — each dropped state's sea,
## and each cell's water both up her and against the sea, within [param level] metres
## and its rotation within [param turn_deg] degrees of its kept neighbours' [param held]
## values read between them. Each stretch
## runs as far as it holds: doubled while it does, then halved back to the last that did.
static func _kept(
	bake: SinkBake, held: PackedInt64Array, kept_events: Array[Event], level: float, turn_deg: float
) -> PackedInt32Array:
	var count_of := bake.times().size()
	var pinned := PackedByteArray()
	pinned.resize(count_of)
	pinned[0] = 1
	pinned[count_of - 1] = 1
	var at_event := {}
	for event: Event in kept_events:
		at_event[_microseconds(event.seconds)] = true
	var width := 2 + QUATERNION + bake.cells()
	for state in count_of:
		if at_event.has(held[state * width]):
			pinned[state] = 1
	var fit := Fit.new(bake, held, level, turn_deg)
	var kept := PackedInt32Array([0])
	var from := 0
	while from < count_of - 1:
		var limit := from + 1
		while pinned[limit] == 0:
			limit += 1
		var good := from + 1
		var probe := from + 2
		while probe <= limit and fit.holds(from, probe):
			good = probe
			probe = from + (probe - from) * 2
		var bad := mini(probe, limit + 1)
		while bad - good > 1:
			var middle := (good + bad) >> 1
			if fit.holds(from, middle):
				good = middle
			else:
				bad = middle
		kept.append(good)
		from = good
	return kept


## Whether the states between two kept ones are reproduced, read between them.
class Fit:
	var _times := PackedFloat64Array()
	var _true_seas: PackedFloat64Array
	var _true_heads: PackedFloat64Array
	var _true_turns := PackedFloat64Array()
	var _seas := PackedFloat64Array()
	var _heads := PackedFloat64Array()
	var _turns := PackedFloat64Array()
	var _cells: int
	var _level: float
	## The cosine of half the turn allowed: two unit quaternions closer than it in their
	## dot product are within the turn.
	var _close: float

	func _init(bake: SinkBake, held: PackedInt64Array, level: float, turn_deg: float) -> void:
		_cells = bake.cells()
		_true_seas = bake.seas()
		_true_heads = bake.heads()
		_level = level
		var half := Attitude.sine_of_degrees(turn_deg * 0.25)
		_close = 1.0 - 2.0 * half * half
		var rotations := bake.rotations()
		var width := 2 + QUATERNION + _cells
		for state in bake.times().size():
			var at := state * width
			_times.append(SinkTimeline._seconds_of(held[at]))
			_seas.append(held[at + 1] / PER_METRE)
			var q := PackedFloat64Array()
			for part in QUATERNION:
				q.append(held[at + 2 + part] / PER_UNIT)
			_turns.append_array(SinkTimeline._unit(q))
			for cell in _cells:
				_heads.append(held[at + 2 + QUATERNION + cell] / PER_METRE)
			var truth := SinkTimeline.quaternion_of(rotations.slice(state * 9, state * 9 + 9))
			_true_turns.append_array(truth)

	func holds(from: int, to: int) -> bool:
		var span := _times[to] - _times[from]
		for state in range(from + 1, to):
			var weight := (_times[state] - _times[from]) / span if span > 0.0 else 1.0
			var sea := _seas[from] + (_seas[to] - _seas[from]) * weight
			if absf(sea - _true_seas[state]) > _level:
				return false
			var q := SinkTimeline._blended(_turns, from, _turns, to, weight)
			var dot := 0.0
			for part in QUATERNION:
				dot += q[part] * _true_turns[state * QUATERNION + part]
			if absf(dot) < _close:
				return false
			var sea_off := sea - _true_seas[state]
			for cell in _cells:
				var a := _heads[from * _cells + cell]
				var off := a + (_heads[to * _cells + cell] - a) * weight
				off -= _true_heads[state * _cells + cell]
				# Up her, and in the world: her height in the sea moves the water with her.
				if absf(off) > _level or absf(off - sea_off) > _level:
					return false
		return true


## Quaternion [param frame] of [param first] blended [param weight] of the way to
## quaternion [param next] of [param second], made a unit: w x y z.
static func _blended(
	first: PackedFloat64Array, frame: int, second: PackedFloat64Array, next: int, weight: float
) -> PackedFloat64Array:
	var q := PackedFloat64Array()
	q.resize(QUATERNION)
	for part in QUATERNION:
		var a := first[frame * QUATERNION + part]
		q[part] = a + (second[next * QUATERNION + part] - a) * weight
	return _unit(q)


static func _unit(q: PackedFloat64Array) -> PackedFloat64Array:
	var length := sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3])
	for part in QUATERNION:
		q[part] /= length
	return q


## The unit quaternion, w x y z, of [param r] — an Attitude, nine numbers row by row —
## from its largest diagonal, with square roots alone (D4).
static func quaternion_of(r: PackedFloat64Array) -> PackedFloat64Array:
	var trace := r[0] + r[4] + r[8]
	var s := 0.0
	if trace > 0.0:
		s = sqrt(trace + 1.0) * 2.0
		return _unit(
			PackedFloat64Array([s / 4.0, (r[7] - r[5]) / s, (r[2] - r[6]) / s, (r[3] - r[1]) / s])
		)
	if r[0] > r[4] and r[0] > r[8]:
		s = sqrt(1.0 + r[0] - r[4] - r[8]) * 2.0
		return _unit(
			PackedFloat64Array([(r[7] - r[5]) / s, s / 4.0, (r[1] + r[3]) / s, (r[2] + r[6]) / s])
		)
	if r[4] > r[8]:
		s = sqrt(1.0 + r[4] - r[0] - r[8]) * 2.0
		return _unit(
			PackedFloat64Array([(r[2] - r[6]) / s, (r[1] + r[3]) / s, s / 4.0, (r[5] + r[7]) / s])
		)
	s = sqrt(1.0 + r[8] - r[0] - r[4]) * 2.0
	return _unit(
		PackedFloat64Array([(r[3] - r[1]) / s, (r[2] + r[6]) / s, (r[5] + r[7]) / s, s / 4.0])
	)


## The rotation, nine numbers row by row, of unit quaternion [param q], w x y z.
static func _rotation(q: PackedFloat64Array) -> PackedFloat64Array:
	var w := q[0]
	var x := q[1]
	var y := q[2]
	var z := q[3]
	return PackedFloat64Array(
		[
			1.0 - 2.0 * (y * y + z * z),
			2.0 * (x * y - w * z),
			2.0 * (x * z + w * y),
			2.0 * (x * y + w * z),
			1.0 - 2.0 * (x * x + z * z),
			2.0 * (y * z - w * x),
			2.0 * (x * z - w * y),
			2.0 * (y * z + w * x),
			1.0 - 2.0 * (x * x + y * y),
		]
	)


static func _microseconds(seconds: float) -> int:
	return roundi(seconds * PER_SECOND)


static func _seconds_of(microseconds: int) -> float:
	return microseconds / PER_SECOND


static func _sha256(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish()


## [param bytes] compressed behind their own length, four bytes, the low first.
static func _packed(bytes: PackedByteArray) -> PackedByteArray:
	var made := PackedByteArray()
	made.resize(4)
	made.encode_u32(0, bytes.size())
	made.append_array(bytes.compress(COMPRESSION))
	return made


## What [param packed] holds; empty when it holds nothing it could.
static func _unpacked(packed: PackedByteArray) -> PackedByteArray:
	if packed.size() < 4:
		return PackedByteArray()
	var size_of := packed.decode_u32(0)
	if size_of > MOST_BYTES:
		return PackedByteArray()
	var bytes := packed.slice(4).decompress(size_of, COMPRESSION)
	return bytes if bytes.size() == size_of else PackedByteArray()


## [param bytes] cut into the sections to_bytes laid out; empty when they do not cut.
static func _split(bytes: PackedByteArray) -> Array[PackedByteArray]:
	var sections: Array[PackedByteArray] = []
	var at := 0
	while at < bytes.size():
		if at + 4 > bytes.size():
			return []
		var size_of := bytes.decode_u32(at)
		if at + 4 + size_of > bytes.size():
			return []
		sections.append(bytes.slice(at + 4, at + 4 + size_of))
		at += 4 + size_of
	return sections


## Integers as zigzag varints, any 64-bit one, the small ones in a byte.
class Writer:
	var bytes := PackedByteArray()

	func integer(value: int) -> void:
		var zigzag := (value << 1) ^ (value >> 63)
		while true:
			var low := zigzag & 0x7F
			zigzag = (zigzag >> 7) & 0x01FFFFFFFFFFFFFF
			if zigzag == 0:
				bytes.append(low)
				return
			bytes.append(low | 0x80)

	func raw(more: PackedByteArray) -> void:
		bytes.append_array(more)

	func text(value: String) -> void:
		var utf8 := value.to_utf8_buffer()
		integer(utf8.size())
		bytes.append_array(utf8)


## Reads what Writer wrote, noting rather than failing when it runs short.
class Reader:
	var ok := true
	var _bytes: PackedByteArray
	var _at := 0

	func _init(read: PackedByteArray) -> void:
		_bytes = read
		ok = not read.is_empty()

	func integer() -> int:
		var zigzag := 0
		var shift := 0
		while shift < 64:
			if _at >= _bytes.size():
				ok = false
				return 0
			var next := _bytes[_at]
			_at += 1
			zigzag |= (next & 0x7F) << shift
			if next & 0x80 == 0:
				break
			shift += 7
		return ((zigzag >> 1) & 0x7FFFFFFFFFFFFFFF) ^ -(zigzag & 1)

	## A length: one past MOST_BYTES, or negative, breaks it.
	func count() -> int:
		var value := integer()
		if value < 0 or value > MOST_BYTES:
			ok = false
			return 0
		return value

	func bytes(length_of: int) -> PackedByteArray:
		if _at + length_of > _bytes.size():
			ok = false
			return PackedByteArray()
		_at += length_of
		return _bytes.slice(_at - length_of, _at)

	func text() -> String:
		return bytes(count()).get_string_from_utf8()

	func finished() -> bool:
		return ok and _at == _bytes.size()
