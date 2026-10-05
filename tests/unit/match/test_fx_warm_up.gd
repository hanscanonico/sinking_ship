extends GutTest
## The sinking's effects build their shaders as the match starts (FxWarmUp), not the
## moment the iceberg strikes: every see-through mesh their pools draw — the strike's
## among them — is drawn once, as its emitter draws it, before the eye for a frame;
## then nothing of it is left.


func test_every_see_through_mesh_the_pools_draw_is_drawn_once() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var warm: FxWarmUp = autofree(FxWarmUp.new(fx.emitters()))
	var drawn := warm.meshes()
	var pooled: Array[Mesh] = []
	for emitter: CPUParticles3D in fx.emitters():
		if not FxWarmUp.see_through(emitter.mesh):
			assert_does_not_have(drawn, emitter.mesh, "%s is solid and shows" % emitter.name)
			continue
		assert_has(drawn, emitter.mesh, "%s is drawn" % emitter.name)
		if not pooled.has(emitter.mesh):
			pooled.append(emitter.mesh)
	assert_eq(drawn.size(), pooled.size(), "each mesh is drawn once")
	var gash: GashFx = fx.get_node("Gash")
	for emitter: CPUParticles3D in gash.emitters():
		assert_has(drawn, emitter.mesh, "the strike's %s is drawn" % emitter.name)
	var grains := warm.find_children("*", "MultiMeshInstance3D", false, false)
	assert_eq(grains.size(), drawn.size(), "one grain for each")
	for grain: MultiMeshInstance3D in grains:
		var laid := grain.multimesh
		assert_has(drawn, laid.mesh)
		assert_true(laid.use_colors and laid.use_custom_data, "laid out as a particle's")
		assert_eq(laid.instance_count, 1)


func test_it_is_drawn_before_the_eye_for_a_frame_then_gone() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.position = Vector3(3.0, 5.0, -2.0)
	camera.rotation_degrees = Vector3(-20.0, 70.0, 0.0)
	camera.make_current()
	var warm := FxWarmUp.new(fx.emitters())
	add_child(warm)
	assert_false(warm.visible, "nothing drawn until the eye is known")
	var seen := false
	for _frame in 4:
		await get_tree().process_frame
		if not is_instance_valid(warm):
			break
		if warm.visible:
			seen = true
			assert_true(camera.is_position_in_frustum(warm.global_position), "before the eye")
	assert_true(seen, "drawn for a frame")
	assert_false(is_instance_valid(warm), "nothing of it is left")
