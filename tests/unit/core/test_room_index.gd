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
