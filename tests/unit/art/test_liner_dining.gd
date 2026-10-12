extends GutTest
## LinerDining on the Titanic: her four dining saloons dressed by rule from their
## walls — more to them than the saloon's dressing they had, within a budget — and
## nothing the whole ship's dressing draws standing in a body's way.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

const SALOONS: Array[StringName] = [
	&"first-class dining saloon",
	&"second-class dining saloon",
	&"third-class dining saloon, aft",
	&"third-class dining saloon, forward",
]
## The most triangles one saloon's dressing may draw.
const BUDGET := 4000

var _titanic: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace
var _faces: PackedVector3Array


func before_all() -> void:
	_rules = RunMatch.default_config(1701).rules
	_titanic = load("res://data/ships/titanic.tres")
	_space = ShipSpace.new(_titanic)
	var art := ShipArt.new()
	art.build(_titanic, _rules.railing_height, _rules.body_radius)
	_faces = FurnishingCheck.furnishings(art)
	art.free()


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _titanic.rooms:
		if room.name == room_name:
			return room
	return null


## The faces [param draw] (mesh: ShipMesh) -> void draws, as triangles' corners.
func _drawn(draw: Callable) -> PackedVector3Array:
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, _space.room_lines())
	draw.call(mesh)
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	var parent := Node3D.new()
	mesh.commit(parent, materials)
	var faces := PackedVector3Array()
	for node: Node in parent.get_children():
		faces.append_array((node as MeshInstance3D).mesh.get_faces())
	parent.free()
	return faces


## How many triangles of [param faces] stand in [param room]: their middle over its
## area, between its floor and its ceiling.
func _in_room(faces: PackedVector3Array, room: ShipRoom) -> int:
	var count := 0
	for index in range(0, faces.size(), 3):
		var middle := (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
		if not room.area.grow(0.05).has_point(Vector2(middle.x, middle.z)):
			continue
		var ceiling := _space.ceiling(room, middle.x, middle.z)
		if middle.y >= room.floor_height - 0.05 and middle.y <= ceiling + 0.05:
			count += 1
	return count


func test_her_dining_saloons_are_dining_saloons() -> void:
	for room_name: StringName in SALOONS:
		var room := _room(room_name)
		assert_not_null(room, room_name)
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.DINING, room_name)
		assert_eq(LinerDining.first_class(room), room_name == SALOONS[0], room_name)


func test_nothing_her_dressing_draws_stands_in_a_body_s_way() -> void:
	assert_gt(_faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_titanic, _rules, _faces), PackedStringArray())


func test_each_saloon_has_more_to_it_than_a_saloon_s_dressing_within_a_budget() -> void:
	var cabins := CabinDressing.new(_space)
	var dining := LinerDining.new(_space, cabins)
	var none: Array[Array] = []
	for room_name: StringName in SALOONS:
		var room := _room(room_name)
		var before := _drawn(func(mesh: ShipMesh) -> void: cabins.saloon(mesh, room, none))
		var after := _drawn(func(mesh: ShipMesh) -> void: dining.build(mesh, room, none))
		assert_gt(_in_room(after, room), _in_room(before, room), room_name)
		assert_lt(after.size() / 3, BUDGET, room_name)
		# And the whole ship's dressing draws them there.
		assert_gte(_in_room(_faces, room), _in_room(after, room), room_name)


func test_the_first_class_saloon_s_pilasters_stand_a_bay_apart_a_sconce_in_each() -> void:
	var room := _room(SALOONS[0])
	var sconces := 0
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var posts := LinerDining.pilasters(wall, LinerDining.FIRST_PITCH, true)
		if posts.size() < 2:
			continue
		assert_almost_eq(posts[0], wall.from + LinerDining.PILASTER.x * 0.5, 0.001)
		assert_almost_eq(posts[-1], wall.to - LinerDining.PILASTER.x * 0.5, 0.001)
		var bays := LinerDining.bays(posts)
		# An odd number of bays, so the middle one is the sideboard's.
		assert_eq(bays.size() % 2, 1, "bays along side %d" % wall.side)
		for index in posts.size() - 1:
			var pitch := posts[index + 1] - posts[index]
			assert_between(pitch, 2.0, 4.5, "pitch along side %d" % wall.side)
		sconces += bays.size()
	# Two runs either side of a doorway at each end, a full wall along each side.
	assert_gt(sconces, 2 * int(room.area.size.x / 4.5))


func test_the_first_class_saloon_hangs_a_chandelier_for_each_pendant() -> void:
	var dining := LinerDining.new(_space, CabinDressing.new(_space))
	var room := _room(SALOONS[0])
	var lights := dining.lights(room)
	var spacing := RoomDressing.LAMP_SPACING
	var pendants := ceili(room.area.size.x / spacing) * ceili(room.area.size.y / spacing)
	assert_eq(lights.size(), pendants)
	for light: RoomDressing.Light in lights:
		assert_eq(light.kind, ShipLamp.Kind.PENDANT)
		assert_gt(light.at.y - room.floor_height, LinerDining.CLEAR_HIGH)
	for plain: StringName in SALOONS.slice(1):
		assert_eq(dining.lights(_room(plain)).size(), 0, "%s keeps the pendants" % plain)


func test_what_hangs_from_the_first_class_ceiling_hangs_over_a_head_on_a_table() -> void:
	var dining := LinerDining.new(_space, CabinDressing.new(_space))
	var room := _room(SALOONS[0])
	var none: Array[Array] = []
	var faces := _drawn(func(mesh: ShipMesh) -> void: dining.build(mesh, room, none))
	var high := 0
	for corner: Vector3 in faces:
		var over := corner.y - room.floor_height
		# Up a wall (pilasters, sconces, sideboards, the carpet) or high overhead.
		if over > RoomDressing.HEADROOM + 0.2:
			assert_gt(over, LinerDining.CLEAR_HIGH - 0.001)
			high += 1
	assert_gt(high, 0)
