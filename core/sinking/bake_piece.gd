class_name BakePiece
extends RefCounted
## One piece of her hull as the bake follows it (SinkBake): a whole ship is one piece,
## a broken one two or three (SH33, HullBreak) — each its own stepper (SinkStepper) over
## its own sections, cells, mass and openings, and its own state. Each step it is carried
## to brings its events — a cell's first water, a cell full, water first over a low wall
## or down a stair, a pocket trapped or let out, a lurch, a side's boats useless, what
## gives way, the plunge, the bottom, the piece going — and where a ceiling, a sill or a
## threshold comes within a step, how far it stands from each (gaps_of), so the bake lands
## a step there. How it ends — gone, afloat, aground — once it does: a piece that has
## ended is not stepped again.

## A level this close to a ceiling or a sill, in metres, has reached it: the
## timeline's millimetre.
const REACHED := 1e-3
## Less than this many m³ a second of its water changing anywhere, and no door still
## moving: the water has stopped coming in — or its pumps lift out what still does
## (SH31) — (est.: a litre a second, under 20 t in the bake's whole cap, where sinking
## her within it takes hundreds).
const STILL := 1e-3
## Slower than this it lies still: m/s of heave, radians a second of pitch and roll
## (est.: a millimetre and a twentieth of a degree in a quarter of an hour).
const STILL_RISE := 1e-6
const STILL_TURN := 1e-6
## The cosine of 45°.
const SQRT_HALF := 0.7071067811865476

var stepper: SinkStepper
var state: FloodState
## Its place among the pieces (SinkTimeline.spans): 0 for the whole ship.
var id: int
var end := SinkTimeline.End.CAPPED
## The physics second it was wholly under, or -1 for never.
var gone_at := -1.0
## Its pockets' pressures at its last state kept (SinkStepper.pressures).
var pressures := PackedFloat64Array()
## The worst its bending came to, a share of its strength — positive hogging — and where.
var bending := 0.0
var bending_x := 0.0
## While a hinge is forming in it (HullBreak): the weak spot's index in her strength, and
## the second the hinge began; -1 for none.
var hinge := -1
var hinged_at := -1.0
var _sea: SeaPhysics
var _events: Array[SinkTimeline.Event] = []
var _cells := 0
var _wet := PackedByteArray()
var _full := PackedByteArray()
var _names: Array[StringName] = []
var _spilled := PackedByteArray()
var _doors_move_until := 0.0
var _plunged := false
var _grounded := false
var _lurches: Lurches
var _boats: Array[ShipFitting] = []
var _useless := PackedByteArray()
## What gives way, with the failures stage on; and its events (Failures).
var _failures: SinkFailures
var _failing: Failures
## Per ceiling and sill — every cell's ceiling, then every opening's sill, then with the
## air stage on every cell's highest opening top, then with the failures stage on every
## threshold of what can give way (SinkFailures.gaps) — how far under it the water stood at
## the last state, and 1 once it was ever under it by more than REACHED; and 1 once a
## step has landed on it, or for a sill no step lands on.
var _gaps := PackedFloat64Array()
var _under := PackedByteArray()
var _landed := PackedByteArray()
## Gaps a step lands on that are not its own water's (HullBreak.gaps): their count.
var _more := 0


