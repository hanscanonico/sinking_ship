extends GutTest
## The main menu as a first-time player meets it: the build's version in its corner,
## Ship, Seats, Bots and Survival up front, the seed, the pace and the bonuses folded under
## Custom match — closed, unless the command line set a seed, the fast clock or no bonuses
## — and Credits between Replays and Quit. A player's match sinks at her slow, paced
## clock unless they tick Fast sinking, and has bonuses unless they untick them.

const GAME := "res://scenes/game/game.tscn"
const MATCH_DATA := "res://data/match/default.tres"
const VERSION := "application/config/version"


## game.tscn's main menu alone, set up with the choices [param args] make for a player
## (MatchArgs.player_choices), as Game sets it up: the rest of the game — its boot, its
## other screens — taken out first.
func _menu(args: PackedStringArray = PackedStringArray()) -> MainMenu:
	var game: Node = load(GAME).instantiate()
	for child: Node in game.get_children():
		if child.name != &"MainMenu":
			game.remove_child(child)
			child.free()
	game.set_script(null)
	add_child_autofree(game)
	var menu: MainMenu = game.get_node("MainMenu")
	menu.setup(load(MATCH_DATA), MatchArgs.parse(args).player_choices())
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


func test_a_ship_is_shown_in_words_and_picked_by_her_name() -> void:
	var menu := _menu(PackedStringArray(["--ship=small_titanic"]))
	var ship: OptionButton = menu.get_node("%Ship")
	assert_eq(ship.get_item_text(ship.selected), "Small Titanic")
	assert_eq(menu.picked_ship(), &"small_titanic")
	assert_eq(menu.choices().ship, &"small_titanic", "the match she starts is hers")


## The ship's and the bots' lists read as every other list does, a capital first, in
## the player's language, and the tier picked is still the data's own name.
func test_the_lists_read_as_headings_in_every_language() -> void:
	var menu := _menu(PackedStringArray(["--ship=small_titanic"]))
	var ship: OptionButton = menu.get_node("%Ship")
	var tier: OptionButton = menu.get_node("%Tier")
	var picked := menu.choices().bot_tier
	assert_true(BotProfile.tiers().has(String(picked)), "a tier of the data")
	for language: String in Language.locales():
		Language.use(language)
		menu.notification(NOTIFICATION_TRANSLATION_CHANGED)
		for list: OptionButton in [ship, tier]:
			for index in list.item_count:
				var text := list.get_item_text(index)
				assert_eq(text[0], text[0].to_upper(), text)
		assert_eq(menu.choices().bot_tier, picked, "the tier is picked by its name")
	Language.use("fr")
	menu.notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(ship.get_item_text(ship.selected), "Petit Titanic")
	Language.use(Language.SOURCE)


func test_the_custom_match_is_folded_by_default() -> void:
	var menu := _menu()
	assert_false(menu.custom_shown(), "the seed, the pace and the bonuses are folded away")
	for upfront: String in ["%Ship", "%Seats", "%Tier", "%Survival"]:
		assert_true(menu.get_node(upfront).visible, "%s is up front" % upfront)
	assert_false(menu.get_node("%Seed").is_visible_in_tree(), "no seed field up front")
	assert_false(menu.get_node("%Fast").is_visible_in_tree(), "no fast sinking up front")
	assert_false(menu.get_node("%Bonuses").is_visible_in_tree(), "no bonuses up front")


func test_a_seed_or_a_pace_given_opens_the_fold() -> void:
	var seeded := _menu(PackedStringArray(["--seed=1701"]))
	assert_true(seeded.custom_shown(), "a seed from the command line is shown")
	assert_eq((seeded.get_node("%Seed") as LineEdit).text, "1701")
	assert_eq(seeded.choices().seed_text, "1701", "and played")
	var fast := _menu(PackedStringArray(["--fast"]))
	assert_true(fast.custom_shown(), "the fast clock from the command line is shown")
	assert_true((fast.get_node("%Fast") as CheckButton).button_pressed, "Fast ticked")
	assert_true(fast.choices().fast, "and played")
	var slow := _menu(PackedStringArray(["--fast=0"]))
	assert_false(slow.custom_shown(), "--fast=0 is a player's pace already: still folded")
	assert_false(slow.choices().fast, "and played")


