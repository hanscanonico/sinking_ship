class_name SinkBake
extends RefCounted
## The bake (§5b.1, §5b.4, D7): SinkStepper run once from the hit, over every piece of
## her hull (BakePiece) — one, or from SH33 the two or three she breaks into (HullBreak)
## — each step as long as the physics chooses (SinkStepper.advance; the shortest any
## piece chooses, every piece stepped by it) but cut short to land where a cell's water
## reaches its ceiling, the sill of an opening it spills over or — with the air stage on
## — the top of the last opening its air had, so those events stand at their own seconds
## and a pocket traps the air it had then — and, with the failures stage on, where
## anything reaches the threshold it gives way at (SinkFailures), and where her hull
## reaches a threshold of its breaking, so each happens at its own second too; to the
## end — every piece gone, wholly under and going down or on the bottom, or the water
## stopped coming in and it lies still, upright or aground — or the bake's cap, which
## finds a piece aground where it rests on the bottom. Every state and every event, a
## lurch and a funnel's fall with their warnings, how she broke and the worst her bending
## came to go into the timeline it makes (SinkTimeline). It runs a slice at a time — run()
## takes the steps it is allowed — so a scene can spread it across frames (R20): a bake
## run in slices is the bake run straight through, step for step, and the stepper stays
## state in, state out.

## A level this close to a ceiling or a sill, in metres, has reached it: the
## timeline's millimetre. A landing its first guess misses is guessed again, by false
## position, at most LAND_TRIES times in all, once per ceiling or sill.
const REACHED := 1e-3
const LAND_TRIES := 4

var _sea: SeaPhysics
var _cap: float
var _breaking: HullBreak
var _done := false
var _end := SinkTimeline.End.CAPPED
var _gone_at := -1.0
var _seconds := 0.0
## Every piece of her the bake has followed, the whole ship first, each one a break made
## after the piece it broke from (SinkTimeline.spans): where along her it runs, from
## then to, the piece it broke from — -1 for the whole ship — and the second it did.
var _pieces: Array[BakePiece] = []
var _spans := PackedFloat64Array()
var _parents := PackedInt32Array()
var _born := PackedFloat64Array()
## The pieces she is in now, aft to fore.
var _alive := PackedInt32Array([0])
## Every state, the hit's first: its physics second and the pieces she was in then, and
## per piece of those, in their order, the sea up it, its rotation (nine numbers), and
## every cell's head, water, pocket's pressure (SinkStepper.pressures) and what lights it
## (FloodState.lit).
var _times := PackedFloat64Array()
var _alive_of: Array[PackedInt32Array] = []
var _seas := PackedFloat64Array()
var _rotations := PackedFloat64Array()
var _heads := PackedFloat64Array()
var _waters := PackedFloat64Array()
var _pockets := PackedFloat64Array()
var _lits := PackedByteArray()
## The same per piece of her that never broke (leaves), once the bake is over and she
## broke: made from the above, each state's numbers for a piece being those of the piece
## it was part of then.
var _leafed: Array = []
var _timeline: SinkTimeline


## The bake of [param stepper] under [param sea], to [param cap] physics seconds, her
## hull breaking as [param breaking] says — never, without it.
func _init(stepper: SinkStepper, sea: SeaPhysics, cap: float, breaking: HullBreak = null) -> void:
	_sea = sea
	_cap = cap
	_breaking = breaking
	var more := PackedFloat64Array()
	if breaking != null:
		more.resize(breaking.count())
		more.fill(INF)
	var whole := BakePiece.new(stepper, sea, stepper.start(), 0, more)
	_pieces.append(whole)
	var ends := breaking.ends() if breaking != null else Vector2.ZERO
	_spans.append_array([ends.x, ends.y])
	_parents.append(-1)
	_born.append(0.0)
	if breaking != null:
		whole.note(whole.gaps_of(whole.state, breaking.gaps(whole, ends, whole.state, 1)))
	_seconds = whole.state.seconds
	_keep()
	_done = _seconds >= _cap


## The bake of the hit that did [param damage] to [param structure] under [param sea], to
## [param cap] physics seconds: her stepper, and her breaking where she can break.
static func of(
	structure: ShipStructure, damage: HitDamage, sea: SeaPhysics, cap: float
) -> SinkBake:
	var stepper := SinkStepper.new(structure, damage, sea)
	return SinkBake.new(stepper, sea, cap, HullBreak.of(structure, damage, sea))


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
	return _seconds


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


