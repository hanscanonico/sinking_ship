class_name WaterFronts
extends RefCounted
## Where a cell's first water has run to (#642, D7): water let onto a dry floor runs out
## from where it comes in as a thin gravity current, its front at u = Fr·√(g·h), h the
## current's depth just behind it — with q = u·h the flux per metre of front,
## u = Fr^(2/3)·(g·q)^(1/3) (Huppert & Simpson 1980; Simpson, Gravity Currents, 1997). From
## a door or a gash in a wall the flow Q spreads over a half-disc, q = Q / w with
## w = max(b, π·r), b the opening's width and r the front's reach from it; from a hole in
## a floor — water rising through it, or a pour landing under it — over a full disc,
## w = max(its perimeter, 2π·r). Either way w is at most the widest the cell's floor runs
## across that way — twice its narrower side for a disc — so a corridor's front runs on
## as a 2D current at q = Q / width. Hence dr/dt = Fr^(2/3)·(g·Q(t)/w(r))^(1/3).
##
## Each opening that brings water into a cell (Currents.joined: its passages and their
## sides) starts a front there at the first kept stretch of the timeline its inflow into
## that cell runs over — the cell downstream, its water lower than the other side's, the
## sea's always upstream — integrated over the timeline's stretches from that opening's
## flow (SinkTimeline.flow) until it covers the cell's floor. A cell holding water at
## the hit, and one no front reaches, has none: wet everywhere at once, as before. Its
## fronts read beyond every one of them as no water on its floor (ShipPose.reached), until
## one covers the floor; then the cell is wet as before.
##
## A pure function of the timeline, made once a schedule, lazily (SinkSchedule): never in
## a snapshot, nothing on a clock (D4, D5, D11). Its points are ship space, x/z.

## How far a front moves between two samples of its reach at most, in metres: its reach
## between samples is read linearly.
const STEP := 0.25
## The least time a sample spans, in physics seconds.
const SHORTEST := 1.0 / 120.0

## Per cell: its first front and how many it has, when the first starts and when one
## covers its floor — INF for never — in physics seconds after the hit.
var _first := PackedInt32Array()
var _count := PackedInt32Array()
var _starts := PackedFloat64Array()
var _dones := PackedFloat64Array()
## The cells with fronts, ascending.
var _spreading := PackedInt32Array()
## Per front: the x/z rectangle it runs out from (low x, low z, high x, high z), and its
## samples' span in _times and _reaches: from _from[front] to _from[front + 1].
var _rects := PackedVector4Array()
var _from := PackedInt32Array([0])
var _times := PackedFloat64Array()
var _reaches := PackedFloat64Array()
## Per front, its cell.
var _cells := PackedInt32Array()


## The fronts of [param timeline]'s cells of [param structure] — numbered in the timeline
## as [param at] has them — through its openings and [param more] (Currents.joined),
## those holding water at the hit, [param wet] (1 per cell), left without; spreading at
## [param froude] under [param gravity] (SeaPhysics).
func _init(
	timeline: SinkTimeline,
	structure: ShipStructure,
	more: Array[ShipOpening],
	at: PackedInt32Array,
	wet: PackedByteArray,
	froude: float,
	gravity: float
) -> void:
	var cell_count := structure.cells.size()
	_first.resize(cell_count)
	_count.resize(cell_count)
	_starts.resize(cell_count)
	_dones.resize(cell_count)
	_starts.fill(INF)
	_dones.fill(INF)
	var stride := timeline.passages.size()
	if stride == 0 or timeline.count() < 2:
		return
	var pull := pow(froude, 2.0 / 3.0) * pow(gravity, 1.0 / 3.0)
	var joined := Currents.new(null, structure, more).joined(timeline.passages)
	# Per cell, the fronts found for it: [rect, samples] each, in passage order.
	var found: Array[Array] = []
	found.resize(cell_count)
	for each: Array in joined:
		var opening: ShipOpening = each[0]
		var passage: int = each[1]
		for side in 2:
			var cell: int = each[2 + side]
			var other: int = each[3 - side]
			if cell == -1 or wet[cell] == 1:
				continue
			var spread := _spread(timeline, opening, passage, stride, cell, other, at, structure)
			if not spread.is_empty():
				spread.append(pull)
				var made := _run(timeline, spread)
				if made[0].size() > 0:
					found[cell].append([spread[0], made])
	for cell in cell_count:
		_first[cell] = _rects.size()
		for front: Array in found[cell]:
			var made: Array = front[1]
			var times: PackedFloat64Array = made[0]
			_rects.append(front[0])
			_times.append_array(times)
			_reaches.append_array(made[1])
			_from.append(_times.size())
			_cells.append(cell)
			_starts[cell] = minf(_starts[cell], times[0])
			_dones[cell] = minf(_dones[cell], made[2])
		_count[cell] = _rects.size() - _first[cell]
		if _count[cell] > 0:
			_spreading.append(cell)


