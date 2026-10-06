class_name ShippedWater
extends RefCounted
## Green water (§5b.1): the mean effect of a seaway on an open well — a working deck
## between bulwarks — whose edge stands low over the sea. Each edge the sea can come over
## (FloodCell.shipping_edges) is a weir between the well and a sea that stands
## wave_reach × the wave height over its still level at a crest and as far under it in
## a trough: water comes aboard where the crest stands over the edge and over the well's
## own water, and goes back over where the well's water stands over the edge and over
## the trough — per metre of edge, discharge × √(2g) × the depth over it^1.5 (SeaPhysics:
## shipping_discharge, wave_reach, est.). So a well whose freeing ports drain it slower
## than the sea comes over its edge stands above the sea, its loose water to the low side
## (TiltedBox), and a deck hole in it lets that water below — the Gaul's loss; an edge
## deep under even the troughs only keeps the well at the sea's level; in a still sea the
## edge is a plain weir both ways, so nothing comes over until the edge is under.
## A well its edges pass water for fills and drains within seconds — far inside a step —
## so SinkStepper holds it as a stiff cell: its head solved for the step with this flow
## counted (into), and the step's water given at that head (ship). One the stepper lets
## go is given the flow at its level, stopped where the flow turns, so it never
## overshoots. Only +, −, ×, ÷ and square roots on 64-bit floats run here (D4, R21).
## Ship-local metres; heights along the world's up from her origin, as the sea's.

## A stretch of edge whose depth changes by less than this along it, in metres, is
## taken at its middle's depth; the level where the flow turns is found to
## TURN_TOLERANCE metres in at most TURN_STEPS halvings.
const LEVEL_STRETCH := 1e-6
const TURN_TOLERANCE := 1e-6
const TURN_STEPS := 60

## Per cell, its place among the wells, or -1 for a cell the sea comes into only
## through its openings; per well, its cell, its edges' ends in ship space — six
## numbers an edge — and lengths, and at the attitude last begun, its edges' ends'
## heights — two an edge — and the lowest of them.
var _well_of := PackedInt32Array()
var _cells := PackedInt32Array()
var _ends: Array[PackedFloat64Array] = []
var _lengths: Array[PackedFloat64Array] = []
var _heights: Array[PackedFloat64Array] = []
var _lowest := PackedFloat64Array()
## How far a crest stands over the still sea, and a trough under it, in metres;
## discharge × √(2g); and at the step last begun, the crest's and the trough's heights.
var _reach: float
var _rate: float
var _crest := 0.0
var _trough := 0.0


## The green water [param structure]'s open wells ship in a sea of waves
## [param wave_height] metres high, under [param sea]'s constants.
func _init(structure: ShipStructure, wave_height: float, sea: SeaPhysics) -> void:
	_reach = sea.wave_reach * wave_height
	_rate = sea.shipping_discharge * sqrt(2.0 * sea.gravity)
	for cell in structure.cells.size():
		var well := structure.cells[cell]
		if well.kind != FloodCell.Kind.OPEN_WELL or well.shipping_edges.is_empty():
			_well_of.append(-1)
			continue
		_well_of.append(_cells.size())
		var ends := PackedFloat64Array()
		var lengths := PackedFloat64Array()
		for edge in well.shipping_edges.size() / 2:
			var a := well.shipping_edges[edge * 2]
			var b := well.shipping_edges[edge * 2 + 1]
			ends.append_array(PackedFloat64Array([a.x, a.y, a.z, b.x, b.y, b.z]))
			var dx := float(b.x) - a.x
			var dy := float(b.y) - a.y
			var dz := float(b.z) - a.z
			lengths.append(sqrt(dx * dx + dy * dy + dz * dz))
		_cells.append(cell)
		_ends.append(ends)
		_lengths.append(lengths)
		var heights := PackedFloat64Array()
		heights.resize(lengths.size() * 2)
		_heights.append(heights)
		_lowest.append(0.0)


## Turns the wells' edges to [param rotation], the sea still at [param sea]: the step
## about to be taken.
func begin(rotation: PackedFloat64Array, sea: float) -> void:
	_crest = sea + _reach
	_trough = sea - _reach
	var up := Attitude.up(rotation)
	for well in _cells.size():
		var ends := _ends[well]
		var heights := _heights[well]
		var lowest := INF
		for end in heights.size():
			var at := end * 3
			heights[end] = up[0] * ends[at] + up[1] * ends[at + 1] + up[2] * ends[at + 2]
			lowest = minf(lowest, heights[end])
		_lowest[well] = lowest