## What the bake kept, for SinkTimeline to make itself from, per piece that never broke
## (leaves): every state's second; and per state, per leaf, the sea up it and its
## rotation, then per cell of every leaf in turn its head, water, pocket and light; and
## how many cells the leaves have, all together.
func times() -> PackedFloat64Array:
	return _times


func seas() -> PackedFloat64Array:
	return _kept(0)


func rotations() -> PackedFloat64Array:
	return _kept(1)


func heads() -> PackedFloat64Array:
	return _kept(2)


func waters() -> PackedFloat64Array:
	return _kept(3)


func pockets() -> PackedFloat64Array:
	return _kept(4)


func lits() -> PackedByteArray:
	return _kept(5)


func cells() -> int:
	var count := 0
	for leaf: int in leaves():
		count += cells_of(leaf)
	return count


## Where each piece runs along her, from then to (SinkTimeline.spans); the piece each broke
## from; the second each did; and the pieces that never broke, in that order.
func spans() -> PackedFloat64Array:
	return _spans


func parents() -> PackedInt32Array:
	return _parents


func born() -> PackedFloat64Array:
	return _born


func leaves() -> PackedInt32Array:
	var found := PackedInt32Array()
	for piece in _pieces.size():
		if not piece in _parents:
			found.append(piece)
	return found


## How many cells the leaf [param leaf] has.
func cells_of(leaf: int) -> int:
	return _pieces[leaf].state.water.size()


## Its events, every piece's, in the order they happen — where two fall on the same
## second, the earlier piece's first; how it ends and when she was wholly under, -1 for
## never; where the sea stands up her at rest with no water in her.
func events() -> Array[SinkTimeline.Event]:
	var found: Array[SinkTimeline.Event] = []
	for piece: BakePiece in _pieces:
		found = merged(found, piece.events())
	return found


func end() -> SinkTimeline.End:
	return _end


func gone_at() -> float:
	return _gone_at


func rest() -> float:
	return _pieces[0].stepper.rest()


## The worst her bending came to in any piece, a share of its strength — positive hogging
## — and where along her (FloodState.bending): 0 where nobody measured it.
func bending() -> float:
	return _pieces[_worst()].bending


func bending_x() -> float:
	return _pieces[_worst()].bending_x


func _worst() -> int:
	var worst := 0
	for piece in _pieces.size():
		if absf(_pieces[piece].bending) > absf(_pieces[worst].bending):
			worst = piece
	return worst


## How high [param water] short of full leaves the whole ship's [param cell], over its
## average surface at the attitude last turned to; under 0 past full.
func room(cell: int, water: float) -> float:
	return _pieces[0].room(cell, water)


## One step of every piece still going, landed where a ceiling, a sill or a threshold
## comes within it, what it brought, and any break it made.
func _take() -> void:
	var stepping := PackedInt32Array()
	for index: int in _alive:
		if not _pieces[index].has_ended():
			stepping.append(index)
	var nexts := _next(stepping)
	for at in stepping.size():
		var piece := _pieces[stepping[at]]
		if piece.follow(nexts[at], nexts[at].seconds - piece.state.seconds):
			piece.close()
	_seconds = nexts[0].seconds
	_keep()
	if _breaking != null:
		_break()
	var going := false
	for index: int in _alive:
		going = going or not _pieces[index].has_ended()
	_done = _seconds >= _cap or not going
	if _done:
		_finish()


## Every piece still going at the end closed, and how she ends: gone once every piece
## is, aground once every piece is gone or aground, afloat while any lies afloat, else
## capped; wholly under at the last piece's going, once every piece has gone.
func _finish() -> void:
	for index: int in _alive:
		if not _pieces[index].has_ended():
			_pieces[index].close()
	var ends := {}
	var all_gone := true
	for index: int in _alive:
		var piece := _pieces[index]
		ends[piece.end] = true
		all_gone = all_gone and piece.gone_at >= 0.0
		_gone_at = maxf(_gone_at, piece.gone_at)
	if not all_gone:
		_gone_at = -1.0
	if ends.has(SinkTimeline.End.CAPPED):
		_end = SinkTimeline.End.CAPPED
	elif ends.has(SinkTimeline.End.AFLOAT):
		_end = SinkTimeline.End.AFLOAT
	elif ends.has(SinkTimeline.End.AGROUND):
		_end = SinkTimeline.End.AGROUND
	else:
		_end = SinkTimeline.End.GONE


