class_name FloodWatch
extends RefCounted
## The flooding's invariants (§5b.1, #619), checked at every step a WatchedStepper takes:
## it reads each step, never moves water, so a bake watched is the bake unwatched, step
## for step. Each breach is counted per invariant, with the worst and where it stood, for
## a test to assert and a probe to print — a step's once a step begins from where it
## came to, its own otherwise counted as tried and not kept (tried):
## CONSERVED — each cell's change is what passed its openings (FloodState.moved, signed
## from an opening's first side to its second), what came over its edges (ShippedWater)
## and what its pumps lifted out, and her water adds up to the sea's account, to
## TOLERANCE of the cell's capacity (of all of them, for her total);
## DOWNHILL — every opening that moved water moved it from the side whose push stood
## higher at the step's start: its head, a held pocket's pressure counted (SinkAir.lift),
## the sea's for the sea, water over a hole in a floor standing no lower than the hole —
## or at its end, its head then: a step passes water on down a chain, the sweep's heads
## following and a held cell's solved for the step's end, so a side the step fills from
## higher up passes on what rises over the other within it (passed_on counts those); and
## the openings are swept in turn, so a side that gave more away through others in the
## step may stand lower than its neighbour for the ones after (swept counts those). The
## breaches of a step a bake took outside SinkStepper.advance, cut to land on a level or
## to keep pace with another piece, are counted apart (DOWNHILL_CUT); and every breach of
## either through an opening of a cell held stiff whose solve together did not close, let
## go to the sweep (SinkStepper._release), is counted again (RELEASED, #632);
## CAPACITY — no cell holds more than its box and the thin surface over its ceiling up to
## the highest push about at the step's start (full_surface), nor less than nothing;
## FED — a cell's water rises only where something higher feeds it — an opening from a
## side standing over it, at the step's start or its end, as DOWNHILL reads them — or a
## wave over its edges;
## BOYLE — a pocket's air, as the pressure its cells' heads give it (SinkAir) times the
## room their water leaves it, at the atmosphere's pressure, falls only by its leak: it
## neither gains nor, while all its cells stay trapped, loses more — but a pocket its
## cells leave no more room than pocket_least, which SinkAir works out at that room at
## least and lets go once under it, the model's floor (squeezed counts those); one whose
## air leaks under pocket_least, which SinkAir counts gone (let_go); and one whose room
## grows past pocket_least from under it, its air read again past what the floor's push
## left unread (floored).
## Only the steps a stepper takes are checked: a bake's carrying water into the pieces she
## breaks into is not a step.

enum Law { CONSERVED, DOWNHILL, DOWNHILL_CUT, CAPACITY, FED, BOYLE, RELEASED }

## A breach this small, as a share of the cell's capacity (of a pocket's air), is the
## floats' rounding. A held cell's head is solved only until the step's water on it is
## out by SinkStepper.SURPLUS_TOLERANCE, a slip the sweep passes on: in a step holding
## cells, water no more than that tolerance times their number, moved through an opening
## of a held cell or of one beside it, risen in such a cell or held past its box — on a
## full cell, whose thin surface is a hundredth of its plan, centimetres of head, more
## with a pocket's push — is that slip, not judged.
const TOLERANCE := 1e-6
## The water an opening may pass, in m³, under which its way is not judged.
const SLIGHT := 1e-9
const NAMES: Array[String] = [
	"conserved", "downhill", "downhill_cut", "capacity", "fed", "boyle", "released"
]
## How many breaches of each law are kept word for word.
const KEPT := 8

