class_name CellSlosh
extends RefCounted
## Her cells' water swinging as she turns (#621, InnerWater): per cell, the first sloshing
## mode of the water in its box along her (her trim) and across her (her heel), driven by
## her angles as drawn — φ'' + 2ζω φ' + ω² φ = θ'' + 2ζω θ', φ the surface's tilt from the
## world's level and θ hers — so a slow turn leaves it level, and a sudden one carries it
## with her and it swings back past level and settles. Its surface is tilted by it about
## the water's middle, never more than InnerWater.SLOSH_MOST at a box's end, and never so
## far it lays a dry floor bare or reaches the ceiling. Presentation only (D5): it reads
## the ship as drawn and the levels the poses give, frame by frame, and moves no water.

## The most steps one frame's swing is worked out in.
const STEPS_MOST := 16
## The furthest a swing is drawn from level, in radians: far past what SLOSH_MOST allows.
const STEEPEST := 1.0
## How long her way laid level must stay of a unit to slosh along: she stands too near on
## end, or on her side, for water to swing along that way otherwise.
const FLAT_LEAST := 0.3

## Whether this frame sloshes at all: a frame drawn at no moment (begin) leaves her water
## level with the world, as before.
var on := false
## Per cell, its box's length along her and across her, its middle, and its middle at its
## floor; and the corners of every box it is drawn in, three a corner: its offset from the
## middle across her (y 0), and the corner at the box's floor and at its top.
var _lengths := PackedVector2Array()
var _middles := PackedVector3Array()
var _floors := PackedVector3Array()
var _ends: Array[PackedVector3Array] = []
## Per cell, its water's swing against her — along her and how fast, across her and how
## fast, in radians — the frame it was last worked out in, and the world slope it drew.
var _swings := PackedVector4Array()
var _stamps := PackedInt32Array()
var _slopes := PackedVector3Array()
## Per cell, 1 while its water sleeps: level within InnerWater.SLOSH_REST, on a hull
## turning slower than InnerWater.SLOSH_CALM.
var _asleep := PackedByteArray()
## This frame: its count, its moment in seconds, the seconds since the last, her angles
## (trim, heel) now and at the last and how fast they turn, the ship as drawn, the world's
## up in her and her two ways laid level in her space.
var _frame := 0
var _seconds := NAN
var _step := 0.0
var _angles := Vector2.ZERO
var _angles_was := Vector2.ZERO
var _turning := Vector2.ZERO
var _ship := Transform3D.IDENTITY
var _up := Vector3.UP
var _along := Vector3.ZERO
var _across := Vector3.ZERO


## Sloshes [param structure]'s cells, each drawn in its box of [param boxes] — none for a
## zero box — and in [param stacks] (InnerWater._stacks).
func _init(structure: ShipStructure, boxes: Array[AABB], stacks: Array) -> void:
	for cell: FloodCell in structure.cells:
		var size := cell.high - cell.low
		var middle := cell.low.lerp(cell.high, 0.5)
		_lengths.append(Vector2(size.x, size.z))
		_middles.append(middle)
		_floors.append(Vector3(middle.x, cell.low.y, middle.z))
		_ends.append(PackedVector3Array())
	for cell in boxes.size():
		if boxes[cell].size != Vector3.ZERO:
			_add_ends(cell, boxes[cell])
	for stack: Array in stacks:
		_add_ends(stack[0], stack[1])
	_swings.resize(_middles.size())
	_stamps.resize(_middles.size())
	_stamps.fill(-2)
	_slopes.resize(_middles.size())
	_asleep.resize(_middles.size())


func _add_ends(cell: int, box: AABB) -> void:
	for corner in 4:
		var at := box.position
		at.x = box.position.x if corner & 1 == 0 else box.end.x
		at.z = box.position.z if corner & 2 == 0 else box.end.z
		var off := at - _middles[cell]
		off.y = 0.0
		_ends[cell].append_array([off, at, Vector3(at.x, box.end.y, at.z)])


## Starts a frame of her drawn at [param drawn], [param up] the world's up in her, at
## [param seconds] into the match — NAN for none, and nothing sloshes. A frame before the
## last, or more than InnerWater.SLOSH_GAP after it — a replay's seek, a capture's
## start — restarts every cell's water from level.
func begin(drawn: Transform3D, up: Vector3, seconds: float) -> void:
	on = not is_nan(seconds)
	if not on:
		_seconds = NAN
		return
	var angles := Vector2(
		asin(clampf(drawn.basis.x.y, -1.0, 1.0)), asin(clampf(drawn.basis.z.y, -1.0, 1.0))
	)
	var step := seconds - _seconds
	if step >= 0.0 and step <= InnerWater.SLOSH_GAP:
		_frame += 1
		_step = step
		if step > 0.0:
			_turning = (angles - _angles) / step
	else:
		_frame += 2
		_step = 0.0
		_turning = Vector2.ZERO
	_angles_was = _angles
	_angles = angles
	_seconds = seconds
	_ship = drawn
	_up = up
	_along = _flat(Vector3.RIGHT)
	_across = _flat(Vector3.BACK)