func test_a_players_match_sinks_at_her_paced_clock_by_default() -> void:
	var menu := _menu()
	assert_false((menu.get_node("%Fast") as CheckButton).button_pressed, "Fast sinking unticked")
	var match_rules: MatchRules = load(MATCH_DATA)
	var config := menu.choices().with_seed("1701").config(match_rules)
	assert_eq(config.scenario.clock, match_rules.sinking.clock, "the slow, realistic pace")


func test_ticking_fast_plays_the_fast_clock() -> void:
	var menu := _menu()
	(menu.get_node("%Fast") as CheckButton).button_pressed = true
	var match_rules: MatchRules = load(MATCH_DATA)
	var config := menu.choices().with_seed("1701").config(match_rules)
	assert_true(menu.choices().fast)
	assert_eq(config.scenario.clock, match_rules.fast_clock, "the match on the fast clock")


## Bonuses is a tick under Custom match, beside Fast sinking (#314): ticked for every
## player's match, the match data's bonus rules played. The pad goes across from Fast
## sinking to it and back, and down from either to Play.
func test_a_players_match_has_bonuses_by_default() -> void:
	var menu := _menu()
	var bonuses: CheckButton = menu.get_node("%Bonuses")
	var fast: CheckButton = menu.get_node("%Fast")
	assert_true(menu.get_node("%CustomChoices").is_ancestor_of(bonuses), "under Custom match")
	assert_eq(bonuses.get_parent(), fast.get_parent(), "beside Fast sinking")
	assert_true(bonuses.button_pressed, "Bonuses ticked")
	assert_true(menu.choices().bonuses)
	var match_rules: MatchRules = load(MATCH_DATA)
	var config := menu.choices().with_seed("1701").config(match_rules)
	assert_eq(config.bonus_rules, match_rules.bonus_rules, "the match with the data's bonuses")
	assert_eq(fast.get_node(fast.focus_neighbor_right), bonuses, "across from Fast sinking")
	assert_eq(bonuses.get_node(bonuses.focus_neighbor_left), fast, "and back")
	for tick: CheckButton in [fast, bonuses]:
		assert_eq(tick.get_node(tick.focus_neighbor_bottom), menu.get_node("%Play"), tick.name)


func test_unticking_bonuses_plays_the_plain_brawl() -> void:
	var menu := _menu()
	(menu.get_node("%Bonuses") as CheckButton).button_pressed = false
	assert_false(menu.choices().bonuses)
	var config := menu.choices().with_seed("1701").config(load(MATCH_DATA))
	assert_null(config.bonus_rules, "no bonus ever comes")


## Bonuses turned off on the command line (make run BONUSES=0) are shown, not hidden under
## the fold, as a seed or the fast clock is.
func test_no_bonuses_given_opens_the_fold() -> void:
	var off := _menu(PackedStringArray(["--bonuses=0"]))
	assert_true(off.custom_shown(), "the plain brawl from the command line is shown")
	assert_false((off.get_node("%Bonuses") as CheckButton).button_pressed, "Bonuses unticked")
	assert_false(off.choices().bonuses, "and played")
	var on := _menu(PackedStringArray(["--bonuses"]))
	assert_false(on.custom_shown(), "bonuses on are a player's already: still folded")
	assert_true(on.choices().bonuses)


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
	assert_eq(
		names, PackedStringArray(["Play", "Watch", "Settings", "Replays", "Credits", "QuitGame"])
	)
	watch_signals(menu)
	credits.pressed.emit()
	assert_signal_emitted(menu, "credits_requested")


