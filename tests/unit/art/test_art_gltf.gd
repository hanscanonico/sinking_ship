extends GutTest
## `make preview`'s ship as a glTF (ArtGltf): the tug's dressed art written as a .glb
## that holds her meshes, and kept to a stretch along her, nothing of it off that
## stretch. Blender's half (tools/art_preview.py) is not tested here: CI has no Blender.

const RunMatch := preload("res://tools/run_match.gd")
const SHIP := &"tug"
const GLB := "user://test_art_gltf.glb"
## The stretch along her kept, aft to fore, in metres of ship space.
const SPAN := Vector2(-3.0, 2.0)
## How far past an end of the stretch a kept corner may stand: rounding alone.
const GRAIN := 1e-3

var _art: ShipArt


func before_all() -> void:
	var config := RunMatch.default_config(RunMatch.DEFAULT_SEED, 0, SHIP)
	_art = ArtGltf.dressed(Fleet.layout(SHIP), config.rules)


func after_all() -> void:
	_art.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GLB))


func test_her_art_is_written_as_a_glb_holding_her_meshes() -> void:
	var holder := ArtGltf.flattened(_art, "Ship")
	assert_eq(ArtGltf.write(holder, GLB), OK, "written")
	holder.free()
	assert_true(FileAccess.file_exists(GLB), "the .glb is there")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert_eq(document.append_from_file(GLB, state), OK, "read back")
	assert_gt(state.get_meshes().size(), 0, "it holds meshes")
	var scene := document.generate_scene(state)
	assert_gt(_corners(scene).size(), 0, "with corners")
	scene.free()


func test_a_stretch_keeps_only_what_lies_on_it() -> void:
	var whole := ArtGltf.flattened(_art, "Whole")
	var everywhere := _corners(whole)
	whole.free()
	assert_true(_any_off(everywhere), "her whole art reaches past the stretch")
	var kept := ArtGltf.flattened(_art, "Kept", SPAN)
	var corners := _corners(kept)
	kept.free()
	assert_gt(corners.size(), 0, "something of her is kept")
	assert_false(_any_off(corners), "nothing kept lies off the stretch")
	assert_lt(corners.size(), everywhere.size(), "less of her than all of her")


func test_her_art_is_merged_into_few_meshes_in_ship_space() -> void:
	var holder := ArtGltf.flattened(_art, "Merged")
	var merged := _corners(holder)
	var meshes := holder.get_child_count()
	holder.free()
	var shown := _shown(_art)
	assert_gt(shown.size(), 0, "her art has corners")
	assert_eq(meshes, ceili(float(merged.size()) / ArtGltf.CHUNK), "as few meshes as hold them")
	assert_eq(merged.size(), shown.size(), "every corner of hers, and no other")
	var unmatched := 0
	for corner in shown.size():
		if not merged[corner].is_equal_approx(shown[corner]):
			unmatched += 1
	assert_eq(unmatched, 0, "each where her art stands it, in ship space, in order")


## Every corner of every triangle mesh shown under [param node], placed in its frame.
func _shown(node: Node, place := Transform3D.IDENTITY) -> PackedVector3Array:
	var found := PackedVector3Array()
	for child: Node in node.get_children():
		var at := place
		if child is Node3D:
			if not (child as Node3D).visible:
				continue
			at = place * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mesh := (child as MeshInstance3D).mesh
			for surface in mesh.get_surface_count():
				if mesh is ArrayMesh:
					var primitive := (mesh as ArrayMesh).surface_get_primitive_type(surface)
					if primitive != Mesh.PRIMITIVE_TRIANGLES:
						continue
				var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				found.append_array(at * points)
		found.append_array(_shown(child, at))
	return found


## Every corner of every mesh under [param node], placed in its frame.
func _corners(node: Node, place := Transform3D.IDENTITY) -> PackedVector3Array:
	var found := PackedVector3Array()
	for child: Node in node.get_children():
		var at := place
		if child is Node3D:
			at = place * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mesh := (child as MeshInstance3D).mesh
			for surface in mesh.get_surface_count():
				var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				found.append_array(at * points)
		found.append_array(_corners(child, at))
	return found


func _any_off(corners: PackedVector3Array) -> bool:
	for corner in corners:
		if corner.x < SPAN.x - GRAIN or corner.x > SPAN.y + GRAIN:
			return true
	return false
