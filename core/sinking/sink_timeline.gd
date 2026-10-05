class_name SinkTimeline
extends RefCounted
## The bake (§5b.1, D7): SinkStepper run once, from the hit, each step as long as the
## physics chooses (SinkStepper.advance), to the end — she is gone, or the water has
## stopped coming in and she lies still — or the bake's cap, every step's state kept:
## its physics second, where the sea stands up her, her attitude and the head of every
## cell's water; and every event at the step it happens, a lurch with its warning. SH26's
## simplest driver: the whole sinking in memory, read between its steps (SinkSchedule).
## Match data like the ship's: derived from (ship, scenario, seed), never in a snapshot
## (D5).

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
## Less than this many m³ a second passing anywhere, and no door still moving: the
## water has stopped coming in (est.: a litre a second, under 20 t in the bake's whole
## cap, where sinking her within it takes hundreds).
const STILL := 1e-3
## Slower than this she lies still: m/s of heave, radians a second of pitch and roll
## (est.: a millimetre and a twentieth of a degree in a quarter of an hour).
const STILL_RISE := 1e-6
const STILL_TURN := 1e-6
## The cosine of 45°.
const SQRT_HALF := 0.7071067811865476


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

	func _init(
		at: float, event_kind: Kind, event_name: StringName, heel: float = 0.0, length := 0.0
	) -> void:
		seconds = at
		kind = event_kind
		name = event_name
		heel_deg = heel
		lasts = length


## How many cells each kept state keeps.
var cells := 0
## Per kept state, from the hit on: its physics second; the sea's height up her; her
## rotation (Attitude), nine numbers; and then every cell's head in her cells' order.
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
## The steps the bake took.
var steps := 0


## The timeline of [param stepper] from the hit to the end, or to [param cap] physics
## seconds.
static func bake(stepper: SinkStepper, sea: SeaPhysics, cap: float) -> SinkTimeline:
	var timeline := SinkTimeline.new()
	timeline.rest = stepper.rest()
	var state := stepper.start()
	timeline.cells = state.water.size()
	timeline._keep(state)
	var wet := PackedByteArray()
	wet.resize(timeline.cells)
	var full := PackedByteArray()
	full.resize(timeline.cells)
	var names := stepper.opening_names()
	var spilled := PackedByteArray()
	spilled.resize(names.size())
	# Water passing any other kind of opening is never news: as though it had spilled.
	for index in names.size():
		if not _spills(stepper.opening_kind(index)):
			spilled[index] = 1
	var doors_move_until := stepper.last_door()
	var plunged := false
	var lurches := Lurches.new(sea)
	var boats := stepper.lifeboats()
	var useless := PackedByteArray()
	useless.resize(boats.size())
	while state.seconds < cap:
		var before := state
		state = stepper.advance(state)
		var seconds := state.seconds - before.seconds
		timeline.steps += 1
		timeline._keep(state)
		var at := state.seconds
		var passed := 0.0
		for index in names.size():
			var moved := absf(state.moved[index])
			passed += moved
			if moved > 0.0 and spilled[index] == 0:
				spilled[index] = 1
				timeline.events.append(Event.new(at, Kind.SPILLING, names[index]))
		for cell in timeline.cells:
			var head := state.heads[cell]
			if wet[cell] == 0 and head >= stepper.floor_of(cell) + FIRST_WATER:
				wet[cell] = 1
				timeline.events.append(Event.new(at, Kind.FLOODING, stepper.cell_name(cell)))
			if full[cell] == 0 and head >= stepper.ceiling_of(cell):
				full[cell] = 1
				timeline.events.append(Event.new(at, Kind.FULL, stepper.cell_name(cell)))
		lurches.follow(before, state, seconds)
		for boat in boats.size():
			if useless[boat] == 0 and _boats_useless(state.rotation, boats[boat]):
				useless[boat] = 1
				var side := &"starboard" if boats[boat].side == 1 else &"port"
				timeline.events.append(Event.new(at, Kind.BOATS_USELESS, side))
		if state.sea > MAIN_DECK and not plunged:
			plunged = true
			timeline.events.append(Event.new(at, Kind.PLUNGING, &""))
		var above := state.above
		if timeline.gone_at < 0.0 and above < 0.0:
			timeline.gone_at = at
			timeline.events.append(Event.new(at, Kind.GONE, &""))
		if timeline.gone_at >= 0.0 and -above >= sea.gone_depth:
			timeline.end = End.GONE
			break
		if timeline.gone_at < 0.0 and passed < STILL * seconds and at >= doors_move_until:
			if _lies_still(state):
				timeline.end = End.AFLOAT
				break
	lurches.close(state)
	timeline.events = _merged(timeline.events, lurches.events)
	return timeline


