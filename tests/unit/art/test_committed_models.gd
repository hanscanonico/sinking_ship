extends GutTest
## Every committed prop model (assets/models/NAME/NAME.glb) is one ShipMesh.model() can
## paint — every material a ShipPaints paint, every surface inked — and the lifeboat
## and its davit fill the boxes ShipFittings' constants give them: the constants stay
## the boat's measure, the falls and art-lint's open edges hang off them.

const MODELS := "res://assets/models"
## How near a model's box stands to the constants, in metres.
const TOLERANCE := 0.02


func _models() -> Array[String]:
	var found: Array[String] = []
	for folder in DirAccess.get_directories_at(MODELS):
		for file in DirAccess.get_files_at(MODELS.path_join(folder)):
			if file.get_extension() == "glb":
				found.append(MODELS.path_join(folder).path_join(file))
	return found


func test_the_lifeboat_and_its_davit_are_committed_models() -> void:
	assert_has(_models(), "res://assets/models/lifeboat/lifeboat.glb")
	assert_has(_models(), "res://assets/models/davit/davit.glb")


func test_every_model_is_painted_in_the_ship_s_paints_and_inked() -> void:
	for path in _models():
		var mesh := ShipModel.mesh_of(load(path))
		assert_gt(mesh.get_surface_count(), 0, path)
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			assert_not_null(material, "%s: surface %d's material" % [path, surface])
			if material == null:
				continue
			var paint := material.resource_name
			assert_not_null(ShipPaints.named(paint), "%s: %s is a ship's paint" % [path, paint])
			var ink: Variant = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			assert_not_null(ink, "%s: surface %d (%s) carries its ink" % [path, surface, paint])


func test_the_lifeboat_fills_the_lifeboat_s_box_from_the_middle_of_its_keel() -> void:
	var box := ShipModel.mesh_of(ShipFittings.LIFEBOAT_MODEL).get_aabb()
	var half := Vector3(ShipFittings.LIFEBOAT_LENGTH, 0.0, ShipFittings.LIFEBOAT_BEAM) * 0.5
	var low := -half
	var high := half + Vector3.UP * ShipFittings.LIFEBOAT_DEPTH
	assert_almost_eq(box.position, low, Vector3.ONE * TOLERANCE, "aft, keel and port")
	assert_almost_eq(box.end, high, Vector3.ONE * TOLERANCE, "fore, cover and starboard")


func test_the_davit_s_head_stands_where_the_falls_hang_from() -> void:
	var box := ShipModel.mesh_of(ShipFittings.DAVIT_MODEL).get_aabb()
	var rise := ShipFittings.DAVIT_RISE + ShipFittings.DAVIT_REACH + ShipFittings.DAVIT * 0.5
	assert_almost_eq(box.end.z, ShipFittings.DAVIT_REACH, TOLERANCE, "out over the boat's middle")
	assert_almost_eq(box.end.y, rise, TOLERANCE, "its head's top")
	assert_almost_eq(box.position.y, -ShipFittings.DAVIT_FOOT, TOLERANCE, "its foot")
	assert_almost_eq(box.get_center().x, 0.0, TOLERANCE, "square across its post")
