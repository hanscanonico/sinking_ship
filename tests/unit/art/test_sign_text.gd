extends GutTest
## A sign's letters measure off a buffer of their own (SignText) exactly as the fallback
## font's own measures, which share one unguarded cache with the main thread's draws,
## would have them (#455): the plates the dressing sizes by them stay as they were.

const TEXTS: Array[String] = ["Saloon", "Second class dining saloon", "Boiler room 6", "NO SMOKING"]


func test_one_line_measures_as_the_font_does() -> void:
	var font := ThemeDB.fallback_font
	for size: int in [RoomDressing.SIGN_FONT, VehicleDeck.NOTICE_FONT]:
		for text in TEXTS:
			var expected := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			assert_eq(SignText.line_size(text, size), expected, "%s at %d" % [text, size])


func test_lines_measure_as_the_font_does() -> void:
	var font := ThemeDB.fallback_font
	for text: String in [VehicleDeck.NO_SMOKING, VehicleDeck.AT_SEA]:
		var size := VehicleDeck.NOTICE_FONT
		var expected := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
		assert_eq(SignText.lines_size(text, size), expected, text)
