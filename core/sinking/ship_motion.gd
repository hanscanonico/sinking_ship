class_name ShipMotion
extends RefCounted
## How the ship moves as a whole (§5b.1): her sinkage, trim and list together — heave,
## pitch and roll; she never yaws or drifts. Her lift is the sea's weight her sections
## push aside, cut by the sea at whatever attitude she has, acting at their centre;
## her weight is her own at her centre of mass, and her water's at the centre of each
## cell's water, level with the world — so water running to the low side of a wide cell
## takes its weight with it, the free-surface effect. One implicit step moves her: the
## push on her and how it changes as she moves — her stiffness: her lift's from her
## waterplane, her water's found by turning her a little each way — with her inertia,
## the water moving with her and her damping (ShipStructure), solved for where she is
## heading, so a long step settles her rather than overshooting, and a capsize carries
## on from where she was. Only +, −, ×, ÷ and square roots on 64-bit floats run here
## (D4, R21). Ship-local metres, seconds; forces as volumes of sea, moments as volumes
## times metres.

## How far she is turned to learn how her water's push changes, in radians.
const NUDGE := 1e-3
## Below this a length, an area or a stiffness is none.
const EPSILON := 1e-12

## What lift_under gives, by place.
enum Lift {
	VOLUME,
	X,
	Y,
	Z,
	HIGHEST,
	AREA,
	AHEAD,
	ABEAM,
	AHEAD_AHEAD,
	AHEAD_ABEAM,
	ABEAM_ABEAM,
}

var _g: float
## Per section: where along her and how long; and its outline's points, z then y, from
## its first point's place in the run of all of them, so many.
var _x := PackedFloat64Array()
var _length := PackedFloat64Array()
var _first := PackedInt32Array()
var _count := PackedInt32Array()
var _points := PackedFloat64Array()
## Per section: its whole outline's shoelace sums — twice its area, and its moments in
## z and y times six — and its outline's convex corners, z then y, from their first's
## place in the run of all of them, so many: whichever of its points stands highest or
## lowest along any up is one of these.
var _whole := PackedFloat64Array()
var _corner_first := PackedInt32Array()
var _corner_count := PackedInt32Array()
var _corners := PackedFloat64Array()
## Her centre of mass, x, y, z; her own weight as a volume of sea; her inertia for
## pitch and roll as that volume times the radius of gyration squared, and the share of
## it the water moving with her adds; her damping, heave, pitch, roll: its share of
## critical as she rests intact, times her stiffness there; how hard a hull going down is
## dragged, and the waterplane it is dragged by.
var _centre := PackedFloat64Array()
var _own: float
var _pitch_inertia: float
var _roll_inertia: float
var _added: float
var _damping := PackedFloat64Array()
var _resting := PackedFloat64Array()
var _drag: float
var _plan: float
## Where a section's outline crosses the sea's line, along the line then z and y, while
## it is cut: more than two only where the line crosses a deckhouse too.
var _crossings := PackedFloat64Array()


## The motion of [param structure] under [param sea], resting intact with the sea
## [param rest] up her, level.
func _init(structure: ShipStructure, sea: SeaPhysics, rest: float) -> void:
	_g = sea.gravity
	for section: HullSection in structure.sections:
		_x.append(section.x)
		_length.append(section.length)
		_first.append(_points.size())
		_count.append(section.outline.size())
		for point: Vector2 in section.outline:
			_points.append(point.x)
			_points.append(point.y)
		_shoelace(section.outline)
		_corner_first.append(_corners.size())
		var corners := _convex(section.outline)
		_corner_count.append(corners.size() / 2)
		_corners.append_array(corners)
	_centre = structure.mass_centre()
	_own = structure.total_mass() / sea.sea_density
	_added = structure.added_mass
	_pitch_inertia = _own * structure.pitch_radius * structure.pitch_radius
	_roll_inertia = _own * structure.roll_radius * structure.roll_radius
	_damping = PackedFloat64Array(
		[structure.heave_damping, structure.pitch_damping, structure.roll_damping]
	)
	_drag = sea.sink_drag
	var resting := lift_under(Attitude.level(), rest)
	_plan = resting[Lift.AREA]
	var stiffness := _stiffness(Attitude.level(), resting)
	for axis in 3:
		_resting.append(absf(stiffness[axis * 4]))


