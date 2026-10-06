class_name SinkAir
extends RefCounted
## The air in her cells (§5b.1): SinkStepper's air stage. A cell's air is free while an
## opening gives it a way to the sky — one whose top stands at or over the cell's water,
## out to the sea or the sky, the air bubbling up through any water there, or into a
## cell not full, whose air it joins, free in turn. Air only rises: through an opening
## lying flatter than steep with the cell over it, it passes only into air standing
## there, never down into water. Once none does it is trapped, and trapped cells that
## touch through a dry opening — its top over the water on both sides — share one
## pocket and one pressure.
## Both are read from world heights — the openings' tops, the cells' water — so a hull
## upside down traps air against its old floors with no special case. A pocket keeps its
## air as the m³ it would fill at the atmosphere's pressure: in the room its cells leave
## over their water it is squeezed to a pressure (Boyle's law, at one temperature) that
## pushes back on the water coming in (lift), and it leaks out through each of its cells'
## leak areas — rivets, seams — by the orifice law, at what the pocket stands over the
## sea outside the cell's highest corner. The research's simple form for a step of
## seconds: free or trapped, plus one slow leak. Pressures are metres of sea, as heads
## are. Only +, −, ×, ÷ and square roots on 64-bit floats run here (D4, R21).
## Ship-local metres along the world's up from her origin, as SinkStepper's.

## FloodState.air of a cell whose air is free.
const FREE := -1.0
## The other side of an opening to the sea or the sky (SinkStepper.OUTSIDE).
const OUTSIDE := -1
## The sine of 45°: an opening whose face turns further than this toward the world's up
## lies flat, and air passes it only upward.
const SQRT_HALF := 0.7071067811865476

var _on: bool
## The atmosphere's pressure as metres of sea; the free air a square metre of leak
## passes a second per root metre of sea it is pushed by, at the atmosphere's
## pressure; and the least air a pocket holds.
var _atmosphere: float
var _speed: float
var _least: float
## Per cell: its water at any attitude (the stepper's, turned with it), the water it
## holds full, the area its air leaks through, and the openings that touch it.
var _boxes: Array[TiltedBox] = []
var _capacity := PackedFloat64Array()
var _leaks := PackedFloat64Array()
var _touching: Array[PackedInt32Array] = []
## Per opening, in the stepper's order: its sides, the seconds it takes to shut from the
## hit (0 for one that stays as it is), the ship axis it is flat across and which way
## along it its first side lies (1 or -1); and at the attitude last turned to its top,
## and the way air passes it — 1 up from its first side only, -1 up from its second
## only, 0 either way.
var _first := PackedInt32Array()
var _second := PackedInt32Array()
var _shut_time := PackedFloat64Array()
var _axis := PackedInt32Array()
var _facing := PackedFloat64Array()
var _top := PackedFloat64Array()
var _upward := PackedInt32Array()
## For the step begun (begin): each cell's pocket — its first cell — or -1 for free air;
## and by its first cell, each pocket's air once the step's leak is out, and its cells.
var _pocket := PackedInt32Array()
var _air := PackedFloat64Array()
var _members: Array[PackedInt32Array] = []
## The push each pocket was last worked out at, by its first cell, and the heads of its
## cells it was worked out from: a solve asks it again at every opening of a cell.
var _pushed := PackedFloat64Array()
var _pushed_at := PackedFloat64Array()


func _init(sea: SeaPhysics) -> void:
	_on = sea.air
	_atmosphere = sea.air_pressure / (sea.sea_density * sea.gravity)
	_speed = sea.discharge * sqrt(2.0 * sea.gravity * sea.sea_density / sea.air_density)
	_least = sea.pocket_least


## Adds a cell: its water [param box], the water it holds full, and the area its air
## leaks through.
func add_cell(box: TiltedBox, capacity: float, leak_area: float) -> void:
	_boxes.append(box)
	_capacity.append(capacity)
	_leaks.append(leak_area)


## Adds an opening between [param first] and [param second] — a cell each, or OUTSIDE —
## that the ship shuts over [param shut_time] seconds from the hit, 0 for never: flat
## across ship [param axis], [param first] lying along it the way of [param facing]'s
## sign.
func add_opening(first: int, second: int, shut_time: float, axis: int, facing: float) -> void:
	_first.append(first)
	_second.append(second)
	_shut_time.append(shut_time)
	_axis.append(axis)
	_facing.append(facing)


