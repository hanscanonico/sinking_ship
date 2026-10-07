class_name HullBreak
extends RefCounted
## Breaking (§5b.1, "Bending and breaking"; §5b.3, "Pieces"; SH33): the physics' last
## stage, over the pieces SinkStepper steps — a whole ship is one. A piece's bending at
## each of its weak spots (WeakSpot; HullGirder.share_at) is measured against the share of
## her strength the spot keeps, and at 1 a hinge starts there: the first spot to reach it,
## the most overloaded of those that reach it in one step. Over hinge_seconds the hinge
## loses all but hinge_keeps of that strength; overloaded still against what it keeps
## then, or once it is, the piece parts there into two, each its own stepper over its own
## cut of her structure (PieceStructure) — its own sections, cells, mass, attitude and
## bending check — carrying on from the piece's state: the same second, attitude and
## motion; each cell's water, a cell cut in two sharing it by the volume each half holds at
## its level; its air the same way; what had given way and what had fallen. The piece away
## from her generator is dark from then on: the break cuts the cables. Never more than
## most_pieces pieces, none shorter than shortest_piece of her length (SeaPhysics, est.).
## Every threshold is a gap the bake lands a step on (gaps), never a draw (D4). Only +, −,
## ×, ÷ on 64-bit floats run here (R21).

## A share this close to 1, or a second this close to its time, has reached it: the
## bake's millimetre (SinkBake.REACHED).
const REACHED := 1e-3

var _structure: ShipStructure
var _damage: HitDamage
var _sea: SeaPhysics
var _spots: Array[WeakSpot] = []
## Where her hull starts and ends along her, and the shortest a piece may be, in metres.
var _ends: Vector2
var _shortest: float


## The breaking of [param structure] after the hit that did [param damage] under
## [param sea], or null where she cannot break: the stage off, or no weak spot to part at,
## or nothing measuring her bending.
static func of(structure: ShipStructure, damage: HitDamage, sea: SeaPhysics) -> HullBreak:
	var measured := sea.attitude and sea.failures and sea.bending and structure.strength != null
	if not sea.breaking or not measured or structure.strength.weak.is_empty():
		return null
	return HullBreak.new(structure, damage, sea)


func _init(structure: ShipStructure, damage: HitDamage, sea: SeaPhysics) -> void:
	_structure = structure
	_damage = damage
	_sea = sea
	_spots = structure.strength.weak
	_ends = PieceStructure.span_of(structure)
	_shortest = sea.shortest_piece * (_ends.y - _ends.x)


## Where her hull starts and ends along her: the whole ship's span.
func ends() -> Vector2:
	return _ends


## Where along her weak spot [param spot] stands.
func at(spot: int) -> float:
	return _spots[spot].x


## How many gaps it adds after each piece's own (BakePiece.gaps_of): one per weak spot of
## hers, then the hinge's time and its hold.
func count() -> int:
	return _spots.size() + 2


## How far [param at], a state of [param piece] spanning [param span] while she is in
## [param pieces] pieces, stands from each threshold of the break — per weak spot, its
## bending reaching the spot's strength, while no hinge is forming and the spot may part;
## then the hinge's time running out, in seconds; then, once it has, the bending reaching
## what the hinge keeps — under 0 past it, INF for none to come. It measures [param at]'s
## bending into it.
func gaps(piece: BakePiece, span: Vector2, at: FloodState, pieces: int) -> PackedFloat64Array:
	var girder := piece.stepper.failures().girder()
	girder.measure(at)
	var found := PackedFloat64Array()
	for spot in _spots.size():
		if piece.hinge == -1 and _parts(span, spot, pieces):
			found.append(1.0 - absf(girder.share_at(_spots[spot].x, _spots[spot].share)))
		else:
			found.append(INF)
	if piece.hinge == -1:
		found.append_array([INF, INF])
		return found
	var left := _sea.hinge_seconds - (at.seconds - piece.hinged_at)
	found.append(left)
	found.append(INF if left > REACHED else 1.0 - _hinge_share(girder, piece.hinge))
	return found


## Follows [param piece], spanning [param span] while she is in [param pieces] pieces, to
## its state now — its bending measured there (SinkFailures.measure): starts a hinge at
## the weak spot first overloaded, the event added to the piece; or, its hinge run and
## still overloaded, gives the weak spot it parts at. -1 while it holds.
func follow(piece: BakePiece, span: Vector2, pieces: int) -> int:
	var at := piece.state
	var girder := piece.stepper.failures().girder()
	if piece.hinge == -1:
		var worst := 0.0
		for spot in _spots.size():
			if not _parts(span, spot, pieces):
				continue
			var share := girder.share_at(_spots[spot].x, _spots[spot].share)
			if 1.0 - absf(share) <= REACHED and absf(share) > absf(worst):
				worst = share
				piece.hinge = spot
		if piece.hinge != -1:
			piece.hinged_at = at.seconds
			var hinging := SinkTimeline.Event.new(
				at.seconds, SinkTimeline.Kind.HINGING, _spots[piece.hinge].name, worst
			)
			hinging.lasts = _sea.hinge_seconds
			piece.add(hinging)
		return -1
	if _sea.hinge_seconds - (at.seconds - piece.hinged_at) > REACHED:
		return -1
	return piece.hinge if 1.0 - _hinge_share(girder, piece.hinge) <= REACHED else -1


