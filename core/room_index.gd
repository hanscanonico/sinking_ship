class_name RoomIndex
extends RefCounted
## ShipLayout.room_at's answers for a layout that does not change, looked for among the
## rooms whose areas reach the metre of x the point is in, in the layout's order — for
## a view asking every step or frame: the Titanic has 2,268 rooms.

## How wide each stretch of x is, in metres.
const SLOT := 1.0

var _layout: ShipLayout
var _from := 0.0
## Per stretch of x from _from on, the rooms reaching into it, in order.
var _slots: Array[PackedInt32Array] = []


func _init(layout: ShipLayout) -> void:
	_layout = layout
	if layout.rooms.is_empty():
		return
	var low := INF
	var high := -INF
	for room: ShipRoom in layout.rooms:
		low = minf(low, room.area.position.x)
		high = maxf(high, room.area.end.x)
	_from = low
	var slots: Array[PackedInt32Array] = []
	for slot in _slot(high) + 1:
		slots.append(PackedInt32Array())
	for index in layout.rooms.size():
		var area := layout.rooms[index].area
		for slot in range(_slot(area.position.x), _slot(area.end.x) + 1):
			var held := slots[slot]
			held.append(index)
			slots[slot] = held
	_slots = slots


## The first room of the layout holding [param ship_point] within [param step] of its
## floor (ShipRoom.holds), or -1 — as ShipLayout.room_at.
func room_at(ship_point: Vector3, step: float) -> int:
	var slot := _slot(ship_point.x)
	if slot < 0 or slot >= _slots.size():
		return -1
	for index: int in _slots[slot]:
		if _layout.rooms[index].holds(ship_point, step):
			return index
	return -1


## The room [param ship_point] is in off its floor, as a body afloat in it is: of the
## rooms whose area holds it and whose floor is no more than [param step] over it, the
## one with the highest floor — the first such in the layout's order — or -1. Nothing
## is asked of what lies between the point and that floor: it is the room only of a
## point known to be inside her (ShipPose.cell_at).
func room_around(ship_point: Vector3, step: float) -> int:
	var slot := _slot(ship_point.x)
	if slot < 0 or slot >= _slots.size():
		return -1
	var found := -1
	var highest := -INF
	for index: int in _slots[slot]:
		var room := _layout.rooms[index]
		if room.floor_height <= highest or room.floor_height > ship_point.y + step:
			continue
		# Over its floor, in its area as ShipRoom.holds has it.
		var on_floor := Vector3(ship_point.x, room.floor_height, ship_point.z)
		if room.holds(on_floor, step):
			found = index
			highest = room.floor_height
	return found


func _slot(x: float) -> int:
	return floori((x - _from) / SLOT)
