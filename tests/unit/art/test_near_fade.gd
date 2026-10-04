extends GutTest
## What fades out near the eye rather than fill the view as a jumping head rises
## into it: the rooms' furnishings over HEADROOM, each piece whole by its box
## (ShipMesh.fading, ship_near.gdshader), and the hanging lamps; nothing else.

const RunMatch := preload("res://tools/run_match.gd")

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_space = ShipSpace.new(_layout)


func _indoors() -> ShipMesh:
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	return ShipMesh.new(func(_point: Vector3) -> bool: return false, no_rooms)


## Every vertex [param mesh] commits, with its CUSTOM0 and CUSTOM1, as [position,
## piece middle and whether it fades, piece half size].
func _committed(mesh: ShipMesh) -> Array[Array]:
	var parent := Node3D.new()
	mesh.commit(parent, {ShipMesh.Finish.PLAIN: ShaderMaterial.new()})
	var found: Array[Array] = []
	for part: Node in parent.get_children():
		var arrays := ((part as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var pieces = arrays[Mesh.ARRAY_CUSTOM0]
		var halves = arrays[Mesh.ARRAY_CUSTOM1]
		for index in vertices.size():
			if pieces == null:
				found.append([vertices[index], null, null])
				continue
			var at := index * 4
			var piece := Vector4(pieces[at], pieces[at + 1], pieces[at + 2], pieces[at + 3])
			var half := Vector3(halves[index * 3], halves[index * 3 + 1], halves[index * 3 + 2])
			found.append([vertices[index], piece, half])
	parent.free()
	return found


func test_every_vertex_of_a_piece_carries_the_piece_s_box() -> void:
	var mesh := _indoors()
	mesh.fading = func(piece: AABB) -> bool: return piece.position.y > 1.0
	var paint := ShipPaints.white
	var place := Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0))
	mesh.turned_box(place, Vector3(0.4, 0.2, 0.6), paint)
	mesh.cylinder(Vector2(-2.0, 0.0), 0.3, 0.0, 0.5, 8, paint)
	var found := _committed(mesh)
	assert_gt(found.size(), 0)
	for vertex: Array in found:
		var at: Vector3 = vertex[0]
		var box := [Vector4(1.0, 2.0, 3.0, 1.0), Vector3(0.2, 0.1, 0.3)]
		if at.y < 1.0:
			box = [Vector4(-2.0, 0.25, 0.0, 0.0), Vector3(0.3, 0.25, 0.3)]
		assert_almost_eq(vertex[1] as Vector4, box[0] as Vector4, Vector4.ONE * 1e-5)
		assert_almost_eq(vertex[2] as Vector3, box[1] as Vector3, Vector3.ONE * 1e-5)


func test_a_mesh_that_does_not_fade_carries_no_boxes() -> void:
	var mesh := _indoors()
	mesh.turned_box(Transform3D.IDENTITY, Vector3.ONE, ShipPaints.white)
	for vertex: Array in _committed(mesh):
		assert_null(vertex[1])


func test_only_what_stands_over_headroom_in_a_room_fades() -> void:
	var dressing := RoomDressing.new(_space)
	var cabin: ShipRoom
	for room: ShipRoom in _layout.rooms:
		if room.name == &"middle port cabin":
			cabin = room
	var middle := cabin.area.get_center()
	var floor := cabin.floor_height
	var berth := AABB(Vector3(middle.x, floor + RoomDressing.HEADROOM, middle.y), Vector3.ONE * 0.3)
	var washstand := AABB(Vector3(middle.x, floor + 0.25, middle.y), Vector3(0.5, 0.65, 0.1))
	var outdoors := AABB(Vector3(-17.0, 4.0, 0.0), Vector3.ONE * 0.3)
	assert_true(dressing.overhead(berth))
	assert_false(dressing.overhead(washstand))
	assert_false(dressing.overhead(outdoors))


func test_the_furnishings_and_hanging_lamps_fade_and_nothing_else_does() -> void:
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	var faded := 0
	for part: Node in art.get_node("Dressing").get_children():
		if not part is MeshInstance3D:
			continue
		var material := (part as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		assert_eq(material.shader, ShipArt.NEAR_SHADER)
		assert_eq(material.get_shader_parameter("near_fade"), RoomDressing.NEAR_FADE)
		faded += 1
	assert_gt(faded, 0)
	for part: Node in art.get_children():
		if part is MeshInstance3D:
			var material := (part as MeshInstance3D).mesh.surface_get_material(0)
			assert_ne(material.get("shader"), ShipArt.NEAR_SHADER)
	for lamp: ShipLamp in art.find_children("Lamp*", "ShipLamp", true, false):
		var fire := lamp.find_children("*", "SpotLight3D", false, false).size() > 0
		for part: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", false, false):
			var mode := (part.mesh.surface_get_material(0) as BaseMaterial3D).distance_fade_mode
			var wanted := BaseMaterial3D.DISTANCE_FADE_DISABLED
			if not fire:
				wanted = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			assert_eq(mode, wanted)
	art.free()