## Done adding: each cell's openings, by index, as [param touching] has them.
func close(touching: Array[PackedInt32Array]) -> void:
	_touching = touching
	_top.resize(_first.size())
	_upward.resize(_first.size())
	_pocket.resize(_boxes.size())
	_pocket.fill(-1)
	_air.resize(_boxes.size())
	_members.resize(_boxes.size())
	_pushed.resize(_boxes.size())
	_pushed_at.resize(_boxes.size())


## Opening [param index] turned to the attitude where the world's up is [param up] in
## the ship's axes: its highest corner at [param top].
func turned(index: int, top: float, up: PackedFloat64Array) -> void:
	_top[index] = top
	var rise := up[_axis[index]] * _facing[index] if _axis[index] >= 0 else 0.0
	_upward[index] = -1 if rise > SQRT_HALF else (1 if rise < -SQRT_HALF else 0)


## The air of every cell of [param state], whose water is where it starts: free, or
## all its room's air at the atmosphere's pressure, trapped.
func start(state: FloodState) -> void:
	var free := _free(state)
	state.air.resize(_boxes.size())
	for cell in _boxes.size():
		state.air[cell] = FREE if free[cell] == 1 else _room(cell, state.water[cell])


## Begins a step of [param seconds] from [param state], the boxes turned to its
## attitude: its trapped cells cut into pockets, each with its air less what it leaks
## over the step at the pressure it starts it under — out first, so the water the step
## moves comes in behind it rather than a step late.
func begin(state: FloodState, seconds: float) -> void:
	_pocket.fill(-1)
	_pushed_at.fill(NAN)
	if not _on:
		return
	for first in _boxes.size():
		if state.air[first] < 0.0 or _pocket[first] != -1:
			continue
		var members := PackedInt32Array([first])
		_pocket[first] = first
		var at := 0
		while at < members.size():
			var cell := members[at]
			at += 1
			for index: int in _touching[cell]:
				var other := _second[index] if _first[index] == cell else _first[index]
				if other == OUTSIDE or state.air[other] < 0.0 or _pocket[other] != -1:
					continue
				if _reaches(cell, other, index, state) and _reaches(other, cell, index, state):
					members.append(other)
					_pocket[other] = first
		var air := 0.0
		for cell: int in members:
			air += state.air[cell]
		_members[first] = members
		_air[first] = air
		if seconds > 0.0:
			_air[first] = maxf(air - _leak(first, state) * seconds, 0.0)
			# Its push was worked out with the air it had before the leak.
			for cell: int in members:
				_pushed_at[cell] = NAN


## Whether [param cell]'s water is held by a pocket in the step begun.
func holds(cell: int) -> bool:
	return _pocket[cell] != -1 and _air[_pocket[cell]] > _least


## Whether [param a] and [param b] are cells of one pocket in the step begun.
func shared(a: int, b: int) -> bool:
	return a != OUTSIDE and b != OUTSIDE and _pocket[a] != -1 and _pocket[a] == _pocket[b]


## The cells of [param cell]'s pocket, itself among them; none for free air.
func members(cell: int) -> PackedInt32Array:
	return _members[_pocket[cell]] if _pocket[cell] != -1 else PackedInt32Array()


## How far over [param cell]'s water its pocket's pressure stands, in metres of sea,
## across an opening to [param other] — none to a cell of the same pocket — with the
## cells' heads at [param heads]: what lifts its water's push.
func lift(cell: int, other: int, heads: PackedFloat64Array) -> float:
	if cell == OUTSIDE or _pocket[cell] == -1 or shared(cell, other):
		return 0.0
	return _push(_pocket[cell], heads)


## Every cell's pocket's pressure with [param state]'s heads, the boxes turned to its
## attitude and a step of none begun from it: in metres of sea over nothing — the
## atmosphere's and the push of its squeezed air — or 0 for a cell holding none.
func pressures(state: FloodState) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	found.resize(_boxes.size())
	for cell in _boxes.size():
		if holds(cell):
			found[cell] = _atmosphere + _push(_pocket[cell], state.heads)
	return found