## The piece [param piece_id] the bake follows with [param piece_stepper] under [param sea],
## from [param from] — its state at the hit, or as a break left it — its gaps from there
## with [param more] of the break's after its own (HullBreak.gaps).
func _init(
	piece_stepper: SinkStepper,
	sea: SeaPhysics,
	from: FloodState,
	piece_id: int,
	more := PackedFloat64Array()
) -> void:
	stepper = piece_stepper
	_sea = sea
	state = from
	id = piece_id
	_failures = stepper.failures()
	_cells = state.water.size()
	pressures = stepper.pressures(state)
	_wet.resize(_cells)
	_full.resize(_cells)
	for cell in _cells:
		_wet[cell] = (
			1 if state.heads[cell] >= stepper.floor_of(cell) + SinkTimeline.FIRST_WATER else 0
		)
	_names = stepper.opening_names()
	_spilled.resize(_names.size())
	_more = more.size()
	_gaps = gaps_of(state, more)
	_under.resize(_gaps.size())
	_landed.resize(_gaps.size())
	# Water passing any other kind of opening is never news — as though it had spilled
	# — and no step lands on its sill: only the timeline's events are landed on. One shut
	# until it fails is news as it gives way.
	for index in _names.size():
		var watched := _failures != null and _failures.watches(index)
		if not _spills(stepper.opening_kind(index)) or watched or state.opened[index] > 0.0:
			_spilled[index] = 1
			_landed[_cells + index] = 1
	note_under()
	_doors_move_until = stepper.last_door()
	_lurches = Lurches.new(sea)
	_boats = stepper.lifeboats()
	_useless.resize(_boats.size())
	for boat in _boats.size():
		_useless[boat] = 1 if SinkBake.boats_useless(state.rotation, _boats[boat]) else 0
	if _failures != null:
		_failing = Failures.new(stepper, sea)


## Takes what [param parent] — the piece it broke from — had announced, by name, as
## announced here too: a cell's first water and its being full, water first over a sill,
## the plunge, the bottom, a side's boats, the hull's creak. A break is no news of those.
func carry_news(parent: BakePiece) -> void:
	for cell in _cells:
		var named := stepper.cell_name(cell)
		for other in parent._cells:
			if parent.stepper.cell_name(other) == named:
				_wet[cell] = parent._wet[other]
				_full[cell] = parent._full[other]
	for index in _names.size():
		var was := parent._names.find(_names[index])
		if was != -1 and parent._spilled[was] == 1:
			_spilled[index] = 1
			_landed[_cells + index] = 1
	_plunged = parent._plunged
	_grounded = parent._grounded
	for boat in _boats.size():
		var was := parent._boats.find(_boats[boat])
		if was != -1:
			_useless[boat] = parent._useless[was]
	if _failing != null and parent._failing != null:
		_failing.creaked = parent._failing.creaked


## Whether it has ended: it is not stepped again.
func has_ended() -> bool:
	return end != SinkTimeline.End.CAPPED


## Its events, in the order they happen — its lurches' and failures' merged in once it
## has ended or the bake is over (close).
func events() -> Array[SinkTimeline.Event]:
	return _events


## How far under each ceiling and sill of its own a step lands on the water of
## [param at] stands, the stepper turned to its attitude: the water a cell still has
## room for, over its average surface — not a full cell's push, which stands over its
## ceiling —; the higher of an opening's two sides — the sea's, outside — under its sill;
## then [param more], the break's (HullBreak.gaps).
func gaps_of(at: FloodState, more := PackedFloat64Array()) -> PackedFloat64Array:
	var gaps := PackedFloat64Array()
	gaps.resize(_cells + _names.size())
	for cell in _cells:
		gaps[cell] = room(cell, at.water[cell])
	for index in _names.size():
		var sides := stepper.opening_sides(index)
		var high := maxf(_level(at, sides.x), _level(at, sides.y))
		gaps[_cells + index] = stepper.sill_of(index) - high
	if _sea.air:
		for cell in _cells:
			gaps.append(stepper.highest_top(cell) - at.heads[cell])
	if _failures != null:
		gaps.append_array(_failures.gaps(at, stepper))
	gaps.append_array(more)
	return gaps


## How high [param water] short of full leaves [param cell], over its average surface
## at the attitude last turned to; under 0 past full.
func room(cell: int, water: float) -> float:
	var full := stepper.capacity_of(cell)
	return (full - water) * (stepper.ceiling_of(cell) - stepper.floor_of(cell)) / full


