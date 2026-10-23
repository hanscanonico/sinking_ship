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
## How far from its wall a furnishing may stand under a body's height (art-lint).
const FurnishingCheck := preload("res://tools/furnishing_check.gd")


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
		"handwheel_large": ["furniture", _is_the_handwheel_made_for.bind(0.15, "handwheel_large")],
		"chandelier": ["hero", _hangs_round_its_hub_within_its_rise_and_depth],
		"boiler_100": ["hero", _stands_a_boiler_front_in_its_bulkhead.bind("boiler_100")],
		"boiler_85": ["hero", _stands_a_boiler_front_in_its_bulkhead.bind("boiler_85")],
		"boiler_65": ["hero", _stands_a_boiler_front_in_its_bulkhead.bind("boiler_65")],
		"boiler_50": ["hero", _stands_a_boiler_front_in_its_bulkhead.bind("boiler_50")],
		"crate": ["furniture", _fills_every_cargo_crate_s_square],
		"washstand":
		["furniture", _fills_a_cabin_fitting_s_box.bind(CabinDressing.WASHSTAND, "washstand")],
		"locker": ["furniture", _fills_a_cabin_fitting_s_box.bind(CabinDressing.LOCKER, "locker")],
		"luggage_shelf":
		["furniture", _fills_a_cabin_fitting_s_box.bind(CabinDressing.LUGGAGE_SHELF, "shelf")],
		"luggage_rack":
		["furniture", _fills_a_cabin_fitting_s_box.bind(CabinDressing.LUGGAGE_RACK, "rack")],
		"coat": ["furniture", _fills_a_cabin_fitting_s_box.bind(CabinDressing.COAT, "coat")],
		"folded_berth_190":
		["furniture", _is_the_folded_berth_made_for.bind(1.9, "folded_berth_190")],
		"berth": ["furniture", _fills_the_berth_s_length_and_depth_off_its_wall],
		"lifebelt": ["furniture", _hangs_the_lifebelt_flat_on_its_wall],
		"fire_buckets": ["furniture", _fills_the_fire_buckets_rack_off_its_wall],
		"pendant_lamp": ["wall decor", _hangs_the_pendant_s_globe_from_its_swivel],
		"cargo_lamp": ["furniture", _hangs_the_cargo_lamp_s_globe_under_its_shade],
		"furnace_fire": ["furniture", _fills_the_furnace_s_mouth_behind_its_bars],
		"break_door": ["furniture", _stands_the_break_door_in_its_frame_on_the_face],
		"deck_pipe_13": ["furniture", _is_the_deck_pipe_made_for.bind(0.13, "deck_pipe_13")],
		"deck_pipe_20": ["furniture", _is_the_deck_pipe_made_for.bind(0.2, "deck_pipe_20")],
		"bitts": ["furniture", _lies_on_the_deck_under_a_step.bind(MooringGear.BITTS_BOX, "bitts")],
		"rope_coil":
		["furniture", _lies_on_the_deck_under_a_step.bind(MooringGear.COIL_BOX, "rope coil")],
		"stowed_crate_62":
		["furniture", _is_the_stowed_crate_made_for.bind(0.62, "stowed_crate_62")],
		"stowed_crate_70":
		["furniture", _is_the_stowed_crate_made_for.bind(0.7, "stowed_crate_70")],
		"stowed_crate_80":
		["furniture", _is_the_stowed_crate_made_for.bind(0.8, "stowed_crate_80")],
		"crosstree_15": ["hero", _is_the_crosstree_made_for.bind(0.15, "crosstree_15")],
		"crosstree_20": ["hero", _is_the_crosstree_made_for.bind(0.2, "crosstree_20")],
		"crosstree_60": ["hero", _is_the_crosstree_made_for.bind(0.6, "crosstree_60")],
		"masthead_light": ["hero", _stands_the_masthead_light_off_the_mast],
		"mast_cleat": ["furniture", _fills_its_box.bind(DeckWorks.CLEAT_BOX, "mast cleat")],
		"whistle_90": ["hero", _stands_the_whistle_on_its_steam_pipe.bind("90")],
		"waste_pipe_head_90": ["furniture", _caps_the_waste_pipe_over_the_funnel_s_top.bind("90")],
		"pipe_clamp_90": ["wall decor", _holds_a_pipe_to_the_funnel.bind("90")],
		"whistle_330": ["hero", _stands_the_whistle_on_its_steam_pipe.bind("330")],
		"waste_pipe_head_330":
		["furniture", _caps_the_waste_pipe_over_the_funnel_s_top.bind("330")],
		"pipe_clamp_330": ["wall decor", _holds_a_pipe_to_the_funnel.bind("330")],
		"clock": ["wall decor", _hangs_the_clock_flat_on_its_wall],
		"sconce_tulip": ["wall decor", _hangs_the_tulip_sconce_flat_on_its_wall],
		"sconce_globe": ["wall decor", _hangs_the_dining_sconce_s_globe_off_its_wall],
		"capital_32":
		["wall decor", _is_the_capital_made_for.bind(LinerPublic.CAPITAL, "capital_32")],
		"capital_38":
		["wall decor", _is_the_capital_made_for.bind(_dining_capital(), "capital_38")],
		"pilaster_base": ["wall decor", _stands_the_pilaster_base_on_the_floor],
		"stateroom_door": ["wall decor", _stands_the_stateroom_door_in_its_architrave],
		"hanging_basket": ["furniture", _hangs_the_basket_from_its_hook],
		"copper_pan_120": ["furniture", _is_the_pan_made_for.bind(0.12, "copper_pan_120")],
		"copper_pan_75": ["furniture", _is_the_pan_made_for.bind(0.075, "copper_pan_75")],
		"stockpot": ["furniture", _hangs_the_stockpot_from_the_rack],
		"ladle_35": ["furniture", _is_the_ladle_made_for.bind(0.35, "ladle_35")],
		"ladle_22": ["furniture", _is_the_ladle_made_for.bind(0.22, "ladle_22")],
		"dresser_180": ["furniture", _is_the_dresser_made_for.bind(1.8, "dresser_180")],
		"dresser_140": ["furniture", _is_the_dresser_made_for.bind(1.4, "dresser_140")],
		"wall_bars":
		["furniture", _fills_its_box_off_its_wall.bind(LinerService.WALL_BARS, "wall bars")],
		"mail_sack": ["furniture", _hangs_the_mail_sack_over_headroom],
		"plaque": ["furniture", _hangs_flat_on_its_wall.bind(LinerService.PLAQUE, "plaque")],
		"notice_board":
		["furniture", _hangs_flat_on_its_wall.bind(LinerService.NOTICE_BOARD, "notice board")],
		"bath_lantern": ["furniture", _hangs_the_lantern_round_its_pendant],
		"pool_ladder": ["furniture", _stands_the_ladder_over_the_pool_s_rim],
		"electrolier": ["hero", _hangs_the_electrolier_round_its_pendant],
		"sideboard_180":
		["furniture", _is_the_sideboard_made_for.bind(_dining_sideboard(), "sideboard_180")],
		"sideboard_64":
		["furniture", _is_the_sideboard_made_for.bind(CabinDressing.SIDEBOARD, "sideboard_64")],
		"dining_chair": ["wall decor", _seats_the_chair_inside_its_table_s_box],
		"serving_hatch": ["furniture", _hangs_the_serving_hatch_in_its_wall],
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