## Her centre of mass, x, y, z.
func centre() -> PackedFloat64Array:
	return _centre


## How far the highest point of her outline stands over the sea standing [param sea] up
## her under [param rotation], along the world's up: under it when negative.
func highest(rotation: PackedFloat64Array, sea: float) -> float:
	var ux := rotation[3]
	var uy := rotation[4]
	var uz := rotation[5]
	var most := -INF
	for section in _x.size():
		var along := ux * _x[section] - sea
		var from := _corner_first[section]
		for index in _corner_count[section]:
			var height := (
				along + uz * _corners[from + index * 2] + uy * _corners[from + index * 2 + 1]
			)
			if height > most:
				most = height
	return most


## The sea's height up her, along the world's up from her origin, with her rotation
## [param rotation] and her centre of mass [param rise] over the sea.
func sea_at(rotation: PackedFloat64Array, rise: float) -> float:
	return rotation[3] * _centre[0] + rotation[4] * _centre[1] + rotation[5] * _centre[2] - rise


## Moves [param next] — [param state]'s water already moved over [param seconds] —
## to where she is at the step's end: her rotation, the sea's height up her, her
## motion's rates and her roll stiffness. [param boxes] are her cells' water at any
## attitude, left turned to the new one.
func move(state: FloodState, next: FloodState, boxes: Array[TiltedBox], seconds: float) -> void:
	var rotation := state.rotation
	var rise := sea_at(rotation, 0.0) - state.sea
	var water := next.water
	var lift := lift_under(rotation, state.sea)
	var loaded := _loaded(rotation, water, boxes)
	var stiffness := _stiffness(rotation, lift)
	var held := _held(rotation, loaded)
	# Her water's part: how its push changes as she pitches and rolls a little and it
	# runs within its cells.
	for column in [1, 2]:
		var turned := (
			Attitude.pitched(rotation, NUDGE) if column == 1 else Attitude.rolled(rotation, NUDGE)
		)
		var moved := _held(turned, _loaded(turned, water, boxes))
		for row in 3:
			stiffness[row * 3 + column] -= _g * (moved[row] - held[row]) / NUDGE
	var push := _pushed(rotation, lift, held)
	var total := 0.0
	for volume: float in water:
		total += volume
	var inertia := PackedFloat64Array(
		[
			(_own + total) * (1.0 + _added),
			_pitch_inertia * (1.0 + _added),
			_roll_inertia * (1.0 + _added),
		]
	)
	var rates := PackedFloat64Array([state.heave_rate, state.pitch_rate, state.roll_rate])
	# (inertia + step × damping + step² × stiffness) × rates after = inertia × rates
	# before + step × push: the implicit step.
	var system := PackedFloat64Array()
	system.resize(9)
	var given := PackedFloat64Array()
	given.resize(3)
	for row in 3:
		for column in 3:
			system[row * 3 + column] = seconds * seconds * stiffness[row * 3 + column]
		var damping := 2.0 * _damping[row] * sqrt(_resting[row] * inertia[row])
		if row == 0:
			damping += 0.5 * _drag * _plan * absf(rates[0])
		system[row * 4] += inertia[row] + seconds * damping
		given[row] = inertia[row] * rates[row] + seconds * _g * push[row]
	var after := _solved(system, given)
	next.heave_rate = after[0]
	next.pitch_rate = after[1]
	next.roll_rate = after[2]
	next.roll_stiffness = stiffness[8]
	var turned := Attitude.pitched(rotation, after[1] * seconds)
	next.rotation = Attitude.squared(Attitude.rolled(turned, after[2] * seconds))
	next.sea = sea_at(next.rotation, rise + after[0] * seconds)
	var up := Attitude.up(next.rotation)
	for box: TiltedBox in boxes:
		box.turn(up[0], up[1], up[2])


