class_name SinkBake
extends RefCounted
## The bake (§5b.1, §5b.4, D7): SinkStepper run once from the hit, each step as long as
## the physics chooses (SinkStepper.advance) but cut short to land where a cell's water
## reaches its ceiling, the sill of an opening it spills over or — with the air stage on
## — the top of the last opening its air had, so those events stand at their own seconds
## and a pocket traps the air it had then; to the end — she is gone, or the water has
## stopped coming in and she lies still — or the bake's cap. Every state and every event,
## a lurch with its warning, go into the timeline it makes (SinkTimeline). It runs a
## slice at a time — run() takes the steps it is allowed — so a scene can spread it
## across frames (R20): a bake run in slices is the bake run straight through, step for
## step, and the stepper stays state in, state out.

## A level this close to a ceiling or a sill, in metres, has reached it: the
## timeline's millimetre. A landing its first guess misses is guessed again, by false
## position, at most LAND_TRIES times in all, once per ceiling or sill.
const REACHED := 1e-3
const LAND_TRIES := 4
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

var _stepper: SinkStepper
var _sea: SeaPhysics
var _cap: float
var _state: FloodState
var _done := false
var _end := SinkTimeline.End.CAPPED
var _gone_at := -1.0
## Every state, the hit's first: its physics second, the sea up her, her rotation (nine
## numbers), and every cell's head, water and pocket's pressure (SinkStepper.pressures).
var _times := PackedFloat64Array()
var _seas := PackedFloat64Array()
var _rotations := PackedFloat64Array()
var _heads := PackedFloat64Array()
var _waters := PackedFloat64Array()
var _pockets := PackedFloat64Array()
var _events: Array[SinkTimeline.Event] = []
var _cells := 0
var _wet := PackedByteArray()
var _full := PackedByteArray()
var _names: Array[StringName] = []
var _spilled := PackedByteArray()
var _doors_move_until := 0.0
var _plunged := false
var _lurches: Lurches
var _boats: Array[ShipFitting] = []
var _useless := PackedByteArray()
## Per ceiling and sill — every cell's ceiling, then every opening's sill, then with the
## air stage on every cell's highest opening top — how far under it the water stood at
## the last state, and 1 once it was ever under it by more than REACHED; and 1 once a
## step has landed on it, or for a sill no step lands on.
var _gaps := PackedFloat64Array()
var _under := PackedByteArray()
var _landed := PackedByteArray()
var _timeline: SinkTimeline


## The bake of [param stepper] under [param sea], to [param cap] physics seconds.
func _init(stepper: SinkStepper, sea: SeaPhysics, cap: float) -> void:
	_stepper = stepper
	_sea = sea
	_cap = cap
	_state = stepper.start()
	_cells = _state.water.size()
	_keep(_state)
	_wet.resize(_cells)
	_full.resize(_cells)
	_names = stepper.opening_names()
	_spilled.resize(_names.size())
	_gaps = _gaps_of(_state)
	_under.resize(_gaps.size())
	_landed.resize(_gaps.size())
	# Water passing any other kind of opening is never news — as though it had spilled
	# — and no step lands on its sill: only the timeline's events are landed on.
	for index in _names.size():
		if not _spills(stepper.opening_kind(index)):
			_spilled[index] = 1
			_landed[_cells + index] = 1
	_note_under()
	_doors_move_until = stepper.last_door()
	_lurches = Lurches.new(sea)
	_boats = stepper.lifeboats()
	_useless.resize(_boats.size())
	_done = _state.seconds >= _cap


## Takes up to [param steps] more steps; whether the bake is over.
func run(steps: int) -> bool:
	var taken := 0
	while not _done and taken < steps:
		_take()
		taken += 1
	return _done


func is_done() -> bool:
	return _done


## The steps taken so far, and the physics second reached.
func steps() -> int:
	return _times.size() - 1


func seconds() -> float:
	return _state.seconds


## The timeline once the bake is over, compacted (SinkTimeline): run straight through
## when it is not yet.
func timeline() -> SinkTimeline:
	if _timeline == null:
		run(1 << 62)
		_timeline = SinkTimeline.made(self, _sea.keep_level, _sea.keep_turn_deg, _sea.keep_air)
	return _timeline


## The same bake with every state kept: what the compaction is held to.
func uncompacted() -> SinkTimeline:
	run(1 << 62)
	return SinkTimeline.made(self, 0.0, 0.0, 0.0)


