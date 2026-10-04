extends GutTest
## A name a server sends may be as long as it likes — 255 characters on the wire — where
## this game's own are short: wherever one is drawn over a match, it is cut short with
## an ellipsis to the room it has, and a name that fits is shown whole.

const LONG_NAME_LENGTH := 255


func _long_name() -> String:
	return "Bartholomew Fitz ".repeat(16).left(LONG_NAME_LENGTH)


func _width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func test_a_name_is_fitted_to_its_room() -> void:
	var font := ThemeDB.fallback_font
	assert_eq(UiTheme.fit("Ada", font, 18, 240.0), "Ada", "a name that fits, whole")
	var fitted := UiTheme.fit(_long_name(), font, 18, 240.0)
	assert_true(fitted.ends_with(UiTheme.ELLIPSIS), fitted)
	assert_true(_width(fitted, font, 18) <= 240.0, "within its room")
	assert_true(_long_name().begins_with(fitted.trim_suffix(UiTheme.ELLIPSIS)), "its start")
	assert_true(fitted.length() > 10, "as much as fits, not a stub")
	assert_eq(UiTheme.fit("Ada", font, 18, 1.0), UiTheme.ELLIPSIS, "no room at all")


## The results table and the banner naming whose eyes the view is in.
func test_a_long_name_is_cut_short_over_the_match() -> void:
	var scene: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(scene)
	var stats := MatchStats.new(2, 0)
	stats.add(
		[SimEvent.seat_out(10, 1, 2, PlayerState.Cause.NONE, -1), SimEvent.match_ended(10, 0)]
	)
	var results: EndOverlay = scene.get_node("EndOverlay")
	results.show_results(stats, 0, PackedStringArray(["You", _long_name()]), 1701)
	var shown: Array[Label] = []
	for cell: Node in results.get_node("%Table").get_children():
		var label := cell as Label
		if label.text == "You" or label.text.begins_with("Bartholomew"):
			shown.append(label)
	assert_eq(shown.size(), 2, "both seats named")
	assert_eq(shown[0].text, "You", "a short name whole")
	var long := shown[1]
	assert_true(long.text.ends_with(UiTheme.ELLIPSIS), long.text)
	var font := long.get_theme_font(&"font")
	var font_size := long.get_theme_font_size(&"font_size")
	assert_true(_width(long.text, font, font_size) <= EndOverlay.NAME_WIDTH)
	var hud: Hud = scene.get_node("Hud")
	assert_eq(hud.fit_name("Bot 3"), "Bot 3")
	var banner := hud.fit_name(_long_name())
	assert_true(banner.ends_with(UiTheme.ELLIPSIS), banner)
	assert_true(banner.length() < LONG_NAME_LENGTH)