## The rise, pitch and roll that would bring her to rest from [param rotation] with
## [param lift] (lift_under) and no water of her own, to first order: her push solved
## against her stiffness.
func rest_turn(rotation: PackedFloat64Array, lift: PackedFloat64Array) -> PackedFloat64Array:
	var push := _pushed(rotation, lift, PackedFloat64Array([0.0, 0.0, 0.0]))
	for row in 3:
		push[row] *= _g
	return _solved(_stiffness(rotation, lift), push)


## The longest step [param state] can take without her lost stability running away
## within it, in seconds, from her roll stiffness: INF while she is stable.
func steady_step(state: FloodState) -> float:
	if state.roll_stiffness >= 0.0:
		return INF
	return sqrt(0.5 * _roll_inertia * (1.0 + _added) / -state.roll_stiffness)


## Her water in [param boxes], each cell's [param water] level with the world under
## [param rotation] (each box turned to it here): its volume and its moments about her
## origin, x, y, z, as volume times metres.
func _loaded(
	rotation: PackedFloat64Array, water: PackedFloat64Array, boxes: Array[TiltedBox]
) -> PackedFloat64Array:
	var up := Attitude.up(rotation)
	var loaded := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	for cell in water.size():
		var volume := water[cell]
		if volume <= 0.0:
			continue
		var box := boxes[cell]
		# Full, it turns with her as a solid: its middle wherever she points.
		if volume < box.capacity():
			box.turn(up[0], up[1], up[2])
		var middle := box.centre(box.height(volume))
		loaded[0] += volume
		for axis in 3:
			loaded[axis + 1] += volume * middle[axis]
	return loaded


## The push of her water, [param loaded] (_loaded), under [param rotation]: its weight
## down, as a volume of sea, and its moments about her centre of mass the way she
## pitches — bow up — and rolls — starboard down.
func _held(rotation: PackedFloat64Array, loaded: PackedFloat64Array) -> PackedFloat64Array:
	var weight := loaded[0]
	var wx := loaded[1] - weight * _centre[0]
	var wy := loaded[2] - weight * _centre[1]
	var wz := loaded[3] - weight * _centre[2]
	var ahead := Attitude.ahead(rotation, wx, wy, wz)
	var abeam := Attitude.abeam(rotation, wx, wy, wz)
	return PackedFloat64Array([-weight, -ahead, rotation[0] * abeam - rotation[6] * ahead])


## The whole push on her under [param rotation]: [param lift] (lift_under) up and her
## own weight down, as a volume of sea, and the lift's moments about her centre of mass
## the way she pitches and rolls; [param held], her water's (_held), added.
func _pushed(
	rotation: PackedFloat64Array, lift: PackedFloat64Array, held: PackedFloat64Array
) -> PackedFloat64Array:
	var volume := lift[Lift.VOLUME]
	var bx := lift[Lift.X] - _centre[0]
	var by := lift[Lift.Y] - _centre[1]
	var bz := lift[Lift.Z] - _centre[2]
	# A force up at a point ahead of her centre lifts her bow; abeam to starboard, it
	# lifts her starboard side.
	var pitching := volume * Attitude.ahead(rotation, bx, by, bz)
	var heeling := -volume * Attitude.abeam(rotation, bx, by, bz)
	return PackedFloat64Array(
		[
			volume - _own + held[0],
			pitching + held[1],
			rotation[0] * heeling + rotation[6] * pitching + held[2],
		]
	)