## What the bake kept, for SinkTimeline to make itself from: every state's second, sea,
## rotation, heads and pockets, and how many cells each has.
func times() -> PackedFloat64Array:
	return _times


func seas() -> PackedFloat64Array:
	return _seas


func rotations() -> PackedFloat64Array:
	return _rotations


func heads() -> PackedFloat64Array:
	return _heads


func waters() -> PackedFloat64Array:
	return _waters


func pockets() -> PackedFloat64Array:
	return _pockets


func cells() -> int:
	return _cells


## Its events, in the order they happen; how it ends and when she was wholly under,
## -1 for never; where the sea stands up her at rest with no water in her.
func events() -> Array[SinkTimeline.Event]:
	return _events


func end() -> SinkTimeline.End:
	return _end


func gone_at() -> float:
	return _gone_at


func rest() -> float:
	return _stepper.rest()


## One step, landed where a ceiling or a sill comes within it, and what it brought.
func _take() -> void:
	var before := _state
	_state = _next(before)
	var state := _state
	var seconds := state.seconds - before.seconds
	_keep(state)
	var at := state.seconds
	var passed := 0.0
	for index in _names.size():
		var moved := absf(state.moved[index])
		passed += moved
		var reached := _under[_cells + index] == 1 and _gaps[_cells + index] <= REACHED
		if _spilled[index] == 0 and (moved > 0.0 or reached):
			_spilled[index] = 1
			_events.append(SinkTimeline.Event.new(at, SinkTimeline.Kind.SPILLING, _names[index]))
	for cell in _cells:
		var head := state.heads[cell]
		if _wet[cell] == 0 and head >= _stepper.floor_of(cell) + SinkTimeline.FIRST_WATER:
			_wet[cell] = 1
			_events.append(
				SinkTimeline.Event.new(at, SinkTimeline.Kind.FLOODING, _stepper.cell_name(cell))
			)
		if _full[cell] == 0 and _gaps[cell] <= REACHED:
			_full[cell] = 1
			_events.append(
				SinkTimeline.Event.new(at, SinkTimeline.Kind.FULL, _stepper.cell_name(cell))
			)
		# A pocket at the state before this one, and at this one (_keep).
		var held := _pockets[_pockets.size() - _cells * 2 + cell] > 0.0
		var holds := _pockets[_pockets.size() - _cells + cell] > 0.0
		if holds and not held:
			_events.append(
				SinkTimeline.Event.new(at, SinkTimeline.Kind.TRAPPED, _stepper.cell_name(cell))
			)
		elif held and state.air[cell] < 0.0:
			_events.append(
				SinkTimeline.Event.new(at, SinkTimeline.Kind.VENTED, _stepper.cell_name(cell))
			)
	_lurches.follow(before, state, seconds)
	for boat in _boats.size():
		if _useless[boat] == 0 and _boats_useless(state.rotation, _boats[boat]):
			_useless[boat] = 1
			var side := &"starboard" if _boats[boat].side == 1 else &"port"
			_events.append(SinkTimeline.Event.new(at, SinkTimeline.Kind.BOATS_USELESS, side))
	if state.sea > SinkTimeline.MAIN_DECK and not _plunged:
		_plunged = true
		_events.append(SinkTimeline.Event.new(at, SinkTimeline.Kind.PLUNGING, &""))
	var above := state.above
	if _gone_at < 0.0 and above < 0.0:
		_gone_at = at
		_events.append(SinkTimeline.Event.new(at, SinkTimeline.Kind.GONE, &""))
	if _gone_at >= 0.0 and -above >= _sea.gone_depth:
		_end = SinkTimeline.End.GONE
	elif _gone_at < 0.0 and passed < STILL * seconds and at >= _doors_move_until:
		if _lies_still(state):
			_end = SinkTimeline.End.AFLOAT
	_done = _end != SinkTimeline.End.CAPPED or at >= _cap
	if _done:
		_lurches.close(state)
		_events = _merged(_events, _lurches.events)


