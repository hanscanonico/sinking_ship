extends GutTest
## RoomDressing on the steamer: what each room is, what it is lit by, and art-lint's
## furnishing check — a table in the middle of a cabin stands in a body's way, a plate
## flat on its wall does not, and nothing the dressing draws does.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_space = ShipSpace.new(_layout)


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name:
			return room
	return null


## The twelve triangles of a box over [param area] from [param bottom] to [param top].
func _box(area: Rect2, bottom: float, top: float) -> PackedVector3Array:
	var mesh := BoxMesh.new()
	var size := Vector3(area.size.x, top - bottom, area.size.y)
	mesh.size = size
	var middle := Vector3(area.get_center().x, (bottom + top) * 0.5, area.get_center().y)
	var faces := PackedVector3Array()
	for corner: Vector3 in mesh.get_faces():
		faces.append(corner + middle)
	return faces


func test_each_room_of_the_steamer_is_what_its_shape_says() -> void:
	var kinds := {
		&"engine room": RoomDressing.Kind.ENGINE,
		&"forward hold": RoomDressing.Kind.HOLD,
		&"cabin corridor": RoomDressing.Kind.PASSAGE,
		&"aft port cabin": RoomDressing.Kind.STEERAGE,
		&"forward starboard cabin": RoomDressing.Kind.STEERAGE,
		&"saloon": RoomDressing.Kind.SALOON,
		&"deckhouse hall": RoomDressing.Kind.SALOON,
		&"deckhouse cabin 2": RoomDressing.Kind.CUDDY,
		&"wheelhouse": RoomDressing.Kind.HELM,
	}
	for room_name: StringName in kinds:
		assert_eq(RoomDressing.kind_of(_space, _room(room_name)), kinds[room_name], room_name)


func test_the_engine_room_is_lit_over_its_lanes_and_by_its_boilers_fires() -> void:
	var lights := RoomDressing.new(_space).lights(_room(&"engine room"))
	var pendants := 0
	var fires := 0
	for light: RoomDressing.Light in lights:
		if light.kind == ShipLamp.Kind.PENDANT:
			pendants += 1
			assert_gt(absf(light.at.z), 1.2, "a lamp hangs over a lane, clear of the engine")
		elif light.kind == ShipLamp.Kind.FIRE:
			fires += 1
			assert_almost_eq(light.facing, Vector3.LEFT, Vector3.ONE * 0.001, "into the room")
	assert_eq(pendants, 2)
	assert_eq(fires, 2)


func test_the_hold_hangs_cargo_lamps_clear_of_its_stairs() -> void:
	var lights := RoomDressing.new(_space).lights(_room(&"forward hold"))
	assert_eq(lights.size(), 2)
	for light: RoomDressing.Light in lights:
		assert_eq(light.kind, ShipLamp.Kind.CARGO)
		var spot := Rect2(Vector2(light.at.x, light.at.z), Vector2.ZERO).grow(0.6)
		assert_false(RoomDressing.over_a_ramp(_layout, spot, -2.6, light.at.y))


func test_a_passenger_room_keeps_its_one_pendant_under_its_middle() -> void:
	var saloon := _room(&"saloon")
	var lights := RoomDressing.new(_space).lights(saloon)
	assert_eq(lights.size(), 1)
	assert_eq(lights[0].kind, ShipLamp.Kind.PENDANT)
	var middle := saloon.area.get_center()
	assert_almost_eq(Vector2(lights[0].at.x, lights[0].at.z), middle, Vector2.ONE * 0.001)


func test_a_table_in_the_middle_of_a_cabin_stands_in_a_body_s_way() -> void:
	var cabin := _room(&"aft port cabin")
	var table := Rect2(cabin.area.get_center() - Vector2.ONE * 0.4, Vector2.ONE * 0.8)
	var faces := _box(table, cabin.floor_height, cabin.floor_height + 0.75)
	assert_false(FurnishingCheck.intrusions(_layout, _rules, faces).is_empty())


func test_a_plate_flat_on_a_cabin_wall_stands_in_nobody_s_way() -> void:
	var cabin := _room(&"aft port cabin")
	# The wall between it and the middle cabin, x -8.4, faces it at x -8.5.
	var plate := Rect2(-8.58, -3.0, 0.08, 1.0)
	var faces := _box(plate, cabin.floor_height + 0.4, cabin.floor_height + 1.6)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())


func test_a_shelf_over_head_height_stands_in_nobody_s_way() -> void:
	var cabin := _room(&"aft port cabin")
	var shelf := Rect2(-9.1, -3.0, 0.6, 1.0)
	var faces := _box(shelf, cabin.floor_height + 1.85, cabin.floor_height + 2.1)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())


func test_nothing_the_dressing_draws_on_the_steamer_stands_in_a_body_s_way() -> void:
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	art.free()
	assert_gt(faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())
