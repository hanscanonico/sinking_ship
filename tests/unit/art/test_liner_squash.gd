extends GutTest
## LinerSquash on the Titanic: her squash court lined in white plaster over maple, its
## red lines painted flat on its walls at a court's heights, the gallery's front faced
## over head height. That nothing the whole ship's dressing draws stands in a body's
## way is art-lint's (FurnishingCheck), on every ship.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

const COURT := &"squash court"
const GALLERY := &"squash court gallery"
## Where the gallery's front stands over the court (gen_titanic.py GALLERY_FWD), and
## the court's front wall's face, its wall's half thickness aft of the hall's end.
const GALLERY_FRONT := 89.5
const FRONT_FACE := 101.4

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


func _squash() -> LinerSquash:
	return LinerSquash.new(_space, CabinDressing.new(_space))


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


## The court's front wall.
func _front() -> RoomDressing.Wall:
	return _squash().front_wall(RoomDressing.walls(_space, _room(COURT)))


## How many triangles of [param faces] lie flat on [param wall], no more than
## LinerSquash.LINE_OUT proud of it, their middle between [param low] and
## [param high] over its floor.
func _on_wall(faces: PackedVector3Array, wall: RoomDressing.Wall, low: float, high: float) -> int:
	var count := 0
	for index in range(0, faces.size(), 3):
		var middle := (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
		var out := (middle - wall.at(0.0, 0.0)).dot(wall.normal)
		var along := middle.dot(wall.right)
		var over := middle.y - wall.floor
		if (
			out > 0.0
			and out <= LinerSquash.LINE_OUT + 0.001
			and along > wall.from
			and along < wall.to
			and over > low
			and over < high
		):
			count += 1
	return count


func test_the_court_and_its_gallery_are_a_squash_court() -> void:
	for room_name: StringName in [COURT, GALLERY]:
		var room := _room(room_name)
		assert_not_null(room, room_name)
		assert_eq(RoomDressing.kind_of(_space, room), RoomDressing.Kind.SQUASH, room_name)
		assert_eq(LinerSquash.gallery(room), room_name == GALLERY, room_name)


func test_the_court_and_its_gallery_are_lined_in_plaster_over_maple() -> void:
	var paints := RoomDressing._linings(RoomDressing.Kind.SQUASH)
	assert_eq(paints.size(), RoomDressing.Part.size())
	assert_eq(paints[RoomDressing.Part.WALL].colour_in, LinerSquash.PLASTER)
	assert_eq(paints[RoomDressing.Part.FLOOR].colour_in, LinerSquash.MAPLE)
	assert_null(paints[RoomDressing.Part.OVERHEAD])
	var dressing := RoomDressing.new(_space)
	for room_name: StringName in [COURT, GALLERY]:
		var room := _room(room_name)
		var middle := room.area.get_center()
		var at := Vector3(middle.x, room.floor_height + 1.0, middle.y)
		var lining := dressing.lining(at, RoomDressing.Part.FLOOR)
		assert_not_null(lining, room_name)
		if lining != null:
			assert_eq(lining.colour_in, LinerSquash.MAPLE, room_name)


func test_the_front_wall_is_the_forward_one_and_play_runs_back_to_the_gallery() -> void:
	var front := _front()
	assert_not_null(front)
	assert_almost_eq(front.at(front.middle(), 0.0).x, FRONT_FACE, 0.01)
	var play := _squash().play_depth(_room(COURT), front)
	assert_almost_eq(FRONT_FACE - play, GALLERY_FRONT, 0.01)


## Fails if the whole ship's dressing bypasses LinerSquash: only it paints the court's
## lines across the front wall.
func test_the_whole_ship_paints_the_lines_across_the_court_s_front_wall() -> void:
	var front := _front()
	var bays := ceili(front.length() / LinerSquash.BAY)
	for top: float in [LinerSquash.TIN, LinerSquash.SERVICE, LinerSquash.FRONT_OUT]:
		var on := _on_wall(_faces, front, top - LinerSquash.LINE, top)
		# A quad in each bay, two triangles each.
		assert_gte(on, bays * 2, "the line at %.2f" % top)


func test_the_side_walls_out_line_falls_from_the_front_wall_s_to_the_back_wall_s() -> void:
	var court := _room(COURT)
	var squash := _squash()
	var none: Array[Array] = []
	var drawn := _drawn(func(mesh: ShipMesh) -> void: squash.build(mesh, court, none))
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, court):
		if wall.side % 2 == 1:
			continue
		var highest := -INF
		var lowest := INF
		for index in drawn.size():
			var corner := drawn[index]
			var out := (corner - wall.at(0.0, 0.0)).dot(wall.normal)
			if absf(out - LinerSquash.LINE_OUT) > 0.001:
				continue
			var over := corner.y - wall.floor
			if corner.x > FRONT_FACE - 0.01:
				highest = maxf(highest, over)
			if corner.x < GALLERY_FRONT - 0.5:
				lowest = minf(lowest, over)
		assert_almost_eq(highest, LinerSquash.FRONT_OUT, 0.001, "side %d" % wall.side)
		assert_almost_eq(lowest, LinerSquash.BACK_OUT - LinerSquash.LINE, 0.001)


func test_nothing_it_draws_stands_off_a_wall_under_head_height() -> void:
	var court := _room(COURT)
	var squash := _squash()
	var none: Array[Array] = []
	var drawn := _drawn(func(mesh: ShipMesh) -> void: squash.build(mesh, court, none))
	assert_gt(drawn.size(), 0)
	var inside := court.area.grow(-0.1 - LinerSquash.LINE_OUT - 0.001)
	for corner: Vector3 in drawn:
		if corner.y >= court.floor_height + RoomDressing.HEADROOM:
			continue
		assert_false(inside.has_point(Vector2(corner.x, corner.z)), str(corner))
		assert_gt(corner.y, court.floor_height + 0.3, "nothing on its floor: %s" % corner)
	var gallery := _drawn(func(mesh: ShipMesh) -> void: squash.build(mesh, _room(GALLERY), none))
	assert_eq(gallery.size(), 0, "the gallery is its lining")


func test_the_gallery_s_front_is_faced_over_head_height_between_its_stairs() -> void:
	var court := _room(COURT)
	var squash := _squash()
	var none: Array[Array] = []
	var drawn := _drawn(func(mesh: ShipMesh) -> void: squash.build(mesh, court, none))
	var faced := 0
	for corner: Vector3 in drawn:
		if absf(corner.x - GALLERY_FRONT) > 0.01:
			continue
		faced += 1
		assert_gte(corner.y, court.floor_height + RoomDressing.HEADROOM, str(corner))
		for ramp: ShipRamp in _titanic.ramps:
			var over := Vector2(GALLERY_FRONT + 0.05, corner.z)
			assert_false(ramp.area.grow(-0.01).has_point(over), "over a stair: %s" % corner)
	assert_gt(faced, 0)


func test_the_court_keeps_its_pendants() -> void:
	var squash := _squash()
	for room_name: StringName in [COURT, GALLERY]:
		assert_eq(squash.lights(_room(room_name)).size(), 0, room_name)