## Whether [param state] lies still: neither rising nor falling, pitching nor rolling,
## nor standing unstable.
static func _lies_still(state: FloodState) -> bool:
	return (
		absf(state.heave_rate) < STILL_RISE
		and absf(state.pitch_rate) < STILL_TURN
		and absf(state.roll_rate) < STILL_TURN
		and state.roll_stiffness >= 0.0
	)


## Whether [param boat]'s side stands high past its list limit under [param rotation]:
## its list's sine, read off her rotation — her up's reach athwartships — past the
## limit's, the boat's side up; or she is past her beam ends either way.
static func _boats_useless(rotation: PackedFloat64Array, boat: ShipFitting) -> bool:
	var leaning := rotation[7] * boat.side
	return -leaning >= Attitude.sine_of_degrees(boat.list_limit_deg) or rotation[8] < 0.0


## [param first] and [param second], each in the order they happen, as one: where two
## fall on the same second, the first's first.
static func _merged(first: Array[Event], second: Array[Event]) -> Array[Event]:
	var made: Array[Event] = []
	var at := 0
	for event: Event in first:
		while at < second.size() and second[at].seconds < event.seconds:
			made.append(second[at])
			at += 1
		made.append(event)
	while at < second.size():
		made.append(second[at])
		at += 1
	return made


## Whether water first passing an opening of [param kind] is news: over a low wall,
## down a stair or a hatch, through a doorway between cells.
static func _spills(kind: ShipOpening.Kind) -> bool:
	return kind in [ShipOpening.Kind.OVER_WALL, ShipOpening.Kind.STAIRWELL, ShipOpening.Kind.HATCH]


func _keep(state: FloodState) -> void:
	times.append(state.seconds)
	seas.append(state.sea)
	rotations.append_array(state.rotation)
	heads.append_array(state.heads)


## How many states it keeps, the hit's first.
func count() -> int:
	return times.size()


## The physics seconds it runs for.
func length() -> float:
	return times[times.size() - 1]


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


## Whether she was wholly under before it ended.
func is_gone() -> bool:
	return end == End.GONE


## A hash of everything it keeps: two bakes of the same hit agree on it exactly.
func digest() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(times.to_byte_array())
	hashing.update(seas.to_byte_array())
	hashing.update(rotations.to_byte_array())
	hashing.update(heads.to_byte_array())
	return hashing.finish().hex_encode()


## The lurch rule (§5b.4), followed step by step: a lurch while her list changes faster
## than lurch_rate_deg a second, the list it swings her by added up over it; warned at
## its precursor — the last time she lost her stability since the lurch before — and
## never less than lurch_warning seconds ahead, which is where the bake places the
## warning when the precursor comes later or never. Stood further on end than she is
## level along her length — past 45° of trim — she has no list to speak of: a roll then
## is no lurch.
class Lurches:
	var events: Array[Event] = []
	var _rate: float
	var _warning: float
	## The second she last lost her stability, -1 for not since the last lurch; and the
	## lurch under way: its first second, and the list it has swung her by, in radians,
	## or -1 for none.
	var _lost_at := -1.0
	var _from := -1.0
	var _swung := 0.0

	func _init(sea: SeaPhysics) -> void:
		_rate = sea.lurch_rate_deg * PI / 180.0
		_warning = sea.lurch_warning

	## Follows the step from [param before] to [param after], [param seconds] long.
	func follow(before: FloodState, after: FloodState, seconds: float) -> void:
		if after.roll_stiffness < 0.0 and before.roll_stiffness >= 0.0:
			_lost_at = after.seconds
		var fast := absf(after.roll_rate) > _rate and absf(after.rotation[0]) > SQRT_HALF
		if fast:
			if _from < 0.0:
				_from = before.seconds
				_swung = 0.0
			_swung += after.roll_rate * seconds
		elif _from >= 0.0:
			close(after)

	## Ends the lurch under way, if any, at [param state].
	func close(state: FloodState) -> void:
		if _from < 0.0:
			return
		var warned := _from - _warning
		if _lost_at >= 0.0 and _lost_at < warned:
			warned = _lost_at
		var heel := _swung * 180.0 / PI
		events.append(Event.new(maxf(warned, 0.0), Kind.LURCHING, &"", heel))
		events.append(Event.new(_from, Kind.LURCHED, &"", heel, state.seconds - _from))
		_from = -1.0
		_lost_at = -1.0
