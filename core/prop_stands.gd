class_name PropStands
extends RefCounted
## Where her solid props stand as Surfaces was last told (SH10, #273): each an upright
## circle — its underside's point, its radius, its height and whether its top is a lid —
## on a grid of CELL squares over her bounds, so a question about a point looks only at
## the props in the cells within its reach. A saloon laid with tables and chairs costs a
## body's step, a bot's probe or a crate's contact no more than a hold of cargo. It holds
## nothing it is not told: every prop gone until told where it stands.

## How wide a cell of the grid is, in metres: a laid table and its chairs to a few cells.
const CELL := 2.0
## How much wider than its reach near() looks, in metres: past any rounding of a point's
## distance, single precision or double, at her size.
const SLACK := 0.001

## Per prop of the layout: its radius and height; 1 for a solid one, and 1 for a solid
## one whose top is a lid (PropKind.lid); where its underside stands as last told; and 1
## while it stands nowhere — lost, held, hung, never solid or never told.
var radii := PackedFloat64Array()
var heights := PackedFloat64Array()
var solid := PackedByteArray()
var lids := PackedByteArray()
var feet := PackedVector3Array()
var gone := PackedByteArray()

## The widest prop's radius: how far a prop reaches out of the cell its middle is in;
## how many props stand; and per prop, stand_all()'s mark of those it stands.
var _widest := 0.0
var _standing_count := 0
var _marked := PackedByteArray()
## The grid: where its first cell's corner stands and how many cells it is across x and
## z; per cell, the props whose middles stand in it, in index order, and how many stand
## in it or the cells round it — none, and a question within a cell of it is answered at
## once; per prop, its cell, or -1 while it is gone.
var _origin := Vector2.ZERO
var _columns := 1
var _rows := 1
var _cells: Array[PackedInt32Array] = []
var _round := PackedInt32Array()
var _cell_of := PackedInt32Array()


## The props of [param layout], every one gone, on a grid over [param bounds] — a point
## off it counts as in its nearest edge cell.
func _init(layout: ShipLayout, bounds: Rect2) -> void:
	for prop: ShipProp in layout.props:
		var kind := prop.prop_kind()
		radii.append(prop.radius)
		heights.append(prop.height)
		solid.append(1 if kind.solid else 0)
		lids.append(1 if kind.solid and kind.lid else 0)
		_widest = maxf(_widest, prop.radius)
	feet.resize(radii.size())
	gone.resize(radii.size())
	gone.fill(1)
	_marked.resize(radii.size())
	_cell_of.resize(radii.size())
	_cell_of.fill(-1)
	_origin = bounds.position
	_columns = maxi(1, ceili(bounds.size.x / CELL))
	_rows = maxi(1, ceili(bounds.size.y / CELL))
	_cells.resize(_columns * _rows)
	for cell in _cells.size():
		_cells[cell] = PackedInt32Array()
	_round.resize(_cells.size())


func count() -> int:
	return radii.size()


## Stands each solid prop of [param props] loose where it has it, and none of the others —
## told of every prop at once, as a tick or a bot's reading starts: one where it stood
## costs no more than the looking, and none is taken off unless one standing is missing.
func stand_all(props: Array[PropState]) -> void:
	_marked.fill(0)
	var stood := _standing_count
	var still := 0
	for crate: PropState in props:
		var prop := crate.prop
		var body := crate.body
		# PropState.is_loose(), written out: every tick asks it of every prop.
		if solid[prop] == 0 or body == PropState.Body.LOST or body >= PropState.Body.HUNG:
			continue
		_marked[prop] = 1
		if gone[prop] == 0:
			still += 1
			if feet[prop] == crate.pos:
				continue
		put(prop, crate.pos)
	if still == stood:
		return
	for prop in radii.size():
		if _marked[prop] == 0:
			take(prop)


## Stands [param crate] where it has it, if it is loose and solid, else nowhere — told
## of one crate as it moves, the others as they were.
func stand(crate: PropState) -> void:
	if crate.is_loose() and solid[crate.prop] == 1:
		put(crate.prop, crate.pos)
	else:
		take(crate.prop)