func test_the_boiler_fronts_run_from_the_largest_boiler_to_the_least() -> void:
	var fronts := EngineRoom.BOILER_FRONTS
	assert_eq(fronts.front()[0], EngineRoom.BOILER_RADIUS, "the largest front")
	assert_eq(fronts.back()[0], EngineRoom.BOILER_LEAST, "the least front")
	for index in range(1, fronts.size()):
		assert_lt(fronts[index][0], fronts[index - 1][0], "largest first")
	assert_eq(EngineRoom.front_for(0.86), 0.85, "a boiler is drawn the largest that fits")
	assert_eq(EngineRoom.front_for(2.0), EngineRoom.BOILER_RADIUS, "never past the largest")
	assert_true(is_nan(EngineRoom.front_for(0.49)), "none under the least")


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


## A wall fitting of CabinDressing's: its box as _fills_its_box_off_its_wall has it,
## and whatever of it stands under HEADROOM no further out from its wall than a
## furnishing may stand (art-lint).
func _fills_a_cabin_fitting_s_box(box: AABB, wanted: AABB, name: String) -> void:
	_fills_its_box_off_its_wall(box, wanted, name)
	if box.position.y < RoomDressing.HEADROOM:
		assert_lte(box.end.z, FurnishingCheck.TOLERANCE, name + ": flat to its wall")


## A folded berth [param model] made for [param length] (CabinDressing.FOLDED_BERTHS):
## that long, square across its middle, in CabinDressing.FOLDED_BERTH's height and
## depth, flat to its wall.
func _is_the_folded_berth_made_for(box: AABB, length: float, model: String) -> void:
	assert_eq(CabinDressing.FOLDED_BERTHS.get(length), model, "FOLDED_BERTHS names it")
	assert_almost_eq(box.size.x, length, PART, "%s: its length" % model)
	assert_almost_eq(box.get_center().x, 0.0, PART, "%s: square across its middle" % model)
	var wanted := CabinDressing.FOLDED_BERTH
	wanted.position.x = box.position.x
	wanted.size.x = box.size.x
	_fills_a_cabin_fitting_s_box(box, wanted, model)


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


## A box within TOLERANCE of [param wanted], the placing code's, both corners.
func _fills_its_box(box: AABB, wanted: AABB, name: String) -> void:
	assert_almost_eq(box.position, wanted.position, Vector3.ONE * TOLERANCE, name + ": low")
	assert_almost_eq(box.end, wanted.end, Vector3.ONE * TOLERANCE, name + ": high")


## A piece of the mooring gear (MooringGear): its box, on the deck and under a step over
## it, where bodies walk with nothing to hold them off it.
func _lies_on_the_deck_under_a_step(box: AABB, wanted: AABB, name: String) -> void:
	_fills_its_box(box, wanted, name)
	assert_gte(box.position.y, -0.001, name + ": nothing of it in the deck")
	var rules: BrawlRules = load("res://data/rules/brawl.tres")
	assert_lt(box.end.y, rules.step_height, name + ": under a step")


## A crosstree [param model] made for a mast of [param radius] (DeckWorks.CROSSTREES):
## square round the mast, its arms CROSSTREE_REACH past its side, within its rise and
## its drop.
func _is_the_crosstree_made_for(box: AABB, radius: float, model: String) -> void:
	assert_eq(DeckWorks.CROSSTREES.get(radius), model, "CROSSTREES names it")
	var reach := radius + DeckWorks.CROSSTREE_REACH
	assert_almost_eq(box.end.z, reach, PART, "%s: its arm's reach" % model)
	assert_almost_eq(-box.position.z, reach, PART, "%s: its arm's reach" % model)
	assert_almost_eq(box.get_center().x, 0.0, PART, "%s: square fore and aft" % model)
	assert_gt(box.size.x, radius * 2.0, "%s: its trestle trees past the mast" % model)
	assert_almost_eq(box.end.y, DeckWorks.CROSSTREE_RISE, PART, "%s: its rise" % model)
	assert_almost_eq(-box.position.y, DeckWorks.CROSSTREE_DROP, TOLERANCE, "%s: drop" % model)


