extends GutTest
## Her art packed as a match draws it (ShipArt.pack) draws what the unpacked art does, in
## fewer nodes: each indoor chunk's walls and furnishings one instance, the same faces
## in the same paints; every hanging lamp an instance of a MultiMesh, hung, swung and
## glowing as the lamp; every door sign's letters held, drawn near the eye; and what the
## sinking has yet to show stands apart from her until it does.

const RunMatch := preload("res://tools/run_match.gd")
const FurnishingCheck := preload("res://tools/furnishing_check.gd")

var _layout: ShipLayout
var _rules: BrawlRules
var _loose: ShipArt
var _packed: ShipArt


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_loose = _built(false)
	_packed = _built(true)


func after_all() -> void:
	_loose.free()
	_packed.free()


func _built(pack: bool) -> ShipArt:
	var art := ShipArt.new()
	art.rules = _rules
	art.pack = pack
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	return art


## [param parent]'s indoor chunks (ShipMesh.commit), by name.
func _chunks(parent: Node) -> Dictionary:
	var found := {}
	for child: Node in parent.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("in_"):
			found[String(child.name)] = child
	return found


func test_each_chunk_draws_its_walls_then_its_furnishings_in_their_paints() -> void:
	var walls := _chunks(_loose)
	var furnishings := _chunks(_loose.get_node("Dressing"))
	var packed := _chunks(_packed)
	assert_eq(_chunks(_packed.get_node("Dressing")).size(), 0, "no chunk left apart")
	var names := walls.keys()
	for name: String in furnishings:
		if not name in names:
			names.append(name)
	assert_eq(packed.size(), names.size())
	assert_lt(packed.size(), walls.size() + furnishings.size())
	for name: String in names:
		assert_true(packed.has(name), name)
		if not packed.has(name):
			continue
		var surfaces: Array[Array] = []
		for loose: Dictionary in [walls, furnishings]:
			if loose.has(name):
				var mesh := (loose[name] as MeshInstance3D).mesh
				for surface in mesh.get_surface_count():
					surfaces.append([mesh, surface, loose == furnishings])
		var mesh: ArrayMesh = (packed[name] as MeshInstance3D).mesh
		# Her glass rides after them (test_her_glass_rides_in_its_chunk_where_it_lies_inside_it).
		var walled := 0
		while walled < mesh.get_surface_count():
			if mesh.surface_get_name(walled) == String(PackedChunks.GLASS):
				break
			walled += 1
		for surface in range(walled, mesh.get_surface_count()):
			assert_eq(mesh.surface_get_name(surface), String(PackedChunks.GLASS), name)
		assert_eq(walled, surfaces.size(), name)
		for index in mini(walled, surfaces.size()):
			var from: ArrayMesh = surfaces[index][0]
			var surface: int = surfaces[index][1]
			var wanted := from.surface_get_arrays(surface)
			var got := mesh.surface_get_arrays(index)
			assert_eq(got[Mesh.ARRAY_VERTEX], wanted[Mesh.ARRAY_VERTEX], name)
			assert_eq(got[Mesh.ARRAY_INDEX], wanted[Mesh.ARRAY_INDEX], name)
			assert_eq(got[Mesh.ARRAY_COLOR], wanted[Mesh.ARRAY_COLOR], name)
			assert_eq(got[Mesh.ARRAY_CUSTOM0], wanted[Mesh.ARRAY_CUSTOM0], name)
			var paint := mesh.surface_get_material(index) as ShaderMaterial
			var was := from.surface_get_material(surface) as ShaderMaterial
			assert_eq(paint.shader, was.shader, name)
			assert_eq(paint.get_shader_parameter("finish"), was.get_shader_parameter("finish"))
			var furnishing: bool = surfaces[index][2]
			assert_eq(mesh.surface_get_name(index) == String(ShipArt.FURNISHING), furnishing)


## [param parent]'s glass in chunks (ShipMesh.commit): its instances named "<finish>_in_…",
## by name.
func _glass(parent: Node) -> Dictionary:
	var found := {}
	for child: Node in parent.get_children():
		var name := String(child.name)
		if child is MeshInstance3D and name.contains("_in_") and not name.begins_with("Railing"):
			found[name] = child
	return found


