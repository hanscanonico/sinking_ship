class_name TiltedBox
extends RefCounted
## One cell's water at any attitude (§5b.1): its box cut by a surface level with the
## world, so in a listing ship the water piles into the box's low corner. Seen along
## the world's up, the box's points are three even spreads added up, one per axis, as
## wide as the box reaches up on that axis; the share of the box under a surface is the
## share of that sum under it — exact, from the box's eight corners (a corner's
## simplex, added or taken away) — and so are the water's centre and the height that
## holds a given volume. A spread too narrow to divide by is taken as one at its
## middle: the share shifts by half its width, and the water's centre across it by the
## first term of how it leans that way. Heights are measured along the world's up from
## her origin, as the sea's is (Hydrostatics.Sea). Only +, −, ×, ÷ and square roots on
## 64-bit floats run here (D4, R21). Ship-local metres.

## All three spreads are counted while the middle one times the narrowest's square is
## at least NARROW_THREE of the widest's cube; else two while the middle one's square is
## at least NARROW_TWO of the widest's; else one — so each sum below keeps its digits.
const NARROW_THREE := 1e-9
const NARROW_TWO := 1e-8
## How near the solved height comes, as a share of the box's height along the up, and
## the most steps it takes.
const TOLERANCE := 1e-12
const SOLVE_STEPS := 60

## The box's least corner and its extent, x, y, z.
var _low := PackedFloat64Array([0.0, 0.0, 0.0])
var _size := PackedFloat64Array([0.0, 0.0, 0.0])
## The water it holds full, in m³, and the thin surface over its ceiling once it is
## full (§5b.1), in m² per metre of head.
var _capacity: float
var _full_area: float
## At the attitude it was last turned to: whether each axis runs up (1) or down (0)
## along the world's up; the height of its lowest and highest corner; the axes widest
## first and their widths a ≥ b ≥ c; how many of them count (3, 2 or 1); and how far
## the dropped ones shift the share.
var _rising := PackedByteArray([1, 1, 1])
var _widths := PackedFloat64Array([0.0, 0.0, 0.0])
var _bottom: float
var _top: float
var _order := PackedInt32Array([1, 0, 2])
var _a: float
var _b: float
var _c: float
var _counted := 1
var _shift: float


## The box from [param low] to [param high] holding [param capacity] m³ of water, with
## [param full_area] of surface over its ceiling once full; turned level.
func _init(low: Vector3, high: Vector3, capacity: float, full_area: float) -> void:
	for axis in 3:
		_low[axis] = low[axis]
		_size[axis] = float(high[axis]) - low[axis]
	_capacity = capacity
	_full_area = full_area
	turn(0.0, 1.0, 0.0)


## Turns the box to the attitude where the world's up is ([param up_x], [param up_y],
## [param up_z]) in the ship's axes, a unit vector.
func turn(up_x: float, up_y: float, up_z: float) -> void:
	var reach_x := up_x * _size[0]
	var reach_y := up_y * _size[1]
	var reach_z := up_z * _size[2]
	_rising[0] = 1 if reach_x >= 0.0 else 0
	_rising[1] = 1 if reach_y >= 0.0 else 0
	_rising[2] = 1 if reach_z >= 0.0 else 0
	_widths[0] = absf(reach_x)
	_widths[1] = absf(reach_y)
	_widths[2] = absf(reach_z)
	_bottom = (
		up_x * _low[0]
		+ up_y * _low[1]
		+ up_z * _low[2]
		+ minf(reach_x, 0.0)
		+ minf(reach_y, 0.0)
		+ minf(reach_z, 0.0)
	)
	var widths := _widths
	_top = _bottom + widths[0] + widths[1] + widths[2]
	# The axes widest first, in a fixed order where two are as wide.
	var a := 0
	var b := 1
	var c := 2
	if widths[b] > widths[a]:
		a = 1
		b = 0
	if widths[c] > widths[b]:
		var swap := b
		b = c
		c = swap
		if widths[b] > widths[a]:
			swap = a
			a = b
			b = swap
	_order[0] = a
	_order[1] = b
	_order[2] = c
	_a = widths[a]
	_b = widths[b]
	_c = widths[c]
	if _b * _c * _c >= NARROW_THREE * _a * _a * _a:
		_counted = 3
		_shift = 0.0
	elif _b * _b >= NARROW_TWO * _a * _a:
		_counted = 2
		_shift = _c * 0.5
	else:
		_counted = 1
		_shift = (_b + _c) * 0.5


