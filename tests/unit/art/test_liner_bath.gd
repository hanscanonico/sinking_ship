extends GutTest
## LinerBath on the Titanic: her Turkish bath tiled and lit in bronze, her swimming
## bath's pool drawn inside its box — its top within art-lint's reach all over, the
## water too — more to each than the saloon's dressing they had. That nothing the
## whole ship's dressing draws stands in a body's way is test_dressing_clear's.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

const TURKISH := &"Turkish bath"
const SWIMMING := &"swimming bath"
## How near the pool's top art-lint wants a face over each point it probes (its
## BLOCKER_TOLERANCE), and its grid of those points (SAMPLES_ALONG by SAMPLES_ACROSS,
## SAMPLE_INSET * 0.5 in from the box's sides).
const TOP_TOLERANCE := 0.05
const SAMPLES := Vector2i(6, 3)
const SAMPLE_IN := 0.05
## The most faces a bath may stand in all, its modelled lanterns and ladder too: the
## Turkish bath, the worst, draws 1120.
const CEILING := 1200

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


## The swimming bath's pool: the one box on its floor.
func _pool() -> ShipBlocker:
	var boxes := _space.furniture(_room(SWIMMING))
	assert_eq(boxes.size(), 1)
	return boxes[0]


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
## area, between its floor and its ceiling — under it, for what stands on it is the
## room's over it (the reception room's chairs, over the Turkish bath).
func _in_room(faces: PackedVector3Array, room: ShipRoom) -> int:
	var count := 0
	for index in range(0, faces.size(), 3):
		var middle := (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
		if not room.area.grow(0.05).has_point(Vector2(middle.x, middle.z)):
			continue
		var ceiling := _space.ceiling(room, middle.x, middle.z)
		if middle.y >= room.floor_height - 0.05 and middle.y < ceiling:
			count += 1
	return count


## How many triangles of [param faces] stand wholly inside [param box].
func _in_box(faces: PackedVector3Array, box: ShipBlocker) -> int:
	var area := box.area.grow(0.002)
	var count := 0
	for index in range(0, faces.size(), 3):
		var inside := true
		for corner: Vector3 in faces.slice(index, index + 3):
			if (
				not area.has_point(Vector2(corner.x, corner.z))
				or corner.y < box.bottom - 0.002
				or corner.y > box.top + 0.002
			):
				inside = false
		if inside:
			count += 1
	return count


func test_her_baths_are_baths() -> void:
	for room_name: StringName in [TURKISH, SWIMMING]:
		var room := _room(room_name)
		assert_not_null(room, room_name)
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.BATH, room_name)
		assert_eq(LinerBath.turkish(room), room_name == TURKISH, room_name)


func test_each_bath_has_more_to_it_than_a_saloon_s_dressing() -> void:
	var cabins := CabinDressing.new(_space)
	var bath := LinerBath.new(_space, cabins)
	var none: Array[Array] = []
	for room_name: StringName in [TURKISH, SWIMMING]:
		var room := _room(room_name)
		var before := _drawn(func(mesh: ShipMesh) -> void: cabins.saloon(mesh, room, none))
		var after := _drawn(func(mesh: ShipMesh) -> void: bath.build(mesh, room, none))
		assert_gt(_in_room(after, room), _in_room(before, room), room_name)
		assert_gte(_in_room(_faces, room), _in_room(after, room), room_name)


func test_each_bath_stands_within_its_ceiling() -> void:
	for room_name: StringName in [TURKISH, SWIMMING]:
		assert_lt(_in_room(_faces, _room(room_name)), CEILING, room_name)