func test_her_glass_rides_in_its_chunk_where_it_lies_inside_it() -> void:
	var loose := _glass(_loose)
	var apart := _glass(_packed)
	var chunks := _chunks(_packed)
	assert_gt(loose.size(), 0, "she has glass indoors")
	var riding := 0
	for name: String in loose:
		var was := (loose[name] as MeshInstance3D).mesh
		assert_eq(was.get_surface_count(), 1, name)
		var wanted := was.surface_get_arrays(0)
		var chunk: MeshInstance3D = chunks.get(name.substr(name.find("in_")))
		var found := -1
		var riding_in := chunk.mesh as ArrayMesh if chunk != null else null
		if riding_in != null:
			for surface in riding_in.get_surface_count():
				var got := riding_in.surface_get_arrays(surface)
				var glass := riding_in.surface_get_name(surface) == String(PackedChunks.GLASS)
				if glass and got[Mesh.ARRAY_VERTEX] == wanted[Mesh.ARRAY_VERTEX]:
					found = surface
		if found == -1:
			assert_true(apart.has(name), "%s: in its chunk or its own instance" % name)
			if not apart.has(name):
				continue
			var own := (apart[name] as MeshInstance3D).mesh
			assert_eq(own.surface_get_arrays(0)[Mesh.ARRAY_INDEX], wanted[Mesh.ARRAY_INDEX])
			_assert_same_glass(own.surface_get_material(0), was.surface_get_material(0), name)
			assert_false(chunk != null and chunk.mesh.get_aabb().encloses(was.get_aabb()), name)
			continue
		riding += 1
		assert_false(apart.has(name), "%s: drawn once" % name)
		var got := chunk.mesh.surface_get_arrays(found)
		assert_eq(got[Mesh.ARRAY_INDEX], wanted[Mesh.ARRAY_INDEX], name)
		assert_eq(got[Mesh.ARRAY_TEX_UV2], wanted[Mesh.ARRAY_TEX_UV2], name)
		_assert_same_glass(
			chunk.mesh.surface_get_material(found), was.surface_get_material(0), name
		)
	assert_gt(riding, 0, "some glass rides in its chunk")
	assert_eq(apart.size(), loose.size() - riding, "the rest each its own instance")


func _assert_same_glass(got: Material, wanted: Material, name: String) -> void:
	var paint := got as ShaderMaterial
	var was := wanted as ShaderMaterial
	assert_eq(paint.shader, was.shader, name)
	assert_eq(paint.get_shader_parameter("outside"), was.get_shader_parameter("outside"), name)


func test_a_chunk_meets_the_lamps_it_met_before_what_rides_in_it() -> void:
	# A lamp lights the instances its range reaches: a chunk's box is its walls' and
	# furnishings' alone, whatever glass and railings ride in it.
	var art := _breakable()
	for chunk: MeshInstance3D in _chunks(art).values():
		var own := ArrayMesh.new()
		var mesh := chunk.mesh as ArrayMesh
		for surface in mesh.get_surface_count():
			if mesh.surface_get_name(surface) in [String(ShipArt.FURNISHING), ""]:
				var corners := []
				corners.resize(Mesh.ARRAY_MAX)
				corners[Mesh.ARRAY_VERTEX] = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				own.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, corners)
		assert_eq(mesh.get_aabb(), own.get_aabb(), chunk.name)
	art.free()


## Her art packed as the match draws her, every railing breakable.
func _breakable() -> ShipArt:
	var art := ShipArt.new()
	art.rules = _rules
	art.pack = true
	var none: Array[StringName] = []
	var every := PackedInt32Array(range(_layout.railings.size()))
	art.build(_layout, _rules.railing_height, _rules.body_radius, none, every)
	return art


func test_the_furnishings_read_back_are_the_same_faces() -> void:
	var loose := FurnishingCheck.furnishings(_loose)
	assert_gt(loose.size(), 0)
	assert_eq(FurnishingCheck.furnishings(_packed).size(), loose.size())
	var packed := _chunks(_packed)
	for name: String in _chunks(_loose.get_node("Dressing")):
		var was := (_chunks(_loose.get_node("Dressing"))[name] as MeshInstance3D).mesh.get_faces()
		var mesh := (packed[name] as MeshInstance3D).mesh
		assert_true(FurnishingCheck.packed_faces(mesh, ShipArt.FURNISHING) == was, name)


func _hanging(art: ShipArt) -> Array[ShipLamp]:
	var lamps: Array[ShipLamp] = []
	for child: Node in art.get_children():
		if child is ShipLamp and (child as ShipLamp).kind() != ShipLamp.Kind.FIRE:
			lamps.append(child)
	return lamps