## Whether the step under way is one SinkStepper.advance chose, and the cells it let go
## (SinkStepper._release): WatchedStepper sets both.
var advancing := false
var released := PackedInt32Array()
## Steps watched, and of them the ones taken outside advance; and the flows that ran
## against the step's start but with its end (DOWNHILL).
var steps := 0
var cut_steps := 0
var passed_on := 0
## The flows against both that ran into a side the sweep had drawn down first (DOWNHILL).
var swept := 0
## Pockets squeezed into less room than pocket_least, their air let go; pockets leaked
## under pocket_least, let go; and pockets whose room grew past pocket_least from under
## it, the air its floor left unread read again (BOYLE).
var squeezed := 0
var let_go := 0
var floored := 0
## Per law: breaches, the worst one's size and the words of the first KEPT and the worst.
var counts := PackedInt32Array()
var worst := PackedFloat64Array()
var worst_said: Array[String] = []
var said: Array = []
## Per law, breaches by what breached it — an opening, a cell, a pocket's first cell.
var tallies: Array[Dictionary] = []
## Per law, breaches in steps tried and not kept: a step SinkStepper.advance halved, or a
## landing's guess the bake guessed again (they never become her state).
var tried := PackedInt32Array()

## Per stepper watched, by the state each of its steps since it last began one came to,
## the breaches that step found ([law, size, words] each); and the last state it came to.
var _pending := {}
var _last_of := {}

## Of the step begun (begun): per opening, each side's push at its start — its head, or
## the sea's, and its pocket's lift; per cell, its ceiling then; the highest push about;
## per pocket by its first cell, its air before the leak and as its pressure times its
## room reads it; and what mark() noted of the cells' water since.
var _push := PackedFloat64Array()
var _lift := PackedFloat64Array()
var _ceilings := PackedFloat64Array()
var _highest := -INF
var _crests := PackedFloat64Array()
var _pockets := PackedInt32Array()
var _air_after_leak := PackedFloat64Array()
var _boyle := PackedFloat64Array()
## Per pocket begun, by its first cell, the free air its push leaves unread where its
## cells' heads leave it less room than pocket_least (_floor_hides).
var _hidden := PackedFloat64Array()
var _marks: Array[PackedFloat64Array] = []
var _least := 0.0
var _atmosphere := 0.0
## The stepper's own: per opening, 1 for a hole in a floor; per cell, its water at any
## attitude.
var _in_floor := PackedByteArray()
var _boxes: Array[TiltedBox] = []
## The last step watched: its stepper, the state it came to and its openings' shares.
var _last_stepper: SinkStepper
var _last: FloodState
var _last_shares := PackedFloat64Array()
## The breaches the step under way has found; per cell, 1 where it is held or beside a
## held cell, and the water the step's solves may slip (TOLERANCE).
var _step_breaches: Array = []
var _near := PackedByteArray()
var _step_slip := 0.0


func _init() -> void:
	counts.resize(NAMES.size())
	worst.resize(NAMES.size())
	tried.resize(NAMES.size())
	for law in NAMES.size():
		worst_said.append("")
		said.append([])
		tallies.append({})


## The step from [param state] begun by [param stepper], turned to it, its air [param air]
## begun and its wells [param shipped]; its openings in a floor [param in_floor] and its
## cells' [param boxes].
func begun(
	stepper: SinkStepper,
	air: SinkAir,
	shipped: ShippedWater,
	in_floor: PackedByteArray,
	boxes: Array[TiltedBox],
	state: FloodState
) -> void:
	_marks.clear()
	_least = air.least()
	_atmosphere = air.atmosphere()
	_settle(stepper, state)
	_in_floor = in_floor
	_boxes = boxes
	var count := stepper.opening_names().size()
	var holding := air.holding()
	_push.resize(count * 2)
	_lift.resize(count * 2)
	_highest = state.sea
	for index in count:
		var sides := stepper.opening_sides(index)
		for side in 2:
			var cell := sides.x if side == 0 else sides.y
			var other := sides.y if side == 0 else sides.x
			var push := state.sea
			var lift := 0.0
			if cell != SinkStepper.OUTSIDE:
				push = state.heads[cell]
				if holding[cell] == 1:
					lift = air.lift(cell, other, state.heads)
			_push[index * 2 + side] = push + lift
			_lift[index * 2 + side] = lift
			_highest = maxf(_highest, push)
	_crests.resize(state.heads.size())
	for cell in state.heads.size():
		_crests[cell] = shipped.highest(cell)
		_highest = maxf(_highest, maxf(state.heads[cell], _crests[cell]))
	_ceilings = stepper.ceilings().duplicate()
	var pockets: Array = air.pockets()
	_pockets = (pockets[0] as PackedInt32Array).duplicate()
	_air_after_leak = (pockets[1] as PackedFloat64Array).duplicate()
	_boyle = _pocket_air(stepper, state, state.air, false)
	_hidden = _floor_hides(stepper, state)


