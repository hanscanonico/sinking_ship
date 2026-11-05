class_name StillPoints
extends RefCounted
## Points of her that never move in her (D6) — a doorway's ends, a room's middle, a
## floor's corners — asked about the water of pose after pose, as a walk graph asks it
## of every tick's (D7): the cell of a pose's CellMap each lies in, and the cells under
## it down to the sea (CellMap.cells_under), found once for that CellMap; and all their
## heights in the world under a pose worked out at once, the pose's transform taking
## every one together — the same arithmetic as one at a time. The answers are those
## ShipPose.world_height, Surfaces.wet and ShipPose.above_water give for each point,
## without looking for a cell or a height again.

var _points := PackedVector3Array()
## The CellMap the cells below were found in, and whether they have been yet.
var _map: CellMap
var _located := false
var _chained := false
## Per point, its cell (CellMap.NONE outside her, or for a pose that keeps no cells),
## and the point straight down on that cell's floor (the point itself outside her).
var _cells := PackedInt32Array()
var _own_floors := PackedVector3Array()
## Per point, from _chain_from[point] to _chain_from[point + 1], the cells under it and
## the points of their floors under it.
var _chain_from := PackedInt32Array()
var _chain_cells := PackedInt32Array()
var _chain_points := PackedVector3Array()
## The pose read, and the points and their floors as it sets them in the world: empty
## until a height of them is first asked.
var _pose: ShipPose
var _world := PackedVector3Array()
var _world_floors := PackedVector3Array()
var _floors_set := false
var _world_own_floors := PackedVector3Array()
## The NativeWater the loops over every point go to (#410), or null where they run here:
## the same answers either way (test_water_native).
var water: Object = null


func _init(points: PackedVector3Array, native: Object = null) -> void:
	_points = points
	water = native


## A NativeWater where the game's extension is loaded (native/, make native), else null.
static func native_water() -> Object:
	return ClassDB.instantiate(&"NativeWater") if ClassDB.class_exists(&"NativeWater") else null


func size() -> int:
	return _points.size()


## Point [param index], ship-local.
func point(index: int) -> Vector3:
	return _points[index]


## Answers for [param pose] from now on: a pose is a value, so the same one keeps its
## answers.
func read(pose: ShipPose) -> void:
	if pose == _pose:
		return
	_pose = pose
	_world.clear()
	_world_floors.clear()
	_floors_set = false
	_world_own_floors.clear()
	if pose.cells != _map:
		_map = pose.cells
		_located = false
		_chained = false


## How high point [param index] stands in the world under the pose read
## (ShipPose.world_height).
func world_height(index: int) -> float:
	if _world.is_empty():
		_world = _pose.transform * _points
	return _world[index].y


## The cell point [param index] lies in by the cell map of the pose read (CellMap.cell_at).
func cell(index: int) -> int:
	if not _located:
		_locate()
	return _cells[index]


## Every point's cell by the cell map of the pose read, as cell() has them one by one:
## for a caller that asks of them all.
func cells() -> PackedInt32Array:
	if not _located:
		_locate()
	return _cells


## Every point as the pose read sets it in the world, whose y world_height reads: for a
## caller that asks of them all.
func world_points() -> PackedVector3Array:
	if _world.is_empty():
		_world = _pose.transform * _points
	return _world


## Whether point [param index] is under the water of the pose read (Surfaces.wet).
func wet(index: int) -> bool:
	if not _located:
		_locate()
	return _pose.wet_at(_points[index], world_height(index), _cells[index])


## Per point, 1 where it is under the water of the pose read (wet): every point at
## once, for a caller that asks of them all — those over every water there is passed
## over without asking their cells, the rest judged as ShipPose.wet_at judges them, their
## floors' heights worked out together.
func wet_all() -> PackedByteArray:
	if not _located:
		_locate()
	if _world.is_empty():
		_world = _pose.transform * _points
	var highest := _pose.highest_water()
	var levels := _pose.levels
	# A pose that keeps no cells has her inside the sea's water, as cell_at says.
	var keeps := not levels.is_empty()
	if keeps and _world_own_floors.is_empty():
		_world_own_floors = _pose.transform * _own_floors
	if water != null:
		return water.wet_all(_world, _cells, keeps, levels, _world_own_floors, highest, CellMap.DRY)
	var found := PackedByteArray()
	found.resize(_points.size())
	for index in _points.size():
		var height := _world[index].y
		if height >= highest:
			continue
		var cell := _cells[index] if keeps else CellMap.NONE
		if cell == CellMap.NONE:
			found[index] = 1 if height < 0.0 else 0
			continue
		var level := levels[cell]
		if height < level and level > _world_own_floors[index].y + CellMap.DRY:
			found[index] = 1
	return found


## How far point [param index] stands above the water under it under the pose read
## (ShipPose.above_water).
func above_water(index: int) -> float:
	if not _chained:
		_chain()
	if not _floors_set:
		_world_floors = _pose.transform * _chain_points
		_floors_set = true
	return _pose.above_water_seen(
		world_height(index), _chain_cells, _world_floors, _chain_from[index], _chain_from[index + 1]
	)


## Per group of points — from [param groups][group] to [param groups][group + 1] — the
## least of their above_water, INF for none.
func lowest_of(groups: PackedInt32Array) -> PackedFloat64Array:
	if not _chained:
		_chain()
	if not _floors_set:
		_world_floors = _pose.transform * _chain_points
		_floors_set = true
	if _world.is_empty():
		_world = _pose.transform * _points
	if water != null:
		return water.lowest_of(
			groups, _world, _chain_from, _chain_cells, _world_floors, _pose.levels, CellMap.DRY
		)
	var lowest := PackedFloat64Array()
	lowest.resize(maxi(groups.size() - 1, 0))
	for group in lowest.size():
		lowest[group] = INF
		for index in range(groups[group], groups[group + 1]):
			lowest[group] = minf(lowest[group], above_water(index))
	return lowest


## Every point set in the world under the pose read.
func world_all() -> PackedVector3Array:
	if _world.is_empty():
		_world = _pose.transform * _points
	return _world


func _locate() -> void:
	_cells.resize(_points.size())
	_own_floors.resize(_points.size())
	for index in _points.size():
		var at := _points[index]
		var cell := CellMap.NONE if _map == null else _map.cell_at(at)
		_cells[index] = cell
		_own_floors[index] = (
			at if cell == CellMap.NONE else Vector3(at.x, _map.floor_of(cell), at.z)
		)
	_located = true
	_world_own_floors.clear()


func _chain() -> void:
	_chain_from.clear()
	_chain_cells.clear()
	_chain_points.clear()
	for at: Vector3 in _points:
		_chain_from.append(_chain_cells.size())
		if _map == null:
			continue
		for cell: int in _map.cells_under(at):
			_chain_cells.append(cell)
			_chain_points.append(Vector3(at.x, _map.floor_of(cell), at.z))
	_chain_from.append(_chain_cells.size())
	_chained = true
	_floors_set = false