## Whether cell [param cell], its water at [param level], is a well its edges may pass
## water for at the attitude begun: the crest or its own water over an edge's lowest end.
func ships(cell: int, level: float) -> bool:
	var well := _well_of[cell]
	return well != -1 and maxf(_crest, level) > _lowest[well]


## The highest cell [param cell]'s water may be held at: the crest for a well, which
## nothing comes over past it; -INF for any other cell.
func highest(cell: int) -> float:
	return _crest if _well_of[cell] != -1 else -INF


## The m³ a second cell [param cell] takes over its edges, its water at [param level]:
## positive aboard, 0 for a cell that is no well.
func into(cell: int, level: float) -> float:
	var well := _well_of[cell]
	if well == -1:
		return 0.0
	var heights := _heights[well]
	var lengths := _lengths[well]
	var depth := 0.0
	for edge in lengths.size():
		var from := heights[edge * 2]
		var to := heights[edge * 2 + 1]
		depth += over(from, to, lengths[edge], _crest, level)
		depth -= over(from, to, lengths[edge], level, _trough)
	return _rate * depth


## Gives every well of [param state] its [param seconds] of green water on the sea's
## account, before the step's openings move theirs: one [param held] (1) at the head the
## step solved in [param heads], the flow there — what its openings pass then brings it
## to that head, so it may hold more than it can for the moment; any other the flow at
## its level, stopped where the flow turns and at its ceiling — each cell's water at any
## attitude [param boxes] — its head in [param heads] following. A full well is the
## sea's own: nothing comes over its edge.
func ship(
	state: FloodState,
	heads: PackedFloat64Array,
	held: PackedByteArray,
	boxes: Array[TiltedBox],
	seconds: float
) -> void:
	for cell: int in _cells:
		var box := boxes[cell]
		var water := state.water[cell]
		if water >= box.capacity():
			continue
		var solved := held[cell] == 1
		var level := heads[cell] if solved else box.height(water)
		var now := into(cell, level)
		if now == 0.0:
			continue
		var amount := now * seconds
		if not solved:
			var after := box.height(water + amount)
			if into(cell, after) * now <= 0.0:
				amount = box.volume(_still_level(cell, level, after, now > 0.0)) - water
			amount = minf(amount, box.capacity() - water)
		amount = maxf(amount, -water)
		state.water[cell] = water + amount
		state.sea_given += amount
		if not solved:
			heads[cell] = box.height(state.water[cell])


## The level between [param low] — cell [param cell] taking water there when
## [param rising], giving it when not — and [param high], where it is not, at which its
## edges pass nothing: halved down to TURN_TOLERANCE.
func _still_level(cell: int, low: float, high: float, rising: bool) -> float:
	for _step in TURN_STEPS:
		if absf(high - low) <= TURN_TOLERANCE:
			break
		var middle := (low + high) * 0.5
		if (into(cell, middle) > 0.0) == rising:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## ∫ max(0, [param high] − max(edge, [param low]))^1.5 along an edge [param length]
## long whose height runs straight from [param from] to [param to]: the depth^1.5 a
## weir passes, summed over its wet stretch, water at [param high] coming over it to
## water at [param low]. With u the depth over the edge itself, straight from u0 to u1
## and capped at the most, U = high − low: the integral of min(u, U)^1.5 over u's
## positive part is ⅖ u^2.5 up to U and ⅖ U^2.5 + U^1.5 (u − U) past it, so the
## stretch's is its length × the difference of that between u0 and u1 over u1 − u0.
static func over(from: float, to: float, length: float, high: float, low: float) -> float:
	var most := high - low
	if most <= 0.0:
		return 0.0
	var u0 := high - from
	var u1 := high - to
	if absf(u1 - u0) < LEVEL_STRETCH:
		var depth := clampf((u0 + u1) * 0.5, 0.0, most)
		return length * depth * sqrt(depth)
	return length * (_summed(u1, most) - _summed(u0, most)) / (u1 - u0)


## ∫₀^[param u] min(max(v, 0), [param most])^1.5 dv.
static func _summed(u: float, most: float) -> float:
	if u <= 0.0:
		return 0.0
	if u <= most:
		return 0.4 * u * u * sqrt(u)
	return 0.4 * most * most * sqrt(most) + most * sqrt(most) * (u - most)