## How her lift's push changes as she rises, pitches and rolls, three by three, times
## g, negated — her hull's stiffness — under [param rotation] with [param lift]
## (lift_under): from the volume she pushes aside, its centre and her waterplane's area
## and its first and second moments about her centre of mass. As she turns, her
## waterplane gains or loses a wedge and the volume under it swings about her centre.
func _stiffness(rotation: PackedFloat64Array, lift: PackedFloat64Array) -> PackedFloat64Array:
	var volume := lift[Lift.VOLUME]
	var bx := lift[Lift.X] - _centre[0]
	var by := lift[Lift.Y] - _centre[1]
	var bz := lift[Lift.Z] - _centre[2]
	var ahead := Attitude.ahead(rotation, bx, by, bz)
	var abeam := Attitude.abeam(rotation, bx, by, bz)
	var high := rotation[3] * bx + rotation[4] * by + rotation[5] * bz
	var area := lift[Lift.AREA]
	var s_ahead := lift[Lift.AHEAD]
	var s_abeam := lift[Lift.ABEAM]
	var i_ahead := lift[Lift.AHEAD_AHEAD]
	var i_both := lift[Lift.AHEAD_ABEAM]
	var i_abeam := lift[Lift.ABEAM_ABEAM]
	# Her length in the world: forward (a_x) and up (a_y); she never yaws.
	var a_x := rotation[0]
	var a_y := rotation[3]
	var changes := PackedFloat64Array(
		[
			-area,
			-s_ahead,
			a_x * s_abeam,
			-s_ahead,
			-volume * high - i_ahead,
			a_y * volume * abeam + a_x * i_both,
			a_x * s_abeam,
			a_x * i_both + a_y * volume * abeam,
			-a_x * (a_x * volume * high - a_y * volume * ahead + a_x * i_abeam),
		]
	)
	for index in 9:
		changes[index] *= -_g
	return changes