## Watch hands on the same choices as Play, the match only watched (MatchChoices.watch):
## Play's are played.
func test_watch_plays_the_choices_watched() -> void:
	var menu := _menu(PackedStringArray(["--ship=trawler", "--seats=3"]))
	var heard: Array[MatchChoices] = []
	menu.play_requested.connect(func(chosen: MatchChoices) -> void: heard.append(chosen))
	(menu.get_node("%Watch") as Button).pressed.emit()
	(menu.get_node("%Play") as Button).pressed.emit()
	assert_eq(heard.size(), 2)
	assert_true(heard[0].watch, "Watch: only watched")
	assert_eq(heard[0].ship, &"trawler", "on the choices as they stand")
	assert_eq(heard[0].seats, 3)
	assert_false(heard[1].watch, "Play: played")


## The panel grows up toward the title as the custom match unfolds: in the default
## window it reached over it (seen played, 2026-11-21).
func test_the_wordmark_shrinks_into_the_room_a_tall_panel_leaves() -> void:
	assert_eq(MainMenu.wordmark_scale(400.0, 160.0), 1.0, "room to spare: whole")
	assert_almost_eq(MainMenu.wordmark_scale(80.0, 160.0), 0.5, 0.001, "half the room, half")
	assert_eq(MainMenu.wordmark_scale(-20.0, 160.0), MainMenu.WORDMARK_LEAST, "never gone")
	assert_eq(MainMenu.wordmark_scale(INF, 160.0), 1.0, "no panel showing")


## The held countdown's number stands under the wordmark while a sinking bakes; a long
## tagline (French, 1152×648) ran into it (seen played, 2026-11-23). Shown behind
## another screen with that number in front, the wordmark keeps clear of it.
func test_the_wordmark_keeps_clear_of_what_is_put_in_front_of_it() -> void:
	var menu := _menu()
	var wordmark: Control = menu.get_node("Wordmark")
	var beside := Control.new()
	var number := Control.new()
	menu.add_child(beside)
	menu.add_child(number)
	number.position = Vector2(400.0, wordmark.global_position.y + 90.0)
	number.size = Vector2(400.0, 120.0)
	menu.show_behind(beside, number)
	var bottom := wordmark.global_position.y + wordmark.size.y * wordmark.scale.y
	assert_lt(wordmark.scale.y, 1.0, "shrunk into the room over the number")
	assert_lte(bottom, number.global_position.y, "and clear of it")
	menu.show_behind(beside)
	assert_eq(wordmark.scale, Vector2.ONE, "with nothing in front, whole again")


func test_the_tagline_goes_before_it_is_too_small_to_read() -> void:
	assert_true(MainMenu.tagline_shown(INF, 160.0), "no panel showing")
	assert_true(MainMenu.tagline_shown(160.0, 160.0), "room for it whole")
	assert_true(MainMenu.tagline_shown(160.0 * MainMenu.TAGLINE_LEAST, 160.0), "just legible")
	# The custom match unfolded in a 648 px tall window leaves the wordmark 66 px.
	assert_false(MainMenu.tagline_shown(66.0, 160.0), "a strip nobody reads: the title's room")
	assert_false(MainMenu.tagline_shown(-20.0, 160.0), "no room at all")


func test_the_seed_field_keeps_digits_only() -> void:
	assert_eq(MainMenu.seed_typed("1701"), "1701")
	assert_eq(MainMenu.seed_typed(""), "", "blank: one still to be drawn")
	assert_eq(MainMenu.seed_typed("1701abc-12 xyz"), "170112", "what is no digit is not typed")
	assert_eq(MainMenu.seed_typed("-3"), "3")
	var long := MainMenu.seed_typed("9".repeat(40))
	assert_eq(long.length(), MainMenu.SEED_DIGITS, "no longer than a seed can be")
	var choices := MatchChoices.new().with_seed(long)
	assert_eq(choices.seed_problems(), PackedStringArray(), "and still a seed")
