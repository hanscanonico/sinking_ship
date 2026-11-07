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
## The side of a square of the ship plane the rooms near the eye are filed by (_near): a
## room is filed under every square within ShipLamp.REACH of its box, give or take
## NEAR_SLACK, so the eye's square names every room it may stand near (#410: the Titanic
## has over a thousand).
const NEAR_SQUARE := 8.0
const NEAR_SLACK := 0.5

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
## Per room, its lamps by index into _lamps, and what they were last handed: 1 wanted, 0
## not, 2 nothing yet. Each choice hands only the rooms whose choice changed, and counts
## the lamps burning again only once one has changed (_recount).
var _room_lamps: Array[PackedInt32Array] = []
var _handed := PackedByteArray()
var _recount := true
## Per square of the ship plane (NEAR_SQUARE), the rooms with lamps the eye may stand near
## from it, lowest first, filed again once a lamp is added; the rooms the last choice
## looked at, the only ones it can have lit; and whether some room has never been handed
## its choice, when a choice hands every room.
var _near: Dictionary[Vector2i, PackedInt32Array] = {}
var _filed := false
var _looked := PackedInt32Array()
var _unhanded := true
## Its choice in the game's extension (NativeSight, #410), or null where the GDScript
## makes it: the same rooms lit either way (test_lamp_sight). Her rooms are laid out for
## it each time they are filed.
var native: Object = ArtNative.made(&"NativeSight")


func _init(space: ShipSpace) -> void:
	_space = space
	var rooms := space.layout.rooms.size()
	_boxes.resize(rooms)
	_door_lines.resize(rooms)
	_door_ways.resize(rooms)
	_burning.resize(rooms)
	_reach.resize(rooms)
	_lit.resize(rooms)
	_room_lamps.resize(rooms)
	_handed.resize(rooms)
	_handed.fill(2)
	_reach.fill(INF)
	for index in rooms:
		_room_lamps[index] = PackedInt32Array()
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
	_room_lamps[room].append(_lamps.size())
	_lamps.append(lamp)
	_rooms.append(room)
	_boxes[room] = box
	_handed[room] = 2
	_recount = true
	_filed = false
	_unhanded = true
	lamp.burning_changed.connect(_on_burning_changed)


func _on_burning_changed() -> void:
	_recount = true


## Wants lit the lamps of every room near the eye at [param eye] (ship space) that it
## can see into, then of the rooms near it out of sight, nearest first, until the next
## one's would take the lamps burning past the limit.
func choose(eye: Vector3) -> void:
	if _recount:
		_recount = false
		_burning.fill(0)
		for index in _lamps.size():
			if _lamps[index].burning:
				_burning[_rooms[index]] += 1
	if not _filed:
		_file_near()
		if native != null:
			_lay_out()
	var looked_before := _looked
	_looked = _near.get(_square(eye), PackedInt32Array())
	var handing := PackedInt32Array()
	if native != null:
		var found: Array = native.choose(
			eye, looked_before, _looked, _burning, limit, _lit, _reach, _handed
		)
		_lit = found[0]
		_reach = found[1]
		handing = found[2]
	else:
		_choose_here(eye, looked_before)
	if _unhanded:
		_unhanded = false
		for room in _lit.size():
			_hand(room)
		return
	if native != null:
		# The rooms whose choice changed, in the order the GDScript hands them.
		for each: int in handing:
			var room := each >> 1
			_handed[room] = each & 1
			for index: int in _room_lamps[room]:
				_lamps[index].wanted = each & 1 == 1
		return
	for room: int in looked_before:
		_hand(room)
	for room: int in _looked:
		_hand(room)


## The choice for the eye at [param eye], made here: every room but those looked at is
## unlit and out of reach — [param looked_before], the last choice's, go back to that
## before this one looks at its own (_looked).
func _choose_here(eye: Vector3, looked_before: PackedInt32Array) -> void:
	for room: int in looked_before:
		_lit[room] = 0
		_reach[room] = INF
	var burning := 0
	for room: int in _looked:
		var box := _boxes[room]
		if not ShipLamp.relevant(eye, box, true):
			continue
		if sees(eye, room):
			_lit[room] = 1
			burning += _burning[room]
		else:
			var nearest := eye.clamp(box.position, box.end)
			_reach[room] = Vector2(eye.x - nearest.x, eye.z - nearest.z).length()
	while true:
		var next := -1
		for room: int in _looked:
			if _lit[room] == 0 and (next == -1 or _reach[room] < _reach[next]):
				next = room
		if next == -1 or is_inf(_reach[next]) or burning + _burning[next] > limit:
			break
		_lit[next] = 1
		burning += _burning[next]


## Hands room [param room]'s lamps the last choice for it, when it changed.
func _hand(room: int) -> void:
	var lit := _lit[room]
	if lit == _handed[room]:
		return
	_handed[room] = lit
	for index: int in _room_lamps[room]:
		_lamps[index].wanted = lit == 1


## The square of the ship plane (NEAR_SQUARE) ship point [param point] stands over.
static func _square(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / NEAR_SQUARE), floori(point.z / NEAR_SQUARE))


## Files every room with lamps under each square any point within ShipLamp.REACH of its
## box, across the ship plane, stands over (_near), lowest room first.
func _file_near() -> void:
	_filed = true
	_near.clear()
	var grow := ShipLamp.REACH + NEAR_SLACK
	for room in _boxes.size():
		var box := _boxes[room]
		if not box.has_volume():
			continue
		var low := _square(box.position - Vector3(grow, 0.0, grow))
		var high := _square(box.end + Vector3(grow, 0.0, grow))
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				var at := Vector2i(x, z)
				var filed: PackedInt32Array = _near.get(at, PackedInt32Array())
				filed.append(room)
				_near[at] = filed


## Lays her rooms out for the extension: each one's box and area, and its doorways'
## lines and ways out.
func _lay_out() -> void:
	var box_positions := PackedVector3Array()
	var box_sizes := PackedVector3Array()
	var area_positions := PackedVector2Array()
	var area_sizes := PackedVector2Array()
	var doors_from := PackedInt32Array()
	var lines := PackedVector2Array()
	var ways := PackedVector2Array()
	for room in _boxes.size():
		box_positions.append(_boxes[room].position)
		box_sizes.append(_boxes[room].size)
		var area := _space.layout.rooms[room].area
		area_positions.append(area.position)
		area_sizes.append(area.size)
		doors_from.append(lines.size())
		lines.append_array(_door_lines[room])
		ways.append_array(_door_ways[room])
	doors_from.append(lines.size())
	native.lay_out(
		box_positions,
		box_sizes,
		area_positions,
		area_sizes,
		doors_from,
		lines,
		ways,
		ShipLamp.REACH,
		ShipLamp.STOREY_MARGIN
	)


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
