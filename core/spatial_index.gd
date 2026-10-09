class_name SpatialIndex
extends RefCounted
## A uniform grid in ship space (D6, SH18): a rectangle of the ship plane (x, z) cut
## into square cells of a side the data gives (IndexRules), each listing, in the order
## they went in, the items whose areas reach into it; and each cell cut again into bands
## of a height the data gives, each listing those of them whose heights reach into it. A
## point off the grid is in the nearest cell on its edge, and a height above or below
## every band in the nearest band, so nothing is ever off it. Items go in in ascending
## number, and near() answers in ascending number, each once: the order a scan of every
## item meets them in (D4), so a caller asking it in place of the whole list meets the
## same candidates in the same order and decides as it did. A side of INF is one cell, a
## band of INF one band, and near() that scan; and a query reaching more cells than the
## data's scan_over is handed every item — that scan itself, cheaper than gathering them.

## The most blocks near() keeps once gathered: a body's reach or a swimmer's search asked
## again finds its block kept, but sight lines, seldom asked twice, would pile up without
## end — past this many it forgets them all and starts again.
const KEPT_BLOCKS := 1024
## How far past its ends near() takes a query's heights: a caller's own sums of heights
## may round a hair past them.
const ROUNDING := 0.000001

var _origin: Vector2
var _side: float
var _size: Vector2i
## The height the lowest band starts at, a band's height, and how many there are.
var _low: float
var _band: float
var _bands: int
var _scan_over: float
## Per cell of the plane, every item over it; and per band of each, band after band, the
## items reaching into it — with one band, the plane's cells themselves.
var _columns: Array[PackedInt32Array] = []
var _cells: Array[PackedInt32Array] = []
## The cells of each holding anything, so that clear() empties only those.
var _filled_columns := PackedInt32Array()
var _filled := PackedInt32Array()
## Every item in, in ascending number.
var _all := PackedInt32Array()
## The items of each block of cells near() has gathered, by its corner cells and its
## bands, until anything goes in or is cleared.
var _blocks: Dictionary[Vector4i, PackedInt32Array] = {}
var _last := -1


## A grid over [param bounds] (x/z) of cells [param side] metres square, cut into bands
## [param band] metres high from [param heights]' low (x) to its high (y), that hands a
## query reaching more than [param scan_over] cells every item.
func _init(
	bounds: Rect2, side: float, heights := Vector2.ZERO, band := INF, scan_over := INF
) -> void:
	_origin = bounds.position
	_side = side
	_size = Vector2i(floori(bounds.size.x / side) + 1, floori(bounds.size.y / side) + 1)
	_low = heights.x
	_band = band
	_bands = floori((heights.y - heights.x) / band) + 1
	_scan_over = scan_over
	_columns.resize(_size.x * _size.y)
	for cell in _columns.size():
		_columns[cell] = PackedInt32Array()
	if _bands == 1:
		_cells = _columns
		return
	_cells.resize(_columns.size() * _bands)
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


## The lowest (x) and highest (y) any platform, ramp end or blocker of [param layout]
## stands.
static func heights_of(layout: ShipLayout) -> Vector2:
	var heights := PackedFloat64Array()
	for platform: ShipPlatform in layout.platforms:
		heights.append(platform.height)
	for ramp: ShipRamp in layout.ramps:
		heights.append(ramp.start_height)
		heights.append(ramp.end_height)
	for blocker: ShipBlocker in layout.blockers:
		heights.append(blocker.bottom)
		heights.append(blocker.top)
	if heights.is_empty():
		return Vector2.ZERO
	heights.sort()
	return Vector2(heights[0], heights[heights.size() - 1])


## Puts [param item], numbered above every item already in, into every cell its
## [param area] (x/z) reaches, in every band from [param bottom] up to [param top].
func insert(item: int, area: Rect2, bottom := -INF, top := INF) -> void:
	assert(item > _last, "items go in in ascending number")
	_last = item
	_all.append(item)
	_blocks.clear()
	var low := _cell_of(area.position)
	var high := _cell_of(area.end)
	for row in range(low.y, high.y + 1):
		for column in range(low.x, high.x + 1):
			var cell := row * _size.x + column
			if _columns[cell].is_empty():
				_filled_columns.append(cell)
			_columns[cell].append(item)
	if _bands == 1:
		return
	for band in range(_band_of(bottom), _band_of(top) + 1):
		for row in range(low.y, high.y + 1):
			for column in range(low.x, high.x + 1):
				var cell := (band * _size.y + row) * _size.x + column
				if _cells[cell].is_empty():
					_filled.append(cell)
				_cells[cell].append(item)


## Takes every item out.
func clear() -> void:
	for cell: int in _filled_columns:
		_columns[cell].clear()
	for cell: int in _filled:
		_cells[cell].clear()
	_filled_columns.clear()
	_filled.clear()
	_all.clear()
	_blocks.clear()
	_last = -1


## The items whose areas reach the cells [param box] (x/z) touches, in the bands from
## [param bottom] up to [param top], in ascending number, each once: every item whose area
## meets the box and whose heights meet those is among them. What it hands back may be a
## cell's own list: never added to.
func near(box: Rect2, bottom := -INF, top := INF) -> PackedInt32Array:
	var low := _cell_of(box.position)
	var high := _cell_of(box.end)
	var first := _band_of(bottom - ROUNDING)
	var last := _band_of(top + ROUNDING)
	if (high.x - low.x + 1) * (high.y - low.y + 1) * (last - first + 1) > _scan_over:
		return _all
	var block := Vector4i(low.y * _size.x + low.x, high.y * _size.x + high.x, first, last)
	var cells := _cells
	if last - first + 1 == _bands:
		# Every band over a cell holds nothing its column does not.
		cells = _columns
		first = 0
		last = 0
	if low == high and first == last:
		return cells[(first * _size.y + low.y) * _size.x + low.x]
	if block in _blocks:
		return _blocks[block]
	var gathered := PackedInt32Array()
	for band in range(first, last + 1):
		for row in range(low.y, high.y + 1):
			for column in range(low.x, high.x + 1):
				gathered.append_array(cells[(band * _size.y + row) * _size.x + column])
	gathered.sort()
	var found := PackedInt32Array()
	for item: int in gathered:
		if found.is_empty() or found[found.size() - 1] != item:
			found.append(item)
	if _blocks.size() == KEPT_BLOCKS:
		_blocks.clear()
	_blocks[block] = found
	return found


## How many cells there are in the plane: rows of the grid, each from its low-x end.
func cell_count() -> int:
	return _columns.size()


## The cell of the plane holding [param point] (x/z), by number.
func cell_at(point: Vector2) -> int:
	var at := _cell_of(point)
	return at.y * _size.x + at.x


## The items over cell [param cell] of the plane, every band's, in the order they went
## in. Never added to.
func in_cell(cell: int) -> PackedInt32Array:
	return _columns[cell]


## The column and row of the cell holding [param point] (x/z), the nearest one for a
## point off the grid.
func _cell_of(point: Vector2) -> Vector2i:
	var at := (point - _origin) / _side
	return Vector2i(clampi(floori(at.x), 0, _size.x - 1), clampi(floori(at.y), 0, _size.y - 1))


## The band holding height [param height], the nearest one for a height above or below
## them all.
func _band_of(height: float) -> int:
	if _bands == 1:
		return 0
	return floori(clampf((height - _low) / _band, 0.0, _bands - 1))
