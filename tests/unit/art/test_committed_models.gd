extends GutTest
## Every committed prop model (assets/models/NAME/NAME.glb) stands in this file's table:
## its triangle budget class, and the box or anchor the placing code's constants give
## it — the constants stay the prop's measure, whatever hangs off them. Every ship's
## model is one ShipMesh.model() can paint — every material a ShipPaints paint, every
## surface inked — and a folder with no row, or a row with no folder, fails. A world
## model (the iceberg's) is no ship's: IcebergPlanner reads it and iceberg.gdshader
## draws it, so it is held to what they read instead — its colour on every face, its
## top, foot and width where the planner measures them, and its spur toward her.

const MODELS := "res://assets/models"
## How near a model's box stands to the constants, in metres.
const TOLERANCE := 0.02
## How near a gauge's or a handwheel's box stands to the radius it is made for, in
## metres: a variant a size apart is two to four centimetres off, and a handwheel's rim
## stands a third of its thickness proud of its radius.
const PART := 0.006
## The most triangles a model of each class may carry: wall decor stands by the
## fifty and more, furniture by the ten to a hundred, a hero prop by the one to
## twenty; the lifeboat is the pilot's, grandfathered; a world mesh stands alone, far
## off.
const BUDGETS := {
	"wall decor": 150, "furniture": 400, "hero": 1500, "lifeboat": 2928, "world": 3000
}
const WORLD := "world"


## Every committed model: its budget class and the check of its box (a method taking
## the model's box).
func _rows() -> Dictionary:
	return {
		"lifeboat": ["lifeboat", _fills_the_lifeboat_s_box_from_the_middle_of_its_keel],
		"davit": ["hero", _stands_its_head_where_the_falls_hang_from],
		"wheel_stand": ["hero", _fills_the_wheel_stand_s_box_off_its_wall],
		"chart_case": ["hero", _fills_the_chart_case_s_box_off_its_wall],
		"bell": ["hero", _hangs_the_bell_from_its_bracket_off_the_mast],
		"gauge_small": ["furniture", _is_the_gauge_made_for.bind(0.085, "gauge_small")],
		"gauge_large": ["furniture", _is_the_gauge_made_for.bind(0.11, "gauge_large")],
		"handwheel_small": ["furniture", _is_the_handwheel_made_for.bind(0.11, "handwheel_small")],
		"handwheel_large": ["furniture", _is_the_handwheel_made_for.bind(0.15, "handwheel_large")],
		"iceberg_tabular": [WORLD, _stands_to_the_iceberg_planner_s_measure],
		"iceberg_drydock": [WORLD, _stands_to_the_iceberg_planner_s_measure],
		"iceberg_wedge": [WORLD, _stands_to_the_iceberg_planner_s_measure],
	}


## Whether [param model]'s row puts it in the world class: no ship's prop.
func _world(model: String) -> bool:
	return _rows().get(model, [""])[0] == WORLD


## [param model]'s triangles and box: a ship's read as ShipMesh.model() reads them, a
## world model's as the planner does.
func _triangles(model: String) -> int:
	if _world(model):
		return IcebergPlanner.model_of(model).corners.size() / 3
	return ShipModel.named(model).triangles


func _bounds(model: String) -> AABB:
	if _world(model):
		return IcebergPlanner.model_of(model).bounds
	return ShipModel.named(model).bounds


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
		if not _committed(folder) or _world(folder):
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
		var triangles := _triangles(model)
		assert_gt(triangles, 0, model)
		assert_lte(triangles, budget, "%s within its %s budget" % [model, _rows()[model][0]])


func test_every_model_fills_the_box_its_placing_code_gives_it() -> void:
	for model: String in _rows():
		if not _committed(model):
			continue
		var fills: Callable = _rows()[model][1]
		fills.call(_bounds(model))


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


## A wall fitting's box, against RoomDressing's for it: from the wall's face out no
## deeper than it, on the floor, along the wall either side of its middle.
func _fills_its_box_off_its_wall(box: AABB, wanted: AABB, name: String) -> void:
	assert_almost_eq(box.position, wanted.position, Vector3.ONE * TOLERANCE, name + ": low")
	assert_almost_eq(box.end, wanted.end, Vector3.ONE * TOLERANCE, name + ": high")
	assert_gte(box.position.z, -0.001, name + ": nothing in its wall")
	assert_lte(box.end.z, wanted.end.z + 0.001, name + ": no deeper than its box")


func _fills_the_wheel_stand_s_box_off_its_wall(box: AABB) -> void:
	_fills_its_box_off_its_wall(box, RoomDressing.WHEEL_STAND, "wheel stand")


func _fills_the_chart_case_s_box_off_its_wall(box: AABB) -> void:
	_fills_its_box_off_its_wall(box, RoomDressing.CHART_CASE, "chart case")


