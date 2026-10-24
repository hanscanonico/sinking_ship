extends GutTest
## The spectating line (art pass IV): it names whose view it is in plain words —
## your own seat's, a bot's, an online player's — and runs, whole, clear of the
## readouts' plate and of a wedge's arrow on the bottom edge.

## The canvases the line is checked on: 16:9 and 16:10 windows, and an ultrawide.
const SIZES: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1152.0, 720.0), Vector2(1536.0, 648.0)
]
## As match.tscn's Spectating label draws it.
const FONT_SIZE := 22
const OUTLINE := 6
const WITH_HER := PlayerState.Cause.WITH_HER


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


func test_the_goal_shows_with_the_countdown_and_go_then_goes() -> void:
	var scene: Node = load("res://scenes/match/match.tscn").instantiate()
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
		lines.append_array(
			Hud.spectating_text("16th", 16, "", previous, next, free, true).split("\n")
		)
	var height := 0.0
	for line: String in lines:
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		assert_lt(width + OUTLINE * 2.0, box.size.x, "%s fits on one line" % line)
	for line in 2:
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
