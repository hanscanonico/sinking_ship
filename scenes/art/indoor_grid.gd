class_name IndoorGrid
extends RefCounted
## Her rooms as ShipSpace looks them up of a point a million times while she is dressed:
## on a grid of plane squares, and of squares cut into bands of height, each listing in
## order every room a point there may stand in; each room's bounds as numbers; and each
## room's ceiling (ShipSpace.ceiling) worked out once per cell between the edges of what
## roofs it. Every answer is the one a scan of all her rooms gives: the lists only leave
## out rooms no point there can stand in.

## The side of the grid's squares, and the height of its bands, in metres.
const CELL := 2.0
const BAND := 1.0
## How far past a room's own reach it is listed: well past any rounding of a point.
const SLACK := 0.25

var _layout: ShipLayout
## (room: ShipRoom, x: float, z: float) -> float: a room's ceiling worked out.
var _ceiling_at: Callable
## (room: ShipRoom) -> Array[Rect2]: every rectangle whose edges the answer of
## _ceiling_at changes at, at the precision its tests take a point at.
var _roof_edges: Callable
## (room: ShipRoom) -> float: a height its ceiling never stands over.
var _highest: Callable
## Per room, by index, five numbers: the height under its floor and the bounds of its
## area grown by ShipSpace.INSIDE, x then z.
var _bounds := PackedFloat64Array()
## Per square of the plane, the rooms over it; per band of each square, the rooms a
## point in it may stand in.
var _columns: Array[PackedInt32Array] = []
var _cells: Array[PackedInt32Array] = []
var _origin := Vector2.ZERO
var _size := Vector2i.ONE
var _low := 0.0
var _bands := 1
## Per room, by index, the edges of what roofs it along x and along z, and its ceiling by
## cell between them, gathered as asked; and each room's index.
var _edges_x: Array[PackedFloat64Array] = []
var _edges_z: Array[PackedFloat64Array] = []
var _ceilings := []
var _index := {}
## The grid in the extension (ArtNative), which answers outdoors(), outdoors_over() and
## ceiling() once it is made; null where it is not loaded.
var _native: Object
var _native_tried := false


func _init(
	layout: ShipLayout, ceiling_at: Callable, roof_edges: Callable, highest: Callable
) -> void:
	_layout = layout
	_ceiling_at = ceiling_at
	_roof_edges = roof_edges
	_highest = highest


## The rooms, by index and in order, whose areas grown by ShipSpace.INSIDE may hold
## ship-plane point ([param x], [param z]): every room a point there can stand in.
func rooms_over(x: float, z: float) -> PackedInt32Array:
	if _columns.is_empty():
		_grid()
	return _columns[_square(x, z)]


## Whether ship point [param point] stands outside every room (ShipSpace.outdoors) —
## and, when [param boxes] are given, a box per room holding all of it, outside every
## box too.
func outdoors(point: Vector3, boxes: Array[AABB] = []) -> bool:
	var grid := native()
	if grid != null:
		return grid.outdoors(point, boxes)
	if _columns.is_empty():
		_grid()
	var band := clampi(floori((point.y - _low) / BAND), 0, _bands - 1)
	var near := _cells[band * _columns.size() + _square(point.x, point.z)]
	if not boxes.is_empty():
		var boxed := false
		for index: int in near:
			if boxes[index].has_point(point):
				boxed = true
				break
		if not boxed:
			return true
	for index: int in near:
		var at := index * 5
		if point.y < _bounds[at]:
			continue
		if point.x < _bounds[at + 1] or point.x > _bounds[at + 2]:
			continue
		if point.z < _bounds[at + 3] or point.z > _bounds[at + 4]:
			continue
		if point.y <= ceiling(index, point.x, point.z) + ShipSpace.INSIDE:
			return false
	return true