## Breaks every piece still going whose hinge has run and holds no more, at the weak spot
## it hinged at: its two pieces take its place, aft then fore.
func _break() -> void:
	var alive := _alive
	for index: int in alive:
		var piece := _pieces[index]
		if piece.has_ended():
			continue
		var span := Vector2(_spans[index * 2], _spans[index * 2 + 1])
		if _breaking.follow(piece, span, _alive.size()) == -1:
			continue
		var at := _pieces.size()
		var x := _breaking.at(piece.hinge)
		var parted := _breaking.split(piece, span, at)
		piece.close()
		var cut := parted[1].state.seconds
		var now := PackedInt32Array()
		for other: int in _alive:
			if other != index:
				now.append(other)
				continue
			now.append_array([at, at + 1])
		_alive = now
		for side in 2:
			_pieces.append(parted[side])
			_spans.append_array([span.x, x] if side == 0 else [x, span.y])
			_parents.append(index)
			_born.append(cut)
		for side in 2:
			var child := parted[side]
			var child_span := Vector2(_spans[(at + side) * 2], _spans[(at + side) * 2 + 1])
			child.note(
				child.gaps_of(
					child.state, _breaking.gaps(child, child_span, child.state, _alive.size())
				)
			)


## The states the pieces [param stepping] step to next: the step each chooses
## (SinkStepper.advance), all carried by the shortest; or — where that carries the water
## past a ceiling, a sill or a threshold not yet reached — the shorter one that lands on
## the first of them, its length found by false position on how far from it that piece
## stands, every piece stepped by it, the step to try next kept as each chose it.
func _next(stepping: PackedInt32Array) -> Array[FloodState]:
	var nexts: Array[FloodState] = []
	var used := PackedFloat64Array()
	var seconds := INF
	for index: int in stepping:
		var piece := _pieces[index]
		var next := piece.stepper.advance(piece.state)
		nexts.append(next)
		used.append(next.seconds - piece.state.seconds)
		seconds = minf(seconds, used[used.size() - 1])
	for at in stepping.size():
		if used[at] > seconds:
			nexts[at] = _stepped(_pieces[stepping[at]], seconds, nexts[at].next_step)
	var afters: Array[PackedFloat64Array] = []
	var first := Vector2(1.0, -1.0)
	var landing := -1
	for at in stepping.size():
		var piece := _pieces[stepping[at]]
		afters.append(piece.gaps_of(nexts[at], _more(stepping[at], nexts[at])))
		var found := piece.first_crossing(afters[at])
		if found.x < first.x:
			first = found
			landing = at
	if landing == -1:
		for at in stepping.size():
			_pieces[stepping[at]].note(afters[at])
		return nexts
	var lands := _pieces[stepping[landing]]
	var crossing := int(first.y)
	lands.land(crossing)
	var low := 0.0
	var low_gap := lands.gap(crossing)
	var high := seconds
	var high_gap := afters[landing][crossing]
	var landed := nexts[landing]
	var gaps := afters[landing]
	var taken := seconds
	for _try in LAND_TRIES:
		taken = low + (high - low) * low_gap / (low_gap - high_gap)
		landed = lands.stepper.step(lands.state, taken)
		gaps = lands.gaps_of(landed, _more(stepping[landing], landed))
		var gap := gaps[crossing]
		if absf(gap) <= REACHED:
			break
		if gap > 0.0:
			low = taken
			low_gap = gap
		else:
			high = taken
			high_gap = gap
	landed.above = lands.stepper.above(landed)
	landed.next_step = nexts[landing].next_step
	lands.note(gaps)
	for at in stepping.size():
		if at == landing:
			nexts[at] = landed
			continue
		var piece := _pieces[stepping[at]]
		nexts[at] = _stepped(piece, taken, nexts[at].next_step)
		piece.note(piece.gaps_of(nexts[at], _more(stepping[at], nexts[at])))
	return nexts


## [param piece] stepped [param seconds], the step to try next [param next_step].
static func _stepped(piece: BakePiece, seconds: float, next_step: float) -> FloodState:
	var next := piece.stepper.step(piece.state, seconds)
	next.above = piece.stepper.above(next)
	next.next_step = next_step
	return next


