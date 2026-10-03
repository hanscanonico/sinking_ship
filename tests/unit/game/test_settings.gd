extends GutTest
## The settings screen's choices outlive the game (SH15): what is saved under
## user:// is what the next boot reads, and nothing out of range gets in.

const VIEW_PATH := "user://test_view_settings.tres"
const AUDIO_PATH := "user://test_audio_settings.tres"


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
	var menu: SettingsMenu = autofree(load("res://scenes/game/settings_menu.tscn").instantiate())
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