## outdoors() of the probe of each piece of a face (ShipMesh.face): from [param origin]
## along [param u] and [param v], cut at [param u_cuts] and [param v_cuts], each piece's
## middle a step of [param probe] along [param normal] — by column (u) then row (v), as
## ShipMesh.needed() takes them. Worked out room by room over the whole face, the same
## as point by point; empty when the face does not lie along two axes, its points not
## a grid along them.
func outdoors_over(
	origin: Vector3,
	u: Vector3,
	v: Vector3,
	u_cuts: PackedFloat32Array,
	v_cuts: PackedFloat32Array,
	normal: Vector3,
	probe: float,
	boxes: Array[AABB]
) -> Array:
	var u_axis := _only_axis(u)
	var v_axis := _only_axis(v)
	var n_axis := _only_axis(normal)
	if u_axis == -1 or v_axis == -1 or n_axis == -1 or u_axis == v_axis:
		return []
	if n_axis == u_axis or n_axis == v_axis:
		return []
	var grid := native()
	if grid != null:
		return grid.outdoors_over(origin, u, v, u_cuts, v_cuts, normal, probe, boxes)
	if _columns.is_empty():
		_grid()
	var columns := u_cuts.size() - 1
	var rows := v_cuts.size() - 1
	# Each probe point's coordinate along u's axis is its column's alone, along v's its
	# row's, along the normal's the face's: the other terms of its sum are zeros. Each is
	# ShipMesh._middle()'s sum, term for term — its every rounding the same — the terms
	# that stay the same along a row or a column worked out once.
	var stepped := normal * probe
	var first_u := u * (u_cuts[0] + u_cuts[1]) * 0.5
	var first_v := v * (v_cuts[0] + v_cuts[1]) * 0.5
	var along_u := PackedFloat64Array()
	along_u.resize(columns)
	for i in columns:
		along_u[i] = (origin + u * (u_cuts[i] + u_cuts[i + 1]) * 0.5 + first_v + stepped)[u_axis]
	var along_v := PackedFloat64Array()
	along_v.resize(rows)
	var from_u := origin + first_u
	for j in rows:
		along_v[j] = (from_u + v * (v_cuts[j] + v_cuts[j + 1]) * 0.5 + stepped)[v_axis]
	var level: float = (from_u + first_v + stepped)[n_axis]
	var face := FaceProbes.new()
	face.rows = rows
	face.values.resize(3)
	face.by.resize(3)
	face.values[u_axis] = along_u
	face.by[u_axis] = 0
	face.values[v_axis] = along_v
	face.by[v_axis] = 1
	face.values[n_axis] = PackedFloat64Array([level])
	face.by[n_axis] = 2
	if not face.order():
		return []
	var boxed := PackedByteArray()
	var inside := PackedByteArray()
	boxed.resize(columns * rows)
	inside.resize(columns * rows)
	var low := face.low()
	var high := face.high()
	for index: int in _rooms_reaching(low, high):
		# A room whose bounds miss the face's probes holds none of them: no box of it
		# reaches past them.
		var at := index * 5
		if _bounds[at] > high.y + SLACK:
			continue
		if _bounds[at + 1] > high.x + SLACK or _bounds[at + 2] < low.x - SLACK:
			continue
		if _bounds[at + 3] > high.z + SLACK or _bounds[at + 4] < low.z - SLACK:
			continue
		if not boxes.is_empty():
			_mark_box(boxes[index], face, boxed)
		_mark_room(index, face, inside)
	var shows := []
	shows.resize(columns * rows)
	for cell in shows.size():
		# Outside every box, or inside one but in no room.
		shows[cell] = inside[cell] == 0 or (not boxes.is_empty() and boxed[cell] == 0)
	return shows