## Prop [param prop] standing at [param at], whatever its kind, in the cell its middle is
## in.
func put(prop: int, at: Vector3) -> void:
	feet[prop] = at
	if gone[prop] == 1:
		gone[prop] = 0
		_standing_count += 1
	var cell := _cell(at.x, at.z)
	if cell == _cell_of[prop]:
		return
	if _cell_of[prop] != -1:
		_cells[_cell_of[prop]].remove_at(_cells[_cell_of[prop]].bsearch(prop))
		_count_round(_cell_of[prop], -1)
	# Never through a local: a packed array is a value, and a copy would take the insert.
	_cells[cell].insert(_cells[cell].bsearch(prop), prop)
	_count_round(cell, 1)
	_cell_of[prop] = cell


## Stands prop [param prop] nowhere.
func take(prop: int) -> void:
	if gone[prop] == 1:
		return
	gone[prop] = 1
	_standing_count -= 1
	_cells[_cell_of[prop]].remove_at(_cells[_cell_of[prop]].bsearch(prop))
	_count_round(_cell_of[prop], -1)
	_cell_of[prop] = -1


## Every prop standing nowhere.
func clear() -> void:
	for prop in radii.size():
		take(prop)


## Every prop standing whose circle may come within [param reach] of the ship-plane point
## [param x], [param z] — a box about it SLACK wider, so some may not, and none a
## question's own rounding would find is left out — in index order; never
## [param except_prop].
func near(x: float, z: float, reach: float, except_prop := -1) -> PackedInt32Array:
	var found := PackedInt32Array()
	var out := reach + _widest + SLACK
	if out <= CELL - SLACK:
		# _cell(), written out: every question about a point is asked here first.
		var column := clampi(floori((x - _origin.x) / CELL), 0, _columns - 1)
		var row := clampi(floori((z - _origin.y) / CELL), 0, _rows - 1)
		if _round[row * _columns + column] == 0:
			return found
	var from := _cell_xz(x - out, z - out)
	var to := _cell_xz(x + out, z + out)
	var cells := 0
	for row in range(from.y, to.y + 1):
		for column in range(from.x, to.x + 1):
			var props := _cells[row * _columns + column]
			if props.is_empty():
				continue
			cells += 1
			for prop: int in props:
				var at := feet[prop]
				var within := radii[prop] + reach + SLACK
				if prop != except_prop and absf(at.x - x) <= within and absf(at.z - z) <= within:
					found.append(prop)
	# Each cell is in index order; cells after cells are not.
	if cells > 1:
		found.sort()
	return found


## Whether the ship-plane point [param x], [param z] is within prop [param prop]'s circle.
func covers(prop: int, x: float, z: float) -> bool:
	var at := feet[prop]
	return Vector2(x - at.x, z - at.z).length() <= radii[prop]


## How high prop [param prop]'s top stands.
func top(prop: int) -> float:
	return feet[prop].y + heights[prop]


## Counts a prop in or out — [param by] 1 or -1 — of cell [param cell] and the cells round
## it.
func _count_round(cell: int, by: int) -> void:
	var column := cell % _columns
	var row := cell / _columns
	for near_row in range(maxi(row - 1, 0), mini(row + 2, _rows)):
		for near_column in range(maxi(column - 1, 0), mini(column + 2, _columns)):
			_round[near_row * _columns + near_column] += by


func _cell(x: float, z: float) -> int:
	var at := _cell_xz(x, z)
	return at.y * _columns + at.x


## The column and row of the cell the ship-plane point [param x], [param z] is in, or
## the nearest edge cell's.
func _cell_xz(x: float, z: float) -> Vector2i:
	return Vector2i(
		clampi(floori((x - _origin.x) / CELL), 0, _columns - 1),
		clampi(floori((z - _origin.y) / CELL), 0, _rows - 1)
	)
