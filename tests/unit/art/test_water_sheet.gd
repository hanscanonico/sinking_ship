extends GutTest
## A pour's sheets keep what they were handed (WaterSheet, #410): a frame hands each one
## only what changed — its place, its extent, how hard it pours, how far it is thrown,
## the sky's light on it — and what it draws is what it would draw were everything
## handed again, frame after frame as her real ships sink, natively and in GDScript.

const RunMatch := preload("res://tools/run_match.gd")
const SEA := preload("res://scenes/art/water.gdshader")
const SHIPS: Array[StringName] = [&"steamer", &"small_titanic"]
const SEED := 4
## How many ticks each step checked spans, and where between its two poses each of its
## frames is drawn: the same pair of poses drawn at several moments, as frames are.
const STRIDE := 15
const ALPHAS: Array[float] = [0.5, 1.0]
## What a sheet keeps, and a value none is ever handed, set behind its back.
const HUNG: Array[StringName] = [&"extent", &"strength", &"thrown", &"outdoor"]
const LAID: Array[StringName] = [&"extent", &"strength", &"burst"]
const POKED := -7.0
## What is read of each drawn thing's material, as test_water_fx_native reads it.
const PARAMS: Array[StringName] = [
	&"clip_low",
	&"clip_high",
	&"outdoor",
	&"waders",
	&"wader_count",
	&"inflow",
	&"pocket_glow",
	&"world_to_ship",
	&"extent",
	&"strength",
	&"thrown",
	&"burst",
	&"leaking",
]