## The fronts of every cell — none — for a schedule with no physical sinking.
static func none() -> WaterFronts:
	return null


## What a front of [param opening], passage [param passage] of [param stride], into
## [param cell] from [param other] (-1 the sea) needs to run: [rect, half-disc or disc
## (π or 2π), its least width, its widest, its farthest corner, per stretch the m³ a second
## it brings in] — empty where it brings none in.
func _spread(
	timeline: SinkTimeline,
	opening: ShipOpening,
	passage: int,
	stride: int,
	cell: int,
	other: int,
	at: PackedInt32Array,
	structure: ShipStructure
) -> Array:
	var inflow := PackedFloat64Array()
	inflow.resize(timeline.count() - 1)
	var any := false
	var count := timeline.cells
	for stretch in inflow.size():
		var flow := timeline.flows[(stretch + 1) * stride + passage]
		if flow <= 0.0:
			continue
		if other != -1:
			var here := at[cell]
			var there := at[other]
			var mine := (
				timeline.heads[stretch * count + here]
				+ timeline.heads[(stretch + 1) * count + here]
			)
			var theirs := (
				timeline.heads[stretch * count + there]
				+ timeline.heads[(stretch + 1) * count + there]
			)
			if mine >= theirs:
				continue
		inflow[stretch] = flow
		any = true
	if not any:
		return []
	var box := structure.cells[cell]
	var half := opening.size * 0.5
	var rect := Vector4(
		maxf(opening.centre.x - half.x, box.low.x),
		maxf(opening.centre.z - half.z, box.low.z),
		minf(opening.centre.x + half.x, box.high.x),
		minf(opening.centre.z + half.z, box.high.z)
	)
	rect = Vector4(rect.x, rect.y, maxf(rect.z, rect.x), maxf(rect.w, rect.y))
	var axis := opening.facing()
	var round_it := TAU
	var least := 2.0 * ((rect.z - rect.x) + (rect.w - rect.y))
	var widest := 2.0 * minf(box.high.x - box.low.x, box.high.z - box.low.z)
	if axis != 1:
		round_it = PI
		var along := 2 if axis == 0 else 0
		least = opening.size[along]
		widest = box.high[along] - box.low[along]
	least = maxf(least, 0.01)
	widest = maxf(widest, least)
	var farthest := 0.0
	for corner: Vector2 in [
		Vector2(box.low.x, box.low.z),
		Vector2(box.high.x, box.low.z),
		Vector2(box.low.x, box.high.z),
		Vector2(box.high.x, box.high.z),
	]:
		farthest = maxf(farthest, apart(rect, corner.x, corner.y))
	return [rect, round_it, least, widest, farthest, inflow]