## The masthead light: its plate on the mast's face, its glow round its lens.
func _stands_the_masthead_light_off_the_mast(box: AABB) -> void:
	_fills_its_box(box, DeckWorks.MASTHEAD_LIGHT_BOX, "masthead light")
	assert_almost_eq(box.position.x, 0.0, TOLERANCE, "masthead light: on the mast's face")
	var lens := DeckWorks.MASTHEAD_LENS
	var size := DeckWorks.MASTHEAD_LENS_SIZE
	assert_true(box.has_point(lens), "masthead light: its lens inside it")
	assert_lt(
		lens.x - size.x, box.end.x - lens.x, "masthead light: the lantern stands off the mast"
	)


## A funnel fitting's scale for [param size] (DeckWorks.FUNNEL_FITTINGS), and that
## FUNNEL_FITTINGS names the size.
func _funnel_scale(size: String) -> float:
	assert_has(DeckWorks.FUNNEL_FITTINGS.values(), size, "FUNNEL_FITTINGS names %s" % size)
	return DeckWorks.FUNNEL_FITTING_SCALE[size]


## A box [param scale] times [param box], about the origin.
func _scaled(box: AABB, scale: float) -> AABB:
	return AABB(box.position * scale, box.size * scale)


## The whistle of [param size]: its plate on the funnel's face, standing on its steam
## pipe's end.
func _stands_the_whistle_on_its_steam_pipe(box: AABB, size: String) -> void:
	var scale := _funnel_scale(size)
	_fills_its_box(box, _scaled(DeckWorks.WHISTLE_BOX, scale), "whistle_" + size)
	assert_almost_eq(box.position.x, 0.0, TOLERANCE, "whistle: on the funnel's face")
	var pipe := (DeckWorks.FUNNEL_PIPE_OUT + DeckWorks.FUNNEL_PIPE) * scale
	assert_gt(box.end.x, pipe, "whistle: over its pipe")


## The waste pipe's head of [param size]: on the pipe's end at the funnel's top, its
## mouth WASTE_PIPE_RISE over it, its stay reaching the funnel's rim and no further,
## within the rim's depth.
func _caps_the_waste_pipe_over_the_funnel_s_top(box: AABB, size: String) -> void:
	var scale := _funnel_scale(size)
	var name := "waste_pipe_head_" + size
	assert_almost_eq(box.end.y, DeckWorks.WASTE_PIPE_RISE * scale, PART, name + ": its mouth")
	var rim := DeckWorks.FUNNEL_PIPE_OUT * scale - DeckWorks.FUNNEL_RIM.x
	assert_almost_eq(box.end.x, rim, PART, name + ": its stay meets the rim")
	assert_gt(-box.position.y, 0.0, name + ": its stay under the top")
	assert_lte(-box.position.y, DeckWorks.FUNNEL_RIM.y, name + ": on the rim")
	assert_almost_eq(box.get_center().z, 0.0, PART, name + ": square on its pipe")
	assert_lte(-box.position.x, DeckWorks.WASTE_PIPE_RISE * scale, name + ": its mouth's round")


## A pipe clamp of [param size]: its foot on the funnel's face, its strap round the
## pipe.
func _holds_a_pipe_to_the_funnel(box: AABB, size: String) -> void:
	var scale := _funnel_scale(size)
	_fills_its_box(box, _scaled(DeckWorks.PIPE_CLAMP_BOX, scale), "pipe_clamp_" + size)
	assert_almost_eq(box.position.x, -0.01 * scale, TOLERANCE, "pipe clamp: on the funnel's face")
	var strap := (DeckWorks.FUNNEL_PIPE_OUT + DeckWorks.FUNNEL_PIPE) * scale
	assert_almost_eq(box.end.x, strap, TOLERANCE * scale, "pipe clamp: round its pipe")


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


func _hangs_round_its_hub_within_its_rise_and_depth(box: AABB) -> void:
	var reach := Vector3(LinerPublic.CHANDELIER, 0.0, LinerPublic.CHANDELIER)
	assert_almost_eq(box.end * Vector3(1, 0, 1), reach, Vector3.ONE * TOLERANCE, "its ring")
	assert_almost_eq(box.position * Vector3(1, 0, 1), -reach, Vector3.ONE * TOLERANCE)
	assert_lte(box.end.y, LinerPublic.CHANDELIER_RISE, "under the rod's foot")
	assert_gte(box.position.y, -LinerPublic.CHANDELIER_DEPTH, "over HEADROOM under its hub")
	assert_almost_eq(box.position.y, -LinerPublic.CHANDELIER_DEPTH, TOLERANCE, "its finial")


