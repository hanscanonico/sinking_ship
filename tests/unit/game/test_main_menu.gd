extends GutTest
## The main menu as a first-time player meets it: the build's version in its corner,
## Ship, Seats, Bots and Survival up front, the seed and the pace folded under Custom
## match — closed, unless the command line set one of them — and Credits between
## Replays and Quit.

const GAME := "res://scenes/game/game.tscn"
const MATCH_DATA := "res://data/match/default.tres"
const VERSION := "application/config/version"


## game.tscn's main menu alone, set up with the choices [param args] make: the rest of
## the game — its boot, its other screens — taken out first.
func _menu(args: PackedStringArray = PackedStringArray()) -> MainMenu:
	var game: Node = load(GAME).instantiate()
	for child: Node in game.get_children():
		if child.name != &"MainMenu":
			game.remove_child(child)
			child.free()
	game.set_script(null)
	add_child_autofree(game)
	var menu: MainMenu = game.get_node("MainMenu")
	menu.setup(load(MATCH_DATA), MatchArgs.parse(args).choices)
	return menu


func test_the_version_is_the_projects_or_dev() -> void:
	var had := ProjectSettings.has_setting(VERSION)
	var was: Variant = ProjectSettings.get_setting(VERSION) if had else null
	ProjectSettings.set_setting(VERSION, "0.9.0")
	assert_eq(MainMenu.version_text(), "v0.9.0")
	ProjectSettings.set_setting(VERSION, "")
	assert_eq(MainMenu.version_text(), "dev", "a build that sets none")
	ProjectSettings.set_setting(VERSION, was)
	var menu := _menu()
	var label: Label = menu.get_node("%Version")
	assert_eq(label.text, MainMenu.version_text(), "the corner shows it")


func test_the_custom_match_is_folded_by_default() -> void:
	var menu := _menu()
	assert_false(menu.custom_shown(), "the seed and the pace are folded away")
	for upfront: String in ["%Ship", "%Seats", "%Tier", "%Survival"]:
		assert_true(menu.get_node(upfront).visible, "%s is up front" % upfront)
	assert_false(menu.get_node("%Seed").is_visible_in_tree(), "no seed field up front")
	assert_false(menu.get_node("%Fast").is_visible_in_tree(), "no fast sinking up front")


func test_a_seed_or_a_pace_given_opens_the_fold() -> void:
	var seeded := _menu(PackedStringArray(["--seed=1701"]))
	assert_true(seeded.custom_shown(), "a seed from the command line is shown")
	assert_eq((seeded.get_node("%Seed") as LineEdit).text, "1701")
	assert_eq(seeded.choices().seed_text, "1701", "and played")
	var fast := _menu(PackedStringArray(["--fast"]))
	assert_true(fast.custom_shown(), "a fast sinking from the command line is shown")
	assert_true(fast.choices().fast, "and played")


func test_the_fold_opens_and_closes() -> void:
	var menu := _menu()
	var custom: Button = menu.get_node("%Custom")
	custom.button_pressed = true
	assert_true(menu.custom_shown())
	assert_eq(custom.get_node(custom.focus_neighbor_bottom), menu.get_node("%Seed"))
	_assert_drawn_in_its_font(custom)
	custom.button_pressed = false
	assert_false(menu.custom_shown())
	assert_eq(custom.get_node(custom.focus_neighbor_bottom), menu.get_node("%Play"))
	_assert_drawn_in_its_font(custom)


## Every character of [param button]'s text is in its own font: a web build has no
## system font to fall back on, so a missing one draws as a box there.
func _assert_drawn_in_its_font(button: Button) -> void:
	var font := button.get_theme_font("font")
	for index in button.text.length():
		var code := button.text.unicode_at(index)
		assert_true(font.has_char(code), "%s draws U+%04X" % [button.text, code])


func test_credits_stands_between_replays_and_quit() -> void:
	var menu := _menu()
	var credits: Button = menu.get_node("%Credits")
	var names := PackedStringArray()
	for button: Node in credits.get_parent().get_children():
		names.append(button.name)
	assert_eq(names, PackedStringArray(["Play", "Settings", "Replays", "Credits", "QuitGame"]))
	watch_signals(menu)
	credits.pressed.emit()
	assert_signal_emitted(menu, "credits_requested")