## Notes the cells' water as the step stands: before its wells take the sea's, after, and
## before her pumps lift theirs out.
func mark(water: PackedFloat64Array) -> void:
	_marks.append(water.duplicate())


## Checks the step of [param seconds] [param stepper] took from [param state] to
## [param next], turned to it, holding [param held], each opening open by [param shares].
func stepped(
	stepper: SinkStepper,
	state: FloodState,
	next: FloodState,
	seconds: float,
	held: PackedInt32Array,
	shares: PackedFloat64Array
) -> void:
	steps += 1
	if not advancing:
		cut_steps += 1
	_last_stepper = stepper
	_last = next
	_last_shares = shares.duplicate()
	_last_of[stepper] = next
	_step_breaches = []
	if not _pending.has(stepper):
		_pending[stepper] = {}
	_pending[stepper][next] = _step_breaches
	var where := "%.3f s (+%.3f%s)" % [state.seconds, seconds, "" if advancing else ", cut"]
	var cells := next.water.size()
	var capacity := stepper.capacities()
	_near_held(stepper, held, shares, cells)
	var shipped := PackedFloat64Array()
	var pumped := PackedFloat64Array()
	shipped.resize(cells)
	pumped.resize(cells)
	for cell in cells:
		shipped[cell] = _marks[1][cell] - _marks[0][cell]
		pumped[cell] = _marks[2][cell] - next.water[cell]
	var into := PackedFloat64Array()
	into.resize(cells)
	for index in next.moved.size():
		var sides := stepper.opening_sides(index)
		if sides.x != SinkStepper.OUTSIDE:
			into[sides.x] -= next.moved[index]
		if sides.y != SinkStepper.OUTSIDE:
			into[sides.y] += next.moved[index]
	var fed := _downhill(stepper, next, held, shipped, shares, where)
	var total := 0.0
	var total_capacity := 0.0
	for cell in cells:
		var named := stepper.cell_name(cell)
		var expected := state.water[cell] + into[cell] + shipped[cell] - pumped[cell]
		var off := absf(next.water[cell] - expected)
		var room := TOLERANCE * capacity[cell]
		if off > room:
			_breach(
				Law.CONSERVED,
				off / capacity[cell],
				(
					"%s: %s off by %s m3 (%s of its %s m3; held %s)"
					% [where, named, off, off / capacity[cell], capacity[cell], cell in held]
				)
			)
		total += next.water[cell] - state.water[cell]
		total_capacity += capacity[cell]
		var ceiling := minf(_ceilings[cell], stepper.ceiling_of(cell))
		var full_area := _boxes[cell].full_area()
		var most := capacity[cell] + full_area * maxf(_highest - ceiling, 0.0)
		var slip := _step_slip if _near[cell] == 1 else room
		if next.water[cell] > most + slip or next.water[cell] < -slip:
			var past := next.water[cell] - most if next.water[cell] > most else next.water[cell]
			_breach(
				Law.CAPACITY,
				absf(past) / capacity[cell],
				(
					"%s: %s holds %s m3 of %s (%s past; held %s)"
					% [where, named, next.water[cell], capacity[cell], past, cell in held]
				)
			)
		var rise := next.water[cell] - state.water[cell]
		if rise > slip and fed[cell] == 0 and shipped[cell] <= 0.0:
			_breach(
				Law.FED,
				rise / capacity[cell],
				(
					"%s: %s rose %s m3 with nothing higher feeding it (held %s)"
					% [where, named, rise, cell in held]
				)
			)
	var account := next.sea_given - state.sea_given
	if absf(total - account) > TOLERANCE * total_capacity:
		_breach(
			Law.CONSERVED,
			absf(total - account) / total_capacity,
			"%s: her water moved %s m3, the sea's account %s" % [where, total, account]
		)
	var after := _pocket_air(stepper, next, next.air, true)
	for first in after.size():
		if _pockets.size() <= first or _pockets[first] != first or _boyle[first] <= 0.0:
			continue
		var leaked := _boyle_before(state, first) - _air_after_leak[first]
		var allowed := _boyle[first] - leaked
		var gain := after[first] - allowed
		if gain < 0.0 and _freed(next, first):
			continue
		if gain < 0.0 and _squeezed(stepper, next, first):
			squeezed += 1
			continue
		if gain < 0.0 and _held_after(next, first) <= _least:
			# Leaked under pocket_least: SinkAir counts such a pocket gone, its water moving
			# as though its air were free — the model's floor, not air lost.
			let_go += 1
			continue
		if gain > 0.0 and _hidden[first] > 0.0:
			# Its room stood under pocket_least at the step's start, its push worked out at
			# that room (SinkAir): the air the floor's push left unread is read again once
			# its room grows past it — air it held all along, not air made.
			var read_again := minf(gain, _hidden[first])
			gain -= read_again
			if read_again > TOLERANCE * maxf(_boyle[first], 1.0):
				floored += 1
		if absf(gain) > TOLERANCE * maxf(_boyle[first], 1.0):
			_breach(
				Law.BOYLE,
				absf(gain) / maxf(_boyle[first], 1.0),
				(
					"%s: %s's pocket gained %s m3 of free air beyond its leak (%s, leak %s, to %s)"
					% [where, stepper.cell_name(first), gain, _boyle[first], leaked, after[first]]
				)
			)


