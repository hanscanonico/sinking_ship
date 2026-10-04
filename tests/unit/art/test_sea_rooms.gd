extends GutTest

const STEAMER := "res://data/ships/steamer.tres"

var _layout: ShipLayout
var _space: ShipSpace
var _map: Image
var _bounds: Rect2


func before_all() -> void:
	_layout = load(STEAMER)
	_space = ShipSpace.new(_layout)
	_map = SeaAndSky.room_map(_layout)
	_bounds = SeaAndSky.room_bounds(_layout)


## Whether the sea's shader, reading the map, takes ship point [param point] for a
## room's.
func _in_a_room(point: Vector3) -> bool:
	var uv := (Vector2(point.x, point.z) - _bounds.position) / _bounds.size
	var cell := Vector2i((uv * Vector2(_map.get_size())).floor())
	var span := _map.get_pixelv(cell.clamp(Vector2i.ZERO, _map.get_size() - Vector2i.ONE))
	return point.y > span.r and point.y < span.g


func test_the_map_covers_whole_cells_with_nothing_round_its_edge() -> void:
	assert_eq(Vector2(_map.get_size()) * SeaAndSky.ROOM_CELL, _bounds.size)
	for column in _map.get_width():
		assert_eq(_map.get_pixel(column, 0), Color(0.0, 0.0, 0.0, 1.0))
		assert_eq(_map.get_pixel(column, _map.get_height() - 1), Color(0.0, 0.0, 0.0, 1.0))


func test_the_map_says_what_ship_space_says_of_every_cell_s_middle() -> void:
	var disagree: Array[Vector3] = []
	for row in _map.get_height():
		for column in _map.get_width():
			var at := (
				_bounds.position + (Vector2(column, row) + Vector2(0.5, 0.5)) * SeaAndSky.ROOM_CELL
			)
			for step in range(-40, 60):
				var point := Vector3(at.x, step * 0.25 + 0.1, at.y)
				if _in_a_room(point) == _space.outdoors(point):
					disagree.append(point)
	assert_eq(disagree.size(), 0, "first: %s" % [disagree.slice(0, 5)])