## The first ceiling or sill [param after] — its gaps after a step — carries the water
## past, not yet reached or landed on, as the share of the step that reaches it, then
## its index; INF and -1 for none.
func first_crossing(after: PackedFloat64Array) -> Vector2:
	var first := -1
	var share := INF
	for crossing in _gaps.size():
		var gap := _gaps[crossing]
		if _landed[crossing] == 1 or gap <= REACHED or after[crossing] >= -REACHED:
			continue
		var at := gap / (gap - after[crossing])
		if at < share:
			share = at
			first = crossing
	return Vector2(share, first)


## The gap [param crossing] stood at, before the step.
func gap(crossing: int) -> float:
	return _gaps[crossing]


## A step is landing on [param crossing]: none lands there again.
func land(crossing: int) -> void:
	_landed[crossing] = 1


## Takes [param gaps] as where the water now stands from each ceiling and sill, and
## marks each it now stands clearly under: one it then reaches, it reached from below.
func note(gaps: PackedFloat64Array) -> void:
	_gaps = gaps
	note_under()


func note_under() -> void:
	for crossing in _gaps.size():
		if _gaps[crossing] > REACHED:
			_under[crossing] = 1


## Carries it to [param next], [param seconds] after its state, and keeps the events the
## step brought; whether it ended there. [param cap] is the bake's.
func follow(next: FloodState, seconds: float) -> bool:
	var before := state
	state = next
	var held := pressures
	pressures = stepper.pressures(next)
	var at := next.seconds
	for index in _names.size():
		var moved := absf(next.moved[index])
		var reached := _under[_cells + index] == 1 and _gaps[_cells + index] <= REACHED
		if _spilled[index] == 0 and (moved > 0.0 or reached):
			_spilled[index] = 1
			_add_own(SinkTimeline.Kind.SPILLING, _names[index], at)
	for cell in _cells:
		var head := next.heads[cell]
		if _wet[cell] == 0 and head >= stepper.floor_of(cell) + SinkTimeline.FIRST_WATER:
			_wet[cell] = 1
			_add_own(SinkTimeline.Kind.FLOODING, stepper.cell_name(cell), at)
		if _full[cell] == 0 and _gaps[cell] <= REACHED:
			_full[cell] = 1
			_add_own(SinkTimeline.Kind.FULL, stepper.cell_name(cell), at)
		# A pocket at the state before this one, and at this one.
		var had := held[cell] > 0.0
		var holds := pressures[cell] > 0.0
		if holds and not had:
			_add_own(SinkTimeline.Kind.TRAPPED, stepper.cell_name(cell), at)
		elif had and next.air[cell] < 0.0:
			_add_own(SinkTimeline.Kind.VENTED, stepper.cell_name(cell), at)
	_lurches.follow(before, next, seconds)
	for boat in _boats.size():
		if _useless[boat] == 0 and SinkBake.boats_useless(next.rotation, _boats[boat]):
			_useless[boat] = 1
			var side := &"starboard" if _boats[boat].side == 1 else &"port"
			_add_own(SinkTimeline.Kind.BOATS_USELESS, side, at)
	if _failing != null:
		_failures.measure(next)
		_failing.follow(before, next)
		if absf(next.bending) > absf(bending):
			bending = next.bending
			bending_x = next.bending_x
	if next.sea > SinkTimeline.MAIN_DECK and not _plunged:
		_plunged = true
		_add_own(SinkTimeline.Kind.PLUNGING, _named(), at)
	var above := next.above
	var grounded := stepper.grounded(next)
	if grounded and not _grounded:
		_grounded = true
		_add_own(SinkTimeline.Kind.GROUNDED, _named(), at)
	if gone_at < 0.0 and above < 0.0:
		gone_at = at
		_add_own(SinkTimeline.Kind.GONE, _named(), at)
	if gone_at >= 0.0 and (-above >= _sea.gone_depth or above < 0.0 and grounded):
		end = SinkTimeline.End.GONE
	elif gone_at < 0.0 and _changed(before, next) < STILL * seconds and at >= _doors_move_until:
		# Upside down she floats on air still leaking: followed on, to whether it lets
		# her go under within the cap (§5b.1).
		if _lies_still(next) and (grounded or next.rotation[4] > 0.0):
			end = SinkTimeline.End.AGROUND if grounded else SinkTimeline.End.AFLOAT
	return has_ended()


