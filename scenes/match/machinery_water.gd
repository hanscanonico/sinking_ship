class_name MachineryWater
extends RefCounted
## Which machinery rooms' floors and machines the sea comes to over a step (FxPlanner's
## steam): every room's four floor corners and its machine's top read wet once a pose,
## their cells found once a cell map — the Titanic has thousands, read every step.

## The rooms with a machine, in order.
var rooms := PackedInt32Array()
## Per room, its floor's four corners then its machine's top, in ship space.
var _points := PackedVector3Array()
var _surfaces: Surfaces
## Per cell map, the cell each point lies in under it.
var _cells := {}
## What each point read under the pose at _tick, a byte a point; -1 before any.
var _tick := -1
var _wet := PackedByteArray()


## [param machines] holds per room of [param layout] its machine's top, NAN for none.
func _init(layout: ShipLayout, machines: PackedVector3Array, surfaces: Surfaces) -> void:
	_surfaces = surfaces
	for index in layout.rooms.size():
		if is_nan(machines[index].x):
			continue
		var room := layout.rooms[index]
		var area := room.area
		rooms.append(index)
		for corner: Vector2 in [
			area.position,
			Vector2(area.end.x, area.position.y),
			area.end,
			Vector2(area.position.x, area.end.y)
		]:
			_points.append(Vector3(corner.x, room.floor_height, corner.y))
		_points.append(machines[index])


## Per room, two bytes: 1 where the sea reaches its floor, then 1 where it drowns its
## machine, from [param pose_then] at [param from_tick] to [param pose_now] at
## [param tick]. The pose then is read again only when the last call did not end on it.
func went_under(
	pose_then: ShipPose, pose_now: ShipPose, from_tick: int, tick: int
) -> PackedByteArray:
	var went := PackedByteArray()
	went.resize(rooms.size() * 2)
	if rooms.is_empty():
		return went
	var then := _wet if _tick >= 0 and _tick == from_tick else _read(pose_then)
	var now := _read(pose_now)
	_wet = now
	_tick = tick
	for slot in rooms.size():
		var first := slot * 5
		var reached := now[first] + now[first + 1] + now[first + 2] + now[first + 3] > 0
		var was := then[first] + then[first + 1] + then[first + 2] + then[first + 3] > 0
		went[slot * 2] = 1 if reached and not was else 0
		went[slot * 2 + 1] = 1 if now[first + 4] == 1 and then[first + 4] == 0 else 0
	return went


## Whether each point is wet under [param pose], a byte a point.
func _read(pose: ShipPose) -> PackedByteArray:
	var wet := PackedByteArray()
	wet.resize(_points.size())
	var cells: PackedInt32Array = _cells.get(pose.cells, PackedInt32Array())
	if cells.size() != _points.size():
		cells.resize(_points.size())
		for index in _points.size():
			cells[index] = pose.cell_at(_points[index])
		if not pose.levels.is_empty():
			_cells[pose.cells] = cells
	for index in _points.size():
		if _surfaces.wet(_points[index], pose, cells[index]):
			wet[index] = 1
	return wet