func test_a_hung_sheet_handed_what_it_has_hands_on_nothing() -> void:
	var sheet := _sheet(InnerWater.SPILL_SHADER)
	var material := sheet.material_override as ShaderMaterial
	var basis := Basis(Vector3(2.0, 0.0, 0.0), Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var middle := Vector3(1.0, 2.0, 3.0)
	var thrown := Vector3(0.0, 0.0, 0.25)
	sheet.hang(basis, middle, 0.5, thrown, 1.0)
	assert_true(sheet.visible, "shown")
	assert_eq(sheet.transform, Transform3D(basis, middle), "hung where handed")
	assert_eq(material.get_shader_parameter(&"extent"), Vector2(2.0, 3.0), "its extent")
	assert_eq(material.get_shader_parameter(&"strength"), 0.5, "its strength")
	assert_eq(material.get_shader_parameter(&"thrown"), thrown, "its throw")
	assert_eq(material.get_shader_parameter(&"outdoor"), 1.0, "its sky")
	var poked := _poke(sheet, HUNG)
	sheet.hang(basis, middle, 0.5, thrown, 1.0)
	assert_eq(sheet.transform, poked, "handed its place again, it does not set it")
	for param: StringName in HUNG:
		assert_eq(material.get_shader_parameter(param), POKED, "nor its %s" % param)
	sheet.hang(basis, middle, 0.75, thrown, 1.0)
	assert_eq(material.get_shader_parameter(&"strength"), 0.75, "a new strength is set")
	assert_eq(material.get_shader_parameter(&"extent"), POKED, "and that alone")
	assert_eq(sheet.transform, poked, "its place still not set")
	var moved := middle + Vector3(0.0, 0.5, 0.0)
	sheet.hang(basis, moved, 0.75, thrown, 1.0)
	assert_eq(sheet.transform, Transform3D(basis, moved), "moved, it is placed again")
	sheet.hang(basis, moved, 0.75, thrown * 2.0, 0.0)
	assert_eq(material.get_shader_parameter(&"thrown"), thrown * 2.0, "thrown further")
	assert_eq(material.get_shader_parameter(&"outdoor"), 0.0, "out of the sky")
	sheet.hang(basis.scaled(Vector3(1.0, 2.0, 1.0)), moved, 0.75, thrown * 2.0, 0.0)
	assert_eq(material.get_shader_parameter(&"extent"), Vector2(2.0, 6.0), "taller")


func test_a_laid_sheet_handed_what_it_has_hands_on_nothing() -> void:
	var sheet := _sheet(InnerWater.FROTH_SHADER)
	var material := sheet.material_override as ShaderMaterial
	var basis := Basis(Vector3(2.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 4.0))
	var at := Vector3(1.0, -2.0, 3.0)
	sheet.lay(basis, at, 0.5, -1.0)
	assert_true(sheet.visible, "shown")
	assert_eq(sheet.transform, Transform3D(basis, at), "laid where handed")
	assert_eq(material.get_shader_parameter(&"extent"), Vector2(2.0, 4.0), "its extent")
	assert_eq(material.get_shader_parameter(&"burst"), -1.0, "a landing, no burst")
	var poked := _poke(sheet, LAID)
	sheet.lay(basis, at, 0.5, -1.0)
	assert_eq(sheet.transform, poked, "handed its place again, it does not set it")
	for param: StringName in LAID:
		assert_eq(material.get_shader_parameter(param), POKED, "nor its %s" % param)
	sheet.lay(basis, at, 0.5, 0.0)
	assert_eq(material.get_shader_parameter(&"burst"), 0.0, "a new burst is set")
	assert_eq(material.get_shader_parameter(&"strength"), POKED, "and that alone")
	sheet.forget()
	sheet.lay(basis, at, 0.5, 0.0)
	assert_eq(sheet.transform, Transform3D(basis, at), "forgotten, it is handed everything")
	assert_eq(material.get_shader_parameter(&"extent"), Vector2(2.0, 4.0), "its extent too")
	assert_eq(material.get_shader_parameter(&"strength"), 0.5, "and its strength")


## Stood apart from her (InnerWater._stow) and hung again, a sheet stands where it is
## handed, though it was last handed the same: standing apart rewrote its own transform.
func test_a_sheet_stood_apart_is_placed_again() -> void:
	var holder: Node3D = add_child_autofree(Node3D.new())
	holder.transform = Transform3D(
		Basis(Vector3(0.3, 1.0, 0.2).normalized(), 0.7), Vector3(104.37, -3.9, 17.1)
	)
	var sheet := WaterSheet.new()
	var material := ShaderMaterial.new()
	material.shader = InnerWater.SPILL_SHADER
	sheet.material_override = material
	holder.add_child(sheet)
	var basis := Basis(Vector3(0.9, 0.1, 0.0), Vector3(0.05, 2.3, 0.1), Vector3(0.0, 0.1, 1.0))
	var hung := Transform3D(basis, Vector3(3.3, 1.7, -0.9))
	sheet.hang(hung.basis, hung.origin, 0.5, Vector3.ZERO, 0.0)
	sheet.visible = false
	sheet.top_level = true
	sheet.top_level = false
	assert_ne(sheet.transform, hung, "standing apart and back moved it by a rounding")
	sheet.top_level = true
	sheet.hang(hung.basis, hung.origin, 0.5, Vector3.ZERO, 0.0)
	assert_false(sheet.top_level, "hung on her again")
	assert_eq(sheet.transform, hung, "where it was handed, to the bit")


## Her water drawn as she sinks, by an InnerWater whose sheets keep what they were handed
## and by one whose sheets forget it before every frame, so each is handed everything:
## every sheet, pour, froth and light the same, frame after frame, its loops natively
## and in GDScript.
func test_her_water_is_drawn_as_were_everything_handed_again() -> void:
	for ship: StringName in SHIPS:
		var config := RunMatch.default_config(SEED, 2, ship)
		var schedule := config.schedule()
		var sea := ShaderMaterial.new()
		sea.shader = SEA
		for native: bool in [true, false]:
			var waters: Array[InnerWater] = []
			for side in 2:
				var water: InnerWater = add_child_autofree(InnerWater.new())
				if not native:
					water.native = null
				water.setup(
					config.ship.structure,
					config.ship.rooms,
					config.ship,
					schedule.passages(),
					schedule.failing(),
					sea,
					{}
				)
				waters.append(water)
			if native and waters[0].native == null:
				continue
			var differences: Array[String] = []
			var poured := 0
			for tick in range(0, schedule.end_tick(), STRIDE):
				var then := schedule.pose_at(tick)
				var now := schedule.pose_at(tick + STRIDE)
				for alpha: float in ALPHAS:
					_forget(waters[1])
					var drawn: Array[PackedByteArray] = []
					for water: InnerWater in waters:
						water.show_water(then, now, alpha)
						drawn.append(var_to_bytes(_state(water)))
					poured += _pouring(waters[0])
					if drawn[0] != drawn[1] and differences.size() < 4:
						differences.append("tick %d at %s" % [tick, alpha])
			var path := "natively" if native else "in GDScript"
			gut.p("%s %s: %d pours drawn" % [ship, path, poured])
			assert_eq(differences, [] as Array[String], "%s's water %s is alike" % [ship, path])
			assert_gt(poured, 0, "%s's sinking %s draws pours" % [ship, path])


## A sheet of [param shader] in the tree.
func _sheet(shader: Shader) -> WaterSheet:
	var sheet: WaterSheet = add_child_autofree(WaterSheet.new())
	var material := ShaderMaterial.new()
	material.shader = shader
	sheet.material_override = material
	return sheet


## Sets [param sheet]'s transform and its [param params] behind its back, to values no
## sheet is handed; the transform set.
func _poke(sheet: WaterSheet, params: Array[StringName]) -> Transform3D:
	var poked := Transform3D(Basis.IDENTITY, Vector3.ONE * POKED)
	sheet.transform = poked
	for param: StringName in params:
		(sheet.material_override as ShaderMaterial).set_shader_parameter(param, POKED)
	return poked


## Has every sheet of [param water] forget what it was handed.
func _forget(water: InnerWater) -> void:
	for child: Node in water.get_children():
		if child is WaterSheet:
			(child as WaterSheet).forget()


## How many of [param water]'s pours are shown.
func _pouring(water: InnerWater) -> int:
	var shown := 0
	for pour: WaterSheet in water._pours:
		if pour != null and pour.visible:
			shown += 1
	return shown


## [param water]'s every drawn thing, as bytes compare them.
func _state(water: InnerWater) -> Array:
	var state := []
	for child: Node in water.get_children():
		var drawn := child as Node3D
		if drawn == null:
			continue
		state.append(drawn.visible)
		var mesh := drawn as MeshInstance3D
		if mesh == null:
			state.append(drawn.position)
			continue
		state.append(mesh.top_level)
		state.append(mesh.transform)
		var material := mesh.material_override as ShaderMaterial
		for param: StringName in PARAMS:
			state.append(material.get_shader_parameter(param))
	return state
