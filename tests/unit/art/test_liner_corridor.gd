extends GutTest
## LinerCorridor on the Titanic: her first-class corridors' stateroom doors and sconces
## stand where their spacing says, they add to what the passage dressing drew, and
## nothing the dressing draws stands in a body's way.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")
const CORRIDORS: Array[StringName] = [
	&"B deck corridor", &"C deck corridor", &"D deck corridor", &"D deck corridor, forward"
]
## The most triangles a corridor's own dressing may add.
const BUDGET := 2500

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace
var _faces: PackedVector3Array


func before_all() -> void:
	_layout = load("res://data/ships/titanic.tres")
	_rules = RunMatch.default_config(1701).rules
	_space = ShipSpace.new(_layout)
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	_faces = FurnishingCheck.furnishings(art)
	art.free()


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name:
			return room
	return null


## How many triangles of [param faces] have every corner in [param room]'s area,
## between its floor and its ceiling.
func _faces_in(room: ShipRoom, faces: PackedVector3Array) -> int:
	var count := 0
	var area := room.area.grow(0.01)
	for index in range(0, faces.size(), 3):
		var inside := true
		for corner in 3:
			var point := faces[index + corner]
			var head := _space.ceiling(room, point.x, point.z) + 0.01
			var over := point.y >= room.floor_height - 0.01 and point.y <= head
			if not area.has_point(Vector2(point.x, point.z)) or not over:
				inside = false
				break
		count += 1 if inside else 0
	return count


## The faces [param draw] puts into a mesh of its own, before it is committed.
func _drawn(draw: Callable) -> PackedVector3Array:
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, _space.room_lines())
	draw.call(mesh)
	var faces := PackedVector3Array()
	for key: String in mesh._batches:
		var batch: ShipMesh.Batch = mesh._batches[key]
		for index: int in batch.indices:
			faces.append(batch.vertices[index])
	return faces


func test_the_first_class_corridors_are_dressed_as_such() -> void:
	for room_name: StringName in CORRIDORS:
		var room := _room(room_name)
		assert_not_null(room, room_name)
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.FIRST_CORRIDOR, room_name)
	assert_eq(
		RoomDressing.kind_of(_space, _room(&"Scotland Road, boiler room 1")),
		RoomDressing.Kind.PASSAGE,
		"Scotland Road stays a working passage"
	)


func test_a_first_class_corridor_is_panelled_over_a_carpet() -> void:
	var paints := LinerCorridor.linings()
	assert_eq(paints.size(), 4, "wall, floor, overhead and beam")
	assert_eq(paints[RoomDressing.Part.WALL].colour_in, LinerCorridor.WHITE_PANEL)
	assert_eq(paints[RoomDressing.Part.FLOOR].colour_in, LinerCorridor.CARPET)
	assert_null(paints[RoomDressing.Part.OVERHEAD], "her own deckhead overhead")
	assert_null(paints[RoomDressing.Part.BEAM], "her own beams")


func test_each_corridor_draws_more_than_the_passage_dressing_alone() -> void:
	var dressing := RoomDressing.new(_space)
	var corridor := LinerCorridor.new(_space, dressing._passage)
	for room_name: StringName in CORRIDORS:
		var room := _room(room_name)
		var glass: Array[Array] = []
		var passage := _faces_in(
			room, _drawn(func(mesh: ShipMesh) -> void: dressing._passage(mesh, room))
		)
		var own := _faces_in(
			room, _drawn(func(mesh: ShipMesh) -> void: corridor.build(mesh, room, glass))
		)
		assert_gt(own, passage, room_name)
		# Its own doors and sconces stay within a corridor's budget of triangles.
		assert_lt(own - passage, BUDGET, room_name)
		gut.p(
			"%s: %d triangles over the passage dressing's %d" % [room_name, own - passage, passage]
		)
		assert_gt(_faces_in(room, _faces), passage, room_name)


func test_stateroom_doors_stand_every_three_metres_on_both_long_walls() -> void:
	var room := _room(&"C deck corridor")
	var sides := {}
	var total := 0
	for wall: RoomDressing.Wall in LinerCorridor.long_walls(_space, room):
		var doors := LinerCorridor.doors(_layout, wall)
		for index in doors.size():
			var along := doors[index]
			assert_true(along - LinerCorridor.DOOR.x * 0.5 >= wall.from, "a door on its wall")
			assert_true(along + LinerCorridor.DOOR.x * 0.5 <= wall.to, "a door on its wall")
			var steps := along - wall.from - LinerCorridor.DOOR_SPACING * 0.5
			var spacing := LinerCorridor.DOOR_SPACING
			assert_almost_eq(steps - roundf(steps / spacing) * spacing, 0.0, 0.001)
		for along: float in LinerCorridor.sconces(_layout, wall):
			for door: float in doors:
				assert_gt(absf(along - door), LinerCorridor.DOOR.x * 0.5, "a sconce between doors")
		total += doors.size()
		if not doors.is_empty():
			sides[wall.side] = true
	assert_eq(sides.size(), 2, "doors down both long walls")
	# 114.8 m of corridor, less its doorways: well over a door a wall every 3 m of half.
	assert_gt(total, 40)


func test_nothing_on_the_titanic_stands_in_a_body_s_way() -> void:
	assert_gt(_faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, _faces), PackedStringArray())
