class_name SpatialIndex
extends RefCounted
## A uniform grid in ship space (D6, SH18): a rectangle of the ship plane (x, z) cut
## into square cells of a side the data gives (IndexRules), each listing, in the order
## they went in, the items whose areas reach into it. A point off the grid is in the
## nearest cell on its edge, so nothing is ever off it. Items go in in ascending number,
## and near() answers in ascending number, each once: the order a scan of every item
## meets them in (D4), so a caller asking it in place of the whole list meets the same
## candidates in the same order and decides as it did. A side of INF is one cell, and
## near() that scan.

## The most blocks near() keeps once gathered: a body's reach or a swimmer's search asked
## again finds its block kept, but sight lines, seldom asked twice, would pile up without
## end — past this many it forgets them all and starts again.
const KEPT_BLOCKS := 1024

var _origin: Vector2
var _side: float
var _size: Vector2i
var _cells: Array[PackedInt32Array] = []
## The cells holding anything, so that clear() empties only those.
var _filled := PackedInt32Array()
## The items of each block of cells near() has gathered, by its corner cells, until
## anything goes in or is cleared.
var _blocks: Dictionary[Vector4i, PackedInt32Array] = {}
var _last := -1


## A grid over [param bounds] (x/z) of cells [param side] metres square.
func _init(bounds: Rect2, side: float) -> void:
	_origin = bounds.position
	_side = side
	_size = Vector2i(floori(bounds.size.x / side) + 1, floori(bounds.size.y / side) + 1)
	_cells.resize(_size.x * _size.y)
	for cell in _cells.size():
		_cells[cell] = PackedInt32Array()


## The rectangle (x/z) every platform, ramp and blocker of [param layout] stands in — a
## cylinder by its square.
static func bounds_of(layout: ShipLayout) -> Rect2:
	var areas: Array[Rect2] = []
	for platform: ShipPlatform in layout.platforms:
		areas.append(platform.area)
	for ramp: ShipRamp in layout.ramps:
		areas.append(ramp.area)
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.BOX:
			areas.append(blocker.area)
		else:
			var corner := blocker.centre - Vector2(blocker.radius, blocker.radius)
			areas.append(Rect2(corner, Vector2(blocker.radius, blocker.radius) * 2.0))
	if areas.is_empty():
		return Rect2()
	var bounds := areas[0]
	for area: Rect2 in areas:
		bounds = bounds.merge(area)
	return bounds


## Puts [param item], numbered above every item already in, into every cell its
## [param area] (x/z) reaches.
func insert(item: int, area: Rect2) -> void:
	assert(item > _last, "items go in in ascending number")
	_last = item
	_blocks.clear()
	var low := _cell_of(area.position)
	var high := _cell_of(area.end)
	for row in range(low.y, high.y + 1):
		for column in range(low.x, high.x + 1):
			var cell := row * _size.x + column
			if _cells[cell].is_empty():
				_filled.append(cell)
			_cells[cell].append(item)


## Takes every item out.
func clear() -> void:
	for cell: int in _filled:
		_cells[cell].clear()
	_filled.clear()
	_blocks.clear()
	_last = -1


## The items whose areas reach the cells [param box] (x/z) touches, in ascending
## number, each once: every item whose area meets the box is among them. What it hands
## back may be a cell's own list: never added to.
func near(box: Rect2) -> PackedInt32Array:
	var low := _cell_of(box.position)
	var high := _cell_of(box.end)
	if low == high:
		return _cells[low.y * _size.x + low.x]
	var block := Vector4i(low.x, low.y, high.x, high.y)
	if block in _blocks:
		return _blocks[block]
	var gathered := PackedInt32Array()
	for row in range(low.y, high.y + 1):
		for column in range(low.x, high.x + 1):
			gathered.append_array(_cells[row * _size.x + column])
	gathered.sort()
	var found := PackedInt32Array()
	for item: int in gathered:
		if found.is_empty() or found[found.size() - 1] != item:
			found.append(item)
	if _blocks.size() == KEPT_BLOCKS:
		_blocks.clear()
	_blocks[block] = found
	return found


## How many cells there are: rows of the grid, each from its low-x end.
func cell_count() -> int:
	return _cells.size()


## The cell holding [param point] (x/z), by number.
func cell_at(point: Vector2) -> int:
	var at := _cell_of(point)
	return at.y * _size.x + at.x


## The items of cell [param cell], in the order they went in. Never added to.
func in_cell(cell: int) -> PackedInt32Array:
	return _cells[cell]


## The column and row of the cell holding [param point] (x/z), the nearest one for a
## point off the grid.
func _cell_of(point: Vector2) -> Vector2i:
	var at := (point - _origin) / _side
	return Vector2i(clampi(floori(at.x), 0, _size.x - 1), clampi(floori(at.y), 0, _size.y - 1))
