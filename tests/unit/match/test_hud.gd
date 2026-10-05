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


func test_the_line_names_whose_view_it_is() -> void:
	assert_eq(Hud.whose_view("Bot 3", false, false), "through Bot 3's eyes")
	assert_eq(Hud.whose_view("Ines", false, false), "through Ines's eyes")
	assert_eq(Hud.whose_view("You", true, false), "through your own eyes", "never You's")
	assert_eq(Hud.whose_view("Bot 3", false, true), "watching Bot 3")
	assert_eq(Hud.whose_view("You", true, true), "watching you")


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


## The longest name the line shows — clipped to Hud.NAME_WIDTH as the HUD clips it, in
## the font the HUD draws it in — with the keyboard's or the pad's prompts still fits
## each line in the box, and the box stands clear of the plate and of every arrow a
## wedge on the bottom edge points with, however wide the canvas.
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
			lines.append_array(
				Hud.spectating_text("16th", 16, whose, previous, next, key).split("\n")
			)
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
