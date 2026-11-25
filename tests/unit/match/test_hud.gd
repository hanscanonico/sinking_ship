extends GutTest
## The spectating line (art pass IV): it names whose view it is in plain words —
## your own seat's, a bot's, an online player's — and runs, whole, clear of the
## readouts' plate and of a wedge's arrow on the bottom edge.

const MATCH := preload("res://scenes/match/match.tscn")
## The canvases the line is checked on: 16:9 and 16:10 windows, and an ultrawide.
const SIZES: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1152.0, 720.0), Vector2(1536.0, 648.0)
]
## As match.tscn's Spectating label draws it.
const FONT_SIZE := 22
const OUTLINE := 6
const WITH_HER := PlayerState.Cause.WITH_HER
const COLD := PlayerState.Cause.COLD


func test_the_line_names_whose_view_it_is() -> void:
	assert_eq(Hud.whose_view("Bot 3", false, false), "through Bot 3's eyes")
	assert_eq(Hud.whose_view("Ines", false, false), "through Ines's eyes")
	assert_eq(Hud.whose_view("You", true, false), "through your own eyes", "never You's")
	assert_eq(Hud.whose_view("Bot 3", false, true), "watching Bot 3")
	assert_eq(Hud.whose_view("You", true, true), "watching you")


func test_the_countdown_says_what_the_match_is_played_for() -> void:
	assert_eq(
		Hud.goal_text(MatchRules.Goal.LAST_STANDING),
		"Be the last one dry. Shove rivals into the sea."
	)
	assert_eq(Hud.goal_text(MatchRules.Goal.SURVIVAL), "Stay aboard as long as she floats.")


## A watcher has no seat: the countdown tells them what the seats play for rather than
## asking them to shove anyone (seen watching online, 2026-11-25).
func test_a_watcher_is_told_the_goal_not_asked_it() -> void:
	assert_eq(Hud.goal_text(MatchRules.Goal.LAST_STANDING, false), "The last one dry wins.")
	assert_eq(
		Hud.goal_text(MatchRules.Goal.SURVIVAL, false), "They stay aboard as long as she floats."
	)
	var scene: Node = MATCH.instantiate()
	add_child_autofree(scene)
	var hud: Hud = scene.get_node("Hud")
	hud.setup(MatchSim.create(SimFixtures.config(2)), false)
	assert_eq((hud.get_node("%Goal") as Label).text, "The last one dry wins.")