## The ceiling of room [param index] over ([param x], [param z]) (ShipSpace.ceiling):
## the same over each open cell between the edges of what roofs the room — every test
## it makes is of a point against those edges — so worked out once a cell, and afresh
## only of a point on an edge, to double precision or to the single precision some of
## its tests take a point at.
func ceiling(index: int, x: float, z: float) -> float:
	var grid := native()
	if grid != null:
		return grid.ceiling(index, x, z)
	var cells := _ceiling_cells(index)
	var xs := _edges_x[index]
	var zs := _edges_z[index]
	var column := xs.bsearch(x)
	var row := zs.bsearch(z)
	var on_edge := (
		is_nan(x)
		or is_nan(z)
		or (column < xs.size() and xs[column] == x)
		or (row < zs.size() and zs[row] == z)
	)
	var single := Vector2(x, z)
	if not on_edge and single.x != x:
		var at := xs.bsearch(single.x)
		on_edge = at < xs.size() and xs[at] == single.x
	if not on_edge and single.y != z:
		var at := zs.bsearch(single.y)
		on_edge = at < zs.size() and zs[at] == single.y
	if on_edge:
		return _ceiling_at.call(_layout.rooms[index], x, z)
	return _cell_ceiling(index, cells, column * (zs.size() + 1) + row, x, z)


## The grid as the extension's NativeIndoorGrid, made the first time it is asked, with
## her ceilings worked out by calling back here; null where the extension is not loaded.
func native() -> Object:
	if _native_tried:
		return _native
	_native_tried = true
	_native = ArtNative.made(&"NativeIndoorGrid")
	if _native == null:
		return null
	if _columns.is_empty():
		_grid()
	var cells_from := PackedInt32Array([0])
	var cells := PackedInt32Array()
	for each: PackedInt32Array in _cells:
		cells.append_array(each)
		cells_from.append(cells.size())
	_native.setup(
		_origin, _size, _low, _bands, _bounds, cells_from, cells, _ceiling_of, _roof_edges_of
	)
	return _native


## [param room]'s index among her rooms.
func index_of(room: ShipRoom) -> int:
	if _index.is_empty():
		for index in _layout.rooms.size():
			_index[_layout.rooms[index]] = index
	return _index[room]


## The ceiling of room [param index] over cell [param cell] of [param cells], worked out
## at ([param x], [param z]) in it the first time it is asked.
func _cell_ceiling(index: int, cells: Dictionary, cell: int, x: float, z: float) -> float:
	var height: float = cells.get(cell, NAN)
	if is_nan(height):
		height = _ceiling_at.call(_layout.rooms[index], x, z)
		cells[cell] = height
	return height


## Room [param index]'s ceiling by cell, its edges gathered the first time it is asked.
func _ceiling_cells(index: int) -> Dictionary:
	if _ceilings.is_empty():
		_ceilings.resize(_layout.rooms.size())
		_edges_x.resize(_layout.rooms.size())
		_edges_z.resize(_layout.rooms.size())
	if _ceilings[index] != null:
		return _ceilings[index]
	var edges := _roof_edges_of(index)
	_edges_x[index] = edges[0]
	_edges_z[index] = edges[1]
	var cells: Dictionary[int, float] = {}
	_ceilings[index] = cells
	return cells


## The edges of what roofs room [param index], along x and along z, each sorted.
func _roof_edges_of(index: int) -> Array[PackedFloat64Array]:
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	for edge: Rect2 in _roof_edges.call(_layout.rooms[index]):
		xs.append_array([edge.position.x, edge.end.x])
		zs.append_array([edge.position.y, edge.end.y])
	xs.sort()
	zs.sort()
	var edges: Array[PackedFloat64Array] = [xs, zs]
	return edges


## Room [param index]'s ceiling over ([param x], [param z]) worked out.
func _ceiling_of(index: int, x: float, z: float) -> float:
	return _ceiling_at.call(_layout.rooms[index], x, z)


## Marks in [param marked] each probe of [param face] that [param box] holds, as
## AABB.has_point() tests a point: its ends included.
func _mark_box(box: AABB, face: FaceProbes, marked: PackedByteArray) -> void:
	var end := box.end
	var span_x := face.span(0, box.position.x, end.x)
	if span_x.x >= span_x.y:
		return
	var span_y := face.span(1, box.position.y, end.y)
	if span_y.x >= span_y.y:
		return
	var span_z := face.span(2, box.position.z, end.z)
	if span_z.x >= span_z.y:
		return
	var u := FaceProbes.pick(face.axis_of(0), span_x, span_y, span_z)
	var v := FaceProbes.pick(face.axis_of(1), span_x, span_y, span_z)
	var rows := face.rows
	for i in range(u.x, u.y):
		for j in range(v.x, v.y):
			marked[i * rows + j] = 1


