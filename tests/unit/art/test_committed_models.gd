extends GutTest
## Every committed prop model (assets/models/NAME/NAME.glb) stands in this file's table:
## its triangle budget class, and the box or anchor the placing code's constants give
## it — the constants stay the prop's measure, whatever hangs off them. Every model is
## one ShipMesh.model() can paint — every material a ShipPaints paint, every surface
## inked — and a folder with no row, or a row with no folder, fails.

const MODELS := "res://assets/models"
## How near a model's box stands to the constants, in metres.
const TOLERANCE := 0.02
## The most triangles a model of each class may carry: wall decor stands by the
## fifty and more, furniture by the ten to a hundred, a hero prop by the one to
## twenty; the lifeboat is the pilot's, grandfathered.
const BUDGETS := {"wall decor": 150, "furniture": 400, "hero": 1500, "lifeboat": 2928}


## Every committed model: its budget class and the check of its box (a method taking
## the model's box).
func _rows() -> Dictionary:
	return {
		"lifeboat": ["lifeboat", _fills_the_lifeboat_s_box_from_the_middle_of_its_keel],
		"davit": ["hero", _stands_its_head_where_the_falls_hang_from],
	}


func _folders() -> Array[String]:
	var found: Array[String] = []
	found.assign(DirAccess.get_directories_at(MODELS))
	return found


## Whether [param model]'s .glb is committed; the tests that load it skip a model that
## is not, which test_every_row_is_a_committed_model and the painted test report.
func _committed(model: String) -> bool:
	return ResourceLoader.exists(MODELS.path_join(model).path_join(model + ".glb"))


func test_every_model_folder_has_a_row() -> void:
	assert_gt(_folders().size(), 0, "models are committed")
	for folder in _folders():
		assert_has(_rows(), folder, "%s has a row in the table" % folder)


func test_every_row_is_a_committed_model() -> void:
	for model: String in _rows():
		assert_has(_folders(), model, "%s's row names a committed model" % model)
		assert_true(_committed(model), "%s.glb is committed" % model)


func test_every_row_names_a_budget_class() -> void:
	for model: String in _rows():
		assert_has(BUDGETS, _rows()[model][0], "%s's class" % model)


func test_every_model_is_painted_in_the_ship_s_paints_and_inked() -> void:
	for folder in _folders():
		assert_true(_committed(folder), "%s.glb is committed" % folder)
		if not _committed(folder):
			continue
		var model := ShipModel.named(folder)
		assert_eq(model.unfit, "", folder)
		var mesh := model.mesh
		assert_gt(mesh.get_surface_count(), 0, folder)
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			assert_not_null(material, "%s: surface %d's material" % [folder, surface])
			if material == null:
				continue
			var paint := material.resource_name
			assert_not_null(ShipPaints.named(paint), "%s: %s is a ship's paint" % [folder, paint])
			var ink: Variant = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			assert_not_null(ink, "%s: surface %d (%s) carries its ink" % [folder, surface, paint])


func test_every_model_keeps_to_its_triangle_budget() -> void:
	for model: String in _rows():
		if not _committed(model):
			continue
		var budget: int = BUDGETS.get(_rows()[model][0], 0)
		var triangles := ShipModel.named(model).triangles
		assert_gt(triangles, 0, model)
		assert_lte(triangles, budget, "%s within its %s budget" % [model, _rows()[model][0]])


func test_every_model_fills_the_box_its_placing_code_gives_it() -> void:
	for model: String in _rows():
		if not _committed(model):
			continue
		var fills: Callable = _rows()[model][1]
		fills.call(ShipModel.named(model).bounds)


func _fills_the_lifeboat_s_box_from_the_middle_of_its_keel(box: AABB) -> void:
	var half := Vector3(ShipFittings.LIFEBOAT_LENGTH, 0.0, ShipFittings.LIFEBOAT_BEAM) * 0.5
	var low := -half
	var high := half + Vector3.UP * ShipFittings.LIFEBOAT_DEPTH
	assert_almost_eq(box.position, low, Vector3.ONE * TOLERANCE, "lifeboat: aft, keel and port")
	assert_almost_eq(box.end, high, Vector3.ONE * TOLERANCE, "lifeboat: fore, cover, starboard")


func _stands_its_head_where_the_falls_hang_from(box: AABB) -> void:
	var rise := ShipFittings.DAVIT_RISE + ShipFittings.DAVIT_REACH + ShipFittings.DAVIT * 0.5
	assert_almost_eq(box.end.z, ShipFittings.DAVIT_REACH, TOLERANCE, "davit: over the boat")
	assert_almost_eq(box.end.y, rise, TOLERANCE, "davit: its head's top")
	assert_almost_eq(box.position.y, -ShipFittings.DAVIT_FOOT, TOLERANCE, "davit: its foot")
	assert_almost_eq(box.get_center().x, 0.0, TOLERANCE, "davit: square across its post")