func test_the_pool_is_drawn_inside_its_box() -> void:
	var pool := _pool()
	assert_true(LinerBath.is_pool(pool))
	assert_gt(_in_box(_faces, pool), 0)
	var drawn := _drawn(
		func(mesh: ShipMesh) -> void: LinerBath.pool(mesh, pool.area, pool.bottom, pool.top)
	)
	# The whole ship draws in its box what pool() draws and nothing else: no
	# FurnitureDressing case over it (RoomDressing.build() routes a bath's boxes here).
	assert_eq(_in_box(_faces, pool), _in_box(drawn, pool), "drawn by LinerBath alone")
	# Nothing it draws but the ladder's handles over the rim stands out of its box.
	var high := pool.top + LinerBath.HANDLE + LinerBath.HANDLE_BAR
	for corner: Vector3 in drawn:
		assert_true(pool.area.grow(0.002).has_point(Vector2(corner.x, corner.z)), str(corner))
		assert_between(corner.y, pool.bottom - 0.002, high, str(corner))
	assert_lt(high, pool.top + _rules.step_height, "a body on the rim steps over them")


func test_the_pool_s_top_is_drawn_where_art_lint_probes_it_the_water_too() -> void:
	var pool := _pool()
	var drawn := _drawn(
		func(mesh: ShipMesh) -> void: LinerBath.pool(mesh, pool.area, pool.bottom, pool.top)
	)
	var inner := pool.area.grow(-SAMPLE_IN)
	var over_water := 0
	for i in SAMPLES.x:
		for j in SAMPLES.y:
			var share := Vector2(float(i) / (SAMPLES.x - 1), float(j) / (SAMPLES.y - 1))
			var at := inner.position + inner.size * share
			var from := Vector3(at.x, pool.top + 0.01, at.y)
			var nearest := INF
			for index in range(0, drawn.size(), 3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(
					from, Vector3.DOWN, drawn[index], drawn[index + 1], drawn[index + 2]
				)
				if hit != null:
					nearest = minf(nearest, pool.top - (hit as Vector3).y)
			assert_lte(nearest, TOP_TOLERANCE, "over %s" % at)
			if pool.area.grow(-LinerBath.RIM).has_point(at):
				over_water += 1
	assert_gt(over_water, 0, "some probes fall on the water")


func test_a_bath_lines_its_walls_and_floor_in_tile() -> void:
	var paints := RoomDressing._linings(RoomDressing.Kind.BATH)
	assert_eq(paints.size(), RoomDressing.Part.size())
	assert_eq(paints[RoomDressing.Part.WALL].colour_in, LinerBath.TILE)
	assert_eq(paints[RoomDressing.Part.FLOOR].colour_in, LinerBath.FLOOR_TILE)
	assert_null(paints[RoomDressing.Part.OVERHEAD])


func test_the_turkish_bath_is_tiled_to_its_dado_round_its_walls() -> void:
	var room := _room(TURKISH)
	var bath := LinerBath.new(_space, CabinDressing.new(_space))
	var none: Array[Array] = []
	var drawn := _drawn(func(mesh: ShipMesh) -> void: bath.build(mesh, room, none))
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var tiled := 0
		for index in range(0, drawn.size(), 3):
			var middle := (drawn[index] + drawn[index + 1] + drawn[index + 2]) / 3.0
			var out := (middle - wall.at(0.0, 0.0)).dot(wall.normal)
			var along := middle.dot(wall.right)
			var on_it := out > 0.0 and out < 0.02 and along > wall.from and along < wall.to
			if on_it and middle.y - wall.floor < LinerBath.DADO:
				tiled += 1
		# A border and a field in each bay, two triangles each.
		var bays := ceili(wall.length() / LinerBath.BAY)
		assert_gte(tiled, bays * 4, "side %d" % wall.side)


func test_the_turkish_bath_hangs_a_lantern_for_each_pendant() -> void:
	var bath := LinerBath.new(_space, CabinDressing.new(_space))
	var room := _room(TURKISH)
	var spacing := RoomDressing.LAMP_SPACING
	var pendants := ceili(room.area.size.x / spacing) * ceili(room.area.size.y / spacing)
	var lights := bath.lights(room)
	assert_eq(lights.size(), pendants)
	for light: RoomDressing.Light in lights:
		assert_eq(light.kind, ShipLamp.Kind.PENDANT)
		assert_true(room.area.has_point(Vector2(light.at.x, light.at.z)))
	assert_eq(bath.lights(_room(SWIMMING)).size(), 0, "the swimming bath keeps its pendants")