## Marks in [param marked] each probe of [param face] that stands in room
## [param index], as outdoors() tests a point against it.
func _mark_room(index: int, face: FaceProbes, marked: PackedByteArray) -> void:
	var at := index * 5
	var span_x := face.span(0, _bounds[at + 1], _bounds[at + 2])
	if span_x.x >= span_x.y:
		return
	var span_y := face.span(1, _bounds[at], INF)
	if span_y.x >= span_y.y:
		return
	var span_z := face.span(2, _bounds[at + 3], _bounds[at + 4])
	if span_z.x >= span_z.y:
		return
	var cells := _ceiling_cells(index)
	var xs := _edges_x[index]
	var zs := _edges_z[index]
	# Each x's and each z's cell of the room's ceiling, -1 on an edge of it.
	var columns := _cells_along(face.values[0], span_x, xs)
	var rows := _cells_along(face.values[2], span_z, zs)
	var room := _layout.rooms[index]
	var u := FaceProbes.pick(face.axis_of(0), span_x, span_y, span_z)
	var v := FaceProbes.pick(face.axis_of(1), span_x, span_y, span_z)
	var by := face.by
	if by[1] == 2:
		_mark_level(index, face, Vector4i(u.x, u.y, v.x, v.y), columns, rows, marked)
		return
	# An upright face: its height goes by one of column and row, and its place along her
	# or across her by the other, the room's ceiling over it with it.
	var along := 0 if by[0] != 2 else 2
	var x_at := face.values[0]
	var z_at := face.values[2]
	var depth := zs.size() + 1
	var floor := _bounds[at]
	var face_rows := face.rows
	var by_column := by[1] == 1
	# The cell of the ceiling map the last probe stood under, and the probes over its
	# floor and under its ceiling there: the same for the next probe under that cell.
	var last_cell := -1
	var under := Vector2i.ZERO
	var spans_along := span_x if along == 0 else span_z
	for k in range(spans_along.x, spans_along.y):
		var pick_x := k if by[0] != 2 else 0
		var pick_z := k if by[2] != 2 else 0
		var column := columns[pick_x]
		var row := rows[pick_z]
		if column == -1 or row == -1:
			last_cell = -1
			var height: float = _ceiling_at.call(room, x_at[pick_x], z_at[pick_z])
			under = face.span(1, floor, height + ShipSpace.INSIDE)
		elif column * depth + row != last_cell:
			last_cell = column * depth + row
			var height := _cell_ceiling(index, cells, last_cell, x_at[pick_x], z_at[pick_z])
			under = face.span(1, floor, height + ShipSpace.INSIDE)
		for j in range(under.x, under.y):
			marked[k * face_rows + j if by_column else j * face_rows + k] = 1


## _mark_room() of a level face: its probes at one height, each piece of the room's
## ceiling map over it decided at once. [param spans] are the columns (x to y) and the
## rows (z to w) in the room; [param columns] and [param rows] each x's and each z's
## cell of the map (_cells_along).
func _mark_level(
	index: int,
	face: FaceProbes,
	spans: Vector4i,
	columns: PackedInt32Array,
	rows: PackedInt32Array,
	marked: PackedByteArray
) -> void:
	var y := face.values[1][0]
	var x_by_column := face.by[0] == 0
	var xs_at := face.values[0]
	var zs_at := face.values[2]
	# Each column's and each row's cell of the map, along x or z as the face lies.
	var across_i := columns if x_by_column else rows
	var across_j := rows if x_by_column else columns
	var cells := _ceiling_cells(index)
	var depth := _edges_z[index].size() + 1
	var room := _layout.rooms[index]
	var i := spans.x
	while i < spans.y:
		var i_end := _run_end(across_i, i, spans.y)
		var j := spans.z
		while j < spans.w:
			var j_end := _run_end(across_j, j, spans.w)
			var column := across_i[i] if x_by_column else across_j[j]
			var row := across_j[j] if x_by_column else across_i[i]
			var x := xs_at[i if x_by_column else j]
			var z := zs_at[j if x_by_column else i]
			if column != -1 and row != -1:
				var height := _cell_ceiling(index, cells, column * depth + row, x, z)
				if y <= height + ShipSpace.INSIDE:
					for at in range(i, i_end):
						for on in range(j, j_end):
							marked[at * face.rows + on] = 1
			else:
				# On an edge of the map: each probe of the block worked out alone.
				for at in range(i, i_end):
					for on in range(j, j_end):
						var cell := at * face.rows + on
						var probe_x := xs_at[at if x_by_column else on]
						var probe_z := zs_at[on if x_by_column else at]
						if marked[cell] == 0:
							if y <= _ceiling_at.call(room, probe_x, probe_z) + ShipSpace.INSIDE:
								marked[cell] = 1
			j = j_end
		i = i_end