## A boiler front [param model] of its radius in EngineRoom.BOILER_FRONTS: on the
## floor and the bulkhead's face, square across its middle, as broad and as tall as its
## radius makes it — a stop valve over it only over head height — and under a body's
## height no further out from the bulkhead than a furnishing may stand.
func _stands_a_boiler_front_in_its_bulkhead(box: AABB, model: String) -> void:
	var radius := NAN
	for front: Array in EngineRoom.BOILER_FRONTS:
		if front[1] == model:
			radius = front[0]
	assert_false(is_nan(radius), "%s is one of EngineRoom.BOILER_FRONTS" % model)
	var top := EngineRoom.BOILER_FOOT + radius * 2.0
	assert_almost_eq(box.position.y, 0.0, TOLERANCE, "%s: on the floor" % model)
	assert_almost_eq(box.position.z, 0.0, TOLERANCE, "%s: on the bulkhead" % model)
	assert_almost_eq(box.end.x, radius, TOLERANCE, "%s: its breadth" % model)
	assert_almost_eq(box.get_center().x, 0.0, TOLERANCE, "%s: square across it" % model)
	if top < RoomDressing.HEADROOM:
		assert_almost_eq(box.end.y, top, TOLERANCE, "%s: its top" % model)
	else:
		assert_between(box.end.y, top, top + 0.2, "%s: its stop valve on top" % model)
	var furthest := 0.0
	for surface: ShipModel.Surface in ShipModel.named(model).surfaces:
		for point: Vector3 in surface.points:
			if point.y < RoomDressing.HEADROOM:
				furthest = maxf(furthest, point.z)
	assert_lte(furthest, FurnishingCheck.TOLERANCE, "%s: flat to its bulkhead" % model)


func _fills_every_cargo_crate_s_square(box: AABB) -> void:
	var crates := 0
	for file in DirAccess.get_files_at("res://data/ships"):
		if not file.ends_with(".tres"):
			continue
		var layout: ShipLayout = load("res://data/ships".path_join(file))
		for prop: ShipProp in layout.props:
			if prop.kind != &"cargo":
				continue
			crates += 1
			var half := prop.radius * ShipArt.CRATE_SIDE + ShipArt.CRATE_PROUD
			var low := Vector3(-half, 0.0, -half)
			var high := Vector3(half, prop.height, half)
			assert_almost_eq(box.position, low, Vector3.ONE * TOLERANCE, "%s's crates" % file)
			assert_almost_eq(box.end, high, Vector3.ONE * TOLERANCE, "%s's crates" % file)
	assert_gt(crates, 0, "the ships carry crates")


## A berth: BERTH long either side of its middle and BERTH deep off its wall, from
## its underside at HEADROOM up to its chains' eyes: the steel at each end, its top's
## middle at BERTH_EYE, where slung_berth hangs a chain from. Its blanket is painted
## blanket, the surface slung_berth repaints in its cabin's colour.
func _fills_the_berth_s_length_and_depth_off_its_wall(box: AABB) -> void:
	var berth := RoomDressing.BERTH
	var low := Vector3(-berth.x * 0.5, 0.0, 0.0)
	var high := Vector3(berth.x * 0.5, RoomDressing.BERTH_RISE, berth.y)
	assert_almost_eq(box.position, low, Vector3.ONE * TOLERANCE, "berth: head, under, wall")
	assert_almost_eq(box.end, high, Vector3.ONE * TOLERANCE, "berth: foot, eyes, front")
	assert_gte(box.position.y, -0.001, "berth: nothing under HEADROOM")
	assert_gte(box.position.z, -0.001, "berth: nothing in its wall")
	var eyes := {-1.0: PackedVector3Array(), 1.0: PackedVector3Array()}
	var blankets := 0
	for surface: ShipModel.Surface in ShipModel.named(RoomDressing.BERTH_MODEL).surfaces:
		blankets += 1 if surface.paint == ShipPaints.blanket else 0
		if surface.paint == ShipPaints.steel:
			for point in surface.points:
				eyes[signf(point.x)].append(point)
	assert_gt(blankets, 0, "berth: a blanket for its cabin's colour")
	for end: float in eyes:
		var points: PackedVector3Array = eyes[end]
		assert_gt(points.size(), 0, "berth: an eye at each end")
		var eye := AABB(points[0], Vector3.ZERO)
		for point in points:
			eye = eye.expand(point)
		var top := Vector3(eye.get_center().x, eye.end.y, eye.get_center().z)
		var wanted := Vector3(end * RoomDressing.BERTH_EYE.x, 0.0, 0.0)
		wanted += Vector3(0.0, RoomDressing.BERTH_EYE.y, RoomDressing.BERTH_EYE.z)
		assert_almost_eq(top, wanted, Vector3.ONE * PART, "berth: its chain's eye")


## A lifebelt: its ring LIFEBELT_RADIUS round its middle, standing LIFEBELT_DEPTH out
## from its wall, its grab line no more than LIFEBELT_LINE past it — the size of the
## lifebuoy kind (#273), which the match moves: Godot's form, the model inside it.
func _hangs_the_lifebelt_flat_on_its_wall(box: AABB) -> void:
	var kind := PropKind.named(&"lifebuoy")
	assert_eq(kind.radius, RoomDressing.LIFEBELT_RADIUS, "lifebelt: the lifebuoy kind's radius")
	assert_eq(kind.height, RoomDressing.LIFEBELT_DEPTH, "lifebelt: its thickness")
	var ring := RoomDressing.LIFEBELT_RADIUS
	var line := ring + RoomDressing.LIFEBELT_LINE
	assert_almost_eq(box.position.z, 0.0, TOLERANCE, "lifebelt: on its wall")
	assert_almost_eq(box.end.z, RoomDressing.LIFEBELT_DEPTH, TOLERANCE, "lifebelt: its face")
	assert_almost_eq(box.get_center().x, 0.0, TOLERANCE, "lifebelt: round its middle")
	for reach: float in [box.end.x, -box.position.x, box.end.y, -box.position.y]:
		assert_between(reach, ring, line, "lifebelt: its ring and its grab line")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "lifebelt: flat on its wall")


