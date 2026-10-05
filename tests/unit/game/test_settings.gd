extends GutTest
## The settings screen's choices outlive the game (SH15): what is saved under
## user:// is what the next boot reads, and nothing out of range gets in.

const VIEW_PATH := "user://test_view_settings.tres"
const AUDIO_PATH := "user://test_audio_settings.tres"
const SETTINGS_MENU := preload("res://scenes/game/settings_menu.tscn")


func after_each() -> void:
	for path: String in [VIEW_PATH, AUDIO_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_settings_round_trip_through_user_storage() -> void:
	assert_false(FileAccess.file_exists(VIEW_PATH), "nothing saved yet")
	assert_eq(ViewSettings.read(VIEW_PATH).fov_deg, 90.0, "the defaults stand in")

	var view := ViewSettings.new()
	view.mouse_deg_per_pixel = 0.3
	view.invert_y = true
	view.fov_deg = 104.0
	view.deck_roll = 0.25
	view.view_kick = 0.4
	view.fullscreen = true
	assert_eq(view.save(VIEW_PATH), OK)
	var audio := AudioSettings.new()
	audio.master = 0.5
	audio.music = 0.0
	audio.effects = 0.75
	assert_eq(audio.save(AUDIO_PATH), OK)

	var view_back := ViewSettings.read(VIEW_PATH)
	assert_ne(view_back, view, "read from the file, not the cache")
	assert_almost_eq(view_back.mouse_deg_per_pixel, 0.3, 0.0001)
	assert_true(view_back.invert_y)
	assert_almost_eq(view_back.fov_deg, 104.0, 0.0001)
	assert_almost_eq(view_back.deck_roll, 0.25, 0.0001)
	assert_almost_eq(view_back.view_kick, 0.4, 0.0001)
	assert_true(view_back.fullscreen)
	var audio_back := AudioSettings.read(AUDIO_PATH)
	assert_ne(audio_back, audio)
	assert_almost_eq(audio_back.master, 0.5, 0.0001)
	assert_almost_eq(audio_back.music, 0.0, 0.0001)
	assert_almost_eq(audio_back.effects, 0.75, 0.0001)


func test_the_settings_screen_saves_as_it_closes() -> void:
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	menu.audio_path = AUDIO_PATH
	menu.view_path = VIEW_PATH
	add_child(menu)
	menu.open()
	(menu.get_node("%Music") as HSlider).value = 35.0
	(menu.get_node("%FieldOfView") as HSlider).value = 101.0
	(menu.get_node("%ViewKick") as HSlider).value = 0.0
	assert_eq(menu.get_node("%ViewKickValue").text, "off")
	assert_false(FileAccess.file_exists(AUDIO_PATH), "nothing saved while it is open")
	menu.close()
	assert_almost_eq(AudioSettings.read(AUDIO_PATH).music, 0.35, 0.0001)
	assert_almost_eq(ViewSettings.read(VIEW_PATH).fov_deg, 101.0, 0.0001)
	assert_eq(ViewSettings.read(VIEW_PATH).view_kick, 0.0)


func test_fov_and_volume_are_clamped() -> void:
	var view := ViewSettings.new()
	view.fov_deg = 140.0
	assert_eq(view.fov_deg, ViewSettings.FOV_MAX)
	view.fov_deg = 30.0
	assert_eq(view.fov_deg, ViewSettings.FOV_MIN)
	view.deck_roll = 2.0
	assert_eq(view.deck_roll, 1.0)
	view.deck_roll = -1.0
	assert_eq(view.deck_roll, 0.0)
	view.view_kick = 1.5
	assert_eq(view.view_kick, 1.0)
	view.view_kick = -0.5
	assert_eq(view.view_kick, 0.0)
	var audio := AudioSettings.new()
	audio.master = 1.5
	audio.music = -0.2
	assert_eq(audio.master, 1.0)
	assert_eq(audio.music, 0.0)

	# A hand-edited file out of range is clamped as it is read.
	ViewSettings.new().save(VIEW_PATH)
	var kept := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(VIEW_PATH).split("\n"):
		if not line.begins_with("fov_deg"):
			kept.append(line)
	var file := FileAccess.open(VIEW_PATH, FileAccess.WRITE)
	file.store_string("\n".join(kept).strip_edges() + "\nfov_deg = 170.0\n")
	file.close()
	assert_eq(ViewSettings.read(VIEW_PATH).fov_deg, ViewSettings.FOV_MAX)


func test_graphics_are_this_machine_s_own_until_the_player_picks_them() -> void:
	var view := ViewSettings.new()
	assert_eq(view.quality, ViewSettings.AUTOMATIC)
	assert_eq(view.render_scale, float(ViewSettings.AUTOMATIC))
	assert_eq(view.graphics().preset, GraphicsQuality.automatic_preset())
	assert_eq(view.render_scale_3d(), 1.0, "the default preset's, whatever the screen")
	assert_eq(GraphicsQuality.automatic_preset(), GraphicsQuality.DESKTOP_PRESET, "not a browser")
	view.quality = GraphicsQuality.Preset.LOW
	assert_eq(view.render_scale_3d(), GraphicsQuality.SCALE_MIN, "Low's own, until picked")
	view.quality = ViewSettings.AUTOMATIC
	# Saved untouched, they stay the machine's: another screen may want another scale.
	assert_eq(view.save(VIEW_PATH), OK)
	assert_eq(ViewSettings.read(VIEW_PATH).quality, ViewSettings.AUTOMATIC)
	assert_eq(ViewSettings.read(VIEW_PATH).render_scale, float(ViewSettings.AUTOMATIC))

	view.quality = GraphicsQuality.Preset.HIGH
	view.render_scale = 0.85
	assert_eq(view.save(VIEW_PATH), OK)
	var back := ViewSettings.read(VIEW_PATH)
	assert_eq(back.graphics().preset, GraphicsQuality.Preset.HIGH, "the choice wins")
	assert_almost_eq(back.render_scale_3d(), 0.85, 0.0001)


func test_graphics_choices_are_held_to_what_there_is() -> void:
	var view := ViewSettings.new()
	view.quality = 7
	assert_eq(view.quality, GraphicsQuality.Preset.HIGH)
	view.quality = -4
	assert_eq(view.quality, ViewSettings.AUTOMATIC)
	view.render_scale = 0.2
	assert_eq(view.render_scale, GraphicsQuality.SCALE_MIN)
	view.render_scale = 1.6
	assert_eq(view.render_scale, GraphicsQuality.SCALE_MAX)
	view.render_scale = 0.0
	assert_eq(view.render_scale, float(ViewSettings.AUTOMATIC))


func test_the_graphics_page_picks_the_preset_and_the_render_scale() -> void:
	# The instance the screen edits, held here and started from the machine's own,
	# whatever this machine has saved.
	var shared := ViewSettings.local()
	shared.quality = ViewSettings.AUTOMATIC
	shared.render_scale = ViewSettings.AUTOMATIC
	shared.run_quality = ViewSettings.AUTOMATIC
	shared.run_render_scale = ViewSettings.AUTOMATIC
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	menu.audio_path = AUDIO_PATH
	menu.view_path = VIEW_PATH
	add_child(menu)
	watch_signals(menu)
	menu.open(SettingsMenu.Page.GRAPHICS)
	assert_true(menu.get_node("%Graphics").visible)
	assert_false(menu.get_node("%Sound").visible)
	assert_false(menu.get_node("%Controls").visible)
	assert_true((menu.get_node("%GraphicsTab") as Button).button_pressed)
	assert_true(menu.get_node("%Fullscreen").has_focus(), "the page's first choice")

	var quality: OptionButton = menu.get_node("%Quality")
	assert_eq(quality.get_selected_id(), GraphicsQuality.automatic_preset(), "the machine's own")
	assert_eq(quality.item_count, GraphicsQuality.Preset.size())
	var slider: HSlider = menu.get_node("%RenderScale")
	assert_eq(slider.value, 100.0, "the default's full resolution")
	var low := quality.get_item_index(GraphicsQuality.Preset.LOW)
	quality.select(low)
	quality.item_selected.emit(low)
	assert_signal_emitted(menu, "view_changed")
	assert_eq(shared.quality, GraphicsQuality.Preset.LOW)
	assert_eq(
		menu.get_node("%QualityHint").text, GraphicsQuality.summary(GraphicsQuality.Preset.LOW)
	)
	assert_eq(shared.render_scale, float(ViewSettings.AUTOMATIC), "the scale left be")
	assert_eq(slider.value, GraphicsQuality.SCALE_MIN * 100.0, "so Low's own, shown")
	slider.value = 60.0
	assert_eq(menu.get_node("%RenderScaleValue").text, "60 %")
	menu.close()
	var saved := ViewSettings.read(VIEW_PATH)
	assert_eq(saved.quality, GraphicsQuality.Preset.LOW)
	assert_almost_eq(saved.render_scale, 0.6, 0.0001)


func test_the_player_s_pick_sets_aside_a_run_s_chosen_graphics() -> void:
	var shared := ViewSettings.local()
	shared.quality = ViewSettings.AUTOMATIC
	shared.render_scale = ViewSettings.AUTOMATIC
	shared.run_quality = GraphicsQuality.Preset.HIGH
	shared.run_render_scale = 0.7
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	menu.audio_path = AUDIO_PATH
	menu.view_path = VIEW_PATH
	add_child(menu)
	menu.open(SettingsMenu.Page.GRAPHICS)
	var quality: OptionButton = menu.get_node("%Quality")
	assert_eq(quality.get_selected_id(), GraphicsQuality.Preset.HIGH, "what the run draws")
	menu.close()
	assert_eq(ViewSettings.read(VIEW_PATH).quality, ViewSettings.AUTOMATIC, "not saved")
	menu.open(SettingsMenu.Page.GRAPHICS)
	var low := quality.get_item_index(GraphicsQuality.Preset.LOW)
	quality.select(low)
	quality.item_selected.emit(low)
	assert_eq(shared.run_quality, ViewSettings.AUTOMATIC)
	assert_eq(shared.graphics().preset, GraphicsQuality.Preset.LOW, "the player's pick")
	(menu.get_node("%RenderScale") as HSlider).value = 80.0
	assert_eq(shared.run_render_scale, float(ViewSettings.AUTOMATIC))
	assert_almost_eq(shared.render_scale_3d(), 0.8, 0.0001)
	menu.close()


func test_every_choice_on_every_page_takes_the_keys_and_the_pad() -> void:
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	add_child(menu)
	for tab: String in ["%SoundTab", "%ControlsTab", "%GraphicsTab"]:
		assert_eq((menu.get_node(tab) as Control).focus_mode, Control.FOCUS_ALL, tab)
	for page: String in ["%Sound", "%Controls", "%Graphics"]:
		for control: Node in menu.get_node(page).find_children("*", "Range", true, true):
			assert_eq((control as Control).focus_mode, Control.FOCUS_ALL, control.name)
		for control: Node in menu.get_node(page).find_children("*", "BaseButton", true, true):
			assert_eq((control as Control).focus_mode, Control.FOCUS_ALL, control.name)
	menu.open()
	(menu.get_node("%ControlsTab") as Button).pressed.emit()
	assert_true(menu.get_node("%Controls").visible, "a tab shows its page")
	assert_false(menu.get_node("%Sound").visible)


func test_a_run_s_chosen_graphics_draw_it_but_are_never_saved() -> void:
	var view := ViewSettings.new()
	view.run_quality = GraphicsQuality.Preset.LOW
	view.run_render_scale = 0.7
	assert_eq(view.graphics().preset, GraphicsQuality.Preset.LOW)
	assert_almost_eq(view.render_scale_3d(), 0.7, 0.0001)
	assert_eq(view.save(VIEW_PATH), OK)
	var back := ViewSettings.read(VIEW_PATH)
	assert_eq(back.quality, ViewSettings.AUTOMATIC, "the player's file keeps their own")
	assert_eq(back.render_scale, float(ViewSettings.AUTOMATIC))
	assert_eq(back.graphics().preset, GraphicsQuality.automatic_preset())


func test_a_run_can_be_drawn_at_chosen_graphics_to_measure_them() -> void:
	var args := MatchArgs.parse(PackedStringArray(["--quality=high", "--render-scale=0.6"]))
	assert_eq(args.quality, GraphicsQuality.Preset.HIGH)
	assert_almost_eq(args.render_scale, 0.6, 0.0001)
	var unset := MatchArgs.parse(PackedStringArray())
	assert_eq(unset.quality, ViewSettings.AUTOMATIC)
	assert_eq(unset.render_scale, float(ViewSettings.AUTOMATIC))
