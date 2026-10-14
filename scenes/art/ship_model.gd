class_name ShipModel
extends RefCounted
## A modelled prop: a committed .glb under assets/models, made in Blender as
## assets/models/README.md says, gathered into one mesh in the prop's own space — every
## object's surfaces, each keeping the material that names its paint — for
## ShipMesh.model() to draw among the ship's own faces. Never a mesh instance of its
## own: it goes into the ship's batches, chunked under the lamp limit as any face is.


## [param scene]'s every mesh, each where it stands in the scene, as one mesh named
## after its file (lifeboat.glb gathers as lifeboat).
static func mesh_of(scene: PackedScene) -> ArrayMesh:
	var root := scene.instantiate()
	var gathered := ArrayMesh.new()
	gathered.resource_name = scene.resource_path.get_file().get_basename()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var place := Transform3D.IDENTITY
		var up: Node = part
		while up != root:
			place = (up as Node3D).transform * place
			up = up.get_parent()
		for surface in part.mesh.get_surface_count():
			var arrays := _placed(part.mesh.surface_get_arrays(surface), place)
			gathered.add_surface_from_arrays(part.mesh.surface_get_primitive_type(surface), arrays)
			var material := part.mesh.surface_get_material(surface)
			gathered.surface_set_material(gathered.get_surface_count() - 1, material)
	root.free()
	return gathered


## A surface's [param arrays] moved by [param place]: its points, its normals turned by
## the inverse transpose, its triangles rewound where the place mirrors them.
static func _placed(arrays: Array, place: Transform3D) -> Array:
	if place == Transform3D.IDENTITY:
		return arrays
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in points.size():
		points[index] = place * points[index]
	arrays[Mesh.ARRAY_VERTEX] = points
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var turn := place.basis.inverse().transposed()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in normals.size():
			normals[index] = (turn * normals[index]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	# A tangent would no longer match its turned normal; the ship's paints read none.
	arrays[Mesh.ARRAY_TANGENT] = null
	if place.basis.determinant() < 0.0:
		var order := PackedInt32Array(range(points.size()))
		if arrays[Mesh.ARRAY_INDEX] != null:
			order = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, order.size(), 3):
			var first := order[index + 1]
			order[index + 1] = order[index + 2]
			order[index + 2] = first
		arrays[Mesh.ARRAY_INDEX] = order
	return arrays
