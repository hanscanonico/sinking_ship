extends GutTest
## The replays list's rows (ReplaysMenu): each says its ship, seats, length and who won
## whole, in every language, with when it was played and its seed under it. In French a
## row was cut after its seats: "Chalutier · Graine 5 · 8 joueu…".

const RunMatch := preload("res://tools/run_match.gd")
const SHIPS: Array[StringName] = [
	&"barque", &"ferry", &"freighter", &"small_titanic", &"steamer", &"titanic", &"trawler", &"tug"
]


func after_each() -> void:
	Language.use(Language.SOURCE)


func _file(ship: StringName, winner: int, ended: bool) -> ReplayFile:
	var chosen := MatchChoices.new()
	chosen.seed_text = "4294967295"
	var file := ReplayFile.record(chosen, InputLog.new(RunMatch.default_config(1701)), 0)
	file.ship = ship
	file.match_seed = 4294967295
	file.seats = 12
	file.ticks = 754 * Ticks.RATE
	file.winner = winner
	file.ended = ended
	return file


func test_a_row_says_the_match_over_when_it_was_played_and_its_seed() -> void:
	var file := _file(&"small_titanic", 3, true)
	assert_eq(ReplaysMenu._what(file, ""), "Small Titanic · 12 seats · 12:34.0 · Bot 3 won")
	assert_eq(ReplaysMenu._more("2026-11-21 23:13", file, ""), "2026-11-21 23:13 · Seed 4294967295")
	assert_eq(
		ReplaysMenu._more("2026-11-21 23:13", file, ReplayListing.CHANGED),
		"2026-11-21 23:13 · Seed 4294967295 — the match data has changed since"
	)
	assert_eq(ReplaysMenu._what(null, ReplayListing.UNREADABLE), "Not a replay the game can read")
	assert_eq(ReplaysMenu._more("old", null, ReplayListing.UNREADABLE), "old", "its file's name")


func test_every_row_reads_whole_in_every_language() -> void:
	var menu := ReplaysMenu.new()
	add_child_autofree(menu)
	for language: String in Language.locales():
		Language.use(language)
		for ship: StringName in SHIPS:
			menu._add_row("a.replay", _file(ship, -1, false), "")
			menu._add_row("a.replay", _file(ship, -1, true), "")
			menu._add_row("a.replay", _file(ship, 11, true), "")
	menu.show()
	await wait_frames(3)
	var checked := 0
	for row: Node in menu._rows.get_children():
		for line: String in ["What", "More"]:
			var label: Label = row.find_child(line, true, false)
			var font := label.get_theme_font(&"font")
			var font_size := label.get_theme_font_size(&"font_size")
			var wide := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			assert_gt(label.size.x, 100.0, "laid out")
			assert_lte(wide.x, label.size.x, "cut short: " + label.text)
			checked += 1
	assert_eq(checked, Language.locales().size() * SHIPS.size() * 3 * 2)
