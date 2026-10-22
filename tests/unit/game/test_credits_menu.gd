extends GutTest
## The credits (CreditsMenu): the game's name, the asset register as plain text, the
## engine's licence and its third-party notices — the register packed into every
## export that shows them — and a register that names every sound and font shipped.

const LICENSES := "res://assets/LICENSES.md"
const PRESETS := "res://export_presets.cfg"
## The shipped files the register must name, by folder.
const REGISTERED: Array[String] = ["res://assets/audio", "res://assets/fonts"]


func test_the_credits_carry_the_name_the_register_and_godots_notices() -> void:
	var text := CreditsMenu.text()
	assert_true(text.begins_with("Last One Dry"), "the game's name first")
	assert_string_contains(text, "Kenney, Impact Sounds 1.0")
	assert_string_contains(text, "Playfair Display by Claus Eggers Sørensen")
	assert_string_contains(text, Engine.get_license_text(), "Godot's licence, whole")
	assert_string_contains(text, "Copyright (c) 2014-present Godot Engine contributors")
	var component: Dictionary = Engine.get_copyright_info()[0]
	assert_string_contains(text, component["name"], "the engine's third-party components")
	for license: String in Engine.get_license_info():
		assert_string_contains(text, license, "every licence they come under")


func test_the_register_reads_as_plain_text() -> void:
	var plain := CreditsMenu.plain(
		"# Asset licenses\n\n| Asset | Source |\n|---|---|\n| `a.wav` | *Kenney* |\n"
	)
	assert_eq(plain, "Asset licenses\n\nAsset — Source\na.wav — Kenney")


func test_every_shown_export_packs_the_register() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load(PRESETS), OK)
	var checked := 0
	for section: String in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		if presets.get_value(section, "dedicated_server", false):
			continue
		var name: String = presets.get_value(section, "name")
		var included: String = presets.get_value(section, "include_filter", "")
		var excluded: String = presets.get_value(section, "exclude_filter", "")
		assert_true(_matches(included, "assets/LICENSES.md"), "%s packs the register" % name)
		assert_false(_matches(excluded, "assets/LICENSES.md"), "%s keeps it" % name)
		checked += 1
	assert_gt(checked, 0, "there are exports that show the menu")


func test_the_register_names_every_sound_and_font() -> void:
	var named := _named(FileAccess.get_file_as_string(LICENSES))
	var files := PackedStringArray()
	for folder: String in REGISTERED:
		files.append_array(_files(folder))
	assert_gt(files.size(), 0)
	var missing := PackedStringArray()
	for path: String in files:
		var local := path.trim_prefix("res://")
		var under_audio := local.trim_prefix("assets/audio/")
		if not (named.has(local) or named.has(under_audio)):
			missing.append(local)
	assert_eq(missing, PackedStringArray(), "every shipped sound and font is in the register")


## Whether a comma-separated export [param filter] takes [param path].
static func _matches(filter: String, path: String) -> bool:
	for pattern: String in filter.split(",", false):
		if path.match(pattern.strip_edges()):
			return true
	return false


## Every file the register names in code marks: `dir/name.ext` alone, and each of a
## range `dir/name_0`–`4.ext` spelled out.
static func _named(register: String) -> Dictionary:
	var named := {}
	var single := RegEx.create_from_string("`([\\w/.\\-\\[\\]]+\\.\\w+)`")
	for found: RegExMatch in single.search_all(register):
		named[found.get_string(1)] = true
	var range_of := RegEx.create_from_string("`([\\w/]+?)(\\d+)`–`(\\d+)\\.(\\w+)`")
	for found: RegExMatch in range_of.search_all(register):
		for index in range(found.get_string(2).to_int(), found.get_string(3).to_int() + 1):
			named["%s%d.%s" % [found.get_string(1), index, found.get_string(4)]] = true
	return named


## Every file under [param folder], Godot's own .import and .uid files aside.
static func _files(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() not in ["import", "uid"]:
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_files(folder.path_join(sub)))
	return found