## [param placed], a sheet of [param cell]'s water at world height [param level]
## (CellSurface.placed), tilted by its slosh this frame about the water's middle.
func tilted(placed: Transform3D, cell: int, level: float) -> Transform3D:
	var slope := _slope_of(cell, level)
	if slope == Vector3.ZERO:
		return placed
	var basis := placed.basis
	basis.x += _up * slope.dot(basis.x)
	basis.z += _up * slope.dot(basis.z)
	return Transform3D(basis, placed.origin + _up * slope.dot(placed.origin - _middles[cell]))


## The first sloshing mode's angular frequency, in radians a second, of water [param depth]
## deep in a box [param length] long: ω² = (π g / L) · tanh(π h / L).
static func omega_of(length: float, depth: float) -> float:
	if length <= 0.0 or depth <= 0.0:
		return 0.0
	var wave := PI / length
	return sqrt(InnerWater.GRAVITY * wave * tanh(wave * depth))


## [param swing] — its angle against her and how fast it turns — [param step] seconds on,
## her angle going from [param was] to [param angle] meanwhile, at [param omega]: semi-
## implicitly, in steps of at most InnerWater.SLOSH_STEP of a swing's radian.
static func swung(swing: Vector2, was: float, angle: float, step: float, omega: float) -> Vector2:
	if step <= 0.0 or omega <= 0.0:
		return swing
	var steps := clampi(ceili(step * omega / InnerWater.SLOSH_STEP), 1, STEPS_MOST)
	var each := step / steps
	var damping := 2.0 * InnerWater.SLOSH_DAMPING * omega
	var spring := omega * omega
	var against := swing.x
	var turning := swing.y
	for at in steps:
		var hull := lerpf(was, angle, float(at + 1) / steps)
		turning += each * (-spring * (against + hull) - damping * turning)
		against += each * turning
	return Vector2(against, turning)


## [param direction] in her laid level with the world, a unit long; none where she stands
## too near on end, or on her side, for it to lie along the water.
func _flat(direction: Vector3) -> Vector3:
	var flat := direction - _up * direction.dot(_up)
	return flat.normalized() if flat.length() >= FLAT_LEAST else Vector3.ZERO


## [param cell]'s water's world slope this frame, its level at [param level]: worked out
## once a frame, from level where it was not worked out the frame before. Water asleep on
## a calm hull stays asleep, level, with nothing worked out.
func _slope_of(cell: int, level: float) -> Vector3:
	if _stamps[cell] == _frame:
		return _slopes[cell]
	var calm := (
		absf(_turning.x) < InnerWater.SLOSH_CALM and absf(_turning.y) < InnerWater.SLOSH_CALM
	)
	if calm and _asleep[cell] == 1 and _stamps[cell] == _frame - 1:
		_swings[cell] = Vector4(-_angles.x, -_turning.x, -_angles.y, -_turning.y)
		_stamps[cell] = _frame
		_slopes[cell] = Vector3.ZERO
		return Vector3.ZERO
	var row := Vector3(_ship.basis.x.y, _ship.basis.y.y, _ship.basis.z.y)
	var rise := _ship.origin.y
	var depth := maxf(level - row.dot(_floors[cell]) - rise, InnerWater.SLOSH_SHALLOWEST)
	var swing := _swings[cell]
	if _stamps[cell] != _frame - 1:
		swing = Vector4(-_angles.x, -_turning.x, -_angles.y, -_turning.y)
	else:
		var lengths := _lengths[cell]
		var along := swung(
			Vector2(swing.x, swing.y), _angles_was.x, _angles.x, _step, omega_of(lengths.x, depth)
		)
		var across := swung(
			Vector2(swing.z, swing.w), _angles_was.y, _angles.y, _step, omega_of(lengths.y, depth)
		)
		swing = Vector4(along.x, along.y, across.x, across.y)
	_swings[cell] = swing
	_stamps[cell] = _frame
	var tilt := Vector2(swing.x + _angles.x, swing.z + _angles.y)
	var resting := absf(tilt.x) < InnerWater.SLOSH_REST and absf(tilt.y) < InnerWater.SLOSH_REST
	_asleep[cell] = 1 if calm and resting else 0
	var slope := Vector3.ZERO
	if tilt != Vector2.ZERO and _asleep[cell] == 0:
		slope = (
			tan(clampf(tilt.x, -STEEPEST, STEEPEST)) * _along
			+ tan(clampf(tilt.y, -STEEPEST, STEEPEST)) * _across
		)
		slope *= _room(cell, level, slope, row, rise)
	_slopes[cell] = slope
	return slope


## How much of [param slope] [param cell]'s water at world height [param level] may take,
## 0…1, on her drawn with heights [param row] · point + [param rise]: at every corner of
## every box it is drawn in, never more than SLOSH_MOST off its level, never under the
## floor there by CLEAR_OF_FLOOR — nor lower at all where the floor stands out of it
## already — nor within SHOWS of the top.
func _room(cell: int, level: float, slope: Vector3, row: Vector3, rise: float) -> float:
	var room := 1.0
	var ends := _ends[cell]
	for at in range(0, ends.size(), 3):
		var lift := slope.dot(ends[at])
		if lift == 0.0:
			continue
		var most := InnerWater.SLOSH_MOST
		if lift > 0.0:
			most = minf(most, row.dot(ends[at + 2]) + rise - InnerWater.SHOWS - level)
		else:
			most = minf(most, level - row.dot(ends[at + 1]) - rise - InnerWater.CLEAR_OF_FLOOR)
		room = minf(room, maxf(most, 0.0) / absf(lift))
	return room