## The height of its lowest and of its highest corner.
func bottom() -> float:
	return _bottom


func top() -> float:
	return _top


## The water it holds full, in m³, and the surface over its ceiling once full, in m²
## per metre of head.
func capacity() -> float:
	return _capacity


func full_area() -> float:
	return _full_area


## The water under a surface at [param height], in m³: over its ceiling, its capacity
## and the thin surface's.
func volume(height: float) -> float:
	if height <= _bottom:
		return 0.0
	if height >= _top:
		return _capacity + _full_area * (height - _top)
	return _capacity * _share(height - _bottom - _shift)


## The height its surface stands at holding [param water] m³.
func height(water: float) -> float:
	if water <= 0.0:
		return _bottom
	if water >= _capacity:
		return _top + (water - _capacity) / _full_area
	var share := water / _capacity
	if _counted == 1:
		return _bottom + _shift + share * _a
	if _counted == 2:
		# Two spreads: a square rise over the first b, straight up to a, a square
		# fill to a + b — each solved back with one root.
		var t := 0.0
		if share * 2.0 * _a <= _b:
			t = sqrt(2.0 * _a * _b * share)
		elif share <= 1.0 - _b / (2.0 * _a):
			t = share * _a + _b * 0.5
		else:
			t = _a + _b - sqrt(2.0 * _a * _b * (1.0 - share))
		return _bottom + _shift + t
	var spread := _b + _c
	if _a >= spread and share * 2.0 * _a >= spread and (1.0 - share) * 2.0 * _a >= spread:
		# Its surface across every edge up the widest: the share rises straight.
		return _bottom + share * _a + spread * 0.5
	# Three: Newton on the cubic pieces, kept within its bracket.
	var low := 0.0
	var high := _top - _bottom
	var close := TOLERANCE * high
	var at := share * high
	for _step in SOLVE_STEPS:
		var off := _share(at) - share
		if off < 0.0:
			low = at
		else:
			high = at
		var slope := _rate(at)
		var next := at - off / slope if slope > 0.0 else NAN
		next = next if next > low and next < high else (low + high) * 0.5
		var moved := next - at
		at = next
		if (moved < close and moved > -close) or high - low < close:
			break
	return _bottom + at


## Where the water under [param height] has its centre, x, y, z: along a spread that
## counts, where its share of the sum's mean lies; across one that does not, its middle
## less its width times the rate the share rises at over twelve times the share — how
## the water leans across it, to first order. A full box's is its middle.
func centre(height: float) -> PackedFloat64Array:
	var along := PackedFloat64Array([0.5, 0.5, 0.5])
	var t := height - _bottom - _shift
	if height > _bottom and height < _top and t > 0.0:
		if _counted == 3:
			_spreads(along, t)
		else:
			var share := _share(t)
			var rate := 0.0
			if _counted == 1:
				along[_order[0]] = minf(t, _a) / (2.0 * _a)
				rate = 1.0 / _a if t < _a else 0.0
			else:
				_spread(along, t)
				rate = _rise(t)
			for narrow in range(_counted, 3):
				var width := _b if narrow == 1 else _c
				along[_order[narrow]] = clampf(0.5 - width * rate / (12.0 * share), 0.0, 1.0)
	var found := PackedFloat64Array([0.0, 0.0, 0.0])
	for axis in 3:
		var share := along[axis] if _rising[axis] == 1 else 1.0 - along[axis]
		found[axis] = _low[axis] + _size[axis] * share
	return found


