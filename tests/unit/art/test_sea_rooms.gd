extends GutTest

const STEAMER := "res://data/ships/steamer.tres"
## How near a wall, in metres, no pixel of the wall's foot tells which side it is.
const NEAR := 0.03

var _layout: ShipLayout
var _space: ShipSpace
var _map: Image
var _edges: Image
var _bounds: Rect2


func before_all() -> void:
	_layout = load(STEAMER)
	_space = ShipSpace.new(_layout)
	_map = SeaAndSky.room_map(_layout)
	_edges = SeaAndSky.room_edges(_layout)
	_bounds = SeaAndSky.room_bounds(_layout)


## Whether the sea's shader, reading the maps, takes ship point [param point] for a
## room's: the span of its cell, and the edges read between the cells' middles.
func _in_a_room(point: Vector3) -> bool:
	var uv := (Vector2(point.x, point.z) - _bounds.position) / _bounds.size
	var cell := Vector2i((uv * Vector2(_map.get_size())).floor())
	var span := _map.get_pixelv(cell.clamp(Vector2i.ZERO, _map.get_size() - Vector2i.ONE))
	return _between(uv) > 0.0 and point.y > span.r and point.y < span.g


## The edges' map at [param uv], read between texels as a linear filter does, its
## edges clamped.
func _between(uv: Vector2) -> float:
	var texel := uv * Vector2(_edges.get_size()) - Vector2(0.5, 0.5)
	var low := texel.floor()
	var part := texel - low
	var last := _edges.get_size() - Vector2i.ONE
	var read := func(dx: int, dy: int) -> float:
		return _edges.get_pixelv((Vector2i(low) + Vector2i(dx, dy)).clamp(Vector2i.ZERO, last)).r
	var top := lerpf(read.call(0, 0), read.call(1, 0), part.x)
	var bottom := lerpf(read.call(0, 1), read.call(1, 1), part.x)
	return lerpf(top, bottom, part.y)


func test_the_map_covers_whole_cells_with_nothing_round_its_edge() -> void:
	assert_eq(Vector2(_map.get_size()) * SeaAndSky.ROOM_CELL, _bounds.size)
	for column in _map.get_width():
		assert_eq(_map.get_pixel(column, 0), Color(0.0, 0.0, 0.0, 1.0))
		assert_eq(_map.get_pixel(column, _map.get_height() - 1), Color(0.0, 0.0, 0.0, 1.0))


## Every 0.1 m over the maps, at every height: water in a room never takes the sky
## (the maps say a room wherever ShipSpace does), and the sea well clear of every
## room — by the hull too — always does. Within a few centimetres of a wall no pixel
## of a wall's foot shows which; the open by a room's wall may go without the sky for
## up to SeaAndSky.EDGE_GRACE, and twice that in the crook of two rooms' walls; and
## over a room's walls the open may be taken for a room by up to a cell: there it is
## the deck by a deckhouse's wall.
func test_the_maps_keep_the_sky_off_every_room_and_on_the_open_sea() -> void:
	var in_the_open: Array[Vector3] = []
	var over_the_sea: Array[Vector3] = []
	for x in range(0, int(_bounds.size.x / 0.1)):
		for z in range(0, int(_bounds.size.y / 0.1)):
			var at := _bounds.position + Vector2(x, z) * 0.1 + Vector2(0.031, 0.047)
			var inside := -INF
			var reach := -INF
			for room: ShipRoom in _layout.rooms:
				inside = maxf(inside, SeaAndSky._inside(room.area, at))
				reach = maxf(reach, SeaAndSky._inside(room.area.grow(SeaAndSky.ROOM_CELL), at))
			for step in range(-40, 60):
				var point := Vector3(at.x, step * 0.25 + 0.1, at.y)
				var room := _in_a_room(point)
				if inside > NEAR and not room and not _space.outdoors(point):
					in_the_open.append(point)
				if inside < -SeaAndSky.EDGE_GRACE * 2.0 and room:
					over_the_sea.append(point)
				if reach < 0.0 and room:
					over_the_sea.append(point)
	assert_eq(in_the_open.size(), 0, "sky in a room: %s" % [in_the_open.slice(0, 5)])
	assert_eq(over_the_sea.size(), 0, "no sky outside: %s" % [over_the_sea.slice(0, 5)])