## Judges every opening that moved water in the step to [param next] (DOWNHILL), telling
## [param where]; gives per cell 1 where something higher fed it (FED). A flow is downhill
## where its side stood over the other at the step's start or end, or where what fed that
## side in the step — a wave over its edges, [param shipped], or a flow judged downhill,
## from as high as its own source — stood over the other: the sweep passes water on down
## a chain within a step, and a full cell's head is the push it passes on, not a level.
func _downhill(
	stepper: SinkStepper,
	next: FloodState,
	held: PackedInt32Array,
	shipped: PackedFloat64Array,
	shares: PackedFloat64Array,
	where: String
) -> PackedByteArray:
	var cells := next.water.size()
	var count := next.moved.size()
	# Per opening that moved water: from and to, each side's push at the start and the end.
	var ends := PackedFloat64Array()
	ends.resize(count * 4)
	var end_push := _end_pushes(stepper, next)
	for index in count:
		var amount := next.moved[index]
		if absf(amount) <= SLIGHT:
			continue
		var forward := amount > 0.0
		var sides := stepper.opening_sides(index)
		var from_side := sides.x if forward else sides.y
		var to_side := sides.y if forward else sides.x
		var at := index * 4
		ends[at] = _push[index * 2] if forward else _push[index * 2 + 1]
		ends[at + 1] = _push[index * 2 + 1] if forward else _push[index * 2]
		ends[at + 2] = next.sea if from_side == SinkStepper.OUTSIDE else next.heads[from_side]
		ends[at + 3] = next.sea if to_side == SinkStepper.OUTSIDE else next.heads[to_side]
		# At the step's end too a pocket lifts its water's push, as at its start.
		ends[at + 2] += _end_lift(end_push, from_side, to_side)
		ends[at + 3] += _end_lift(end_push, to_side, from_side)
		if _in_floor[index] == 1:
			# Over the hole — its second side — water stands no lower than the hole.
			var sill := stepper.sill_of(index)
			var over := at + (1 if forward else 0)
			ends[over] = maxf(ends[over], sill)
			ends[over + 2] = maxf(ends[over + 2], sill)
	# What feeds each cell in the step, as high as it stood: a wave over its edges, and
	# every flow judged downhill into it, from as high as its side or what fed that.
	var feeds := PackedFloat64Array()
	feeds.resize(cells)
	feeds.fill(-INF)
	for cell in cells:
		if shipped[cell] > 0.0:
			feeds[cell] = _crests[cell]
	# What each cell gave away through its openings in the step.
	var gave := PackedFloat64Array()
	gave.resize(cells)
	for index in count:
		var amount := next.moved[index]
		var sides := stepper.opening_sides(index)
		var giver := sides.x if amount > 0.0 else sides.y
		if giver != SinkStepper.OUTSIDE:
			gave[giver] += absf(amount)
	var downhill := PackedByteArray()
	downhill.resize(count)
	var changed := true
	while changed:
		changed = false
		for index in count:
			var amount := next.moved[index]
			if absf(amount) <= SLIGHT or downhill[index] == 1:
				continue
			var sides := stepper.opening_sides(index)
			if absf(amount) <= _slip(sides):
				continue
			var from_side := sides.x if amount > 0.0 else sides.y
			var to_side := sides.y if amount > 0.0 else sides.x
			var at := index * 4
			var source := maxf(ends[at], ends[at + 2])
			if from_side != SinkStepper.OUTSIDE:
				source = maxf(source, feeds[from_side])
			if ends[at] <= ends[at + 1] and ends[at + 2] <= ends[at + 3]:
				if source <= minf(ends[at + 1], ends[at + 3]):
					continue
			downhill[index] = 1
			changed = true
			if to_side != SinkStepper.OUTSIDE:
				feeds[to_side] = maxf(feeds[to_side], source)
	var fed := PackedByteArray()
	fed.resize(cells)
	for cell in cells:
		fed[cell] = 1 if shipped[cell] > 0.0 else 0
	for index in count:
		var amount := next.moved[index]
		if absf(amount) <= SLIGHT:
			continue
		var forward := amount > 0.0
		var sides := stepper.opening_sides(index)
		var from_side := sides.x if forward else sides.y
		var to_side := sides.y if forward else sides.x
		var at := index * 4
		var from_push := ends[at]
		var to_push := ends[at + 1]
		if absf(amount) <= _slip(sides):
			# Not judged, and not a breach of FED where it feeds a cell.
			if to_side != SinkStepper.OUTSIDE:
				fed[to_side] = 1
			continue
		if downhill[index] == 1:
			if to_side != SinkStepper.OUTSIDE:
				fed[to_side] = 1
			if from_push <= to_push:
				passed_on += 1
			continue
		if to_side != SinkStepper.OUTSIDE and gave[to_side] - absf(amount) >= absf(amount):
			# The sweep's order: the side it came to gave more away elsewhere in the step,
			# standing lower for the openings swept after that.
			fed[to_side] = 1
			swept += 1
			continue
		var words := (
			"%s: %s passed %s m3 from %s to %s, up %s m (share %s; %s)"
			% [
				where,
				stepper.opening_names()[index],
				absf(amount),
				_side_name(stepper, from_side),
				_side_name(stepper, to_side),
				to_push - from_push,
				shares[index] if index < shares.size() else -1.0,
				_sides_said(index, from_side, to_side, forward, next, held)
			]
		)
		_breach(Law.DOWNHILL if advancing else Law.DOWNHILL_CUT, to_push - from_push, words)
		if from_side in released or to_side in released:
			_breach(Law.RELEASED, to_push - from_push, words)
	return fed