## Her sections under the sea standing [param sea] up her, under [param rotation]
## (Lift's places): the volume they push aside and its centre, x, y, z; how far the
## highest point of her outline stands over the sea — under it when negative; and her
## waterplane — each section's chord along the sea swept along her as a strip — its
## area and, about her centre of mass along the world's forward and athwartships axes,
## its first moments and its second. Each section's own share of the volume goes into
## [param by_section] when it has a place for each (HullGirder).
func lift_under(
	rotation: PackedFloat64Array, sea: float, by_section := PackedFloat64Array()
) -> PackedFloat64Array:
	var shares := by_section.size() == _x.size()
	var ux := rotation[3]
	var uy := rotation[4]
	var uz := rotation[5]
	var across := uy * uy + uz * uz
	var volume := 0.0
	var mx := 0.0
	var my := 0.0
	var mz := 0.0
	var highest := -INF
	var plane := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for section in _x.size():
		var x := _x[section]
		var level := sea - ux * x
		# Wholly over the sea's line, or wholly under it: nothing to cut.
		var low := INF
		var high := -INF
		var corner := _corner_first[section]
		for index in _corner_count[section]:
			var off := uz * _corners[corner + index * 2] + uy * _corners[corner + index * 2 + 1]
			low = minf(low, off)
			high = maxf(high, off)
		highest = maxf(highest, high - level)
		if shares:
			by_section[section] = 0.0
		if low > level:
			continue
		if high <= level:
			var whole := _whole[section * 3]
			var piece := whole * 0.5 * _length[section]
			if shares:
				by_section[section] = piece
			volume += piece
			mx += piece * x
			mz += piece * _whole[section * 3 + 1] / (3.0 * whole)
			my += piece * _whole[section * 3 + 2] / (3.0 * whole)
			continue
		var from := _first[section]
		var count := _count[section]
		# The outline's part under the sea's line, walked round once: its area and its
		# moments, by the shoelace over the points kept and where the line cuts it.
		var twice := 0.0
		var sum_z := 0.0
		var sum_y := 0.0
		var first_z := 0.0
		var first_y := 0.0
		var last_z := 0.0
		var last_y := 0.0
		var started := false
		_crossings.clear()
		var z0 := _points[from + (count - 1) * 2]
		var y0 := _points[from + (count - 1) * 2 + 1]
		var f0 := uz * z0 + uy * y0 - level
		for index in count:
			var z1 := _points[from + index * 2]
			var y1 := _points[from + index * 2 + 1]
			var f1 := uz * z1 + uy * y1 - level
			if (f0 <= 0.0) != (f1 <= 0.0):
				var t := f0 / (f0 - f1)
				var cz := z0 + (z1 - z0) * t
				var cy := y0 + (y1 - y0) * t
				_crossings.append(uy * cz - uz * cy)
				_crossings.append(cz)
				_crossings.append(cy)
				if started:
					var cross := last_z * cy - cz * last_y
					twice += cross
					sum_z += (last_z + cz) * cross
					sum_y += (last_y + cy) * cross
				else:
					first_z = cz
					first_y = cy
					started = true
				last_z = cz
				last_y = cy
			if f1 <= 0.0:
				if started:
					var cross := last_z * y1 - z1 * last_y
					twice += cross
					sum_z += (last_z + z1) * cross
					sum_y += (last_y + y1) * cross
				else:
					first_z = z1
					first_y = y1
					started = true
				last_z = z1
				last_y = y1
			z0 = z1
			y0 = y1
			f0 = f1
		if not started:
			continue
		var closing := last_z * first_y - first_z * last_y
		twice += closing
		sum_z += (last_z + first_z) * closing
		sum_y += (last_y + first_y) * closing
		if twice > EPSILON:
			var part := twice * 0.5 * _length[section]
			if shares:
				by_section[section] = part
			volume += part
			mx += part * x
			mz += part * sum_z / (3.0 * twice)
			my += part * sum_y / (3.0 * twice)
		if _crossings.size() >= 6 and across > EPSILON:
			_strips(rotation, section, across, plane)
	var made := PackedFloat64Array()
	made.resize(Lift.size())
	made[Lift.HIGHEST] = highest
	for index in 6:
		made[Lift.AREA + index] = plane[index]
	if volume > EPSILON:
		made[Lift.VOLUME] = volume
		made[Lift.X] = mx / volume
		made[Lift.Y] = my / volume
		made[Lift.Z] = mz / volume
	return made


## Into [param plane], section [param section]'s strips of waterplane under
## [param rotation] — its chords along the sea, paired off where the sea's line crosses
## its outline (_crossings), each swept along her by the section's length — their area,
## and their first and second moments along the world's forward and athwartships axes
## about her centre of mass. [param across] is the world's up's square reach in the
## section's plane.
func _strips(
	rotation: PackedFloat64Array, section: int, across: float, plane: PackedFloat64Array
) -> void:
	var pairs := _crossings.size() / 3
	if pairs > 2:
		_sort_crossings()
	var x := _x[section] - _centre[0]
	var length := _length[section]
	# Along her by the section's length, staying on the sea: its world forward and
	# athwartships reach.
	var sweep := -rotation[3] * length / across
	var sweep_y := sweep * rotation[4]
	var sweep_z := sweep * rotation[5]
	var s_ahead := Attitude.ahead(rotation, length, sweep_y, sweep_z)
	var s_abeam := Attitude.abeam(rotation, length, sweep_y, sweep_z)
	for pair in pairs / 2:
		var y1 := _crossings[pair * 6 + 2] - _centre[1]
		var z1 := _crossings[pair * 6 + 1] - _centre[2]
		var y2 := _crossings[pair * 6 + 5] - _centre[1]
		var z2 := _crossings[pair * 6 + 4] - _centre[2]
		var c_ahead := Attitude.ahead(rotation, 0.0, y2 - y1, z2 - z1)
		var c_abeam := Attitude.abeam(rotation, 0.0, y2 - y1, z2 - z1)
		var area := absf(c_ahead * s_abeam - c_abeam * s_ahead)
		var m_ahead := Attitude.ahead(rotation, x, (y1 + y2) * 0.5, (z1 + z2) * 0.5)
		var m_abeam := Attitude.abeam(rotation, x, (y1 + y2) * 0.5, (z1 + z2) * 0.5)
		plane[0] += area
		plane[1] += area * m_ahead
		plane[2] += area * m_abeam
		plane[3] += area * (m_ahead * m_ahead + (c_ahead * c_ahead + s_ahead * s_ahead) / 12.0)
		plane[4] += area * (m_ahead * m_abeam + (c_ahead * c_abeam + s_ahead * s_abeam) / 12.0)
		plane[5] += area * (m_abeam * m_abeam + (c_abeam * c_abeam + s_abeam * s_abeam) / 12.0)