## A front's samples from [param spread] (_spread, with its pull Fr^(2/3)·g^(1/3) last):
## [times, reaches, when it covers the floor — INF for never], empty times for none.
static func _run(timeline: SinkTimeline, spread: Array) -> Array:
	var round_it: float = spread[1]
	var least: float = spread[2]
	var widest: float = spread[3]
	var farthest: float = spread[4]
	var inflow: PackedFloat64Array = spread[5]
	var pull: float = spread[6]
	var times := PackedFloat64Array()
	var reaches := PackedFloat64Array()
	var reach := 0.0
	var done := INF
	for stretch in inflow.size():
		var from := timeline.times[stretch]
		var to := timeline.times[stretch + 1]
		var flow := inflow[stretch]
		if times.is_empty():
			if flow <= 0.0:
				continue
		elif times[times.size() - 1] < from:
			times.append(from)
			reaches.append(reach)
		if times.is_empty():
			times.append(from)
			reaches.append(0.0)
		if flow <= 0.0 or to <= from:
			continue
		var now := from
		while now < to:
			var speed := _speed(reach, flow, round_it, least, widest, pull)
			var span := minf(to - now, maxf(STEP / speed, SHORTEST))
			var half := _speed(reach + speed * span * 0.5, flow, round_it, least, widest, pull)
			var next := reach + half * span
			if next >= farthest:
				done = now + (farthest - reach) / half
				times.append(done)
				reaches.append(farthest)
				return [times, reaches, done]
			reach = next
			now += span
			times.append(now)
			reaches.append(reach)
	return [times, reaches, done]


## How fast a front [param reach] out goes with [param flow] behind it (_spread's).
static func _speed(
	reach: float, flow: float, round_it: float, least: float, widest: float, pull: float
) -> float:
	var wide := clampf(round_it * reach, least, widest)
	return pull * pow(flow / wide, 1.0 / 3.0)


## How far x/z ([param x], [param z]) lies from rectangle [param rect] (low x, low z,
## high x, high z).
static func apart(rect: Vector4, x: float, z: float) -> float:
	var dx := maxf(maxf(rect.x - x, x - rect.z), 0.0)
	var dz := maxf(maxf(rect.y - z, z - rect.w), 0.0)
	return sqrt(dx * dx + dz * dz)


## Whether any cell has a front.
func is_empty() -> bool:
	return _spreading.is_empty()


## Sets on [param pose] where the fronts stand [param seconds] after the hit
## (ShipPose.spreading, ShipPose.reaches): nothing where no cell is spreading then.
func pose(pose: ShipPose, seconds: float) -> void:
	for cell: int in _spreading:
		if seconds < _starts[cell] or seconds >= _dones[cell]:
			continue
		if pose.spreading.is_empty():
			pose.spreading.resize(_first.size())
			pose.reaches.resize(_rects.size())
			pose.fronts = self
		pose.spreading[cell] = 1
		pose.spread_cells.append(cell)
		for front in range(_first[cell], _first[cell] + _count[cell]):
			pose.reaches[front] = reach_of(front, seconds)


## How far front [param front] has run [param seconds] after the hit: -1 before it starts.
func reach_of(front: int, seconds: float) -> float:
	var low := _from[front]
	var high := _from[front + 1] - 1
	if seconds < _times[low]:
		return -1.0
	if seconds >= _times[high]:
		return _reaches[high]
	while high - low > 1:
		var middle := (low + high) >> 1
		if _times[middle] <= seconds:
			low = middle
		else:
			high = middle
	var span := _times[high] - _times[low]
	var weight := (seconds - _times[low]) / span if span > 0.0 else 1.0
	return lerpf(_reaches[low], _reaches[high], weight)


## Whether ship x/z ([param x], [param z]) of [param cell] is inside one of its fronts,
## standing at [param reaches] (ShipPose.reaches).
func within(cell: int, x: float, z: float, reaches: PackedFloat64Array) -> bool:
	return margin(cell, x, z, reaches) >= 0.0


## How far inside its nearest front ship x/z ([param x], [param z]) of [param cell] lies,
## standing at [param reaches]: below 0 beyond every one — what InnerWater's mask reads.
func margin(cell: int, x: float, z: float, reaches: PackedFloat64Array) -> float:
	var best := -INF
	for front in range(_first[cell], _first[cell] + _count[cell]):
		var reach := reaches[front]
		if reach >= 0.0:
			best = maxf(best, reach - apart(_rects[front], x, z))
	return best


## Cell [param cell]'s fronts: their first number and how many.
func of_cell(cell: int) -> Vector2i:
	return Vector2i(_first[cell], _count[cell])


## Front [param front]'s rectangle (low x, low z, high x, high z).
func rect_of(front: int) -> Vector4:
	return _rects[front]


## When cell [param cell]'s first front starts and when one covers its floor, in physics
## seconds after the hit; INF for never.
func span_of(cell: int) -> Vector2:
	return Vector2(_starts[cell], _dones[cell])
