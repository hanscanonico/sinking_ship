extends GutTest
## The Titanic's baths on F deck as her plate draws them: each dressed as a bath, her
## swimming bath with its pool (test_liner_bath reads LinerBath on her smaller sister).

const SWIMMING := &"swimming bath"

var _titanic: ShipLayout
var _space: ShipSpace


func before_all() -> void:
	_titanic = load("res://data/ships/titanic.tres")
	_space = ShipSpace.new(_titanic)


func test_her_swimming_bath_holds_its_pool() -> void:
	var pools := 0
	for room: ShipRoom in _titanic.rooms:
		if room.name != SWIMMING:
			continue
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.BATH)
		for box: ShipBlocker in _space.furniture(room):
			pools += 1 if LinerBath.is_pool(box) else 0
	assert_eq(pools, 1)


func test_her_turkish_baths_are_baths_and_lit() -> void:
	var dressing := RoomDressing.new(_space, INF)
	var rooms := 0
	for room: ShipRoom in _titanic.rooms:
		if not LinerBath.turkish(room) or String(room.name).contains("attendant"):
			continue
		rooms += 1
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.BATH, room.name)
		assert_gt(dressing.lights(room).size(), 0, room.name)
	assert_gt(rooms, 5, "her hot, steam, temperate, cooling and shampooing rooms and lobby")
