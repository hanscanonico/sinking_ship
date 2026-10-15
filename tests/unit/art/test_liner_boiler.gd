extends GutTest
## LinerBoiler and EngineRoom's lamps: the steamer's stokehold and the trawler's
## engine room lit where they always were; the Titanic's boiler rooms 2–5 drawn as
## boiler rooms by LinerBoiler alone — boilers in the boxes, their fronts and fires on
## the boxes' ends, a coal face on the bunker's — lit over their firing aisles, no lamp
## hung inside a boiler, and nothing the whole ship's dressing draws in a body's way.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

const BOILER_ROOMS: Array[StringName] = [
	&"boiler room 2", &"boiler room 3", &"boiler room 4", &"boiler room 5"
]
## How far in plan a pendant hangs from a boiler, at least (EngineRoom.LAMP_CLEAR).
const CLEAR := 0.3

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


## [param ship_name]'s room [param room_name] and the lights RoomDressing hangs in it.
func _lights(ship_name: String, room_name: StringName) -> Array[RoomDressing.Light]:
	var layout: ShipLayout = load("res://data/ships/%s.tres" % ship_name)
	var space := ShipSpace.new(layout)
	for room: ShipRoom in layout.rooms:
		if room.name == room_name:
			return RoomDressing.new(space).lights(room)
	var none: Array[RoomDressing.Light] = []
	return none


## [param lights] are [param pinned], each [kind, where], in order.
func _assert_lit(lights: Array[RoomDressing.Light], pinned: Array[Array], what: String) -> void:
	assert_eq(lights.size(), pinned.size(), what)
	for index in mini(lights.size(), pinned.size()):
		assert_eq(lights[index].kind, pinned[index][0], "%s %d" % [what, index])
		var off := lights[index].at.distance_to(pinned[index][1] as Vector3)
		assert_lt(off, 0.001, "%s %d at %s" % [what, index, lights[index].at])


func test_the_steamer_s_stokehold_is_lit_where_it_was() -> void:
	var pinned: Array[Array] = [
		[ShipLamp.Kind.PENDANT, Vector3(1.875, -0.06, -2.15)],
		[ShipLamp.Kind.PENDANT, Vector3(1.875, -0.06, 2.15)],
		[ShipLamp.Kind.FIRE, Vector3(3.9, -3.78, -1.85)],
		[ShipLamp.Kind.FIRE, Vector3(3.9, -3.78, 1.85)],
	]
	_assert_lit(_lights("steamer", &"stokehold"), pinned, "stokehold")


func test_the_trawler_s_engine_room_is_lit_where_it_was() -> void:
	var pinned: Array[Array] = [
		[ShipLamp.Kind.PENDANT, Vector3(-10.25, -0.06, 0.0)],
		[ShipLamp.Kind.PENDANT, Vector3(-5.4, -0.06, 0.0)],
		[ShipLamp.Kind.FIRE, Vector3(-3.1, -1.58, -1.625)],
		[ShipLamp.Kind.FIRE, Vector3(-3.1, -1.58, 1.625)],
	]
	_assert_lit(_lights("trawler", &"engine room"), pinned, "engine room")


func test_her_boiler_rooms_hang_their_pendants_clear_of_the_boilers() -> void:
	var dressing := RoomDressing.new(_space)
	for room_name: StringName in BOILER_ROOMS:
		var room := _room(room_name)
		var machines := _space.machinery(room)
		assert_gt(machines.size(), 1, room_name)
		var pendants := 0
		for light: RoomDressing.Light in dressing.lights(room):
			if light.kind != ShipLamp.Kind.PENDANT:
				continue
			pendants += 1
			var at := Vector2(light.at.x, light.at.z)
			assert_true(room.area.has_point(at), "%s %s" % [room_name, light.at])
			for machine: ShipBlocker in machines:
				assert_false(machine.area.grow(CLEAR).has_point(at), "%s %s" % [room_name, at])
			var ceiling := _space.ceiling(room, at.x, at.y)
			assert_lte(light.at.y, ceiling, "%s %s" % [room_name, light.at])
			assert_gt(light.at.y, room.floor_height + RoomDressing.HEADROOM, room_name)
		assert_between(pendants, 1, EngineRoom.LAMPS, room_name)


func test_nothing_her_dressing_draws_stands_in_a_body_s_way() -> void:
	assert_gt(_faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_titanic, _rules, _faces), PackedStringArray())


func test_her_boilers_burn_on_their_ends_and_none_on_a_bunker() -> void:
	var dressing := RoomDressing.new(_space)
	for room_name: StringName in BOILER_ROOMS:
		var room := _room(room_name)
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.BOILER, room_name)
		var machines := _space.machinery(room)
		var fires := 0
		for light: RoomDressing.Light in dressing.lights(room):
			if light.kind != ShipLamp.Kind.FIRE:
				continue
			fires += 1
			assert_gt(absf(light.at.x - room.area.end.x), 0.5, "on the bunker: %s" % light.at)
			var on_an_end := false
			for box: ShipBlocker in machines:
				var end := box.area.end.x if light.facing.x > 0.0 else box.area.position.x
				var across := light.at.z > box.area.position.y and light.at.z < box.area.end.y
				if is_equal_approx(light.at.x, end) and across:
					on_an_end = true
			assert_true(on_an_end, "%s fire %s" % [room_name, light.at])
			assert_almost_eq(light.at.y, room.floor_height + EngineRoom.FURNACE_HEIGHT, 0.001)
		# Two fronts on each end of every boiler: each opens on a firing aisle.
		assert_eq(fires, machines.size() * 2 * LinerBoiler.FRONTS, room_name)


func test_her_boiler_rooms_are_drawn_by_liner_boiler_alone() -> void:
	var engine := EngineRoom.new(_space)
	var boiler := LinerBoiler.new(engine)
	var none: Array[Array] = []
	for room_name: StringName in BOILER_ROOMS:
		var room := _room(room_name)
		var drawn := _drawn(func(mesh: ShipMesh) -> void: boiler.build(mesh, room, none))
		var engines := _drawn(func(mesh: ShipMesh) -> void: engine.build(mesh, room))
		for box: ShipBlocker in _space.machinery(room):
			# The whole ship draws in each box what LinerBoiler draws, no engine.
			assert_gt(_in_box(drawn, box), 0, room_name)
			assert_eq(_in_box(_faces, box), _in_box(drawn, box), "%s by LinerBoiler" % room_name)
			assert_ne(_in_box(drawn, box), _in_box(engines, box), "%s no engine" % room_name)
