extends GutTest
## The replay's key hints wrap between hints, never inside one (ReplayHud.hint_line).


func test_no_hint_breaks_inside_itself() -> void:
	for pad: bool in [false, true]:
		var prompts: InputPrompts = autofree(InputPrompts.new())
		prompts.pad = pad
		var hints := ReplayHud.hint_line(prompts).split("   ·   ")
		assert_eq(hints.size(), ReplayHud.HINTS.size(), "one hint for each key")
		for hint: String in hints:
			assert_false(hint.contains(" "), "%s holds together" % hint.c_escape())
			assert_true(hint.contains(ReplayHud.NO_BREAK), "%s keeps its spaces" % hint)


func test_the_line_breaks_between_hints() -> void:
	var prompts: InputPrompts = autofree(InputPrompts.new())
	assert_string_contains(ReplayHud.hint_line(prompts), "   ·   ")