func _fills_the_fire_buckets_rack_off_its_wall(box: AABB) -> void:
	var wanted := RoomDressing.FIRE_BUCKETS
	assert_almost_eq(box.position, wanted.position, Vector3.ONE * TOLERANCE, "fire buckets: low")
	assert_almost_eq(box.end, wanted.end, Vector3.ONE * TOLERANCE, "fire buckets: high")
	assert_gte(box.position.y, -0.001, "fire buckets: nothing under HEADROOM")
	assert_gte(box.position.z, -0.001, "fire buckets: nothing in its wall")


## A lamp swings round where it hangs (ShipLamp): nothing of it more than its swivel's
## ball over that, its globe's foot [param drop] under it, [param reach] round it.
func _hangs_a_lamp(box: AABB, drop: float, reach: float, lamp: String) -> void:
	assert_between(box.end.y, 0.0, TOLERANCE, "%s: its swivel in the ceiling" % lamp)
	assert_almost_eq(box.position.y, -drop, TOLERANCE, "%s: its globe's foot" % lamp)
	assert_almost_eq(box.get_center() * Vector3(1, 0, 1), Vector3.ZERO, Vector3.ONE * 0.001, lamp)
	for across: float in [box.size.x, box.size.z]:
		assert_almost_eq(across * 0.5, reach, TOLERANCE, "%s: round its cord" % lamp)


func _hangs_the_pendant_s_globe_from_its_swivel(box: AABB) -> void:
	var drop := ShipLamp.CORD + ShipLamp.GLOBE_RADIUS
	_hangs_a_lamp(box, drop, ShipLamp.GLOBE_RADIUS, "pendant lamp")


func _hangs_the_cargo_lamp_s_globe_under_its_shade(box: AABB) -> void:
	var drop := ShipLamp.CARGO_CORD + ShipLamp.GLOBE_RADIUS
	_hangs_a_lamp(box, drop, ShipLamp.CARGO_SHADE, "cargo lamp")


## The fire fills the furnace's mouth (ShipLamp.MOUTH) up to its ragged crown, standing
## MOUTH_PROUD out, behind the boiler front's grate bars a centimetre further out.
func _fills_the_furnace_s_mouth_behind_its_bars(box: AABB) -> void:
	var half := ShipLamp.MOUTH * 0.5
	assert_almost_eq(box.position.x, -half.x, TOLERANCE, "fire: across the mouth")
	assert_almost_eq(box.end.x, half.x, TOLERANCE, "fire: across the mouth")
	assert_almost_eq(box.position.y, -half.y, TOLERANCE, "fire: the mouth's foot")
	assert_between(box.end.y, half.y * 0.5, half.y, "fire: its crown under the mouth's top")
	assert_almost_eq(box.position.z, ShipLamp.MOUTH_PROUD, TOLERANCE, "fire: in its mouth")
	assert_lte(box.end.z, ShipLamp.MOUTH_PROUD + 0.004, "fire: behind the grate bars")


## The break door: its box ShipFittings.BREAK_DOOR_BOX, on the face and no further
## out from it than a furnishing may stand (art-lint), round BREAK_DOOR standing on
## its sill.
func _stands_the_break_door_in_its_frame_on_the_face(box: AABB) -> void:
	var wanted := ShipFittings.BREAK_DOOR_BOX
	assert_almost_eq(box.position, wanted.position, Vector3.ONE * TOLERANCE, "break door: low")
	assert_almost_eq(box.end, wanted.end, Vector3.ONE * TOLERANCE, "break door: high")
	assert_gte(box.position.z, -0.001, "break door: nothing in the face")
	assert_gte(box.position.y, -0.001, "break door: nothing under the deck")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "break door: flat to the face")
	var door := ShipFittings.BREAK_DOOR
	assert_gt(box.size.x, door.x, "break door: its frame round the door")
	assert_gt(box.end.y, ShipFittings.BREAK_DOOR_SILL + door.y, "break door: its head")
	assert_almost_eq(box.get_center().x, 0.0, PART, "break door: square on its sill")


## A deck pipe's mouth [param model] made for [param radius]
## (ShipFittings.DECK_PIPES): its flange that round its axis, on the deck and no
## higher than DECK_PIPE_RISE, under a toe rail's height.
func _is_the_deck_pipe_made_for(box: AABB, radius: float, model: String) -> void:
	assert_eq(ShipFittings.DECK_PIPES.get(radius), model, "DECK_PIPES names it")
	for reach: float in [box.end.x, -box.position.x, box.end.z, -box.position.z]:
		assert_almost_eq(reach, radius, PART, "%s: its flange's radius" % model)
	assert_almost_eq(box.position.y, 0.0, 0.001, "%s: on the deck, nothing under it" % model)
	assert_lte(box.end.y, ShipFittings.DECK_PIPE_RISE + 0.001, "%s: its lip" % model)
	assert_lt(box.end.y, ShipHull.TOE_RAIL_HEIGHT, "%s: under a toe rail's height" % model)