func test_the_goal_shows_with_the_countdown_and_go_then_goes() -> void:
	var scene: Node = MATCH.instantiate()
	add_child_autofree(scene)
	var hud: Hud = scene.get_node("Hud")
	var goal: Label = hud.get_node("%Goal")
	var countdown := Ticks.from_seconds(3.0)
	for rule: MatchRules.Goal in [MatchRules.Goal.LAST_STANDING, MatchRules.Goal.SURVIVAL]:
		var config := SimFixtures.config(2)
		config.countdown_ticks = countdown
		config.goal = rule
		var sim := MatchSim.create(config)
		hud.setup(sim)
		assert_eq(goal.text, Hud.goal_text(rule), "the match's own goal")
		var snapshot := sim.snapshot()
		for tick: int in [0, countdown - 1, countdown]:
			snapshot["tick"] = tick
			hud.show_snapshot(snapshot)
			assert_true(goal.visible, "up at tick %d, the countdown's or Go!'s" % tick)
		snapshot["tick"] = countdown + Ticks.from_seconds(Hud.GO_SECONDS)
		hud.show_snapshot(snapshot)
		assert_false(goal.visible, "gone with Go!")
		var font := goal.get_theme_font(&"font")
		var font_size := goal.get_theme_font_size(&"font_size")
		var width := font.get_string_size(goal.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var outline := goal.get_theme_constant(&"outline_size")
		assert_lt(width + outline * 2.0, goal.size.x, "%s fits on one line" % goal.text)


func test_the_line_says_how_into_the_free_camera_and_back() -> void:
	assert_eq(
		Hud.spectating_text("3rd", 8, "through Bot 3's eyes", "Q", "E", "C"),
		"Overboard — 3rd of 8   ·   through Bot 3's eyes\nQ / E to switch   ·   C free camera"
	)
	assert_eq(
		Hud.spectating_text("3rd", 8, "through Bot 3's eyes", "Q", "E", "C", true),
		"Overboard — 3rd of 8   ·   free camera\nQ / E to switch   ·   C eyes"
	)
	assert_eq(
		Hud.spectating_text("3rd", 8, "watching Bot 3", "Q", "E"),
		"Overboard — 3rd of 8   ·   watching Bot 3\nQ / E to switch",
		"no free camera from the observer's"
	)
	assert_eq(
		Hud.spectating_text("3rd", 8, "watching Bot 3", "Q", "E", "", false, WITH_HER),
		"Sunk — 3rd of 8   ·   watching Bot 3\nQ / E to switch",
		"inside her as she went, never overboard"
	)


## A seat the cold put out inside one of her rooms never went overboard: the line says
## frozen. Sunk with her stays sunk wherever it was.
func test_the_line_says_frozen_for_a_seat_the_cold_put_out_aboard() -> void:
	assert_eq(Hud.out_word(COLD), "Overboard")
	assert_eq(Hud.out_word(COLD, true), "Frozen")
	assert_eq(Hud.out_word(WITH_HER, true), "Sunk", "inside her as she went: sunk")
	var aboard := Hud.spectating_text(
		"3rd", 8, "watching Bot 3", "Q", "E", "", false, COLD, "", false, "", false, true
	)
	assert_eq(aboard, "Frozen — 3rd of 8   ·   watching Bot 3\nQ / E to switch")


## Frozen is no wider than overboard — the English word the line's box was sized for — in
## any language, and the line a seat frozen aboard reads, the widest name in it, fits the
## box in each.
func test_frozen_is_no_wider_than_overboard_in_any_language() -> void:
	var font := UiTheme.shared().get_font(&"font", &"Label")
	var box := Hud.spectating_box(SIZES[0])
	var widest := UiTheme.fit("WWWWWWWWWWWWWWWW", font, FONT_SIZE, Hud.NAME_WIDTH)
	var english := Hud.out_word(COLD)
	var overboard := font.get_string_size(english, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	for language: String in ["en", "fr", "es"]:
		Language.use(language)
		var frozen := Hud.out_word(COLD, true)
		assert_ne(frozen, Hud.out_word(COLD), "%s: a word of its own" % language)
		var word := font.get_string_size(frozen, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		assert_lte(word, overboard, "%s: %s against Overboard" % [language, frozen])
		for observer: bool in [false, true]:
			var whose := Hud.whose_view(widest, false, observer)
			var text := Hud.spectating_text(
				Language.ordinal(16),
				16,
				whose,
				"Q",
				"E",
				"C",
				false,
				COLD,
				"",
				false,
				"",
				false,
				true
			)
			var line := text.split("\n")[0]
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			assert_lt(width + OUTLINE * 2.0, box.size.x, "%s fits on one line" % line)
	Language.use(Language.SOURCE)


## Once out, the free camera's line says how to follow the seat watched, and how to let go.
func test_the_line_from_the_free_camera_says_how_to_follow() -> void:
	assert_eq(
		Hud.spectating_text("3rd", 8, "through Bot 3's eyes", "Q", "E", "C", true, COLD, "V"),
		"Overboard — 3rd of 8   ·   free camera\nQ / E to switch   ·   C eyes\nV follow"
	)
	assert_eq(
		Hud.spectating_text("3rd", 8, "", "Q", "E", "C", true, COLD, "V", true),
		"Overboard — 3rd of 8   ·   free camera\nQ / E to switch   ·   C eyes\nV let go"
	)
	assert_eq(
		Hud.spectating_text("3rd", 8, "through Bot 3's eyes", "Q", "E", "C", false, COLD, "V"),
		"Overboard — 3rd of 8   ·   through Bot 3's eyes\nQ / E to switch   ·   C free camera",
		"no follow from the eyes"
	)


## The ghost's key ends the line, into it or back to the eyes from it, which the line
## then names.
func test_the_line_says_how_into_the_ghost_and_back() -> void:
	assert_eq(
		Hud.spectating_text(
			"3rd", 8, "through Bot 3's eyes", "Q", "E", "C", false, COLD, "V", false, "B"
		),
		"Overboard — 3rd of 8   ·   through Bot 3's eyes\nQ / E to switch   ·   C free camera\nB ghost"
	)
	assert_eq(
		Hud.spectating_text(
			"3rd", 8, "through Bot 3's eyes", "Q", "E", "C", false, COLD, "V", false, "B", true
		),
		"Overboard — 3rd of 8   ·   ghost\nQ / E to switch   ·   C free camera\nB eyes"
	)
	assert_eq(
		Hud.spectating_text("3rd", 8, "", "Q", "E", "C", true, COLD, "V", false, "B"),
		"Overboard — 3rd of 8   ·   free camera\nQ / E to switch   ·   C eyes\nV follow   ·   B ghost"
	)
	assert_eq(
		Hud.watching_text("Bot 3", Hud.Camera.GHOST, false, "Q", "E", "C", "V", "B"),
		"Watching   ·   ghost\nQ / E to switch   ·   C free camera\nB eyes"
	)
	assert_eq(
		Hud.watching_text("Bot 3", Hud.Camera.EYES, false, "Q", "E", "C", "V", "B"),
		"Watching   ·   through Bot 3's eyes\nQ / E to switch   ·   C free camera\nB ghost"
	)


## A watcher's line names the seat watched, from its eyes or the free camera following
## it, and the keys to switch seat and camera — the follow only from the free camera.
func test_the_watchers_line_names_the_seat_and_the_cameras() -> void:
	var eyes := Hud.Camera.EYES
	var free := Hud.Camera.FREE
	assert_eq(
		Hud.watching_text("Bot 3", eyes, false, "Q", "E", "C", "V"),
		"Watching   ·   through Bot 3's eyes\nQ / E to switch   ·   C free camera"
	)
	assert_eq(
		Hud.watching_text("Bot 3", free, false, "Q", "E", "C", "V"),
		"Watching   ·   free camera\nQ / E to switch   ·   C eyes\nV follow"
	)
	assert_eq(
		Hud.watching_text("Bot 3", free, true, "Q", "E", "C", "V"),
		"Watching   ·   following Bot 3\nQ / E to switch   ·   C eyes\nV let go"
	)


## The watcher's line, the widest name and either device's keys, fits each of its lines
## in the spectating line's box.
func test_the_watchers_line_fits_its_box() -> void:
	var box := Hud.spectating_box(SIZES[0])
	var font := UiTheme.shared().get_font(&"font", &"Label")
	var widest := UiTheme.fit("WWWWWWWWWWWWWWWW", font, FONT_SIZE, Hud.NAME_WIDTH)
	for pad: bool in [false, true]:
		var keys := PackedStringArray()
		for action: StringName in [
			&"spectate_previous",
			&"spectate_next",
			&"spectate_free",
			&"spectate_follow",
			&"spectate_ghost",
		]:
			keys.append(InputPrompts.word_for(InputMap.action_get_events(action), pad))
		for camera: Hud.Camera in [Hud.Camera.EYES, Hud.Camera.FREE, Hud.Camera.GHOST]:
			for following: bool in [false, true]:
				var text := Hud.watching_text(
					widest, camera, following, keys[0], keys[1], keys[2], keys[3], keys[4]
				)
				for line: String in text.split("\n"):
					var width := (
						font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
					)
					assert_lt(width + OUTLINE * 2.0, box.size.x, "%s fits on one line" % line)


## The longest name the line shows — clipped to Hud.NAME_WIDTH as the HUD clips it, in
## the font the HUD draws it in — with the keyboard's or the pad's prompts, gone
## overboard or sunk with her, still fits each line in the box, and the box stands
## clear of the plate and of every arrow a wedge on the bottom edge points with,
## however wide the canvas.
func test_the_line_fits_clear_of_the_plate_and_the_wedges() -> void:
	var narrowest := SIZES[0]
	var box := Hud.spectating_box(narrowest)
	var font := UiTheme.shared().get_font(&"font", &"Label")
	var widest := UiTheme.fit("WWWWWWWWWWWWWWWW", font, FONT_SIZE, Hud.NAME_WIDTH)
	var lines := PackedStringArray()
	for pad: bool in [false, true]:
		var previous := InputPrompts.word_for(InputMap.action_get_events(&"spectate_previous"), pad)
		var next := InputPrompts.word_for(InputMap.action_get_events(&"spectate_next"), pad)
		var free := InputPrompts.word_for(InputMap.action_get_events(&"spectate_free"), pad)
		for observer: bool in [false, true]:
			var whose := Hud.whose_view(widest, false, observer)
			var key := "" if observer else free
			for cause: PlayerState.Cause in [PlayerState.Cause.COLD, WITH_HER]:
				var text := Hud.spectating_text(
					"16th", 16, whose, previous, next, key, false, cause
				)
				lines.append_array(text.split("\n"))
		var follow := InputPrompts.word_for(InputMap.action_get_events(&"spectate_follow"), pad)
		var ghost := InputPrompts.word_for(InputMap.action_get_events(&"spectate_ghost"), pad)
		for following: bool in [false, true]:
			for walking: bool in [false, true]:
				var text := Hud.spectating_text(
					"16th",
					16,
					widest,
					previous,
					next,
					free,
					not walking,
					WITH_HER,
					follow,
					following,
					ghost,
					walking
				)
				lines.append_array(text.split("\n"))
	var height := 0.0
	for line: String in lines:
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		assert_lt(width + OUTLINE * 2.0, box.size.x, "%s fits on one line" % line)
	for line in 3:
		height += font.get_height(FONT_SIZE)
	for size: Vector2 in SIZES:
		# Anchored to the bottom middle: a wider or taller canvas moves it as a whole.
		var bottom := box.end.y + size.y - narrowest.y
		var shown := Rect2(size.x * 0.5 - box.size.x * 0.5, bottom - height, box.size.x, height)
		shown = shown.grow(OUTLINE)
		assert_false(
			shown.intersects(FirstPersonHud.plate_rect(size)), "%s: clear of the plate" % size
		)
		var reach := FirstPersonHud.behind_arrow_reach()
		for degrees in range(136, 225):
			var bearing := deg_to_rad(degrees if degrees <= 180 else degrees - 360)
			var root := FirstPersonHud.wedge_behind(size, bearing)
			var arrow := Rect2(root - Vector2(reach, reach), Vector2(reach * 2.0, reach))
			assert_false(shown.intersects(arrow), "%s %d°: clear of the arrow" % [size, degrees])


## The hints for play under the countdown keep clear of the window's sides in every
## language, on a keyboard and on a pad, broken between two hints and never inside one:
## Spanish stood 1136 px wide in a 1152 px window.
func test_the_hints_for_play_fit_the_window_in_every_language() -> void:
	var font := UiTheme.shared().get_font(&"font", &"Label")
	for language: String in Language.locales():
		Language.use(language)
		for on_pad: bool in [false, true]:
			var line := InputPrompts.controls_for(on_pad)
			for size: Vector2 in SIZES:
				var width := size.x - 2.0 * Hud.CONTROLS_MARGIN
				var text := Hud.controls_text(line, font, FONT_SIZE, width)
				var said := "%s pad=%s %d" % [language, on_pad, size.x]
				assert_eq(text.replace("\n", ReplayHud.SEPARATOR), line, "whole: " + said)
				for row: String in text.split("\n"):
					var wide := font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
					assert_lte(wide.x, width, "fits: " + said)
					assert_eq(row, row.strip_edges(), "no dot at an end: " + said)
	Language.use(Language.SOURCE)


func test_a_line_of_hints_too_long_for_the_window_breaks_between_two() -> void:
	var font := UiTheme.shared().get_font(&"font", &"Label")
	var line := "W A S D — move   ·   Space — jump   ·   Left click — shove"
	assert_eq(Hud.controls_text(line, font, FONT_SIZE, 2000.0), line, "room for it: one line")
	var five := line + "   ·   Shift — brace   ·   G — grab"
	var lines := Hud.controls_text(five, font, FONT_SIZE, 760.0).split("\n")
	assert_eq(lines.size(), 2)
	for row: String in lines:
		assert_gt(row.split(ReplayHud.SEPARATOR).size(), 1, "no hint left alone: " + row)
	var two := Hud.controls_text(line, font, FONT_SIZE, 420.0)
	assert_eq(two, "W A S D — move   ·   Space — jump\nLeft click — shove")


## The keys' hints stay up through the countdown and a few seconds of play past it: they
## went with "Go!", four seconds after they came, and a bot's first shove lands at the
## sixth. A match with no countdown has none.
func test_the_keys_hints_outlast_go() -> void:
	var countdown := Ticks.from_seconds(3.0)
	var past := Ticks.from_seconds(Hud.HINT_SECONDS)
	assert_true(Hud.hinting(0, countdown))
	assert_true(Hud.hinting(countdown + Ticks.from_seconds(Hud.GO_SECONDS), countdown), "past Go!")
	assert_true(Hud.hinting(countdown + past - 1, countdown))
	assert_false(Hud.hinting(countdown + past, countdown), "then gone")
	assert_false(Hud.hinting(0, 0), "no countdown: no hints")
	assert_gt(Hud.HINT_SECONDS, 4.0, "long enough to read five hints")
	var scene: Node = MATCH.instantiate()
	add_child_autofree(scene)
	var hud: Hud = scene.get_node("Hud")
	var config := SimFixtures.config(2)
	config.countdown_ticks = countdown
	var sim := MatchSim.create(config)
	hud.setup(sim)
	var prompts: InputPrompts = autofree(InputPrompts.new())
	var controls: Label = hud.get_node("%Controls")
	var snapshot := sim.snapshot()
	snapshot["tick"] = countdown + Ticks.from_seconds(2.0)
	hud.show_snapshot(snapshot)
	hud.show_controls(prompts)
	assert_true(controls.visible, "two seconds in: still up")
	hud.show_controls(null)
	assert_false(controls.visible, "none for a watcher")
	snapshot["tick"] = countdown + past
	hud.show_snapshot(snapshot)
	hud.show_controls(prompts)
	assert_false(controls.visible, "gone")