## Per cell, the push of the pocket begun that holds it at [param next], its air and its
## cells' heads as the step left them (SinkAir's push: its air over the room the heads
## leave it, at no less room than pocket_least, times the atmosphere's pressure); 0 for a
## cell in none, freed, or in a pocket whose air is under pocket_least.
func _end_pushes(stepper: SinkStepper, next: FloodState) -> PackedFloat64Array:
	var cells := next.water.size()
	var found := PackedFloat64Array()
	found.resize(cells)
	var capacity := stepper.capacities()
	var held := PackedFloat64Array()
	var room := PackedFloat64Array()
	held.resize(cells)
	room.resize(cells)
	for cell in mini(cells, _pockets.size()):
		var first := _pockets[cell]
		if first == -1 or next.air[cell] < 0.0:
			continue
		held[first] += next.air[cell]
		room[first] += maxf(capacity[cell] - stepper.volume_at(cell, next.heads[cell]), 0.0)
	for cell in mini(cells, _pockets.size()):
		var first := _pockets[cell]
		if first == -1 or next.air[cell] < 0.0 or held[first] <= _least:
			continue
		found[cell] = _atmosphere * (held[first] / maxf(room[first], _least) - 1.0)
	return found


## The lift [param end_push] gives [param side]'s water across an opening to
## [param other]: none to a cell of its own pocket, nor for the sea.
func _end_lift(end_push: PackedFloat64Array, side: int, other: int) -> float:
	if side == SinkStepper.OUTSIDE or side >= _pockets.size() or _pockets[side] == -1:
		return 0.0
	if other != SinkStepper.OUTSIDE and _pockets[other] == _pockets[side]:
		return 0.0
	return end_push[side]


