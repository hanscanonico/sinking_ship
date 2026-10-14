extends GutTest
## ShipModel.mesh_of(): a modelled prop's scene gathered into one mesh in the prop's
## own space — every part where it stands in the scene, its paint kept, its faces
## still facing out however the part is turned.


## A scene of one part, moved by [param place]: an inked, unindexed triangle a metre
## across facing up, in white.
func _scene(place: Transform3D) -> PackedScene:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	# Godot's front faces wind clockwise seen from the front: this one faces up.
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)]
	)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.BLACK, Color.BLACK])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var white := StandardMaterial3D.new()
	white.resource_name = "white"
	mesh.surface_set_material(0, white)
	var root := Node3D.new()
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.transform = place
	root.add_child(part)
	part.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_each_part_is_gathered_where_it_stands_in_its_paint() -> void:
	var mesh := ShipModel.mesh_of(_scene(Transform3D(Basis.IDENTITY, Vector3(2, 1, 0))))
	assert_eq(mesh.surface_get_material(0).resource_name, "white")
	var box := mesh.get_aabb()
	assert_almost_eq(box.position, Vector3(2, 1, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(box.end, Vector3(3, 1, 1), Vector3.ONE * 0.0001)


func test_a_mirrored_part_still_faces_out() -> void:
	var mesh := ShipModel.mesh_of(_scene(Transform3D(Basis.from_scale(Vector3(1, 1, -1)))))
	var corners := mesh.get_faces()
	assert_eq(corners.size(), 3)
	var a := corners[0]
	var b := corners[1]
	var c := corners[2]
	# Godot draws a face's front turning clockwise, so one facing up crosses down.
	assert_lt((b - a).cross(c - a).y, 0.0, "faces up")
	for normal: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(normal, Vector3.UP, Vector3.ONE * 0.0001)