## It is over, by its end or the bake's: still capped and on the bottom, it is aground;
## its lurch under way ends, and its lurches' and failures' events join its own.
func close() -> void:
	if end == SinkTimeline.End.CAPPED and stepper.grounded(state):
		end = SinkTimeline.End.AGROUND
	_lurches.close(state)
	_events = SinkBake.merged(_events, _owned(_lurches.events))
	if _failing != null:
		_events = SinkBake.merged(_events, _owned(_failing.events))


## [param found], each marked as this piece's.
func _owned(found: Array[SinkTimeline.Event]) -> Array[SinkTimeline.Event]:
	for event: SinkTimeline.Event in found:
		event.piece = id
	return found


## Adds an event of its own — one the bake does not merge in later — of [param kind]
## naming [param named] at [param at].
func _add_own(kind: SinkTimeline.Kind, named: StringName, at: float) -> void:
	var event := SinkTimeline.Event.new(at, kind, named)
	event.piece = id
	_events.append(event)


## What an event of the whole of it names: nothing for the whole ship; a piece she broke
## into, by its number.
func _named() -> StringName:
	return &"" if id == 0 else StringName("piece %d" % id)


## Adds [param event], from the break, after every one at or before its second.
func add(event: SinkTimeline.Event) -> void:
	event.piece = id
	var at := _events.size()
	while at > 0 and _events[at - 1].seconds > event.seconds:
		at -= 1
	_events.insert(at, event)


func _level(at: FloodState, side: int) -> float:
	return at.sea if side == SinkStepper.OUTSIDE else at.heads[side]


## How much water [param after]'s cells hold more or less than [param before]'s, all of
## them together, in m³.
func _changed(before: FloodState, after: FloodState) -> float:
	var changed := 0.0
	for cell in _cells:
		changed += absf(after.water[cell] - before.water[cell])
	return changed


## Whether [param at] lies still: neither rising nor falling, pitching nor rolling, nor
## standing unstable.
static func _lies_still(at: FloodState) -> bool:
	return (
		absf(at.heave_rate) < STILL_RISE
		and absf(at.pitch_rate) < STILL_TURN
		and absf(at.roll_rate) < STILL_TURN
		and at.roll_stiffness >= 0.0
	)


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

	## Ends the lurch under way, if any, at [param at]: its warning first, then the
	## lurch, which carries the second it was warned at.
	func close(at: FloodState) -> void:
		if _from < 0.0:
			return
		var warned := _from - _warning
		if _lost_at >= 0.0 and _lost_at < warned:
			warned = _lost_at
		warned = maxf(warned, 0.0)
		var heel := _swung * 180.0 / PI
		events.append(SinkTimeline.Event.new(warned, SinkTimeline.Kind.LURCHING, &"", heel))
		var lurch := SinkTimeline.Event.new(
			_from, SinkTimeline.Kind.LURCHED, &"", heel, at.seconds - _from
		)
		lurch.warned = warned
		events.append(lurch)
		_from = -1.0
		_lost_at = -1.0


