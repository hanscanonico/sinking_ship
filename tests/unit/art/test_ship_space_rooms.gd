extends GutTest
## ShipSpace looks up the rooms a point or a piece may stand in on a grid (rooms_near),
## and finds a room's roof lowest deck first: what outdoors(), indoors(), roof() and
## RoomDressing.room_at() answer is what trying every room and every deck over it
## answers, all over the Titanic — her hundred rooms on eight decks.

const TITANIC := "res://data/ships/titanic.tres"


## Outdoors as trying every room in turn says it.
static func _outdoors_trying_all(space: ShipSpace, point: Vector3) -> bool:
	for room: ShipRoom in space.layout.rooms:
		if point.y < room.floor_height - ShipSpace.INSIDE:
			continue
		var area := room.area.grow(ShipSpace.INSIDE)
		if point.x < area.position.x or point.x > area.end.x:
			continue
		if point.z < area.position.y or point.z > area.end.y:
			continue
		if point.y <= space.ceiling(room, point.x, point.z) + ShipSpace.INSIDE:
			return false
	return true


## The room trying every room in turn finds a point in, -1 for none.
static func _room_trying_all(space: ShipSpace, point: Vector3) -> int:
	for index in space.layout.rooms.size():
		var room := space.layout.rooms[index]
		var area := room.area
		if point.x < area.position.x or point.x > area.end.x:
			continue
		if point.z < area.position.y or point.z > area.end.y:
			continue
		if point.y < room.floor_height - ShipSpace.INSIDE:
			continue
		if point.y <= space.ceiling(room, point.x, point.z) + ShipSpace.INSIDE:
			return index
	return -1


## The lowest deck over [param room]'s floor over (x, z), trying every deck.
static func _roof_trying_all(space: ShipSpace, room: ShipRoom, x: float, z: float) -> int:
	var lowest := -1
	for index in space.layout.platforms.size():
		var platform := space.layout.platforms[index]
		var reach := platform.area.grow(ShipSpace.ROOF_REACH)
		if platform.height <= room.floor_height + ShipSpace.SLIVER:
			continue
		if not reach.intersects(room.area, true) or not platform.contains(x, z):
			continue
		if lowest == -1 or platform.height < space.layout.platforms[lowest].height:
			lowest = index
	return lowest


func test_every_point_stands_where_trying_every_room_says() -> void:
	var space := ShipSpace.new(load(TITANIC))
	var dice := RandomNumberGenerator.new()
	dice.seed = 2026
	var indoors := 0
	for point in 4000:
		# Over her length, breadth and decks; a fifth of them on a room's very edge.
		var at := Vector3(
			dice.randf_range(-140.0, 140.0),
			dice.randf_range(-14.0, 22.0),
			dice.randf_range(-15.0, 15.0)
		)
		if point % 5 == 0:
			var room := space.layout.rooms[dice.randi() % space.layout.rooms.size()]
			at.x = room.area.position.x if dice.randf() < 0.5 else room.area.end.x
			at.y = room.floor_height + dice.randf_range(0.0, 2.0)
		assert_eq(space.outdoors(at), _outdoors_trying_all(space, at), "outdoors at %s" % at)
		var found := RoomDressing.room_at(space, at)
		assert_eq(found, _room_trying_all(space, at), "the room at %s" % at)
		indoors += 1 if found != -1 else 0
	assert_gt(indoors, 400, "a good share of the points in her rooms")


func test_a_piece_stands_indoors_by_the_share_trying_every_room_finds() -> void:
	var space := ShipSpace.new(load(TITANIC))
	var dice := RandomNumberGenerator.new()
	dice.seed = 1912
	for piece in 1500:
		var at := Vector2(dice.randf_range(-140.0, 140.0), dice.randf_range(-15.0, 15.0))
		var area := Rect2(at, Vector2(dice.randf_range(0.05, 6.0), dice.randf_range(0.05, 3.0)))
		var height := dice.randf_range(-14.0, 22.0)
		var inside := 0.0
		for room: ShipRoom in space.layout.rooms:
			var overlap := room.area.intersection(area)
			if not overlap.has_area() or height < room.floor_height - ShipSpace.INSIDE:
				continue
			var middle := overlap.get_center()
			if height <= space.ceiling(room, middle.x, middle.y) + ShipSpace.INSIDE:
				inside += overlap.get_area()
		var share := clampf(inside / area.get_area(), 0.0, 1.0)
		assert_eq(space.indoors(area, height), share, "the share of %s at %.2f" % [area, height])


func test_a_room_is_roofed_by_the_lowest_deck_over_it() -> void:
	var space := ShipSpace.new(load(TITANIC))
	var dice := RandomNumberGenerator.new()
	dice.seed = 1514
	for room: ShipRoom in space.layout.rooms:
		for point in 12:
			var x := dice.randf_range(room.area.position.x, room.area.end.x)
			var z := dice.randf_range(room.area.position.y, room.area.end.y)
			assert_eq(
				space.roof(room, x, z),
				_roof_trying_all(space, room, x, z),
				"roof at %f %f" % [x, z]
			)