## Sorts _crossings along the sea's line, so that each chord pairs off in turn: an
## insertion sort, the crossings few.
func _sort_crossings() -> void:
	var count := _crossings.size() / 3
	for index in range(1, count):
		var at := index
		while at > 0 and _crossings[(at - 1) * 3] > _crossings[at * 3]:
			for field in 3:
				var swap := _crossings[at * 3 + field]
				_crossings[at * 3 + field] = _crossings[(at - 1) * 3 + field]
				_crossings[(at - 1) * 3 + field] = swap
			at -= 1


## Keeps [param outline]'s shoelace sums in _whole: twice its area, and its moments in
## z and y times six.
func _shoelace(outline: PackedVector2Array) -> void:
	var twice := 0.0
	var sum_z := 0.0
	var sum_y := 0.0
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var cross := float(a.x) * b.y - float(b.x) * a.y
		twice += cross
		sum_z += (float(a.x) + b.x) * cross
		sum_y += (float(a.y) + b.y) * cross
	_whole.append_array(PackedFloat64Array([twice, sum_z, sum_y]))


## The corners of [param outline]'s convex hull, z then y: a monotone chain, by cross
## products alone.
static func _convex(outline: PackedVector2Array) -> PackedFloat64Array:
	var points: Array[Vector2] = []
	points.assign(outline)
	points.sort_custom(
		func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or a.x == b.x and a.y < b.y
	)
	var chain: Array[Vector2] = []
	for round_trip in 2:
		var start := chain.size()
		for point: Vector2 in points:
			while chain.size() >= start + 2:
				var o := chain[chain.size() - 2]
				var a := chain[chain.size() - 1]
				var turn := (
					(float(a.x) - o.x) * (float(point.y) - o.y)
					- (float(a.y) - o.y) * (float(point.x) - o.x)
				)
				if turn > 0.0:
					break
				chain.pop_back()
			chain.append(point)
		chain.pop_back()
		points.reverse()
	var corners := PackedFloat64Array()
	for point: Vector2 in chain:
		corners.append(point.x)
		corners.append(point.y)
	return corners


## [param system] (three by three, row by row) solved for [param given]: Gaussian
## elimination in a fixed order.
static func _solved(system: PackedFloat64Array, given: PackedFloat64Array) -> PackedFloat64Array:
	var a := system.duplicate()
	var b := given.duplicate()
	for pivot in 3:
		var at := a[pivot * 4]
		if absf(at) <= EPSILON:
			continue
		for row in range(pivot + 1, 3):
			var factor := a[row * 3 + pivot] / at
			for column in range(pivot, 3):
				a[row * 3 + column] -= factor * a[pivot * 3 + column]
			b[row] -= factor * b[pivot]
	var found := PackedFloat64Array([0.0, 0.0, 0.0])
	for row in range(2, -1, -1):
		var sum := b[row]
		for column in range(row + 1, 3):
			sum -= a[row * 3 + column] * found[column]
		var at := a[row * 4]
		found[row] = sum / at if absf(at) > EPSILON else 0.0
	return found
