extends GutTest


func test_the_water_line_is_not_drawn_with_the_eye_well_over_it() -> void:
	assert_false(Underwater.meniscus_shown(0.2))


func test_the_water_line_is_drawn_with_the_eye_just_over_it() -> void:
	assert_true(Underwater.meniscus_shown(0.1))


func test_the_overlay_is_drawn_with_the_eye_just_under_it() -> void:
	assert_true(Underwater.meniscus_shown(-0.1))


func test_the_overlay_is_drawn_with_the_eye_deep_under_it() -> void:
	assert_true(Underwater.meniscus_shown(-1.0))


func test_the_water_line_is_not_drawn_with_the_eye_at_a_swimmer_s_rest_over_it() -> void:
	assert_false(Underwater.meniscus_shown(Underwater.MENISCUS))


func test_the_ship_s_paint_has_the_eye_under_global_to_read() -> void:
	var setting := "shader_globals/" + String(Underwater.EYE_UNDER)
	assert_true(ProjectSettings.has_setting(setting))
	assert_eq(ProjectSettings.get_setting(setting)["type"], "float")
