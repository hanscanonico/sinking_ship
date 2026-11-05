extends GutTest
## Handrail on the steamer: a corridor wall's rail turns only where a stair beside it,
## on its deck, begins and ends — never at a stair elsewhere on the ship (#431).

const RunMatch := preload("res://tools/run_match.gd")

var _layout: ShipLayout
var _space: ShipSpace


func before_all() -> void:
	_layout = RunMatch.default_config(1701).ship
	_space = ShipSpace.new(_layout)


## The cabin corridor's wall on its side 0 that begins at [param from] along it.
func _wall(from: float) -> RoomDressing.Wall:
	for room: ShipRoom in _layout.rooms:
		if room.name != &"cabin corridor":
			continue
		for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
			if wall.side == 0 and is_equal_approx(wall.from, from):
				return wall
	return null


## A stair over [param area] climbing [param rise] along x from [param base].
func _stair(area: Rect2, base: float, rise: float) -> ShipRamp:
	var stair := ShipRamp.new()
	stair.area = area
	stair.axis = ShipRamp.Axis.X
	stair.start_height = base
	stair.end_height = base + rise
	return stair


func test_a_wall_with_no_stair_beside_it_keeps_only_its_two_end_stops() -> void:
	# The stairs whose spans fall along it stand elsewhere on the ship.
	var wall := _wall(-6.5)
	assert_not_null(wall)
	var stops := Handrail.stops(_layout, wall)
	assert_eq(stops, PackedFloat32Array([wall.from + 0.1, wall.to - 0.1]))


func test_a_stair_beside_a_wall_on_its_deck_keeps_its_stops() -> void:
	var wall := _wall(-6.5)
	var layout := ShipLayout.new()
	var beside := _stair(wall.rect(-6.1, -5.3, 0.0, 1.0), wall.floor, 1.0)
	var overhead := _stair(wall.rect(-6.3, -5.2, 0.0, 1.0), wall.floor + 2.6, 2.6)
	var across := _stair(wall.rect(-6.4, -5.1, 3.0, 4.0), wall.floor, 1.0)
	layout.ramps.assign([beside, overhead, across])
	var stops := Handrail.stops(layout, wall)
	# Where it begins, and where it ends a metre up in a step, and the floor just past.
	var want := [wall.from + 0.1, -6.1, -5.3, -5.3 + Handrail.DROP, wall.to - 0.1]
	assert_eq(stops.size(), want.size(), str(stops))
	for index in mini(stops.size(), want.size()):
		assert_almost_eq(stops[index], want[index], 0.001)
