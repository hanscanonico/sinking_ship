extends GutTest
## The game speaks English, French and Spanish (Language): the catalogs under locale/
## have a line for everything the screens say, each keeping what its English fills in,
## and the code's own sentences read right in each language.

const VIEW_PATH := "user://test_language_view_settings.tres"
const AUDIO_PATH := "user://test_language_audio_settings.tres"
const KEYS_PATH := "user://test_language_key_bindings.json"
const SETTINGS_MENU := preload("res://scenes/game/settings_menu.tscn")
const BONUSES := "res://data/bonuses"
## What a scene writes that is no word to translate: the wordmark, a room code's and an
## address's stand-ins, and the hint line the results word themselves.
const UNTRANSLATED: Array[String] = [
	"Last One Dry", "ABCD", "ws://host:port", "R / Start — rematch   ·   Esc — menu"
]
## What a text is filled in with: %s, %d, %.1f — and %% for a per cent.
const FILLED := "%[-+ 0-9.]*[sdf%]"


func after_each() -> void:
	Language.use(Language.SOURCE)
	for path: String in [VIEW_PATH, AUDIO_PATH, KEYS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_a_system_s_language_picks_the_one_on_offer() -> void:
	assert_eq(Language.pick("fr"), "fr")
	assert_eq(Language.pick("fr_CA"), "fr", "a region's French is French")
	assert_eq(Language.pick("es-MX"), "es")
	assert_eq(Language.pick("ES"), "es")
	assert_eq(Language.pick("de_DE"), "en", "a language not on offer reads English")
	assert_eq(Language.pick(""), "en")


func test_the_command_line_s_language_goes_before_the_saved_one() -> void:
	assert_eq(Language.chosen("es", "fr"), "es")
	assert_eq(Language.chosen("", "fr"), "fr")
	assert_eq(Language.chosen("", ""), "en", "headless, the system's is never asked")
	assert_eq(MatchArgs.parse(PackedStringArray(["--language=fr"])).language, "fr")
	assert_eq(MatchArgs.parse(PackedStringArray()).language, "")


func test_english_is_what_the_code_says_until_a_language_is_used() -> void:
	assert_eq(Language.current(), "en")
	assert_eq(Language.t("Settings"), "Settings")
	Language.use("fr")
	assert_eq(Language.current(), "fr")
	assert_eq(Language.t("Settings"), "Paramètres")
	Language.use("es")
	assert_eq(Language.t("Settings"), "Ajustes")
	Language.use("en")
	assert_eq(Language.t("Settings"), "Settings")
	assert_eq(Language.t(""), "", "nothing stays nothing: never a catalog's header")


func test_a_context_tells_two_uses_of_a_word_apart() -> void:
	Language.use("fr")
	assert_eq(Language.t("Play"), "Jouer")
	assert_eq(Language.t("Play", ReplayHud.ON_REPLAY), "Lecture")
	assert_eq(Language.t("Back"), "Retour")
	assert_eq(Language.t("Back", InputPrompts.ON_PAD), "Back", "a pad's Back is its label")
	assert_eq(Language.t("Start", InputPrompts.ON_PAD), "Start")
	assert_eq(Language.t("Space", InputPrompts.ON_KEYBOARD), "Espace")
	assert_eq(Language.with_article("lifebuoy"), "la bouée")
	Language.use("en")
	assert_eq(Language.with_article("lifebuoy"), "lifebuoy", "English says the itself")


func test_each_catalog_has_the_same_lines_and_fills_in_what_the_english_does() -> void:
	var french := _catalog("fr")
	var spanish := _catalog("es")
	assert_gt(french.size(), 300, "the catalog was read")
	var missing: Array = french.keys().filter(func(key: String) -> bool: return not key in spanish)
	var extra: Array = spanish.keys().filter(func(key: String) -> bool: return not key in french)
	assert_eq(missing, [], "in French, not in Spanish")
	assert_eq(extra, [], "in Spanish, not in French")
	var filled := RegEx.create_from_string(FILLED)
	for catalog: Dictionary in [french, spanish]:
		for key: String in catalog:
			var said: String = catalog[key]
			assert_false(said.is_empty(), "%s is translated" % key)
			var text := key.get_slice("\u0004", key.get_slice_count("\u0004") - 1)
			var wanted := _matches(filled, text)
			if _matches(filled, said) != wanted:
				fail_test("%s fills in %s, its translation %s" % [key, wanted, said])
			if text.begins_with(" ") != said.begins_with(" "):
				fail_test("%s and its translation %s begin alike" % [key, said])


func test_every_text_of_the_scenes_and_the_code_has_its_line() -> void:
	var catalog := _catalog("fr")
	var scene_text := RegEx.create_from_string(
		'(?m)^(?:text|placeholder_text|tooltip_text) = "((?:[^"\\\\]|\\\\.)*)"$'
	)
	var asked := RegEx.create_from_string('Language\\.t\\(\\s*"((?:[^"\\\\]|\\\\.)*)"')
	var checked := 0
	for path: String in _files("res://scenes", ["tscn", "gd"]):
		var source := FileAccess.get_file_as_string(path)
		for found: RegExMatch in (scene_text if path.ends_with(".tscn") else asked).search_all(
			source
		):
			var text := found.get_string(1).c_unescape()
			checked += 1
			if not text in UNTRANSLATED and not _has(catalog, text):
				fail_test("%s says %s, which no catalog has" % [path, text])
	assert_gt(checked, 120, "the scenes and the code were read")


func test_every_name_out_of_the_data_has_its_line() -> void:
	var catalog := _catalog("fr")
	var names := PackedStringArray()
	for ship: String in Fleet.names():
		names.append(ship.replace("_", " "))
		var layout := Fleet.layout(ship)
		for platform: ShipPlatform in layout.platforms:
			names.append(String(platform.name))
		for prop: ShipProp in layout.props:
			var kind := String(prop.kind).replace("_", " ")
			names.append(kind)
			names.append("%s\u0004%s" % [Language.WITH_ARTICLE, kind])
	names.append_array(BotProfile.tiers())
	for file: String in DirAccess.get_files_at(BONUSES):
		if file.ends_with(".tres"):
			names.append((load(BONUSES.path_join(file)) as BonusKind).title)
	for preset: int in GraphicsQuality.Preset.values():
		names.append(GraphicsQuality.title(preset))
		names.append(GraphicsQuality.summary(preset))
	names.append_array(KeyBindings.TITLES.values())
	names.append_array(OnlinePlay.REFUSALS.values())
	names.append_array([OnlinePlay.NO_CONNECTION, OnlinePlay.LOST, OnlinePlay.AWAY])
	names.append_array(MatchTranscript.FOUNDERS.values())
	names.append_array([ReplayListing.MIDWAY, ReplayListing.CHANGED, ReplayListing.UNREADABLE])
	names.append_array(EndOverlay.HEADINGS)
	names.append_array(EndOverlay.SURVIVAL_HEADINGS)
	names.append_array(EndOverlay.SESSION_HEADINGS)
	names.append_array(InputPrompts.PAD_AXES.values().filter(_is_words))
	names.append_array(InputPrompts.MOUSE_BUTTONS.values())
	names.append_array(SinkSchedule.PHASES)
	for hint: Array in ReplayHud.HINTS:
		names.append(hint[1])
	for line: String in InputPrompts.pause_controls_for(false, true).split("\n"):
		names.append(line.get_slice(" — ", 1))
	for line: String in InputPrompts.watch_controls_for(false).split("\n"):
		names.append(line.get_slice(" — ", 1))
	assert_gt(names.size(), 150, "the data was read")
	var seen := {}
	for name: String in names:
		if not seen.has(name) and not catalog.has(name):
			fail_test("%s has no line in the catalogs" % name)
		seen[name] = true


func test_a_place_is_counted_as_each_language_counts() -> void:
	assert_eq(Language.ordinal(1), "1st")
	assert_eq(Language.ordinal(12), "12th")
	assert_eq(EndOverlay.ordinal(3), "3rd")
	Language.use("fr")
	assert_eq(Language.ordinal(1), "1er")
	assert_eq(EndOverlay.ordinal(2), "2e")
	Language.use("es")
	assert_eq(Language.ordinal(3), "3.º")


func test_a_name_out_of_the_data_reads_as_a_heading() -> void:
	assert_eq(Language.titled("boat deck"), "Boat Deck", "English as the data's words read")
	assert_eq(Language.titled(""), "")
	Language.use("fr")
	assert_eq(Language.titled("boat deck"), "Pont des embarcations")
	assert_eq(Language.titled("engine room, B deck"), "Salle des machines, pont B", "by its parts")
	assert_eq(Language.titled("bacon store, B deck"), "Bacon Store, B Deck", "whole, or not at all")
	assert_eq(Language.named("small titanic"), "petit Titanic")
	assert_eq(Language.numbered("funnel 4"), "cheminée 4")
	assert_eq(Language.numbered("funnel"), "cheminée")


func test_the_feed_s_lines_read_right_in_french_and_spanish() -> void:
	var names := PackedStringArray(["Vous", "Bot 1", "Bot 2"])
	Language.use("fr")
	assert_eq(KnockoutFeed.feed_line(names, 2, 0, 0), "Vous avez poussé Bot 2 à la mer")
	assert_eq(KnockoutFeed.feed_line(names, 0, 1, 0), "Bot 1 vous a poussé à la mer")
	assert_eq(KnockoutFeed.feed_line(names, 2, 1, 0), "Bot 1 a poussé Bot 2 à la mer")
	assert_eq(KnockoutFeed.feed_line(names, 0, -1, 0), "Vous êtes tombé à la mer")
	assert_eq(
		KnockoutFeed.feed_line(names, 1, -1, 0, PlayerState.Cause.WITH_HER),
		"Bot 1 a coulé avec le navire"
	)
	Language.use("es")
	assert_eq(KnockoutFeed.feed_line(names, 2, 0, 0), "Has empujado a Bot 2 al mar")


## The replay's seek hints stand after their keys' names, which French and Spanish
## keyboards call Début / Inicio and Fin: the hint must not say the key's name again
## ("Début au début · Fin à la fin", seen played 2026-11-23).
func test_a_seek_hint_does_not_repeat_its_key_s_name() -> void:
	for locale: String in ["fr", "es"]:
		Language.use(locale)
		for pair: Array in [["Home", "to the start"], ["End", "to the end"]]:
			var key := Language.t(pair[0], InputPrompts.ON_KEYBOARD).to_lower()
			var hint := Language.t(pair[1]).to_lower()
			assert_ne(key, pair[0].to_lower(), "the key's name is the language's")
			var words := hint.replace("'", " ").split(" ")
			assert_false(key in words, "%s: %s %s" % [locale, key, hint])


func test_the_hud_s_lines_read_in_the_language_in_use() -> void:
	Language.use("fr")
	assert_eq(Hud.whose_view("Bot 3", false, false), "par les yeux de Bot 3")
	assert_eq(Hud.out_word(PlayerState.Cause.WITH_HER), "Coulé")
	assert_eq(FirstPersonHud.height_words(2.04), "2,0 m au-dessus de l'eau")
	assert_eq(WarningChips.straining_words(&"funnel_4"), "CHEMINÉE 4 VA CÉDER")
	assert_eq(WarningChips.straining_words(&"funnel"), "LA CHEMINÉE VA CÉDER")
	assert_eq(EndOverlay.survived(Ticks.from_seconds(134.0), 3), "Survie 02:14.0 · 3e")
	assert_string_contains(InputPrompts.controls_for(false), "— sauter")
	Language.use("es")
	assert_eq(Hud.whose_view("Bot 3", true, false), "por tus propios ojos")
	assert_eq(WarningChips.straining_words(&"funnel_2"), "CHIMENEA 2 VA A CEDER")


## French and Spanish write a decimal comma (Language.decimal): the panel's height, the
## dials, the mouse's sensitivity and the replay's speed.
func test_a_number_s_decimal_mark_is_the_language_s() -> void:
	assert_eq(Language.decimal(2.54), "2.5")
	assert_eq(FirstPersonHud.degrees_words(-3.21), "-3.2°")
	Language.use("fr")
	assert_eq(Language.decimal(2.54), "2,5")
	assert_eq(Language.decimal(0.123, 2), "0,12")
	assert_eq(FirstPersonHud.height_words(-3.8), "3,8 m sous la mer")
	assert_eq(FirstPersonHud.degrees_words(-3.21), "-3,2°")
	assert_eq(FirstPersonHud.degrees_words(0.01), "+0,0°", "level reads +0,0, never -0,0")
	assert_eq(Language.marked("0.25"), "0,25")
	Language.use("es")
	assert_eq(FirstPersonHud.height_words(2.5), "2,5 m sobre el mar")
	assert_eq(FirstPersonHud.degrees_words(14.7), "+14,7°")


func test_the_settings_screen_picks_the_language_and_saves_it() -> void:
	var menu: SettingsMenu = autofree(SETTINGS_MENU.instantiate())
	menu.audio_path = AUDIO_PATH
	menu.view_path = VIEW_PATH
	menu.keys_path = KEYS_PATH
	add_child(menu)
	menu.open()
	var picker: OptionButton = menu.get_node("%Language")
	assert_eq(picker.item_count, 3)
	assert_eq(picker.get_item_text(picker.selected), "English", "the language in use")
	var title: Label = menu.get_node("Panel/Box/Title")
	picker.select(1)
	picker.item_selected.emit(1)
	assert_eq(picker.get_item_text(1), "Français", "each language under its own name")
	assert_eq(Language.current(), "fr")
	assert_eq(title.atr(title.text), "Paramètres", "the screen words itself again")
	menu.close()
	assert_eq(ViewSettings.read(VIEW_PATH).language, "fr", "saved as the screen closes")
	ViewSettings.local().language = ""


## The lines of [param locale]'s catalog as its file has them: each English text —
## after its context and a U+0004, when it has one — and its translation.
func _catalog(locale: String) -> Dictionary:
	var lines := {}
	var context := ""
	var key := ""
	for line: String in FileAccess.get_file_as_string(Language.catalog_path(locale)).split("\n"):
		if line.begins_with("msgctxt "):
			context = _unquoted(line.trim_prefix("msgctxt "))
		elif line.begins_with("msgid "):
			key = _unquoted(line.trim_prefix("msgid "))
			if not context.is_empty():
				key = "%s\u0004%s" % [context, key]
			context = ""
		elif line.begins_with("msgstr ") and not key.is_empty():
			lines[key] = _unquoted(line.trim_prefix("msgstr "))
	return lines


func _unquoted(text: String) -> String:
	return text.strip_edges().trim_prefix('"').trim_suffix('"').c_unescape()


## Whether [param catalog] has [param text], under no context or under any.
func _has(catalog: Dictionary, text: String) -> bool:
	if catalog.has(text):
		return true
	for key: String in catalog:
		if key.ends_with("\u0004" + text):
			return true
	return false


func _matches(pattern: RegEx, text: String) -> PackedStringArray:
	var found := PackedStringArray()
	for each: RegExMatch in pattern.search_all(text):
		found.append(each.get_string())
	return found


## Whether [param text] is words to translate, not a pad's own label (LT, RT).
func _is_words(text: String) -> bool:
	return text.contains(" ")


func _files(dir: String, extensions: Array) -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() in extensions:
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_files(dir.path_join(sub), extensions))
	return found


