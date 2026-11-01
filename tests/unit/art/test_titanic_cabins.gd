extends GutTest
## Her staterooms are furnished by rule off their names (tools/titanic_cabins.py,
## CabinDressing.stateroom): as many berths as a name says, those a room cannot stand
## folded flat, an upper only ever over a lower, and a body still gets in at each door
## and stands inside (#390).

const BODY := 0.4
const STEP := 0.35
const HEIGHT := 1.7
const CELLS: Array[float] = [0.2, 0.05]
## Each class's cabins: how many name a count, the boxes they stand and the berths they
## fold. Moves only with the plates' rooms or the rule.
const PINNED := {
	"first-class": [331, 658, 111],
	"second-class": [183, 490, 128],
	"third-class": [280, 484, 521],
	"none": [6, 14, 7],
}

var _layout: ShipLayout
var _dressing: CabinDressing
var _rooms: Array[ShipRoom] = []


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")
	_dressing = CabinDressing.new(ShipSpace.new(_layout))
	for room: ShipRoom in _layout.rooms:
		if CabinDressing.is_stateroom(room):
			_rooms.append(room)


func test_a_name_gives_its_count() -> void:
	for pair: Array in [
		["single-berth first-class stateroom, B deck", 1],
		["one-berth first-class stateroom", 1],
		["two-berth second-class stateroom, D deck", 2],
		["three-berth first-class stateroom, C deck", 3],
		["four-berth second-class stateroom, D deck aft of O", 4],
		["six-berth third-class room, D deck", 6],
		["first-class stateroom, B deck", 0],
		["parlour suite stateroom", 0],
	]:
		var room := ShipRoom.new()
		room.name = StringName(pair[0])
		assert_eq(CabinDressing.berths_named(room), pair[1], pair[0])


func test_only_the_traced_titanic_has_staterooms() -> void:
	for ship: StringName in [&"small_titanic", &"steamer", &"freighter"]:
		for room: ShipRoom in Fleet.layout(ship).rooms:
			assert_false(CabinDressing.is_stateroom(room), "%s: %s" % [ship, room.name])


func test_each_class_sleeps_what_its_names_say() -> void:
	var found := {}
	for room: ShipRoom in _rooms:
		var named := CabinDressing.berths_named(room)
		var boxes := _standing(room)
		assert_lte(boxes, maxi(named, 2), "%s: no more berths than it says" % room.name)
		if named == 0:
			continue
		var cls := _class_of(room)
		if not found.has(cls):
			found[cls] = [0, 0, 0]
		found[cls][0] += 1
		found[cls][1] += boxes
		found[cls][2] += named - boxes
	assert_eq(found, PINNED)


func test_an_upper_stands_over_a_lower() -> void:
	for room: ShipRoom in _rooms:
		var lowers := _dressing.berth_boxes(room, 0.0)
		for upper: ShipBlocker in _dressing.berth_boxes(room, CabinDressing.UPPER_BOTTOM):
			var under := false
			for lower: ShipBlocker in lowers:
				under = under or lower.area.is_equal_approx(upper.area)
			assert_true(under, "%s: its upper over its lower" % room.name)


func test_a_body_gets_in_at_each_door_and_stands_inside() -> void:
	var surfaces := Surfaces.new(_layout)
	var space := ShipSpace.new(_layout)
	for room: ShipRoom in _rooms:
		var doors: Array[Vector2] = []
		var runs := space.wall_runs(room)
		for side in 4:
			for gap: Vector2 in RoomDressing._gaps(room, side, runs):
				if RoomDressing._beyond(space, room, side, gap) != -1:
					doors.append(space.on_side(room, side, (gap.x + gap.y) * 0.5, BODY + 0.05))
		var got_in := false
		# Coarse first, for most stand open; a way barely a body wide wants the fine grid.
		for cell: float in CELLS:
			got_in = got_in or _doors_meet(surfaces, room, doors, cell)
		assert_true(
			got_in, "%s at %s: nowhere to stand, or a door cut off" % [room.name, room.area]
		)


func _standing(room: ShipRoom) -> int:
	return (
		_dressing.berth_boxes(room, 0.0).size()
		+ _dressing.berth_boxes(room, CabinDressing.UPPER_BOTTOM).size()
	)


func _class_of(room: ShipRoom) -> String:
	for cls: String in PINNED:
		if cls in String(room.name):
			return cls
	return "none"


## Whether a body stands somewhere in [param room] that every one of [param doors] reaches,
## on a grid of [param cell].
func _doors_meet(surfaces: Surfaces, room: ShipRoom, doors: Array[Vector2], cell: float) -> bool:
	var free := _free_cells(surfaces, room, cell)
	if free.is_empty():
		return false
	var first := _nearest(free, doors[0] if not doors.is_empty() else room.area.get_center())
	var reached := _flood(free, first)
	for door: Vector2 in doors:
		if not reached.has(_nearest(free, door)):
			return false
	return true


## The cells of side [param cell] of [param room] a body's middle stands in with nothing
## holding it off.
func _free_cells(surfaces: Surfaces, room: ShipRoom, cell: float) -> Dictionary:
	var free := {}
	var count := Vector2i((room.area.size / cell).ceil())
	for i in count.x:
		for k in count.y:
			var at := room.area.position + (Vector2(i, k) + Vector2.ONE * 0.5) * cell
			var feet := Vector3(at.x, room.floor_height, at.y)
			if surfaces.obstacle_contacts(feet, BODY, HEIGHT, STEP).is_empty():
				free[Vector2i(i, k)] = at
	return free


func _nearest(free: Dictionary, to: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var far := INF
	for cell: Vector2i in free:
		var off: float = (free[cell] as Vector2).distance_squared_to(to)
		if off < far:
			best = cell
			far = off
	return best


func _flood(free: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + way
			if free.has(next) and not seen.has(next):
				seen[next] = true
				todo.append(next)
	return seen
