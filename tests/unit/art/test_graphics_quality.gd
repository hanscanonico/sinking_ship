extends GutTest
## The graphics presets (GraphicsQuality): HIGH is the look as it was tuned in the
## scenes, and each cheaper preset costs no more than the one above it.

const SEA_AND_SKY := preload("res://scenes/art/sea_and_sky.tscn")


func test_high_is_the_look_as_tuned() -> void:
	var high := GraphicsQuality.of(GraphicsQuality.Preset.HIGH)
	var scene: SeaAndSky = autofree(SEA_AND_SKY.instantiate())
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var dusk: Environment = (scene.get_node("Environment") as WorldEnvironment).environment
	assert_eq(high.shadow_mode, sun.directional_shadow_mode)
	assert_eq(high.shadow_distance, sun.directional_shadow_max_distance)
	assert_eq(high.glow, dusk.glow_enabled)
	assert_eq(high.msaa, ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"))
	assert_eq(
		high.shadow_size,
		ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")
	)
	assert_eq(
		high.shadow_filter,
		ProjectSettings.get_setting(
			"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
		)
	)
	assert_eq(high.sea_detail, 1.0)
	assert_false(high.lamp_sight)


func test_each_cheaper_preset_costs_no_more() -> void:
	for preset in [GraphicsQuality.Preset.LOW, GraphicsQuality.Preset.MEDIUM]:
		var cheaper := GraphicsQuality.of(preset)
		var dearer := GraphicsQuality.of(preset + 1)
		assert_lte(cheaper.msaa, dearer.msaa)
		assert_lte(cheaper.shadow_distance, dearer.shadow_distance)
		assert_lte(cheaper.shadow_mode, dearer.shadow_mode)
		assert_lte(cheaper.shadow_size, dearer.shadow_size)
		assert_lte(cheaper.shadow_filter, dearer.shadow_filter)
		assert_lte(cheaper.sea_detail, dearer.sea_detail)
		assert_lte(cheaper.lamps, dearer.lamps)
		assert_false(cheaper.glow and not dearer.glow)
		assert_false(dearer.lamp_sight and not cheaper.lamp_sight)


func test_a_preset_out_of_range_is_held_to_the_ones_there_are() -> void:
	assert_eq(GraphicsQuality.of(9).preset, GraphicsQuality.Preset.HIGH)
	assert_eq(GraphicsQuality.of(-1).preset, GraphicsQuality.Preset.LOW)
	for preset: int in GraphicsQuality.Preset.values():
		assert_false(GraphicsQuality.title(preset).is_empty())
		assert_false(GraphicsQuality.summary(preset).is_empty())


func test_the_sea_and_the_sun_take_a_preset() -> void:
	var scene: SeaAndSky = autofree(SEA_AND_SKY.instantiate())
	add_child(scene)
	var low := GraphicsQuality.of(GraphicsQuality.Preset.LOW)
	scene.show_graphics(low)
	var sun: DirectionalLight3D = scene.get_node("Sun")
	assert_eq(sun.directional_shadow_max_distance, low.shadow_distance)
	assert_eq(sun.directional_shadow_mode, low.shadow_mode)
	assert_eq(scene.dusk().glow_enabled, low.glow)
	assert_eq(scene.water().get_shader_parameter(&"fine_share"), low.sea_detail)
