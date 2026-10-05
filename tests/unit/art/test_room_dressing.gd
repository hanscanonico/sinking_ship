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


## The binnacle's two spheres on the wheelhouse's forward wall, as (along, height over
## the floor, radius): from the dark discs the dressed ship draws in front of it.
func _spheres(art: ShipArt, wall: RoomDressing.Wall) -> Array[Vector3]:
	var points := PackedVector3Array()
	for child: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		if not mesh is ArrayMesh:
			continue
		var arrays := mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_COLOR] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for index in vertices.size():
			var point := vertices[index]
			var out := (point - wall.at(0.0, 0.0)).dot(wall.normal)
			var along := point.dot(wall.right)
			var high := point.y - wall.floor
			if not colours[index].is_equal_approx(ArtPalette.FUNNEL_TOP):
				continue
			if out > 0.0 and out < 0.15 and along > wall.from and along < wall.to and high < 2.0:
				points.append(Vector3(along, high, 0.0))
	var alongs: Array[float] = []
	for point: Vector3 in points:
		alongs.append(point.x)
	alongs.sort()
	var split := 0.0
	var widest := 0.0
	for index in alongs.size() - 1:
		if alongs[index + 1] - alongs[index] > widest:
			widest = alongs[index + 1] - alongs[index]
			split = (alongs[index] + alongs[index + 1]) * 0.5
	var found: Array[Vector3] = []
	for left: bool in [true, false]:
		var box := Rect2()
		var first := true
		for point: Vector3 in points:
			if (point.x < split) == left:
				box = (
					Rect2(point.x, point.y, 0.0, 0.0)
					if first
					else box.expand(Vector2(point.x, point.y))
				)
				first = false
		found.append(Vector3(box.get_center().x, box.get_center().y, box.size.x * 0.5))
	return found


## Whether a disc at [param centre] of [param radius] keeps [param gap] clear of the
## segment [param a]…[param b].
func _clear_of(centre: Vector2, radius: float, a: Vector2, b: Vector2, gap: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(centre, a, b).distance_to(centre) > radius + gap


func test_the_binnacle_s_spheres_stand_clear_of_rail_windows_and_wheel() -> void:
	var room := _room(&"wheelhouse")
	var wall: RoomDressing.Wall = null
	for each: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if each.side == 1:
			wall = each
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	var spheres := _spheres(art, wall)
	art.free()
	var fittings := ShipFittings.new(_space, ShipHull.new(_space, _rules.railing_height), 0.3)
	fittings.build(ShipMesh.new(_space.outdoors, _space.room_lines()))
	# The cabin finish's dado rail (ship.gdshaderinc), 0.95 m up and 0.07 deep; the wheel
	# (RoomDressing.wheel) round its hub 1 m up, handles 0.09 past a 0.32 rim, 0.022 thick.
	var rail := Vector2(0.915, 0.985)
	var hub := Vector2(wall.middle(), 1.0)
	for sphere: Vector3 in spheres:
		var centre := Vector2(sphere.x, sphere.y)
		var radius := sphere.z
		assert_almost_eq(radius, 0.05, 0.02, "a sphere, not stray dark faces")
		var low := centre.y - radius
		var high := centre.y + radius
		assert_true(low > rail.y or high < rail.x, "clear of the dado rail: %s" % centre)
		for pane: Array in fittings.panes:
			if pane[0] != room or not (pane[2] as Vector3).is_equal_approx(wall.normal):
				continue
			var half: Vector2 = pane[4] + Vector2.ONE * (ShipFittings.WINDOW_FRAME + 0.05)
			var middle := Vector2((pane[1] as Vector3).dot(wall.right), pane[1].y - wall.floor)
			# Its surround, and the sill under it.
			var surround := Rect2(middle - half, half * 2.0).grow_individual(0.0, 0.05, 0.0, 0.0)
			var near := Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			assert_false(surround.intersects(near), "clear of the window at %s" % middle)
		var from_hub := centre.distance_to(hub)
		assert_true(
			from_hub + radius < 0.32 - 0.033 or from_hub - radius > 0.32 + 0.011,
			"clear of the wheel's rim: %s" % centre
		)
		for spoke in 8:
			var out := Vector2(cos(PI * spoke / 8), sin(PI * spoke / 8)) * 0.41
			assert_true(_clear_of(centre, radius, hub - out, hub + out, 0.011), "of a handle")
	assert_eq(spheres.size(), 2, "two spheres")
