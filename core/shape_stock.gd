class_name ShapeStock
extends RefCounted
## What every reader of one match's ship builds of her the same way, built once and
## handed to every later asker (#563): each piece's layout cut from hers (Pieces), the
## solids its Faces frame (Faces), and per piece and frame the Surfaces built over its
## layout — a prototype no one honours, which each asker's own Surfaces shares
## (Surfaces' like). The match's sim, its HUD and its bots each stand on a Surfaces of
## their own; without the stock each builds the same piece's, or the same frame's, in
## the one frame she breaks or turns onto her side — seconds of tens of thousands of
## plates, three times over. Whoever asks first builds it — a ShapeWarmer ahead of the
## match on a worker thread, or else the first reader then — so a stocked shape is the
## very one a reader would have built itself (D4). Safe across threads: a shape is
## built outside the lock and kept by the first to finish, never changed after.

var _mutex := Mutex.new()
var _made := {}


## The shape kept under [param key], made by [param make] and kept the first time it
## is asked for.
func take(key: Array, make: Callable) -> Variant:
	_mutex.lock()
	var kept: Variant = _made.get(key)
	_mutex.unlock()
	if kept != null:
		return kept
	var made: Variant = make.call()
	_mutex.lock()
	if not _made.has(key):
		_made[key] = made
	kept = _made[key]
	_mutex.unlock()
	return kept


## Builds [param into] as [param like], a Surfaces built over [param layout] and never
## honoured since, builds itself: sharing what nothing changes once it is built — its
## numbering, areas, grids and floors — and with its own of what a pose or a crate does
## (Surfaces.honour) as like's stood when it was built.
static func share(into: Surfaces, like: Surfaces, layout: ShipLayout) -> void:
	into._platforms = like._platforms
	into._ramps = like._ramps
	into._blockers = like._blockers
	into._railings = like._railings
	into._rail_normals = like._rail_normals
	into._platform_rails = like._platform_rails
	into._layout = layout
	into._ladder_normals = like._ladder_normals
	into._first_ramp = like._first_ramp
	into._first_top = like._first_top
	into._first_lid = like._first_lid
	into._areas = like._areas
	into._bottoms = like._bottoms
	into._tops = like._tops.duplicate()
	into._level_rects = like._level_rects
	into._grid = like._grid.sharing()
	into._rail_grid = like._rail_grid.sharing()
	into._floors = like._floors
	into._floor_clearances = like._floor_clearances
	into._gone = like._gone.duplicate()
	into._rail_gone = like._rail_gone.duplicate()
	into.stands = PropStands.new(layout, SpatialIndex.bounds_of(layout))
	into.doors = DoorLeaves.new(layout.structure)
	into._fallen = FallenFunnels.new(layout)
	into._obstacles = ObstacleContacts.new(into.stands.native() != null)


## The Surfaces of [param ship]'s decks kept in [param stock] for the whole ship, piece
## 0, to share (Surfaces' like).
static func deck_of(stock: ShapeStock, ship: ShipLayout) -> Surfaces:
	return stock.take([&"deck", 0], func() -> Surfaces: return Surfaces.new(ship))


## Keeps [param shapes] under [param key] for one reader to claim, unless something is
## kept there: what a ShapeWarmer builds a reader of its own (BotFloors) ahead.
func offer(key: Array, shapes: Variant) -> void:
	_mutex.lock()
	if not _made.has(key):
		_made[key] = shapes
	_mutex.unlock()


## What was offered under [param key], no longer kept; null when nothing was.
func claim(key: Array) -> Variant:
	_mutex.lock()
	var kept: Variant = _made.get(key)
	_made.erase(key)
	_mutex.unlock()
	return kept


## Whether a shape is kept under [param key].
func has(key: Array) -> bool:
	_mutex.lock()
	var kept := _made.has(key)
	_mutex.unlock()
	return kept