## The state after [param state]: the step SinkStepper.advance chooses, or — where it
## carries the water past a ceiling or a sill it has not yet reached — the shorter one
## that lands on the first of them, its length found by false position on how far under
## it the water stands, the step to try next kept as advance chose it.
func _next(state: FloodState) -> FloodState:
	var next := _stepper.advance(state)
	var after := _gaps_of(next)
	var first := -1
	var share := 1.0
	for crossing in _gaps.size():
		var gap := _gaps[crossing]
		if _landed[crossing] == 1 or gap <= REACHED or after[crossing] >= -REACHED:
			continue
		var at := gap / (gap - after[crossing])
		if at < share:
			share = at
			first = crossing
	if first == -1:
		_gaps = after
		_note_under()
		return next
	_landed[first] = 1
	var low := 0.0
	var low_gap := _gaps[first]
	var high := next.seconds - state.seconds
	var high_gap := after[first]
	var landed := next
	var gaps := after
	for _try in LAND_TRIES:
		var seconds := low + (high - low) * low_gap / (low_gap - high_gap)
		landed = _stepper.step(state, seconds)
		gaps = _gaps_of(landed)
		var gap := gaps[first]
		if absf(gap) <= REACHED:
			break
		if gap > 0.0:
			low = seconds
			low_gap = gap
		else:
			high = seconds
			high_gap = gap
	landed.above = _stepper.above(landed)
	landed.next_step = next.next_step
	_gaps = gaps
	_note_under()
	return landed


## How far under each ceiling and sill a step lands on the water of [param state]
## stands, the stepper turned to its attitude: the water a cell still has room for,
## over its average surface — not a full cell's push, which stands over its ceiling —;
## the higher of an opening's two sides — the sea's, outside — under its sill.
func _gaps_of(state: FloodState) -> PackedFloat64Array:
	var gaps := PackedFloat64Array()
	gaps.resize(_cells + _names.size())
	for cell in _cells:
		gaps[cell] = room(cell, state.water[cell])
	for index in _names.size():
		var sides := _stepper.opening_sides(index)
		var high := maxf(_level(state, sides.x), _level(state, sides.y))
		gaps[_cells + index] = _stepper.sill_of(index) - high
	if _sea.air:
		for cell in _cells:
			gaps.append(_stepper.highest_top(cell) - state.heads[cell])
	return gaps


## How high [param water] short of full leaves [param cell], over its average surface
## at the attitude last turned to; under 0 past full.
func room(cell: int, water: float) -> float:
	var full := _stepper.capacity_of(cell)
	return (full - water) * (_stepper.ceiling_of(cell) - _stepper.floor_of(cell)) / full


func _level(state: FloodState, side: int) -> float:
	return state.sea if side == SinkStepper.OUTSIDE else state.heads[side]


## Marks each ceiling and sill the water now stands clearly under: one it then reaches,
## it reached from below.
func _note_under() -> void:
	for crossing in _gaps.size():
		if _gaps[crossing] > REACHED:
			_under[crossing] = 1


func _keep(state: FloodState) -> void:
	_times.append(state.seconds)
	_seas.append(state.sea)
	_rotations.append_array(state.rotation)
	_heads.append_array(state.heads)
	_waters.append_array(state.water)
	_pockets.append_array(_stepper.pressures(state))


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
static func _merged(
	first: Array[SinkTimeline.Event], second: Array[SinkTimeline.Event]
) -> Array[SinkTimeline.Event]:
	var made: Array[SinkTimeline.Event] = []
	var at := 0
	for event: SinkTimeline.Event in first:
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


## The lurch rule (§5b.4), followed step by step: a lurch while her list changes faster
## than lurch_rate_deg a second, the list it swings her by added up over it; warned at
## its precursor — the last time she lost her stability since the lurch before — and
## never less than lurch_warning seconds ahead, which is where the bake places the
## warning when the precursor comes later or never. Stood further on end than she is
## level along her length — past 45° of trim — she has no list to speak of: a roll then
## is no lurch.
class Lurches:
	var events: Array[SinkTimeline.Event] = []
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

	## Ends the lurch under way, if any, at [param state]: its warning first, then the
	## lurch, which carries the second it was warned at.
	func close(state: FloodState) -> void:
		if _from < 0.0:
			return
		var warned := _from - _warning
		if _lost_at >= 0.0 and _lost_at < warned:
			warned = _lost_at
		warned = maxf(warned, 0.0)
		var heel := _swung * 180.0 / PI
		events.append(SinkTimeline.Event.new(warned, SinkTimeline.Kind.LURCHING, &"", heel))
		var lurch := SinkTimeline.Event.new(
			_from, SinkTimeline.Kind.LURCHED, &"", heel, state.seconds - _from
		)
		lurch.warned = warned
		events.append(lurch)
		_from = -1.0
		_lost_at = -1.0
