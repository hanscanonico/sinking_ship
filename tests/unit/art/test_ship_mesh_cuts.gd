extends GutTest
## ShipMesh.face(): an axis-aligned face is cut at its chunk lines, and at those room
## lines alone where it passes indoors or out — a stretch of it all indoors, or all
## out, is one piece however many rooms' edges cross it, and every cut runs the whole
## face, so no piece's corner stands on another's edge.

## The room lines a mesh cuts at, across x and across z: none on a chunk line.
const XS: Array[float] = [1.0, 2.0, 2.5, 3.0, 5.0, 6.0, 7.0]
const ZS: Array[float] = [1.5, 3.0]
## A floor 7 m along x from x 0.5 and 4 m across from z 0.5: one chunk line, x 4,
## crosses it.
const ORIGIN := Vector3(0.5, 0.0, 0.5)
const ALONG := Vector3(7.0, 0.0, 0.0)
const ACROSS := Vector3(0.0, 0.0, 4.0)

var _paint := ShipMesh.Paint.new(ShipMesh.Finish.DECK, Color.WHITE)


## The floor drawn by a mesh cutting at XS and ZS that has a ship point outdoors where
## [param outdoors] says, committed: its mesh instances.
func _floor(outdoors: Callable) -> Array[MeshInstance3D]:
	var cuts: Array[PackedFloat32Array] = [
		PackedFloat32Array(XS), PackedFloat32Array(), PackedFloat32Array(ZS)
	]
	var mesh := ShipMesh.new(outdoors, cuts)
	mesh.face(ORIGIN, ACROSS, ALONG, _paint)
	var node := Node3D.new()
	add_child_autofree(node)
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	mesh.commit(node, materials)
	var found: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		found.append(child as MeshInstance3D)
	return found


## Where along [param axis] (0 x, 2 z) the pieces of [param instances] meet: each
## corner's, but for those at the floor's edges and their rims, once each, in order.
func _seams(instances: Array[MeshInstance3D], axis: int) -> Array[float]:
	var low := ORIGIN[axis] + ShipMesh.RIM + 0.01
	var high := ORIGIN[axis] + (ALONG + ACROSS)[axis] - ShipMesh.RIM - 0.01
	var found: Array[float] = []
	for instance: MeshInstance3D in instances:
		for surface in instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[
				Mesh.ARRAY_VERTEX
			]
			for vertex: Vector3 in vertices:
				var at := snappedf(vertex[axis], 0.001)
				if at > low and at < high and not at in found:
					found.append(at)
	found.sort()
	return found


func test_a_face_all_indoors_is_cut_at_its_chunk_lines_alone() -> void:
	var drawn := _floor(func(_point: Vector3) -> bool: return false)
	assert_eq(_seams(drawn, 0), [4.0] as Array[float], "along")
	assert_eq(_seams(drawn, 2), [] as Array[float], "across")


func test_a_face_all_outdoors_is_too() -> void:
	var drawn := _floor(func(_point: Vector3) -> bool: return true)
	assert_eq(_seams(drawn, 0), [4.0] as Array[float], "along")
	assert_eq(_seams(drawn, 2), [] as Array[float], "across")


func test_a_face_is_cut_where_it_passes_out_of_doors() -> void:
	var drawn := _floor(func(point: Vector3) -> bool: return point.x > 2.5)
	assert_eq(_seams(drawn, 0), [2.5, 4.0] as Array[float], "along")
	assert_eq(_seams(drawn, 2), [] as Array[float], "across")
	for instance: MeshInstance3D in drawn:
		var outdoors := String(instance.name).contains("out")
		for vertex: Vector3 in instance.mesh.get_faces():
			if outdoors:
				assert_gt(vertex.x, 2.499, "outdoors: %s" % vertex)
			else:
				assert_lt(vertex.x, 2.501, "indoors: %s" % vertex)


func test_a_cut_runs_the_whole_face_where_any_piece_needs_it() -> void:
	var drawn := _floor(func(point: Vector3) -> bool: return point.x > 2.5 and point.z > 3.0)
	assert_eq(_seams(drawn, 0), [2.5, 4.0] as Array[float], "along")
	assert_eq(_seams(drawn, 2), [3.0] as Array[float], "across")
