extends GutTest
## RoomIndex answers as ShipLayout.room_at does, in her rooms, on their walls, between
## decks and outside her.


func test_it_answers_as_the_layout_does() -> void:
	var layout := SimFixtures.steamer()
	var index := RoomIndex.new(layout)
	var step := SimFixtures.rules().step_height
	var found := 0
	for along in 120:
		for up in 30:
			for across in 40:
				var point := Vector3(-30.0 + along * 0.5, -7.0 + up * 0.5, -10.0 + across * 0.5)
				var room := layout.room_at(point, step)
				assert_eq(index.room_at(point, step), room, "at %s" % point)
				found += 1 if room != -1 else 0
	for room: ShipRoom in layout.rooms:
		# Its corners, on the edges every stretch of x is cut at.
		for corner: Vector2 in [room.area.position, room.area.end]:
			var point := Vector3(corner.x, room.floor_height, corner.y)
			assert_eq(index.room_at(point, step), layout.room_at(point, step))
	assert_gt(found, 100, "many points in a room")


func test_a_layout_with_no_rooms_has_none() -> void:
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.rooms = []
	assert_eq(RoomIndex.new(layout).room_at(Vector3.ZERO, 0.4), -1)


## A point afloat in a room is off its floor (room_at has none): room_around names the
## room whose floor is the nearest under it — never the one under that floor, nor one
## whose floor is over it — and none outside every room's area.
func test_a_point_afloat_is_in_the_room_round_it() -> void:
	var layout := SimFixtures.steamer()
	var index := RoomIndex.new(layout)
	var step := SimFixtures.rules().step_height
	var hold := _room(layout, &"forward hold")
	var lower := _room(layout, &"lower hold")
	var afloat := Vector3(9.0, layout.rooms[hold].floor_height + 1.4, 0.0)
	assert_eq(index.room_at(afloat, step), -1, "off every floor")
	assert_eq(index.room_around(afloat, step), hold, "over the lower hold too: the nearer floor")
	var deep := Vector3(9.0, layout.rooms[lower].floor_height + 1.4, 0.0)
	assert_eq(index.room_around(deep, step), lower, "under the forward hold's floor")
	var on_floor := Vector3(9.0, layout.rooms[hold].floor_height, 0.0)
	assert_eq(index.room_around(on_floor, step), index.room_at(on_floor, step), "on its floor too")
	assert_eq(index.room_around(Vector3(9.0, -40.0, 0.0), step), -1, "under every floor")
	assert_eq(index.room_around(Vector3(9.0, -1.2, 30.0), step), -1, "off her side")
	assert_eq(index.room_around(Vector3(900.0, -1.2, 0.0), step), -1, "off her end")


func _room(layout: ShipLayout, room_name: StringName) -> int:
	for index in layout.rooms.size():
		if layout.rooms[index].name == room_name:
			return index
	return -1
