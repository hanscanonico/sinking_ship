extends GutTest
## The replay's key hints wrap between hints, never inside one, and no line starts or
## ends on a lone dot (ReplayHud.hint_line).

const NO_BREAK_DOT := ReplayHud.NO_BREAK + "·"


func test_no_hint_breaks_inside_itself() -> void:
	for pad: bool in [false, true]:
		var prompts: InputPrompts = autofree(InputPrompts.new())
		prompts.pad = pad
		var hints := ReplayHud.hint_line(prompts).split(ReplayHud.SEPARATOR)
		assert_eq(hints.size(), ReplayHud.HINTS.size(), "one hint for each key")
		for hint: String in hints:
			assert_false(hint.contains(" "), "%s holds together" % hint.c_escape())
			assert_true(hint.contains(ReplayHud.NO_BREAK), "%s keeps its spaces" % hint)


func test_each_dot_holds_to_the_hint_before_it() -> void:
	# Wherever the line wraps — at an ordinary space — a line ends on a hint and its dot
	# and the next starts on a hint: never a dot alone at either end.
	for pad: bool in [false, true]:
		var prompts: InputPrompts = autofree(InputPrompts.new())
		prompts.pad = pad
		var pieces := ReplayHud.hint_line(prompts).split(" ", false)
		assert_eq(pieces.size(), ReplayHud.HINTS.size(), "a break only between hints")
		for i: int in pieces.size():
			var piece := pieces[i]
			assert_false(piece.begins_with("·"), "%s starts on a dot" % piece.c_escape())
			if i < pieces.size() - 1:
				assert_true(piece.ends_with(NO_BREAK_DOT), "%s keeps its dot" % piece.c_escape())
			else:
				assert_false(piece.contains("·"), "the last hint has no dot after it")