## [param piece], spanning [param span], parted at the weak spot it hinged at: the piece
## aft of it, then the piece fore of it, numbered [param aft_id] and [param aft_id] + 1.
## The PARTED event goes to [param piece].
func split(piece: BakePiece, span: Vector2, aft_id: int) -> Array[BakePiece]:
	var spot := _spots[piece.hinge]
	var parted := SinkTimeline.Event.new(
		piece.state.seconds,
		SinkTimeline.Kind.PARTED,
		spot.name,
		_hinge_share(piece.stepper.failures().girder(), piece.hinge)
	)
	piece.add(parted)
	var made: Array[BakePiece] = []
	for side in 2:
		var from := span.x if side == 0 else spot.x
		var to := spot.x if side == 0 else span.y
		var structure := PieceStructure.cut(_structure, from, to)
		var stepper := SinkStepper.new(
			structure, PieceStructure.damaged(_damage, structure, from, to), _sea
		)
		var state := _carried(piece, structure, stepper)
		var more := PackedFloat64Array()
		more.resize(count())
		more.fill(INF)
		var child := BakePiece.new(stepper, _sea, state, aft_id + side, more)
		child.carry_news(piece)
		made.append(child)
	return made


## Whether weak spot [param spot] may part a piece spanning [param span] while she is in
## [param pieces] pieces: one more is allowed, it stands inside the span, and neither
## part would be shorter than the shortest.
func _parts(span: Vector2, spot: int, pieces: int) -> bool:
	var x := _spots[spot].x
	return pieces < _sea.most_pieces and x - span.x >= _shortest and span.y - x >= _shortest


## The bending at the weak spot [param spot] measured last by [param girder] against what
## its hinge keeps of its strength.
func _hinge_share(girder: HullGirder, spot: int) -> float:
	return absf(girder.share_at(_spots[spot].x, _spots[spot].share * _sea.hinge_keeps))


## The state the piece of her [param structure] stepped by [param stepper] starts in, from
## [param parent]'s now: see the class's note.
func _carried(parent: BakePiece, structure: ShipStructure, stepper: SinkStepper) -> FloodState:
	var before := parent.state
	var state := FloodState.new()
	state.seconds = before.seconds
	state.steps = before.steps
	state.sea = before.sea
	state.rotation = before.rotation.duplicate()
	state.heave_rate = before.heave_rate
	state.pitch_rate = before.pitch_rate
	state.roll_rate = before.roll_rate
	state.roll_stiffness = before.roll_stiffness
	state.next_step = before.next_step
	var cells := {}
	for cell in before.water.size():
		cells[parent.stepper.cell_name(cell)] = cell
	var up := Attitude.up(before.rotation)
	for cell: FloodCell in structure.cells:
		var from: int = cells[cell.name]
		var head := before.heads[from]
		var whole := parent.stepper.volume_at(from, head)
		var area := (
			(float(cell.high.x) - cell.low.x)
			* (float(cell.high.z) - cell.low.z)
			* cell.permeability_in(_sea)
			* cell.shape
		)
		var capacity := area * (float(cell.high.y) - cell.low.y)
		var box := TiltedBox.new(cell.low, cell.high, capacity, area * _sea.full_surface)
		box.turn(up[0], up[1], up[2])
		var water := before.water[from] * box.volume(head) / whole if whole > 0.0 else 0.0
		state.water.append(water)
		state.heads.append(head)
		var room := parent.stepper.capacity_of(from) - before.water[from]
		var air := before.air[from]
		state.air.append(air if air < 0.0 or room <= 0.0 else air * (capacity - water) / room)
		state.shorted.append(before.shorted[from])
		state.lit.append(before.lit[from])
		state.sea_given += water
	var names := parent.stepper.opening_names()
	for named: StringName in stepper.opening_names():
		var index := names.find(named)
		state.opened.append(before.opened[index] if index != -1 else 0.0)
	state.moved.resize(state.opened.size())
	var funnels: Array[StringName] = []
	for funnel: ShipFitting in parent.stepper.failures().funnels().fittings():
		funnels.append(funnel.name)
	for funnel: ShipFitting in stepper.failures().funnels().fittings():
		state.fallen.append(before.fallen[funnels.find(funnel.name)])
	var powered := stepper.failures().power().generator() != null
	state.power = before.power if powered else ShipPower.Power.DARK
	state.drowned = before.drowned if powered else false
	state.battery = before.battery if powered else -1.0
	stepper.pressures(state)
	for cell in state.water.size():
		state.heads[cell] = stepper.head(cell, state.water[cell])
	state.above = stepper.above(state)
	return state