## A stowed crate [param model] made for [param side] (CargoHold.STOWED_CRATES): that
## square round its middle, on its underside and STOWED_CRATE_HEIGHTS' height for it
## tall, never past either: the crate stacked on it sits on its lashing.
func _is_the_stowed_crate_made_for(box: AABB, side: float, model: String) -> void:
	assert_eq(CargoHold.STOWED_CRATES.get(side), model, "STOWED_CRATES names it")
	var height: float = CargoHold.STOWED_CRATE_HEIGHTS[side]
	assert_almost_eq(box.size.x, side, PART, "%s: its side" % model)
	assert_almost_eq(box.size.z, side, PART, "%s: its side" % model)
	assert_lte(box.size.x, side + 0.001, "%s: within its square" % model)
	assert_lte(box.size.z, side + 0.001, "%s: within its square" % model)
	assert_almost_eq(box.get_center() * Vector3(1, 0, 1), Vector3.ZERO, Vector3.ONE * 0.001)
	assert_almost_eq(box.position.y, 0.0, 0.001, "%s: on its underside" % model)
	assert_almost_eq(box.end.y, height, PART, "%s: its height" % model)
	assert_lte(box.end.y, height + 0.001, "%s: no taller" % model)


## The wall clock: its bezel RoomDressing.CLOCK_RADIUS round its dial's middle, no
## bigger than the clearance the dining saloon and the baths keep for it, flat on its
## wall CLOCK_DEPTH out.
func _hangs_the_clock_flat_on_its_wall(box: AABB) -> void:
	var radius := RoomDressing.CLOCK_RADIUS
	for reach: float in [box.end.x, -box.position.x, box.end.y, -box.position.y]:
		assert_almost_eq(reach, radius, PART, "clock: its bezel's radius")
	assert_lte(radius, LinerDining.CLOCK, "clock: in the dining saloon's clearance")
	assert_lte(radius, LinerBath.CLOCK, "clock: in the baths' clearance")
	assert_almost_eq(box.position.z, 0.0, 0.001, "clock: on its wall")
	assert_almost_eq(box.end.z, RoomDressing.CLOCK_DEPTH, PART, "clock: its bezel's crown")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "clock: flat on its wall")


## The brass sconce public rooms and corridors hang: square round its plate's middle,
## on its wall, no further out than SCONCE_REACH (within each room's depth) nor over
## SCONCE_RISE.
func _hangs_the_tulip_sconce_flat_on_its_wall(box: AABB) -> void:
	assert_almost_eq(box.get_center().x, 0.0, PART, "sconce: square on its plate")
	assert_almost_eq(box.position.z, 0.0, 0.001, "sconce: on its wall")
	assert_almost_eq(box.end.z, RoomDressing.SCONCE_REACH, PART, "sconce: its shade's lip")
	assert_lte(box.end.z, RoomDressing.SCONCE_REACH + 0.001, "sconce: no further out")
	assert_lte(RoomDressing.SCONCE_REACH, LinerCorridor.SCONCE_DEPTH, "in a corridor's depth")
	assert_lte(RoomDressing.SCONCE_REACH, LinerPublic.DEPTH, "in a public room's depth")
	assert_almost_eq(box.end.y, RoomDressing.SCONCE_RISE, PART, "sconce: its shade's top")


## The dining saloon's sconce: its globe SCONCE_GLOBE round, its middle SCONCE_OUT out
## and SCONCE_LIFT up, square on its plate and flat on its wall.
func _hangs_the_dining_sconce_s_globe_off_its_wall(box: AABB) -> void:
	var globe := LinerDining.SCONCE_GLOBE
	assert_almost_eq(box.get_center().x, 0.0, PART, "sconce: square on its plate")
	assert_almost_eq(box.position.z, 0.0, 0.001, "sconce: on its wall")
	assert_almost_eq(box.end.z, LinerDining.SCONCE_OUT + globe, PART, "sconce: its globe")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "sconce: flat on its wall")
	var glass := AABB()
	var first := true
	for surface: ShipModel.Surface in ShipModel.named(LinerDining.SCONCE_MODEL).surfaces:
		if surface.paint != ShipPaints.sconce_glass:
			continue
		for point in surface.points:
			glass = AABB(point, Vector3.ZERO) if first else glass.expand(point)
			first = false
	assert_false(first, "sconce: a globe of sconce glass")
	var middle := Vector3(0.0, LinerDining.SCONCE_LIFT, LinerDining.SCONCE_OUT)
	var centre := glass.get_center() * Vector3(1, 0, 1) + Vector3.UP * middle.y
	assert_almost_eq(centre, middle, Vector3.ONE * PART, "sconce: its globe's middle")
	assert_almost_eq(glass.end.y, middle.y + globe, PART, "sconce: its globe's crown")


## The dining saloon's capital: as wide as CAPITAL.x, CAPITAL_HEIGHT tall, CAPITAL.y out.
static func _dining_capital() -> Vector3:
	return Vector3(LinerDining.CAPITAL.x, LinerDining.CAPITAL_HEIGHT, LinerDining.CAPITAL.y)


## A capital [param model] made for [param size]'s width (RoomDressing.CAPITALS):
## hanging that tall from its origin under the ceiling, that wide square across it
## and that far out from its wall.
func _is_the_capital_made_for(box: AABB, size: Vector3, model: String) -> void:
	assert_eq(RoomDressing.variant(RoomDressing.CAPITALS, size.x), model, "CAPITALS names it")
	assert_almost_eq(box.size.x, size.x, PART, "%s: its width" % model)
	assert_almost_eq(box.get_center().x, 0.0, PART, "%s: square across it" % model)
	assert_almost_eq(box.end.y, 0.0, 0.001, "%s: up to the ceiling" % model)
	assert_almost_eq(box.position.y, -size.y, PART, "%s: its height" % model)
	assert_almost_eq(box.position.z, 0.0, 0.001, "%s: on its wall" % model)
	assert_almost_eq(box.end.z, size.z, PART, "%s: its depth" % model)


