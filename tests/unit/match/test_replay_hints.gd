extends GutTest
## The replay's key hints are broken into lines between hints, never inside one, and a
## line break takes the separator's place: no line starts or ends on a dot
## (ReplayHud.hint_text).

const FONT_SIZE := UiTheme.HINT_FONT_SIZE
## The plate's width in a window 1152 wide: from past the seat's own plate to its margin.
const AT_1152 := 1152.0 - 276.0 - ReplayHud.PLATE_MARGIN


func _widths(of: Array) -> PackedFloat32Array:
	return PackedFloat32Array(of)


func test_hints_fill_a_line_and_go_on_to_the_next() -> void:
	var lines := ReplayHud.lines_of(_widths([40.0, 40.0, 40.0, 40.0, 40.0]), 10.0, 100.0)
	assert_eq(lines, PackedInt32Array([2, 2, 1]), "40 + 10 + 40, and a third would not fit")
	lines = ReplayHud.lines_of(_widths([40.0, 50.0]), 10.0, 100.0)
	assert_eq(lines, PackedInt32Array([2]), "a line filled to its width holds")
	lines = ReplayHud.lines_of(_widths([40.0, 51.0]), 10.0, 100.0)
	assert_eq(lines, PackedInt32Array([1, 1]), "the gap counts")
	lines = ReplayHud.lines_of(_widths([30.0, 140.0, 30.0]), 10.0, 100.0)
	assert_eq(lines, PackedInt32Array([1, 1, 1]), "a hint wider than a line has its own")
	assert_eq(ReplayHud.lines_of(_widths([]), 10.0, 100.0), PackedInt32Array(), "no hints")


## Whatever the width, the device and the language: every hint is whole on one line, in
## its order, every line fits unless it is one hint alone, and none starts or ends on a
## dot or a space.
func test_no_line_starts_or_ends_on_a_dot() -> void:
	var font := UiTheme.shared().get_font(&"font", UiTheme.HINT_LABEL)
	for language: String in Language.locales():
		Language.use(language)
		for pad: bool in [false, true]:
			var prompts: InputPrompts = autofree(InputPrompts.new())
			prompts.pad = pad
			var hints := ReplayHud.hints(prompts)
			var keyed := 0
			for hint: Array in ReplayHud.HINTS:
				keyed += 0 if prompts.word(hint[0]).is_empty() else 1
			assert_eq(hints.size(), keyed, "one hint for each key the device has")
			assert_gt(hints.size(), 5, "and it has most")
			for hint: String in hints:
				assert_gt(hint.split(" ").size(), 1, "a key and what it does: " + hint)
			for width: float in [200.0, 480.0, 800.0, AT_1152, 1896.0, 4000.0]:
				var text := ReplayHud.hint_text(hints, font, FONT_SIZE, width)
				var found := PackedStringArray()
				for line: String in text.split("\n"):
					var on_line := line.split(ReplayHud.SEPARATOR)
					found.append_array(on_line)
					assert_eq(line, line.strip_edges(), "no space at an end of a line")
					assert_false(line.begins_with("·") or line.ends_with("·"), line)
					var wide := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
					if on_line.size() > 1:
						assert_lte(wide.x, width, "%s fits %d" % [line, width])
				assert_eq(found, hints, "every hint whole, in its order")
	Language.use(Language.SOURCE)


## The bar stands beside the watched seat's plate, never over it.
func test_the_bar_leaves_the_seat_s_plate_in_sight() -> void:
	for size: Vector2 in [Vector2(1152.0, 648.0), Vector2(1152.0, 864.0), Vector2(1536.0, 648.0)]:
		var seat := FirstPersonHud.plate_rect(size, 2)
		assert_gte(ReplayHud.plate_left(), seat.end.x + ReplayHud.PLATE_MARGIN, str(size))
	assert_eq(1152.0 - ReplayHud.plate_left() - ReplayHud.PLATE_MARGIN, AT_1152)


## In a window 1152 wide the hints take three lines at the most, in every language, on
## the keys and on a pad.
func test_the_hints_take_three_lines_at_the_most_at_1152() -> void:
	var font := UiTheme.shared().get_font(&"font", UiTheme.HINT_LABEL)
	var panel := UiTheme.shared().get_stylebox(&"panel", &"PanelContainer")
	var width := AT_1152 - panel.get_minimum_size().x
	for language: String in Language.locales():
		Language.use(language)
		for pad: bool in [false, true]:
			var prompts: InputPrompts = autofree(InputPrompts.new())
			prompts.pad = pad
			var text := ReplayHud.hint_text(ReplayHud.hints(prompts), font, FONT_SIZE, width)
			assert_lte(text.split("\n").size(), 3, "%s, pad %s:\n%s" % [language, pad, text])
	Language.use(Language.SOURCE)


## The plate lays its hints out in the width it has: wide, they are one line; narrowed,
## they are broken with no dot left at a line's end.
func test_the_plate_breaks_its_hints_to_its_width() -> void:
	var hud: ReplayHud = add_child_autofree(ReplayHud.new())
	var prompts: InputPrompts = add_child_autofree(InputPrompts.new())
	hud.show_state(0, true, 1.0, "", "", prompts)
	var hint: Label = hud.find_children("*", "Label", true, false).back()
	hint.size.x = 4000.0
	assert_eq(hint.text.split("\n").size(), 1, "all on one line")
	hint.size.x = 480.0
	var lines := hint.text.split("\n")
	assert_gt(lines.size(), 2)
	for line: String in lines:
		assert_false(line.ends_with("·") or line.ends_with(" "), line)


## A pad has no button to the replay's start or its end: it is told of neither, where it
## read "to the start" with nothing to press.
func test_a_pad_is_not_told_of_what_it_has_no_button_for() -> void:
	var prompts: InputPrompts = autofree(InputPrompts.new())
	prompts.pad = false
	var keyboard := ReplayHud.hints(prompts)
	assert_true(keyboard.has("Home to the start"), "a keyboard has the key")
	prompts.pad = true
	var pad := ReplayHud.hints(prompts)
	assert_lt(pad.size(), keyboard.size())
	for hint: String in pad:
		assert_false(hint.ends_with("to the start") or hint.ends_with("to the end"), hint)