## The water a flow through an opening between [param sides] may pass either way as the
## solve's slip (TOLERANCE): the step's where a side is held or beside a held cell.
func _slip(sides: Vector2i) -> float:
	for side: int in [sides.x, sides.y]:
		if side != SinkStepper.OUTSIDE and _near[side] == 1:
			return maxf(_step_slip, SLIGHT)
	return SLIGHT


## Marks for the step the cells [param held] and those an opening open by [param shares]
## joins to one of them, and the slip their solves may leave (TOLERANCE).
func _near_held(
	stepper: SinkStepper, held: PackedInt32Array, shares: PackedFloat64Array, cells: int
) -> void:
	_near.resize(cells)
	_near.fill(0)
	_step_slip = SinkStepper.SURPLUS_TOLERANCE * held.size()
	for cell: int in held:
		_near[cell] = 1
	for index in shares.size():
		var sides := stepper.opening_sides(index)
		if shares[index] <= 0.0 or sides.x == SinkStepper.OUTSIDE or sides.y == SinkStepper.OUTSIDE:
			continue
		if sides.x in held or sides.y in held:
			_near[sides.x] = 1
			_near[sides.y] = 1


## Words for every law: one line each, its breaches, its worst and where.
func report(prefix: String) -> PackedStringArray:
	close()
	var lines := PackedStringArray()
	lines.append(
		(
			(
				"%s steps: %d (%d cut), %d flows passed on down a chain, %d into a side swept"
				+ " lower, %d pockets squeezed, %d let go, %d read past their floor"
			)
			% [prefix, steps, cut_steps, passed_on, swept, squeezed, let_go, floored]
		)
	)
	for law in NAMES.size():
		var also := "; %d in steps tried and not kept" % tried[law] if tried[law] > 0 else ""
		if counts[law] == 0:
			lines.append("%s %s: ok%s" % [prefix, NAMES[law], also])
			continue
		lines.append(
			(
				"%s %s: %d breaches%s, worst %s at %s"
				% [prefix, NAMES[law], counts[law], also, worst[law], worst_said[law]]
			)
		)
	return lines