## A public room's pilaster base: LinerPublic.PILASTER_BASE on the floor at its wall.
func _stands_the_pilaster_base_on_the_floor(box: AABB) -> void:
	var size := LinerPublic.PILASTER_BASE
	var wanted := AABB(Vector3(-size.x * 0.5, 0.0, 0.0), size)
	assert_almost_eq(box.position, wanted.position, Vector3.ONE * PART, "pilaster base: low")
	assert_almost_eq(box.end, wanted.end, Vector3.ONE * PART, "pilaster base: high")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "pilaster base: flat on its wall")


## A stateroom door: LinerCorridor.DOOR on the floor in its ARCHITRAVE, its knob
## DOOR_KNOB out of its face DOOR_DEPTH out of the wall.
func _stands_the_stateroom_door_in_its_architrave(box: AABB) -> void:
	var door := LinerCorridor.DOOR
	var trim := LinerCorridor.ARCHITRAVE
	var half := door.x * 0.5 + trim
	var low := Vector3(-half, 0.0, 0.0)
	var high := Vector3(half, door.y + trim, LinerCorridor.DOOR_DEPTH + LinerCorridor.DOOR_KNOB)
	assert_almost_eq(box.position, low, Vector3.ONE * PART, "stateroom door: low")
	assert_almost_eq(box.end, high, Vector3.ONE * PART, "stateroom door: high")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "stateroom door: flat on its wall")


## The café's hanging basket: from its hook down BASKET_DROP to its rim and
## BASKET_DEPTH to its foot, its leaves spread no further than BASKET_SPREAD.
func _hangs_the_basket_from_its_hook(box: AABB) -> void:
	var foot := -LinerPublic.BASKET_DROP - LinerPublic.BASKET_DEPTH
	assert_almost_eq(box.end.y, 0.0, PART, "basket: from its hook")
	assert_almost_eq(box.position.y, foot, PART, "basket: its foot")
	assert_gte(box.position.y, foot - 0.001, "basket: nothing under its foot")
	for reach: float in [box.end.x, -box.position.x, box.end.z, -box.position.z]:
		assert_between(reach, LinerPublic.BASKET, LinerPublic.BASKET_SPREAD, "basket: round")


## A copper pan [param model] made for [param radius] (LinerService.PANS): that round,
## square across its middle, hanging from the bar no further than its handle and its
## breadth.
func _is_the_pan_made_for(box: AABB, radius: float, model: String) -> void:
	assert_eq(LinerService.PANS.get(radius), model, "PANS names it")
	assert_almost_eq(box.size.x, radius * 2.0, PART, "%s: its radius" % model)
	assert_almost_eq(box.get_center().x, 0.0, PART, "%s: square across it" % model)
	assert_almost_eq(box.end.y, 0.0, PART, "%s: from the bar" % model)
	var drop := LinerService.PAN_HANDLE + radius * 2.0
	assert_almost_eq(box.position.y, -drop, TOLERANCE, "%s: its foot" % model)
	assert_gte(box.position.y, -drop - 0.001, "%s: no further down" % model)


func _hangs_the_stockpot_from_the_rack(box: AABB) -> void:
	_fills_its_box(box, LinerService.STOCKPOT, "stockpot")
	assert_lte(box.end.y, 0.0, "stockpot: under the bar")


## A ladle [param model] made to hang [param drop] (LinerService.LADLES): its bowl's
## foot that far under the bar, square across its middle.
func _is_the_ladle_made_for(box: AABB, drop: float, model: String) -> void:
	assert_eq(LinerService.LADLES.get(drop), model, "LADLES names it")
	assert_almost_eq(box.position.y, -drop, PART, "%s: its foot" % model)
	assert_gte(box.position.y, -drop - 0.001, "%s: no further down" % model)
	assert_almost_eq(box.end.y, 0.0, PART, "%s: from the bar" % model)
	assert_almost_eq(box.get_center().x, 0.0, PART, "%s: square across it" % model)


## A dresser [param model] made [param width] wide (LinerService.DRESSERS): that wide,
## square across its middle, from DRESSER.x to DRESSER.y over the floor, flat to its
## wall.
func _is_the_dresser_made_for(box: AABB, width: float, model: String) -> void:
	assert_eq(LinerService.DRESSERS.get(width), model, "DRESSERS names it")
	assert_almost_eq(box.size.x, width, PART, "%s: its width" % model)
	assert_almost_eq(box.get_center().x, 0.0, PART, "%s: square across it" % model)
	assert_almost_eq(box.position.y, LinerService.DRESSER.x, PART, "%s: its foot" % model)
	assert_almost_eq(box.end.y, LinerService.DRESSER.y, PART, "%s: its top" % model)
	assert_gte(box.position.z, -0.001, "%s: nothing in its wall" % model)
	assert_lte(box.end.z, LinerService.FLAT + 0.001, "%s: flat to its wall" % model)


func _hangs_the_mail_sack_over_headroom(box: AABB) -> void:
	_fills_its_box_off_its_wall(box, LinerService.MAIL_SACK, "mail sack")
	assert_gte(box.position.y, 0.0, "mail sack: nothing under HEADROOM")


## A fitting flat on its wall round its middle: its box, and under HEADROOM no further
## out than a furnishing may stand.
func _hangs_flat_on_its_wall(box: AABB, wanted: AABB, name: String) -> void:
	_fills_its_box_off_its_wall(box, wanted, name)
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, name + ": flat to its wall")


