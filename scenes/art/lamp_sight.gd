class_name LampSight
extends RefCounted
## Which of the dressed ship's room lamps (ShipArt) light the frame: those of the
## rooms the eye stands near on their storey (ShipLamp.relevant) — and on a cheaper
## graphics preset only those it can see into, from inside or through a doorway,
## nearest first and no more than the preset's limit (GraphicsQuality) — so a frame
## pays for the few lights it shows. A room's lamps light all together or not at
## all, so none goes out in a room the eye stands in; each fades itself in and out
## as it is wanted (ShipLamp), so none pops.

## A gap at least this wide along a room's side, between its full walls
## (ShipSpace.wall_runs), is a doorway the eye can see into the room through.
const DOORWAY := 0.5

## The most lamps burning at once, and whether only the rooms the eye can see into
## light: the graphics preset's (show_graphics), as tuned until told.
var limit := GraphicsQuality.of(GraphicsQuality.Preset.HIGH).lamps
var sight := GraphicsQuality.of(GraphicsQuality.Preset.HIGH).lamp_sight

var _space: ShipSpace
## Every lamp, and per lamp its room's index.
var _lamps: Array[ShipLamp] = []
var _rooms := PackedInt32Array()
## Per room, its box (ship space), its sides with a doorway, and this frame's
## choice: how far across the ship plane the eye is while it is in sight (INF out of
## it), and whether its lamps light.
var _boxes: Array[AABB] = []
var _doorways: Array[PackedInt32Array] = []
var _reach := PackedFloat32Array()
var _lit := PackedByteArray()


func _init(space: ShipSpace) -> void:
	_space = space
	var rooms := space.layout.rooms.size()
	_boxes.resize(rooms)
	_doorways.resize(rooms)
	_reach.resize(rooms)
	_lit.resize(rooms)
	for index in rooms:
		_doorways[index] = doorway_sides(space, space.layout.rooms[index])


## Takes up [param quality]'s limit and sight.
func show_graphics(quality: GraphicsQuality) -> void:
	limit = quality.lamps
	sight = quality.lamp_sight


## [param lamp] hangs in room [param room], whose box (ship space) is [param box].
func add(lamp: ShipLamp, room: int, box: AABB) -> void:
	_lamps.append(lamp)
	_rooms.append(room)
	_boxes[room] = box


## Wants lit the lamps of the rooms in sight of the eye at [param eye] (ship space),
## nearest room first, until the next room's would take the burning lamps past the
## limit; the nearest room in sight always lights.
func choose(eye: Vector3) -> void:
	for room in _boxes.size():
		_lit[room] = 0
		_reach[room] = INF
		var box := _boxes[room]
		if (
			box.has_volume()
			and ShipLamp.relevant(eye, box, true)
			and (not sight or sees(eye, room))
		):
			var nearest := eye.clamp(box.position, box.end)
			_reach[room] = Vector2(eye.x - nearest.x, eye.z - nearest.z).length()
	var burning := 0
	while true:
		var next := -1
		for room in _reach.size():
			if _lit[room] == 0 and (next == -1 or _reach[room] < _reach[next]):
				next = room
		if next == -1 or is_inf(_reach[next]):
			break
		var lamps := 0
		for index in _lamps.size():
			if _rooms[index] == next and _lamps[index].burning:
				lamps += 1
		if burning > 0 and burning + lamps > limit:
			break
		_lit[next] = 1
		burning += lamps
	for index in _lamps.size():
		_lamps[index].wanted = _lit[_rooms[index]] == 1


## Whether the last choice lit room [param room]'s lamps.
func lights(room: int) -> bool:
	return _lit[room] == 1


## Whether the eye at [param eye] (ship space) can see into room [param room]: from
## inside it, or from beyond a side of it with a doorway, through which it looks in.
func sees(eye: Vector3, room: int) -> bool:
	var ship_room := _space.layout.rooms[room]
	var across := Vector2(eye.x, eye.z)
	if ship_room.area.has_point(across):
		return true
	for side: int in _doorways[room]:
		var on_line := _space.on_side(ship_room, side, 0.0, 0.0)
		if (across - on_line).dot(ShipSpace.outward(side)) > 0.0:
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