## At rest, the last step watched: every cell joined to the sea through openings open
## and wet — the sea, or a cell standing at it, over the sill — its air free, standing
## within [param keep] metres of the sea. One line: those that do not, the worst first.
func at_rest(keep: float) -> PackedStringArray:
	var lines := PackedStringArray()
	if _last == null:
		return lines
	var stepper := _last_stepper
	var state := _last
	var cells := state.water.size()
	var reached := PackedByteArray()
	reached.resize(cells)
	var found := PackedInt32Array()
	var changed := true
	while changed:
		changed = false
		for index in state.moved.size():
			if _last_shares[index] <= 0.0:
				continue
			var sides := stepper.opening_sides(index)
			var sill := stepper.sill_of(index)
			for side in 2:
				var from := sides.x if side == 0 else sides.y
				var to := sides.y if side == 0 else sides.x
				if to == SinkStepper.OUTSIDE or reached[to] == 1 or state.air[to] >= 0.0:
					continue
				if from != SinkStepper.OUTSIDE and reached[from] == 0:
					continue
				if state.sea <= sill or stepper.floor_of(to) >= state.sea:
					continue
				reached[to] = 1
				found.append(to)
				changed = true
	var off := PackedStringArray()
	var worst_off := 0.0
	for cell: int in found:
		var apart := state.heads[cell] - state.sea
		if absf(apart) > keep:
			worst_off = maxf(worst_off, absf(apart))
			off.append("%s %+.3f m" % [stepper.cell_name(cell), apart])
	if off.is_empty():
		lines.append("at_rest: ok (%d cells open to the sea)" % found.size())
	else:
		lines.append(
			(
				"at_rest: %d of %d cells open to the sea stand off it, worst %.3f m: %s"
				% [off.size(), found.size(), worst_off, ", ".join(off.slice(0, 12))]
			)
		)
	return lines


## Every breach of [param law] in words: the first KEPT and the worst.
func breaches(law: Law) -> PackedStringArray:
	close()
	var found := PackedStringArray(said[law])
	if counts[law] > KEPT:
		found.append("worst: " + worst_said[law])
	if counts[law] > 0:
		var by := PackedStringArray()
		for subject: String in tallies[law]:
			by.append("%s %d" % [subject, tallies[law][subject]])
		found.append("by: " + ", ".join(by))
	return found


func _breach(law: Law, size: float, words: String) -> void:
	_step_breaches.append([law, size, words])


## Counts the breaches of the step of [param stepper] that came to [param state] — kept,
## as a step now begins from it — and those of its other steps since it last began one
## as tried.
func _settle(stepper: SinkStepper, state: FloodState) -> void:
	if not _pending.has(stepper):
		return
	var steps_found: Dictionary = _pending[stepper]
	for came_to: FloodState in steps_found:
		for found: Array in steps_found[came_to]:
			if came_to == state:
				_count(found[0], found[1], found[2])
			else:
				tried[found[0]] += 1
	_pending.erase(stepper)


## Settles every stepper's last step as kept: the state it ended at.
func close() -> void:
	for stepper: SinkStepper in _pending.keys():
		_settle(stepper, _last_of[stepper])


func _count(law: Law, size: float, words: String) -> void:
	counts[law] += 1
	var subject := words.get_slice(": ", 1).get_slice(" ", 0)
	tallies[law][subject] = tallies[law].get(subject, 0) + 1
	if (said[law] as Array).size() < KEPT:
		(said[law] as Array).append(words)
	if size > worst[law]:
		worst[law] = size
		worst_said[law] = words