## Where the run of [param cells] from [param start] of one cell ends (before
## [param end]): an edge's -1 is a run of its own.
static func _run_end(cells: PackedInt32Array, start: int, end: int) -> int:
	var at := start + 1
	if cells[start] == -1:
		return at
	while at < end and cells[at] == cells[start]:
		at += 1
	return at


## Per value of [param values] within [param span], its cell between [param edges]
## (their bsearch()), -1 for one on an edge; the rest unset.
static func _cells_along(
	values: PackedFloat64Array, span: Vector2i, edges: PackedFloat64Array
) -> PackedInt32Array:
	var found := PackedInt32Array()
	found.resize(values.size())
	for index in range(span.x, span.y):
		var at := edges.bsearch(values[index])
		found[index] = -1 if at < edges.size() and edges[at] == values[index] else at
	return found


## The rooms, by index, whose reach may meet the box from [param low] to [param high]:
## every room any point in it may stand in.
func _rooms_reaching(low: Vector3, high: Vector3) -> PackedInt32Array:
	var first := _square_of(low.x, low.z)
	var last := _square_of(high.x, high.z)
	var bottom := clampi(floori((low.y - _low) / BAND), 0, _bands - 1)
	var top := clampi(floori((high.y - _low) / BAND), 0, _bands - 1)
	var found := PackedInt32Array()
	var seen := {}
	for band in range(bottom, top + 1):
		for row in range(first.y, last.y + 1):
			for column in range(first.x, last.x + 1):
				var square := row * _size.x + column
				for index: int in _cells[band * _columns.size() + square]:
					if not seen.has(index):
						seen[index] = true
						found.append(index)
	return found


## The one axis [param vector] has a component along — every other exactly zero — or -1.
static func _only_axis(vector: Vector3) -> int:
	var found := -1
	for axis in 3:
		if vector[axis] != 0.0:
			if found != -1:
				return -1
			found = axis
	return found


## The square of the plane ship-plane point ([param x], [param z]) stands over, by index.
func _square(x: float, z: float) -> int:
	var at := _square_of(x, z)
	return at.y * _size.x + at.x


func _square_of(x: float, z: float) -> Vector2i:
	return Vector2i(
		clampi(floori((x - _origin.x) / CELL), 0, _size.x - 1),
		clampi(floori((z - _origin.y) / CELL), 0, _size.y - 1)
	)


