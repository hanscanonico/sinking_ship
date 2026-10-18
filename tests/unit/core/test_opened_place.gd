extends GutTest
## Where a gash opens a place people can be (ShipLayout.opened_place): the part of a
## stretch of it into a cell that stands between the floor of a room in that cell and
## the cell's top — the one rule the breach's planner (GashPlanner) and the hits report
## (tools/hits.gd) both read (#148).

const TRAWLER := "res://data/ships/trawler.tres"

var _layout: ShipLayout


func before_all() -> void:
	_layout = load(TRAWLER)


func test_a_stretch_into_a_room_opens_all_of_it_over_the_floor() -> void:
	var room := _room(&"engine room")
	var cell := _cell(&"engine_room")
	var opening := _stretch(&"engine_room", room.floor_height + 1.0, 0.4)
	var span := _layout.opened_place(opening)
	assert_almost_eq(span.x, room.floor_height + 0.8, 1e-5, "from its foot")
	assert_almost_eq(span.y, room.floor_height + 1.2, 1e-5, "to its top")
	assert_true(_layout.opens_place(opening))
	assert_lt(span.y, cell.high.y, "under the cell's top")


func test_a_stretch_wholly_under_a_room_s_floor_opens_nothing() -> void:
	var room := _room(&"engine room")
	var opening := _stretch(&"engine_room", room.floor_height - 0.5, 0.4)
	assert_false(_layout.opens_place(opening), "under the floor plates: nobody is there")
	var span := _layout.opened_place(opening)
	assert_gt(span.x, span.y, "an empty span")


func test_a_stretch_across_a_room_s_floor_opens_only_its_part_over_the_floor() -> void:
	var room := _room(&"engine room")
	var opening := _stretch(&"engine_room", room.floor_height, 0.6)
	var span := _layout.opened_place(opening)
	assert_almost_eq(span.x, room.floor_height, 1e-5, "from the floor")
	assert_almost_eq(span.y, room.floor_height + 0.3, 1e-5, "to its top")


func test_a_stretch_into_a_cell_with_no_room_opens_nothing() -> void:
	var wing := _cell(&"engine_wing_s")
	assert_true(wing.rooms.is_empty(), "her wing void is nobody's room")
	var opening := _stretch(&"engine_wing_s", (wing.low.y + wing.high.y) * 0.5, 0.4)
	assert_false(_layout.opens_place(opening))


func test_a_stretch_along_a_cell_past_its_rooms_opens_nothing() -> void:
	var room := _room(&"engine room")
	var opening := _stretch(&"engine_room", room.floor_height + 1.0, 0.4)
	opening.centre.x = room.area.end.x + 2.0
	opening.size.x = 1.0
	assert_false(_layout.opens_place(opening), "along the cell, but past every room in it")


## A stretch of a gash 2 m long into [param cell_name], from the sea, standing
## [param height] tall round [param middle], ship space, along the cell's middle.
func _stretch(cell_name: StringName, middle: float, height: float) -> ShipOpening:
	var cell := _cell(cell_name)
	var room := _room(&"engine room")
	var opening := ShipOpening.new()
	opening.joins = [cell_name, ShipOpening.SEA]
	opening.centre = Vector3(room.area.get_center().x, middle, cell.high.z)
	opening.size = Vector3(2.0, height, 0.0)
	return opening


func _cell(cell_name: StringName) -> FloodCell:
	return _layout.structure.cells[_layout.structure.cell_named(cell_name)]


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name:
			return room
	return null
