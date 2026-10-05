class_name LampSight
extends RefCounted
## Which of the dressed ship's room lamps (ShipArt) light the frame: those of the
## rooms the eye stands near on their storey (ShipLamp.relevant). Every one of those
## the eye can see into — from inside or through a doorway — lights, whatever the
## graphics preset; a room it cannot see into lights only while the lamps burning stay
## within the preset's limit (GraphicsQuality), nearest first, so a cheap preset pays
## for no light behind a wall and never darkens a room in view. A room's lamps light
## all together or not at all; each fades itself in and out as it is wanted
## (ShipLamp), so none pops.

## A gap at least this wide along a room's side, between its full walls
## (ShipSpace.wall_runs), is a doorway the eye can see into the room through.
const DOORWAY := 0.5

## The most lamps burning at once but for those of the rooms in sight: the graphics
## preset's (show_graphics), as tuned until told.
var limit := GraphicsQuality.of(GraphicsQuality.Preset.HIGH).lamps

var _space: ShipSpace
## Every lamp, and per lamp its room's index.
var _lamps: Array[ShipLamp] = []
var _rooms := PackedInt32Array()
## Per room, its box (ship space); per side of it with a doorway, a point on the
## side's line and the side's way out (ship plane); and this frame's choice: how many
## of its lamps burn, how far across the ship plane the eye is while it is near (INF
## when it is not), and whether its lamps light.
var _boxes: Array[AABB] = []
var _door_lines: Array[PackedVector2Array] = []
var _door_ways: Array[PackedVector2Array] = []
var _burning := PackedInt32Array()
var _reach := PackedFloat32Array()
var _lit := PackedByteArray()


func _init(space: ShipSpace) -> void:
	_space = space
	var rooms := space.layout.rooms.size()
	_boxes.resize(rooms)
	_door_lines.resize(rooms)
	_door_ways.resize(rooms)
	_burning.resize(rooms)
	_reach.resize(rooms)
	_lit.resize(rooms)
	for index in rooms:
		var room := space.layout.rooms[index]
		var lines := PackedVector2Array()
		var ways := PackedVector2Array()
		for side: int in doorway_sides(space, room):
			lines.append(space.on_side(room, side, 0.0, 0.0))
			ways.append(ShipSpace.outward(side))
		_door_lines[index] = lines
		_door_ways[index] = ways


## Takes up [param quality]'s limit.
func show_graphics(quality: GraphicsQuality) -> void:
	limit = quality.lamps


## [param lamp] hangs in room [param room], whose box (ship space) is [param box].
func add(lamp: ShipLamp, room: int, box: AABB) -> void:
	_lamps.append(lamp)
	_rooms.append(room)
	_boxes[room] = box


## Wants lit the lamps of every room near the eye at [param eye] (ship space) that it
## can see into, then of the rooms near it out of sight, nearest first, until the next
## one's would take the lamps burning past the limit.
func choose(eye: Vector3) -> void:
	_burning.fill(0)
	for index in _lamps.size():
		if _lamps[index].burning:
			_burning[_rooms[index]] += 1
	var burning := 0
	for room in _boxes.size():
		_lit[room] = 0
		_reach[room] = INF
		var box := _boxes[room]
		if not box.has_volume() or not ShipLamp.relevant(eye, box, true):
			continue
		if sees(eye, room):
			_lit[room] = 1
			burning += _burning[room]
		else:
			var nearest := eye.clamp(box.position, box.end)
			_reach[room] = Vector2(eye.x - nearest.x, eye.z - nearest.z).length()
	while true:
		var next := -1
		for room in _reach.size():
			if _lit[room] == 0 and (next == -1 or _reach[room] < _reach[next]):
				next = room
		if next == -1 or is_inf(_reach[next]) or burning + _burning[next] > limit:
			break
		_lit[next] = 1
		burning += _burning[next]
	for index in _lamps.size():
		_lamps[index].wanted = _lit[_rooms[index]] == 1


## Whether the last choice lit room [param room]'s lamps.
func lights(room: int) -> bool:
	return _lit[room] == 1


## Whether the eye at [param eye] (ship space) can see into room [param room]: from
## inside it, or from beyond a side of it with a doorway, through which it looks in.
func sees(eye: Vector3, room: int) -> bool:
	var across := Vector2(eye.x, eye.z)
	if _space.layout.rooms[room].area.has_point(across):
		return true
	var lines := _door_lines[room]
	for door in lines.size():
		if (across - lines[door]).dot(_door_ways[room][door]) > 0.0:
			return true
	return false


## The sides of [param room] with a doorway in them: a gap of DOORWAY or more between
## its full walls, or no full wall at all.
static func doorway_sides(space: ShipSpace, room: ShipRoom) -> PackedInt32Array:
	var runs := space.wall_runs(room)
	var sides := PackedInt32Array()
	for side in 4:
		var length := room.area.size.x if side % 2 == 0 else room.area.size.y
		var walled := 0.0
		var half := 0.0
		for run: Array in runs:
			if run[0] == side:
				walled += run[2] - run[1]
				half = run[3]
		if length - 2.0 * half - walled >= DOORWAY:
			sides.append(side)
	return sides