## Builds the grid: each room over the squares its area grown by ShipSpace.INSIDE and
## SLACK reaches, and in the bands from under its floor to over its highest ceiling.
func _grid() -> void:
	var rooms := _layout.rooms
	var bounds := Rect2()
	var heights := PackedFloat64Array()
	for index in rooms.size():
		var area := rooms[index].area.grow(ShipSpace.INSIDE + SLACK)
		bounds = area if index == 0 else bounds.merge(area)
		heights.append(rooms[index].floor_height - ShipSpace.INSIDE - SLACK)
		heights.append(_highest.call(rooms[index]) + ShipSpace.INSIDE + SLACK)
	_origin = bounds.position
	_size = Vector2i(floori(bounds.size.x / CELL) + 1, floori(bounds.size.y / CELL) + 1)
	var lowest := INF
	var highest := -INF
	for height: float in heights:
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	_low = lowest if lowest < INF else 0.0
	_bands = floori((highest - lowest) / BAND) + 1 if lowest < INF else 1
	_columns.resize(_size.x * _size.y)
	for square in _columns.size():
		_columns[square] = PackedInt32Array()
	_cells.resize(_columns.size() * _bands)
	for cell in _cells.size():
		_cells[cell] = PackedInt32Array()
	for index in rooms.size():
		var room := rooms[index]
		var grown := room.area.grow(ShipSpace.INSIDE)
		_bounds.append_array([room.floor_height - ShipSpace.INSIDE, grown.position.x])
		_bounds.append_array([grown.end.x, grown.position.y, grown.end.y])
		var area := grown.grow(SLACK)
		var first := _square_of(area.position.x, area.position.y)
		var last := _square_of(area.end.x, area.end.y)
		var bottom := clampi(floori((heights[index * 2] - _low) / BAND), 0, _bands - 1)
		var top := clampi(floori((heights[index * 2 + 1] - _low) / BAND), 0, _bands - 1)
		for row in range(first.y, last.y + 1):
			for column in range(first.x, last.x + 1):
				var square := row * _size.x + column
				_columns[square].append(index)
				for band in range(bottom, top + 1):
					_cells[band * _columns.size() + square].append(index)


## The probe points of a face (outdoors_over) as a grid: per axis x, y, z, its values
## and which of a probe's column (0), its row (1) or neither (2, one value) they go by.
class FaceProbes:
	var values: Array[PackedFloat64Array] = []
	var by := PackedInt32Array()
	## How many rows the face has: a probe's cell is its column times this and its row.
	var rows := 0
	## Per axis, its values or their negations, whichever rise, and which (1 or -1).
	var _rising: Array[PackedFloat64Array] = []
	var _signs := PackedFloat64Array()

	## Sorts out each axis's rising values: false when some axis's neither rise nor fall.
	func order() -> bool:
		for axis in 3:
			var own := values[axis]
			var negated := PackedFloat64Array()
			for value: float in own:
				negated.append(-value)
			if FaceProbes._rises(own):
				_rising.append(own)
				_signs.append(1.0)
			elif FaceProbes._rises(negated):
				_rising.append(negated)
				_signs.append(-1.0)
			else:
				return false
		return true

	## The least of every axis's values, and the greatest.
	func low() -> Vector3:
		return Vector3(_least(0), _least(1), _least(2))

	func high() -> Vector3:
		return Vector3(_most(0), _most(1), _most(2))

	## The values, by index from x up to but not y, of [param axis] from [param low] to
	## [param high], both included.
	func span(axis: int, low: float, high: float) -> Vector2i:
		var rising := _rising[axis]
		if _signs[axis] > 0.0:
			return Vector2i(rising.bsearch(low, true), rising.bsearch(high, false))
		return Vector2i(rising.bsearch(-high, true), rising.bsearch(-low, false))

	## The axis that goes by a probe's column (0) or its row (1).
	func axis_of(source: int) -> int:
		return by.find(source)

	## Of [param x], [param y] and [param z], [param axis]'s: z for -1, as an array of the
	## three indexed by it gives.
	static func pick(axis: int, x: Vector2i, y: Vector2i, z: Vector2i) -> Vector2i:
		if axis == 0:
			return x
		return y if axis == 1 else z

	func _least(axis: int) -> float:
		var least := INF
		for value: float in values[axis]:
			least = minf(least, value)
		return least

	func _most(axis: int) -> float:
		var most := -INF
		for value: float in values[axis]:
			most = maxf(most, value)
		return most

	static func _rises(sequence: PackedFloat64Array) -> bool:
		for index in range(1, sequence.size()):
			if sequence[index] < sequence[index - 1]:
				return false
		return true