## The break's gaps for piece [param index] at [param at] (HullBreak.gaps): none where
## she cannot break.
func _more(index: int, at: FloodState) -> PackedFloat64Array:
	if _breaking == null:
		return PackedFloat64Array()
	var span := Vector2(_spans[index * 2], _spans[index * 2 + 1])
	return _breaking.gaps(_pieces[index], span, at, _alive.size())


func _keep() -> void:
	_times.append(_seconds)
	_alive_of.append(_alive)
	for index: int in _alive:
		var piece := _pieces[index]
		var state := piece.state
		_seas.append(state.sea)
		_rotations.append_array(state.rotation)
		_heads.append_array(state.heads)
		_waters.append_array(state.water)
		_pockets.append_array(piece.pressures)
		_lits.append_array(state.lit if not state.lit.is_empty() else _lit_throughout(state))


## What lights each cell of [param state] without the failures stage: everything, as
## before SH31.
static func _lit_throughout(state: FloodState) -> PackedByteArray:
	var lit := PackedByteArray()
	lit.resize(state.water.size())
	lit.fill(ShipPower.Power.MAIN)
	return lit


## The kept numbers of kind [param kind] — seas, rotations, heads, waters, pockets, lits —
## per leaf: as kept, while she is whole.
func _kept(kind: int) -> Variant:
	var kept: Array = [_seas, _rotations, _heads, _waters, _pockets, _lits]
	if _pieces.size() == 1:
		return kept[kind]
	if _leafed.is_empty():
		_leafed = _by_leaf()
	return _leafed[kind]


## The kept numbers per leaf (_kept): each state's for a leaf those of the piece it was
## part of then, its cells found in that piece by name — a cell cut in two by a later
## break carries the whole cell's head, water, pocket and light until it is.
func _by_leaf() -> Array:
	var made: Array = [
		PackedFloat64Array(),
		PackedFloat64Array(),
		PackedFloat64Array(),
		PackedFloat64Array(),
		PackedFloat64Array(),
		PackedByteArray(),
	]
	var leaf_pieces := leaves()
	var pose_at := 0
	var cell_at := 0
	for state in _times.size():
		var alive := _alive_of[state]
		var starts := PackedInt32Array()
		var cells_from := cell_at
		for index: int in alive:
			starts.append(cells_from)
			cells_from += cells_of(index)
		for leaf: int in leaf_pieces:
			var holder := _holder(alive, leaf)
			var pose := pose_at + holder
			made[0].append(_seas[pose])
			made[1].append_array(_rotations.slice(pose * 9, pose * 9 + 9))
			var piece := _pieces[alive[holder]]
			for cell in cells_of(leaf):
				var named := _pieces[leaf].stepper.cell_name(cell)
				var at := starts[holder] + _cell_named(piece, named)
				made[2].append(_heads[at])
				made[3].append(_waters[at])
				made[4].append(_pockets[at])
				made[5].append(_lits[at])
		pose_at += alive.size()
		cell_at = cells_from
	return made


## The place in [param alive] of the piece holding leaf [param leaf]: itself, or the piece
## it broke from that was standing then.
func _holder(alive: PackedInt32Array, leaf: int) -> int:
	for at in alive.size():
		var piece := alive[at]
		if _spans[piece * 2] <= _spans[leaf * 2] and _spans[leaf * 2 + 1] <= _spans[piece * 2 + 1]:
			return at
	return -1


## The cell of [param piece] called [param named].
static func _cell_named(piece: BakePiece, named: StringName) -> int:
	for cell in piece.state.water.size():
		if piece.stepper.cell_name(cell) == named:
			return cell
	return -1


## Whether [param boat]'s side stands high past its list limit under [param rotation]:
## its list's sine, read off her rotation — her up's reach athwartships — past the
## limit's, the boat's side up; or she is past her beam ends either way.
static func boats_useless(rotation: PackedFloat64Array, boat: ShipFitting) -> bool:
	var leaning := rotation[7] * boat.side
	return -leaning >= Attitude.sine_of_degrees(boat.list_limit_deg) or rotation[8] < 0.0


## [param first] and [param second], each in the order they happen, as one: where two
## fall on the same second, the first's first.
static func merged(
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