## Both sides of opening [param index] in words, from [param from] to [param to] — its
## first to its second where [param forward]: each's head and pocket's lift at the step's
## start, its head at [param next]'s and whether the step held it.
func _sides_said(
	index: int, from: int, to: int, forward: bool, next: FloodState, held: PackedInt32Array
) -> String:
	var words := PackedStringArray()
	for at in 2:
		var side := from if at == 0 else to
		var slot := index * 2 + (0 if forward == (at == 0) else 1)
		var lift := _lift[slot]
		var end := next.sea if side == SinkStepper.OUTSIDE else next.heads[side]
		words.append(
			(
				"%.4f+%.4f then %.4f%s"
				% [_push[slot] - lift, lift, end, " held" if side in held else ""]
			)
		)
	return " -> ".join(words)


func _side_name(stepper: SinkStepper, side: int) -> String:
	return "the sea" if side == SinkStepper.OUTSIDE else String(stepper.cell_name(side))


## Per pocket begun, by its first cell, its air as [param state]'s heads squeeze it,
## times the room its cells' water leaves it, at the atmosphere's pressure: its free air
## as Boyle's law reads the push it gives (SinkAir) — over the cells of it that [param
## air] still holds trapped, the air [param air] gives them, or, where not [param ended],
## the pocket's air before its leak.
func _pocket_air(
	stepper: SinkStepper, state: FloodState, air: PackedFloat64Array, ended: bool
) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	found.resize(_pockets.size())
	var capacity := stepper.capacities()
	for first in _pockets.size():
		if _pockets[first] != first:
			continue
		var held := 0.0
		var by_heads := 0.0
		var by_water := 0.0
		for cell in _pockets.size():
			if _pockets[cell] != first or (ended and air[cell] < 0.0):
				continue
			held += air[cell]
			by_heads += maxf(capacity[cell] - stepper.volume_at(cell, state.heads[cell]), 0.0)
			by_water += maxf(capacity[cell] - state.water[cell], 0.0)
		if held <= _least:
			continue
		found[first] = held * by_water / maxf(by_heads, _least)
	return found


## Per pocket of [param state] begun, by its first cell, the free air its push leaves
## unread: SinkAir works a pocket's push out at no less room than pocket_least, so where
## its cells' heads leave it less, its air as that push reads it (_pocket_air) is less
## than the air it holds by as much as the room falls short.
func _floor_hides(stepper: SinkStepper, state: FloodState) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	found.resize(_pockets.size())
	var capacity := stepper.capacities()
	for first in _pockets.size():
		if _pockets[first] != first or _boyle[first] <= 0.0:
			continue
		var held := 0.0
		var by_heads := 0.0
		for cell in _pockets.size():
			if _pockets[cell] == first:
				held += state.air[cell]
				by_heads += maxf(capacity[cell] - stepper.volume_at(cell, state.heads[cell]), 0.0)
		if by_heads < _least:
			found[first] = maxf(held - _boyle[first], 0.0)
	return found


## The air pocket [param first]'s cells still trapped at [param next] hold.
func _held_after(next: FloodState, first: int) -> float:
	var held := 0.0
	for cell in _pockets.size():
		if _pockets[cell] == first and next.air[cell] >= 0.0:
			held += next.air[cell]
	return held


## Whether a cell of pocket [param first] has its air free at [param next]: its share of
## the pocket's air let out, not lost.
func _freed(next: FloodState, first: int) -> bool:
	for cell in _pockets.size():
		if _pockets[cell] == first and next.air[cell] < 0.0:
			return true
	return false


## Whether pocket [param first]'s cells leave it no more room than pocket_least at
## [param next]: SinkAir counts no pocket's room under that (its push is worked out at it
## at least) and lets go the air of one squeezed into less (SinkAir.settle).
func _squeezed(stepper: SinkStepper, next: FloodState, first: int) -> bool:
	var capacity := stepper.capacities()
	var room := 0.0
	for cell in _pockets.size():
		if _pockets[cell] == first:
			room += maxf(capacity[cell] - next.water[cell], 0.0)
	return room <= _least


func _boyle_before(state: FloodState, first: int) -> float:
	var held := 0.0
	for cell in _pockets.size():
		if _pockets[cell] == first:
			held += state.air[cell]
	return held