func test_every_hanging_lamp_is_drawn_by_the_globes_where_it_hangs() -> void:
	var lamps := _hanging(_packed)
	var globes := _packed.get_node("Globes") as LampGlobes
	assert_gt(lamps.size(), 0)
	assert_eq(globes.size(), lamps.size())
	assert_lt(globes.get_child_count(), lamps.size())
	var drawn := 0
	for multi: MultiMeshInstance3D in globes.get_children():
		drawn += multi.multimesh.instance_count
		for surface in multi.multimesh.mesh.get_surface_count():
			var paint := multi.multimesh.mesh.surface_get_material(surface) as ShaderMaterial
			var shaders: Array[Shader] = [
				LampGlobes.GLASS_SHADER, LampGlobes.METAL_SHADER, LampGlobes.TIN_SHADER
			]
			assert_true(paint.shader in shaders)
			assert_eq(paint.get_shader_parameter("distance_fade_max"), RoomDressing.NEAR_FADE.y)
	assert_eq(drawn, lamps.size())
	var slots := {}
	for lamp: ShipLamp in lamps:
		assert_eq(lamp.find_children("*", "MeshInstance3D", false, false).size(), 0)
		assert_ne(lamp.globe(), -1)
		slots[lamp.globe()] = true
		assert_eq(globes.placed(lamp.globe()), lamp.transform)
		assert_eq(globes.lit(lamp.globe()), Vector2(1.0, 0.0), "lit as its glass")
	assert_eq(slots.size(), lamps.size(), "a slot each")
	var loose := _hanging(_loose)
	assert_eq(loose.size(), lamps.size())
	var faces := 0
	for lamp: ShipLamp in loose:
		var parts := lamp.find_children("*", "MeshInstance3D", false, false)
		assert_eq(parts.size(), 1)
		faces += (parts[0] as MeshInstance3D).mesh.get_faces().size()
	assert_eq(globes.faces().size(), faces, "every lamp's model drawn")


func test_a_drawn_lamp_glows_red_on_emergency_power_and_swings_as_its_own() -> void:
	var art := _built(true)
	add_child_autofree(art)
	var lamp: ShipLamp = _hanging(art)[0]
	var globes := art.get_node("Globes") as LampGlobes
	lamp.power = ShipPower.Power.EMERGENCY
	art.rotation.z = 0.3
	for _frame in 40:
		lamp._process(0.05)
	var lit := globes.lit(lamp.globe())
	assert_eq(lit.y, 1.0, "red")
	assert_almost_eq(lit.x, ShipLamp.EMERGENCY_GLOW, 0.001)
	assert_eq(globes.placed(lamp.globe()), lamp.transform)
	assert_gt(lamp.basis.y.angle_to(Vector3.UP), 0.05, "swung toward her new down")


func test_every_sign_is_held_and_drawn_only_near_the_eye() -> void:
	var texts: Array[String] = []
	for child: Node in _loose.get_node("Dressing").get_children():
		if child is Label3D:
			texts.append((child as Label3D).text)
	assert_gt(texts.size(), 0)
	var signs := _packed.get_node("Dressing/Signs") as SignPool
	var held: Array[String] = []
	for label: Label3D in signs.signs():
		held.append(label.text)
	texts.sort()
	held.sort()
	assert_eq(held, texts)
	assert_eq(signs.drawn(), 0)
	var eye: Vector3 = signs.signs()[0].position
	signs.show_near(eye)
	assert_gt(signs.drawn(), 0)
	for label: Label3D in signs.signs():
		var near := label.position.distance_to(eye) <= SignPool.READ and label.visible
		assert_eq(label.get_parent() == signs, near)
	signs.show_near(eye + Vector3.UP * 1000.0)
	assert_eq(signs.drawn(), 0)


func test_what_the_sinking_has_yet_to_show_stands_apart_until_it_does() -> void:
	var node := Node3D.new()
	var parent := Node3D.new()
	parent.add_child(node)
	add_child_autofree(parent)
	node.position = Vector3(1.0, 2.0, 3.0)
	ShipArt.show_apart(node, false)
	assert_true(node.top_level)
	assert_false(node.visible)
	parent.position = Vector3(5.0, 0.0, 0.0)
	ShipArt.show_apart(node, true)
	assert_false(node.top_level)
	assert_true(node.visible)
	assert_eq(node.position, Vector3(1.0, 2.0, 3.0))
	assert_eq(node.global_position, Vector3(6.0, 2.0, 3.0))
