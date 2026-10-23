extends GutTest
## A block of cabins drawn as one room is a block of berths (RoomDressing.NAMED,
## LinerBerths): the freighter's officers', crew's and forward cabins hang berths along
## their walls, a washstand and a locker under every third, and nothing they draw stands
## in a body's way (FurnishingCheck). On main her officers' cabins were taken for an
## office — "officers'" holds "office" — and drew nothing at all.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")
const CABINS: Array[StringName] = [&"officers' cabins", &"crew cabins", &"forward cabins"]


func test_the_freighter_s_cabins_are_blocks_of_berths() -> void:
	var layout := Fleet.layout(&"freighter")
	var space := ShipSpace.new(layout)
	for cabins: StringName in CABINS:
		var room := _room(layout, cabins)
		assert_eq(RoomDressing.kind_of(space, room), RoomDressing.Kind.BERTHS, cabins)
		assert_gt(LinerBerths.spots(space, room).size(), 0, "%s's berths" % cabins)


func test_nothing_the_freighter_s_cabins_draw_stands_in_a_body_s_way() -> void:
	var rules := RunMatch.default_config(1701).rules
	var layout := Fleet.layout(&"freighter")
	var space := ShipSpace.new(layout)
	var art := ShipArt.new()
	art.build(layout, rules.railing_height, rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	art.free()
	var rooms: Array[ShipRoom] = []
	for cabins: StringName in CABINS:
		rooms.append(_room(layout, cabins))
	var theirs := PackedVector3Array()
	for index in range(0, faces.size(), 3):
		var middle := (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
		for room: ShipRoom in rooms:
			if not room.area.has_point(Vector2(middle.x, middle.z)):
				continue
			if middle.y < room.floor_height - 0.01:
				continue
			if middle.y > space.ceiling(room, middle.x, middle.z):
				continue
			theirs.append_array(faces.slice(index, index + 3))
			break
	assert_gt(theirs.size(), 0, "the cabins' berths, washstands and lockers")
	assert_eq(FurnishingCheck.intrusions(layout, rules, theirs), PackedStringArray())


func _room(layout: ShipLayout, room_name: StringName) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.name == room_name:
			return room
	return null