## A button or an axis the game has no name for is its kind and its number, in the
## player's language: a mouse's thumb button read "Mouse 8" in French and Spanish.
func test_a_button_with_no_name_is_numbered_in_the_language() -> void:
	var thumb := InputEventMouseButton.new()
	thumb.button_index = MOUSE_BUTTON_XBUTTON1
	var paddle := InputEventJoypadButton.new()
	paddle.button_index = JOY_BUTTON_PADDLE1
	var axis := InputEventJoypadMotion.new()
	axis.axis = 9 as JoyAxis
	Language.use("fr")
	assert_eq(InputPrompts.word_for([thumb], false), "Souris 8")
	assert_eq(InputPrompts.word_for([paddle], true), "Bouton %d" % JOY_BUTTON_PADDLE1)
	assert_eq(InputPrompts.word_for([axis], true), "Axe 9")
	Language.use("es")
	assert_eq(InputPrompts.word_for([thumb], false), "Ratón 8")
	Language.use(Language.SOURCE)
	assert_eq(InputPrompts.word_for([thumb], false), "Mouse 8")


## French as a player reads it: Esc is Échap as Space is Espace, a colon has its space
## before it, and the height over the sea fits its plate with two digits of metres
## ("13.3 m au-dessus de la mer" ran to the plate's edge on the Titanic's decks).
func test_french_keys_colons_and_heights() -> void:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	var room := FirstPersonHud.plate_rect(Vector2(1152.0, 648.0)).size.x - 2.0 * 12.0
	for language: String in Language.locales():
		Language.use(language)
		var high := FirstPersonHud.height_words(99.9)
		var wide := ThemeDB.fallback_font.get_string_size(
			high, HORIZONTAL_ALIGNMENT_LEFT, -1, FirstPersonHud.FONT_SIZE
		)
		assert_lte(wide.x, room, high)
	Language.use("fr")
	assert_eq(InputPrompts.word_for([escape], false), "Échap")
	assert_eq(Language.t("%s: %s") % ["Pied sûr", "cale"], "Pied sûr : cale")
	assert_eq(Language.t("Sure footing"), "Pied sûr")
	Language.use(Language.SOURCE)
	assert_eq(InputPrompts.word_for([escape], false), "Esc")