## The bath's lantern: round its pendant's cord, LinerBath.LANTERN round, nothing over
## where it hangs, its band's foot LANTERN_DROP under the globe's middle.
func _hangs_the_lantern_round_its_pendant(box: AABB) -> void:
	_fills_its_box(box, LinerBath.LANTERN_BOX, "lantern")
	assert_lte(box.end.y, 0.001, "lantern: nothing over where it hangs")
	assert_almost_eq(box.get_center() * Vector3(1, 0, 1), Vector3.ZERO, Vector3.ONE * 0.001)
	assert_almost_eq(box.size.x * 0.5, LinerBath.LANTERN, TOLERANCE, "lantern: its band")


## The pool's ladder: its box, its handles no higher over the rim than a body on it
## steps over, nothing of it behind the rim's back edge.
func _stands_the_ladder_over_the_pool_s_rim(box: AABB) -> void:
	_fills_its_box(box, LinerBath.LADDER, "pool ladder")
	var high := LinerBath.HANDLE + LinerBath.HANDLE_BAR
	assert_lte(box.end.y, high, "pool ladder: under its handles' height")
	assert_gte(box.position.x, -LinerBath.RIM, "pool ladder: on the rim")
	assert_almost_eq(box.size.z, LinerBath.LADDER_SPAN, 0.1, "pool ladder: its span")


## The dining saloon's electrolier: its corona LinerDining.HOOP round its origin, its
## gilt's underside HOOP_DROP under it, nothing over it nor more than ELECTROLIER_DEPTH
## under it.
func _hangs_the_electrolier_round_its_pendant(box: AABB) -> void:
	for reach: float in [box.end.x, -box.position.x, box.end.z, -box.position.z]:
		assert_almost_eq(reach, LinerDining.HOOP, PART, "electrolier: its corona's radius")
	assert_lte(box.end.y, 0.001, "electrolier: nothing over where it hangs from")
	var depth := LinerDining.ELECTROLIER_DEPTH
	assert_almost_eq(box.position.y, -depth, PART, "electrolier: its drops")
	assert_gte(box.position.y, -depth - 0.001, "electrolier: nothing lower")
	var lowest := INF
	for surface: ShipModel.Surface in ShipModel.named(LinerDining.ELECTROLIER_MODEL).surfaces:
		if surface.paint != ShipPaints.gilt:
			continue
		for point in surface.points:
			lowest = minf(lowest, point.y)
	assert_almost_eq(lowest, -LinerDining.HOOP_DROP, PART, "electrolier: its corona's underside")


## The dining saloon's sideboard: SIDEBOARD long, deep and tall, its gallery over that.
static func _dining_sideboard() -> AABB:
	var size := LinerDining.SIDEBOARD
	var over := Vector3(size.x, size.z + LinerDining.SIDEBOARD_GALLERY, size.y)
	return AABB(Vector3(-size.x * 0.5, 0.0, 0.0), over)


## A sideboard [param model] made for [param wanted]'s length (CabinDressing.SIDEBOARDS),
## filling that box off its wall as a cabin's fitting does.
func _is_the_sideboard_made_for(box: AABB, wanted: AABB, model: String) -> void:
	var made := RoomDressing.variant(CabinDressing.SIDEBOARDS, wanted.size.x)
	assert_eq(made, model, "SIDEBOARDS names it")
	_fills_a_cabin_fitting_s_box(box, wanted, model)
	assert_almost_eq(box.size.x, wanted.size.x, PART, "%s: its length" % model)


## A dining chair tucked under a laid table: LinerDining.CHAIR wide, square across the
## table box's side, its back ShipMesh.SLIVER inside it, its crest CHAIR_HEIGHT over the
## floor, its front legs CHAIR_DEPTH in.
func _seats_the_chair_inside_its_table_s_box(box: AABB) -> void:
	assert_almost_eq(box.size.x, LinerDining.CHAIR.x, PART, "chair: its width")
	assert_almost_eq(box.get_center().x, 0.0, PART, "chair: square on its side")
	assert_almost_eq(box.position.y, 0.0, 0.001, "chair: on the floor")
	assert_almost_eq(box.end.y, LinerDining.CHAIR_HEIGHT, PART, "chair: its crest")
	assert_almost_eq(box.end.z, -ShipMesh.SLIVER, 0.001, "chair: its back inside the box")
	assert_almost_eq(box.position.z, -LinerDining.CHAIR_DEPTH, PART, "chair: its front legs")


## A plain saloon's serving hatch: its opening LinerDining.HATCH each way from its
## origin in its HATCH_RIM, its shelf HATCH_SILL under that and its brackets
## HATCH_BRACKET under the shelf, flat on its wall.
func _hangs_the_serving_hatch_in_its_wall(box: AABB) -> void:
	var rim := LinerDining.HATCH + Vector2.ONE * LinerDining.HATCH_RIM
	var sill := LinerDining.HATCH_SILL
	var low := Vector3(-rim.x, -rim.y - sill.x - LinerDining.HATCH_BRACKET, 0.0)
	var high := Vector3(rim.x, rim.y, sill.y)
	assert_almost_eq(box.position, low, Vector3.ONE * PART, "serving hatch: low")
	assert_almost_eq(box.end, high, Vector3.ONE * PART, "serving hatch: high")
	assert_lte(box.end.z, FurnishingCheck.TOLERANCE, "serving hatch: flat on its wall")


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
