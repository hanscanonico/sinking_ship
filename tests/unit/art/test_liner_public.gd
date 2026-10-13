extends GutTest
## LinerPublic on the Titanic: her public rooms and her grand staircase's landings
## each dressed by name — and nothing they draw stands in a body's way.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace
## Every face of the dressing, three corners to a face, in ship space.
var _faces := PackedVector3Array()
## Per room index, how many of _faces stand in it, but those of its furniture.
var _counts := {}
## The middle of each of _faces that stands in no room: through a deck or a wall.
var _strays := PackedVector3Array()

## Each room's faces under the saloon's dressing it had before LinerPublic drew its
## own (main 71002e8), and how many more it may take: a room's budget.
const BEFORE := {
	&"grand staircase, boat deck": 774,
	&"verandah café": 702,
	&"first-class smoking room": 942,
	&"after entrance": 366,
	&"first-class lounge": 654,
	&"reading and writing room": 462,
	&"grand staircase, A deck": 384,
	&"à la carte restaurant": 312,
	&"grand staircase, B deck": 0,
	&"grand staircase, C deck": 174,
	&"third-class general room": 144,
	&"reception room": 174,
	&"third-class open space": 0,
	&"grand staircase, E deck": 174,
}
const BUDGET := 3000


func before_all() -> void:
	_rules = RunMatch.default_config(1701).rules
	_layout = load("res://data/ships/titanic.tres")
	_space = ShipSpace.new(_layout)
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	_faces = FurnishingCheck.furnishings(art)
	art.free()
	for index in range(0, _faces.size(), 3):
		var middle := (_faces[index] + _faces[index + 1] + _faces[index + 2]) / 3.0
		var room := RoomDressing.room_at(_space, middle)
		# A table FurnitureDressing draws to its box is the furniture's, not the room's.
		if room != -1 and _in_furniture(_layout.rooms[room], middle):
			continue
		_counts[room] = _counts.get(room, 0) + 1
		if room == -1:
			_strays.append(middle)


## Whether [param middle] stands in one of [param room]'s furniture boxes, on its sides
## or its top.
func _in_furniture(room: ShipRoom, middle: Vector3) -> bool:
	for box: ShipBlocker in _space.furniture(room):
		var over := middle.y >= box.bottom - 0.01 and middle.y <= box.top + 0.01
		if over and box.area.grow(0.01).has_point(Vector2(middle.x, middle.z)):
			return true
	return false


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name:
			return room
	return null


## How many of the dressing's faces stand in [param room_name].
func _faces_in(room_name: StringName) -> int:
	return _counts.get(_layout.rooms.find(_room(room_name)), 0)


## How many of the dressing's faces stand in [param room_name] within [param reach]
## of [param at] across the ship plane, from [param low] to [param high] over its floor.
func _faces_near(room_name: StringName, at: Vector2, reach: float, low: float, high: float) -> int:
	var room := _room(room_name)
	var count := 0
	for index in range(0, _faces.size(), 3):
		var middle := (_faces[index] + _faces[index + 1] + _faces[index + 2]) / 3.0
		if Vector2(middle.x, middle.z).distance_to(at) > reach:
			continue
		var height := middle.y - room.floor_height
		if height >= low and height <= high:
			count += 1
	return count


func test_nothing_the_liner_s_rooms_draw_stands_in_a_body_s_way() -> void:
	assert_gt(_faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, _faces), PackedStringArray())


func test_each_public_room_and_landing_is_dressed_more_than_a_saloon_within_budget() -> void:
	for room_name: StringName in BEFORE:
		var faces := _faces_in(room_name)
		assert_gt(faces, BEFORE[room_name], room_name)
		assert_lt(faces - BEFORE[room_name], BUDGET, room_name)


func test_nothing_of_a_public_room_or_landing_pokes_out_of_it() -> void:
	var through := PackedStringArray()
	for room_name: StringName in BEFORE:
		var room := _room(room_name)
		var area := room.area.grow(0.3)
		for middle: Vector3 in _strays:
			var over := _space.ceiling(room, middle.x, middle.z) + 0.5
			var in_it := middle.y > room.floor_height and middle.y < over
			if in_it and area.has_point(Vector2(middle.x, middle.z)):
				through.append("%s: %s" % [room_name, middle])
	assert_eq(through, PackedStringArray())


func test_each_room_takes_its_style_by_its_name() -> void:
	var styles := {
		&"grand staircase, boat deck": LinerPublic.Style.LANDING,
		&"grand staircase, E deck": LinerPublic.Style.LANDING,
		&"after entrance": LinerPublic.Style.ENTRANCE,
		&"first-class smoking room": LinerPublic.Style.SMOKING,
		&"first-class lounge": LinerPublic.Style.LOUNGE,
		&"reading and writing room": LinerPublic.Style.READING,
		&"verandah café": LinerPublic.Style.CAFE,
		&"à la carte restaurant": LinerPublic.Style.RESTAURANT,
		&"reception room": LinerPublic.Style.RECEPTION,
		&"third-class general room": LinerPublic.Style.THIRD,
		&"third-class open space": LinerPublic.Style.THIRD,
	}
	for room_name: StringName in styles:
		assert_eq(LinerPublic.style_of(_room(room_name)), styles[room_name], room_name)


func test_a_chandelier_hangs_over_headroom_for_each_pendant_of_a_landing_and_the_lounge() -> void:
	var dressing := RoomDressing.new(_space)
	for room_name: StringName in [
		&"first-class lounge",
		&"grand staircase, boat deck",
		&"grand staircase, B deck",
		&"grand staircase, C deck",
	]:
		var room := _room(room_name)
		var spots := LinerPublic.chandeliers(room)
		var lights := dressing.lights(room)
		var spacing := RoomDressing.LAMP_SPACING
		var squares := ceili(room.area.size.x / spacing) * ceili(room.area.size.y / spacing)
		assert_eq(lights.size(), squares, "%s: one light for each pendant it had" % room_name)
		for index in lights.size():
			assert_eq(lights[index].kind, ShipLamp.Kind.PENDANT)
			var at := Vector2(lights[index].at.x, lights[index].at.z)
			assert_almost_eq(at, spots[index], Vector2.ONE * 0.001)
			var hung := _faces_near(room_name, at, LinerPublic.CHANDELIER + 0.05, 0.0, 9.0)
			var low := _faces_near(
				room_name, at, LinerPublic.CHANDELIER + 0.05, 0.0, RoomDressing.HEADROOM
			)
			assert_gt(hung, 0, "%s: a chandelier at %s" % [room_name, at])
			assert_eq(low, 0, "%s: nothing of it under HEADROOM" % room_name)
	assert_eq(dressing.lights(_room(&"first-class lounge")).size(), 4)


func test_only_the_boat_deck_landing_has_a_glass_dome() -> void:
	for room_name: StringName in [&"grand staircase, boat deck", &"grand staircase, B deck"]:
		var room := _room(room_name)
		var middle := room.area.get_center()
		var head := _space.ceiling(room, middle.x, middle.y) - room.floor_height
		var dome := _faces_near(room_name, middle, LinerPublic.DOME, head - 0.2, head)
		if room_name == &"grand staircase, boat deck":
			assert_gt(dome, 0, "the dome under her roof")
		else:
			assert_eq(dome, 0, "no dome under B deck's ceiling")