## Settles [param next]'s air once the step begun has moved the water and turned her:
## each pocket's air shared out over the room its cells have left; then which cells are
## free, and those newly trapped holding their room's air at the atmosphere's pressure.
func settle(next: FloodState) -> void:
	if not _on:
		return
	var rooms := PackedFloat64Array()
	rooms.resize(_boxes.size())
	for cell in _boxes.size():
		if _pocket[cell] != -1:
			rooms[_pocket[cell]] += _room(cell, next.water[cell])
	var free := _free(next)
	for cell in _boxes.size():
		var first := _pocket[cell]
		if free[cell] == 1:
			next.air[cell] = FREE
		elif first == -1:
			next.air[cell] = _room(cell, next.water[cell])
		elif rooms[first] > _least:
			next.air[cell] = _air[first] * _room(cell, next.water[cell]) / rooms[first]
		else:
			# Squeezed to no room: what the solve's slip left of it got out.
			next.air[cell] = 0.0


## The highest top of [param cell]'s openings at the attitude last turned to: once its
## water passes it, nothing lets its air out; -INF for a cell with none.
func highest_top(cell: int) -> float:
	var highest := -INF
	for index: int in _touching[cell]:
		highest = maxf(highest, _top[index])
	return highest


## The free air pocket [param first] leaks a second at [param state]: through each of its
## cells' leak area, by what the pocket stands over the sea outside the cell's highest
## corner — the sea's over it, or the atmosphere's where it stands clear — at the
## density of the air squeezed to its pressure.
func _leak(first: int, state: FloodState) -> float:
	var push := _push(first, state.heads)
	var squeezed := (_atmosphere + push) / _atmosphere
	var leaked := 0.0
	for cell: int in _members[first]:
		var over := push - maxf(state.sea - _boxes[cell].top(), 0.0)
		if over > 0.0 and _leaks[cell] > 0.0:
			leaked += _speed * _leaks[cell] * sqrt(over * squeezed)
	return leaked


## How far pocket [param first]'s pressure stands over the atmosphere's, in metres of
## sea, its cells' heads at [param heads]: its air over the room they leave it, times
## the atmosphere's; none for a pocket that has all but leaked away.
func _push(first: int, heads: PackedFloat64Array) -> float:
	var air := _air[first]
	if air <= _least:
		return 0.0
	var members := _members[first]
	var same := true
	for cell: int in members:
		same = same and heads[cell] == _pushed_at[cell]
	if same:
		return _pushed[first]
	var room := 0.0
	for cell: int in members:
		room += maxf(_capacity[cell] - _boxes[cell].volume(heads[cell]), 0.0)
		_pushed_at[cell] = heads[cell]
	_pushed[first] = _atmosphere * (air / maxf(room, _least) - 1.0)
	return _pushed[first]


## The room [param cell] holding [param water] m³ leaves its air, in m³.
func _room(cell: int, water: float) -> float:
	return maxf(_capacity[cell] - water, 0.0)


## Per cell of [param state], 1 where its air is free: an opening lets it out to the
## sea or the sky, or into a cell whose air is free — found until nothing changes.
func _free(state: FloodState) -> PackedByteArray:
	var free := PackedByteArray()
	free.resize(_boxes.size())
	if not _on:
		free.fill(1)
		return free
	var changed := true
	while changed:
		changed = false
		for cell in _boxes.size():
			if free[cell] == 1:
				continue
			for index: int in _touching[cell]:
				var other := _second[index] if _first[index] == cell else _first[index]
				if (other == OUTSIDE or free[other] == 1) and _reaches(cell, other, index, state):
					free[cell] = 1
					changed = true
					break
	return free


## Whether [param cell]'s air passes opening [param index] into [param other] at
## [param state]: the opening not shut, its top at or over the cell's water; through a
## flat one only rising — from over it, only into air standing under it, the sea or
## the other cell's water under its top; and on the other side the sea, the sky or a
## cell not full.
func _reaches(cell: int, other: int, index: int, state: FloodState) -> bool:
	if SinkStepper.open_share(_shut_time[index], state.seconds) <= 0.0:
		return false
	var top := _top[index]
	if state.heads[cell] > top:
		return false
	var upward := _upward[index]
	if upward != 0 and (upward == 1) != (cell == _first[index]):
		if (state.sea if other == OUTSIDE else state.heads[other]) > top:
			return false
	return other == OUTSIDE or state.water[other] < _capacity[other]