func _hangs_the_bell_from_its_bracket_off_the_mast(box: AABB) -> void:
	var wanted := ShipFittings.BELL_BOX
	assert_almost_eq(box.position, wanted.position, Vector3.ONE * TOLERANCE, "bell: low")
	assert_almost_eq(box.end, wanted.end, Vector3.ONE * TOLERANCE, "bell: high")
	assert_almost_eq(box.end.x, 0.0, TOLERANCE, "bell: its bracket meets the mast")
	assert_gt(-box.position.x, ShipFittings.BELL_REACH, "bell: hung at its bracket's end")
	assert_almost_eq(box.get_center().z, 0.0, TOLERANCE, "bell: square under its bracket")


func _is_the_gauge_made_for(box: AABB, radius: float, model: String) -> void:
	assert_eq(RoomDressing.GAUGES.get(radius), model, "gauge: GAUGES names it")
	assert_almost_eq(box.end.x, radius, PART, "gauge: its radius")
	assert_almost_eq(box.position.x, -radius, PART, "gauge: its radius")
	assert_almost_eq(box.end.y, radius, PART, "gauge: its top")
	assert_almost_eq(box.position.z, -RoomDressing.GAUGE_BACK, PART, "gauge: its back")


func _is_the_handwheel_made_for(box: AABB, radius: float, model: String) -> void:
	assert_eq(RoomDressing.HANDWHEELS.get(radius), model, "wheel: HANDWHEELS names it")
	assert_almost_eq(box.size.x * 0.5, radius, PART, "wheel: its radius")
	assert_almost_eq(box.size.y * 0.5, radius, PART, "wheel: its radius")
	assert_almost_eq(box.position.z, -RoomDressing.HANDWHEEL_SPINDLE, PART, "its spindle")
	assert_almost_eq(box.get_center().x, 0.0, PART, "wheel: round its hub")


func test_every_world_model_is_one_the_iceberg_planner_can_draw() -> void:
	for model: String in _rows():
		if not _world(model) or not _committed(model):
			continue
		assert_has(IcebergPlanner.BERGS, model, "%s is one of the planner's bergs" % model)
		var berg := IcebergPlanner.model_of(model)
		var corners := berg.corners
		assert_eq(berg.shades.size() * 3, corners.size(), "%s: a colour on every face" % model)
		var inboard := -INF
		var blade := PackedVector3Array()
		for corner in corners:
			if corner.y >= 0.0:
				inboard = maxf(inboard, corner.z)
			if corner.z > berg.blade_z - IcebergPlanner.BLADE_NEAR and not blade.has(corner):
				blade.append(corner)
		assert_eq(blade.size(), 2, "%s: its spur's blade is two points" % model)
		for point in blade:
			assert_almost_eq(point.x, 0.0, TOLERANCE, "%s: its blade square ahead" % model)
			assert_lt(point.y, 0.0, "%s: its blade under the sea" % model)
			assert_gt(point.z, inboard, "%s: its blade out past the rest" % model)
		var darkest_over := INF
		var lightest_under := -INF
		for face in corners.size() / 3:
			var a := corners[face * 3]
			var b := corners[face * 3 + 1]
			var c := corners[face * 3 + 2]
			var middle := (a + b + c) / 3.0
			var over := a.y >= -TOLERANCE and b.y >= -TOLERANCE and c.y >= -TOLERANCE
			var under := a.y <= TOLERANCE and b.y <= TOLERANCE and c.y <= TOLERANCE
			assert_true(over or under, "%s: face %d wholly over or under the sea" % [model, face])
			var light := berg.shades[face].get_luminance()
			if middle.y >= 0.0:
				darkest_over = minf(darkest_over, light)
			else:
				lightest_under = maxf(lightest_under, light)
				for corner in [a, b, c]:
					if corner.z <= berg.blade_z - IcebergPlanner.BLADE_NEAR:
						assert_lte(
							corner.z, inboard + TOLERANCE, "%s: under the sea clear of her" % model
						)
		assert_lt(
			lightest_under, darkest_over, "%s: under-ice darker than any over the sea" % model
		)


## A berg stands to IcebergPlanner's measure, uniformly scaled from it: its top
## BERG_HEIGHT over the sea, its foot DRAUGHT × FOOT of that under, square across its
## middle and as wide each side as SPREAD allows.
func _stands_to_the_iceberg_planner_s_measure(box: AABB) -> void:
	var height := IcebergPlanner.BERG_HEIGHT
	assert_almost_eq(box.end.y, height, TOLERANCE, "berg: its top")
	var foot := -height * IcebergPlanner.DRAUGHT * IcebergPlanner.FOOT
	assert_almost_eq(box.position.y, foot, TOLERANCE, "berg: its foot")
	assert_almost_eq(box.get_center().x, 0.0, TOLERANCE, "berg: square across its middle")
	var spread := box.size.x * 0.5 / height
	assert_between(spread, IcebergPlanner.SPREAD.x, IcebergPlanner.SPREAD.y, "berg: its width")
