extends GutTest

const STEAMER := "res://data/ships/steamer.tres"

var _space: ShipSpace


func before_each() -> void:
	_space = ShipSpace.new(load(STEAMER))


func _room(name: StringName) -> ShipRoom:
	for room: ShipRoom in _space.layout.rooms:
		if room.name == name:
			return room
	return null


func test_a_point_inside_a_room_under_its_deck_is_indoors() -> void:
	var engine := _room(&"engine room")
	var middle := engine.area.get_center()
	assert_false(_space.outdoors(Vector3(middle.x, engine.floor_height + 1.0, middle.y)))


func test_a_point_on_the_open_deck_over_a_room_is_outdoors() -> void:
	var engine := _room(&"engine room")
	assert_true(_space.outdoors(Vector3(engine.area.end.x - 0.5, 0.5, 0.0)))


func test_a_piece_crossing_into_a_room_is_indoors_by_the_share_inside() -> void:
	var saloon := _room(&"saloon")
	var at := saloon.floor_height + 0.5
	var edge := saloon.area.end.x
	var square := Rect2(edge - 0.5, -0.5, 1.0, 1.0)
	assert_false(_space.outdoors(Vector3(edge - 0.25, at, 0.0)), "the saloon")
	assert_true(_space.outdoors(Vector3(edge + 0.25, at, 0.0)), "the open deck beside it")
	assert_almost_eq(_space.indoors(square, at), 0.5, 0.001, "half across its side")
	assert_eq(_space.indoors(Rect2(edge - 1.5, -0.5, 1.0, 1.0), at), 1.0, "wholly in")
	assert_eq(_space.indoors(Rect2(edge + 0.5, -0.5, 1.0, 1.0), at), 0.0, "wholly out")
	assert_eq(_space.indoors(square, saloon.floor_height + 4.0), 0.0, "over its roof")


func test_a_room_s_ceiling_is_the_lowest_deck_over_it() -> void:
	var hold := _room(&"forward hold")
	assert_almost_eq(_space.ceiling(hold, 6.0, -2.0), 0.0, 0.001)
	assert_almost_eq(_space.ceiling(hold, 14.0, -2.0), 1.8, 0.001)


func test_a_doorway_is_a_gap_between_wall_runs() -> void:
	var engine := _room(&"engine room")
	var aft: Array = []
	for run: Array in _space.wall_runs(engine):
		if run[0] == 3:
			aft.append(run)
	assert_eq(aft.size(), 2, "the aft bulkhead in two pieces round its doorway")
	assert_almost_eq(aft[1][1] - aft[0][2], 1.1, 0.01, "a 1.1 m doorway")