## The share of the box under [param t] over its lowest corner, less the shift.
func _share(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if _counted == 1:
		return minf(t / _a, 1.0)
	var a := _a
	var b := _b
	if _counted == 2:
		var square := t * t
		var past := t - a
		square -= past * past if past > 0.0 else 0.0
		past = t - b
		square -= past * past if past > 0.0 else 0.0
		past = t - a - b
		square += past * past if past > 0.0 else 0.0
		return square / (2.0 * a * b)
	var c := _c
	var cube := t * t * t
	var past := t - a
	cube -= past * past * past if past > 0.0 else 0.0
	past = t - b
	cube -= past * past * past if past > 0.0 else 0.0
	past = t - c
	cube -= past * past * past if past > 0.0 else 0.0
	past = t - a - b
	cube += past * past * past if past > 0.0 else 0.0
	past = t - a - c
	cube += past * past * past if past > 0.0 else 0.0
	past = t - b - c
	cube += past * past * past if past > 0.0 else 0.0
	past = t - a - b - c
	cube -= past * past * past if past > 0.0 else 0.0
	return cube / (6.0 * a * b * c)


## How fast the share rises with [param t], two spreads counted.
func _rise(t: float) -> float:
	var flat := t if t > 0.0 else 0.0
	var past := t - _a
	flat -= past if past > 0.0 else 0.0
	past = t - _b
	flat -= past if past > 0.0 else 0.0
	past = t - _a - _b
	flat += past if past > 0.0 else 0.0
	return flat / (_a * _b)


## How fast the share rises with [param t], three spreads counted.
func _rate(t: float) -> float:
	var a := _a
	var b := _b
	var c := _c
	var square := t * t if t > 0.0 else 0.0
	var past := t - a
	square -= past * past if past > 0.0 else 0.0
	past = t - b
	square -= past * past if past > 0.0 else 0.0
	past = t - c
	square -= past * past if past > 0.0 else 0.0
	past = t - a - b
	square += past * past if past > 0.0 else 0.0
	past = t - a - c
	square += past * past if past > 0.0 else 0.0
	past = t - b - c
	square += past * past if past > 0.0 else 0.0
	past = t - a - b - c
	square -= past * past if past > 0.0 else 0.0
	return square / (2.0 * a * b * c)


## Into [param along], where the water's centre lies along the two counted spreads under
## [param t]: each corner's triangle, added or taken away, by its area and its moment.
func _spread(along: PackedFloat64Array, t: float) -> void:
	var area := 0.0
	var moment_a := 0.0
	var moment_b := 0.0
	for corner in 4:
		var on_a := corner & 1
		var on_b := corner >> 1
		var past := t - on_a * _a - on_b * _b
		if past <= 0.0:
			continue
		var sign := 1.0 if (on_a + on_b) % 2 == 0 else -1.0
		var square := past * past * 0.5
		var tip := square * past / 3.0
		area += sign * square
		moment_a += sign * (on_a * _a * square + tip)
		moment_b += sign * (on_b * _b * square + tip)
	along[_order[0]] = moment_a / (area * _a)
	along[_order[1]] = moment_b / (area * _b)


## Into [param along], where the water's centre lies along the three spreads under
## [param t]: each corner's simplex, added or taken away, by its volume and moment.
func _spreads(along: PackedFloat64Array, t: float) -> void:
	var volume := 0.0
	var moment_a := 0.0
	var moment_b := 0.0
	var moment_c := 0.0
	for corner in 8:
		var on_a := corner & 1
		var on_b := (corner >> 1) & 1
		var on_c := corner >> 2
		var past := t - on_a * _a - on_b * _b - on_c * _c
		if past <= 0.0:
			continue
		var sign := 1.0 if (on_a + on_b + on_c) % 2 == 0 else -1.0
		var cube := past * past * past / 6.0
		var tip := cube * past * 0.25
		volume += sign * cube
		moment_a += sign * (on_a * _a * cube + tip)
		moment_b += sign * (on_b * _b * cube + tip)
		moment_c += sign * (on_c * _c * cube + tip)
	along[_order[0]] = moment_a / (volume * _a)
	along[_order[1]] = moment_b / (volume * _b)
	along[_order[2]] = moment_c / (volume * _c)