## What gives way (SinkFailures), followed step by step: an opening or a wall's panel
## starting to leak, and giving way; a funnel's fall, warned at its creak — the last time
## it began to creak while it stood, creak_share of the way to a limit of its stays — and
## never less than fall_warning seconds ahead, the bake placing the warning where the
## creak comes later or never; her generator stopping and running again, and her going
## dark; a cell's water reaching its lamps; and her hull creaking once its bending passes
## stressed_share of its strength.
class Failures:
	var events: Array[SinkTimeline.Event] = []
	var _stepper: SinkStepper
	var _funnels: FunnelStays
	var _generator: StringName
	## Whether her hull has creaked.
	var creaked := false
	var _warning: float
	var _stressed: float
	## Per funnel, the second it last began to creak while standing, or -1 for not now.
	var _creak_at := PackedFloat64Array()

	func _init(stepper: SinkStepper, sea: SeaPhysics) -> void:
		_stepper = stepper
		_funnels = stepper.failures().funnels()
		var generator := stepper.failures().power().generator()
		_generator = generator.name if generator != null else &""
		_warning = sea.fall_warning
		_stressed = sea.stressed_share
		_creak_at.resize(_funnels.fittings().size())
		_creak_at.fill(-1.0)

	## Follows the step from [param before] to [param after].
	func follow(before: FloodState, after: FloodState) -> void:
		var at := after.seconds
		var names := _stepper.opening_names()
		for index in names.size():
			var opened := after.opened[index]
			if opened == before.opened[index]:
				continue
			var kind := SinkTimeline.Kind.GAVE_WAY
			if opened < SinkFailures.GAVE_WAY:
				kind = SinkTimeline.Kind.LEAKING
			_add(SinkTimeline.Event.new(at, kind, names[index]))
		for funnel in _creak_at.size():
			if before.fallen[funnel] == 0 and after.fallen[funnel] == 1:
				_fall(funnel, after)
			elif after.fallen[funnel] == 0 and _funnels.strained(after, funnel):
				if _creak_at[funnel] < 0.0:
					_creak_at[funnel] = at
			else:
				_creak_at[funnel] = -1.0
		if before.power == ShipPower.Power.MAIN and after.power != ShipPower.Power.MAIN:
			_add(SinkTimeline.Event.new(at, SinkTimeline.Kind.POWER_LOST, _generator))
		elif before.power != ShipPower.Power.MAIN and after.power == ShipPower.Power.MAIN:
			_add(SinkTimeline.Event.new(at, SinkTimeline.Kind.POWER_BACK, _generator))
		if before.power != ShipPower.Power.DARK and after.power == ShipPower.Power.DARK:
			_add(SinkTimeline.Event.new(at, SinkTimeline.Kind.LIGHTS_OUT, &""))
		for cell in after.shorted.size():
			if before.shorted[cell] == 0 and after.shorted[cell] == 1:
				_add(
					SinkTimeline.Event.new(at, SinkTimeline.Kind.SHORTED, _stepper.cell_name(cell))
				)
		if not creaked and absf(after.bending) >= _stressed:
			creaked = true
			_add(SinkTimeline.Event.new(at, SinkTimeline.Kind.HULL_STRESSED, &"", after.bending))

	## Funnel [param funnel] let go at [param state]: its creak, then its fall, along the
	## world's down there, as long as it takes.
	func _fall(funnel: int, state: FloodState) -> void:
		var fitting := _funnels.fittings()[funnel]
		var at := state.seconds
		var warned := at - _warning
		if _creak_at[funnel] >= 0.0 and _creak_at[funnel] < warned:
			warned = _creak_at[funnel]
		warned = maxf(warned, 0.0)
		var toward := FunnelStays.toward(state)
		var creak := SinkTimeline.Event.new(
			warned, SinkTimeline.Kind.FUNNEL_STRAINING, fitting.name, 0.0, at - warned
		)
		creak.along = toward
		_add(creak)
		var falling := SinkTimeline.Event.new(
			at, SinkTimeline.Kind.FUNNEL_FALLING, fitting.name, 0.0, fitting.fall_time
		)
		falling.warned = warned
		falling.along = toward
		_add(falling)
		_creak_at[funnel] = -1.0

	## Adds [param event] after every one at or before its second.
	func _add(event: SinkTimeline.Event) -> void:
		var at := events.size()
		while at > 0 and events[at - 1].seconds > event.seconds:
			at -= 1
		events.insert(at, event)
