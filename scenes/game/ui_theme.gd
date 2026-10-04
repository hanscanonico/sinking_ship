class_name UiTheme
extends RefCounted
## The one look of every screen over the game — the main menu, the pause menu, the
## settings, the results and the online screens — in the ship's livery (ArtPalette):
## hull-dark plates edged in brass, cream type, varnished-teak buttons, a brass ring
## round whatever the keys or the pad have reached, and Playfair Display (assets/fonts,
## OFL) for titles and buttons. Every screen takes it with apply_to(): a CanvasLayer hands no theme
## down, so each layer's own Controls carry it.

## The Label variations a screen opts into with theme_type_variation.
const TITLE := &"TitleLabel"
const WORDMARK := &"WordmarkLabel"
const TAGLINE := &"TaglineLabel"
const HUD_LABEL := &"HudLabel"
## A room's code, large enough to read out across a room; a line of muted help under a
## field; and what is wrong, or what went wrong, in a short sentence.
const CODE_LABEL := &"CodeLabel"
const HINT_LABEL := &"HintLabel"
const PROBLEM_LABEL := &"ProblemLabel"
## The Button variation of one letter of a room code being picked.
const CODE_SLOT := &"CodeSlot"
## The Button variation of a button that waits out a press guard disabled — the
## results': it still reads as a button, only not yet lit, where every other disabled
## control looks it.
const GUARDED_BUTTON := &"GuardedButton"
const SERIF := preload("res://assets/fonts/playfair_display.ttf")
const TEXT := ArtPalette.LINEN
const MUTED := Color(ArtPalette.LINEN, 0.65)
## A screen's plate, opaque so nothing behind it — the wordmark under the settings —
## shows through; and the scrim over the world behind the results.
const PLATE := ArtPalette.HULL
const SCRIM := Color(ArtPalette.HULL, 0.55)
const OUTLINE := ArtPalette.INK
## The livery's rules round the wordmark: the boot-top red between brass lines.
const RULE := ArtPalette.HULL_BOTTOM
const TRIM := ArtPalette.BRASS
const FONT_SIZE := 17
const BUTTON_FONT_SIZE := 19
const TITLE_FONT_SIZE := 40
const WORDMARK_FONT_SIZE := 84
const TAGLINE_FONT_SIZE := 18
const CODE_FONT_SIZE := 60
const CODE_SLOT_FONT_SIZE := 28
const HINT_FONT_SIZE := 14
## What is wrong, in the brass's warm light: read at once on the hull-dark plate.
const PROBLEM := Color(1.0, 0.72, 0.2)
## The switch a CheckButton draws, and a slider's grabber, in pixels.
const SWITCH := Vector2i(40, 22)
const GRABBER := 18
const ELLIPSIS := "…"

static var _shared: Theme


## The theme, built once.
static func shared() -> Theme:
	if _shared == null:
		_shared = _build()
	return _shared


## Gives the theme to every Control directly under [param layer], and so to all of
## theirs.
static func apply_to(layer: CanvasLayer) -> void:
	for child: Node in layer.get_children():
		if child is Control:
			(child as Control).theme = shared()


## [param text] — a name a server sent, as long as it likes — within [param width]
## pixels of [param font] at [param font_size]: whole when it fits, else as much of its
## start as fits before an ellipsis.
static func fit(text: String, font: Font, font_size: int, width: float) -> String:
	if _width(text, font, font_size) <= width:
		return text
	# The longest start that fits with the ellipsis: none always does, all never.
	var kept := 0
	var over := text.length()
	while over - kept > 1:
		var middle := (kept + over) >> 1
		if _width(text.left(middle) + ELLIPSIS, font, font_size) <= width:
			kept = middle
		else:
			over = middle
	return text.left(kept).rstrip(" ") + ELLIPSIS


static func _width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Playfair Display at [param weight], 400 to 900.
static func _serif(weight: int, spacing: int = 0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = SERIF
	font.variation_opentype = {"wght": weight}
	font.spacing_glyph = spacing
	return font


## The main menu's shade over its backdrop: the hull's dark at the left, fading out
## across the screen, so the menu reads over a bright sky.
static func shade() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.8])
	gradient.colors = PackedColorArray(
		[Color(ArtPalette.HULL, 0.8), Color(ArtPalette.HULL, 0.35), Color(ArtPalette.HULL, 0.0)]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 1
	return texture


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	var button_font := _serif(600)
	var plate := _flat(PLATE, TRIM, 2, 4)
	plate.shadow_color = Color(OUTLINE, 0.5)
	plate.shadow_size = 14
	_margins(plate, 32.0, 24.0)
	theme.set_stylebox("panel", "PanelContainer", plate)
	theme.set_stylebox("panel", "Panel", plate)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_type_variation(TITLE, "Label")
	theme.set_font("font", TITLE, _serif(700))
	theme.set_font_size("font_size", TITLE, TITLE_FONT_SIZE)
	theme.set_type_variation(WORDMARK, "Label")
	theme.set_font("font", WORDMARK, _serif(900, 2))
	theme.set_font_size("font_size", WORDMARK, WORDMARK_FONT_SIZE)
	theme.set_color("font_outline_color", WORDMARK, OUTLINE)
	theme.set_constant("outline_size", WORDMARK, 12)
	theme.set_color("font_shadow_color", WORDMARK, Color(OUTLINE, 0.6))
	theme.set_constant("shadow_offset_x", WORDMARK, 0)
	theme.set_constant("shadow_offset_y", WORDMARK, 5)
	theme.set_type_variation(TAGLINE, "Label")
	theme.set_font("font", TAGLINE, _serif(600, 3))
	theme.set_font_size("font_size", TAGLINE, TAGLINE_FONT_SIZE)
	theme.set_color("font_color", TAGLINE, TRIM.lightened(0.45))
	theme.set_color("font_shadow_color", TAGLINE, Color(OUTLINE, 0.8))
	theme.set_constant("shadow_offset_x", TAGLINE, 0)
	theme.set_constant("shadow_offset_y", TAGLINE, 2)
	theme.set_type_variation(HUD_LABEL, "Label")
	theme.set_color("font_outline_color", HUD_LABEL, OUTLINE)
	theme.set_constant("outline_size", HUD_LABEL, 6)
	theme.set_type_variation(CODE_LABEL, "Label")
	theme.set_font("font", CODE_LABEL, _serif(900, 10))
	theme.set_font_size("font_size", CODE_LABEL, CODE_FONT_SIZE)
	theme.set_color("font_color", CODE_LABEL, TRIM.lightened(0.45))
	theme.set_color("font_outline_color", CODE_LABEL, OUTLINE)
	theme.set_constant("outline_size", CODE_LABEL, 8)
	theme.set_type_variation(HINT_LABEL, "Label")
	theme.set_color("font_color", HINT_LABEL, MUTED)
	theme.set_font_size("font_size", HINT_LABEL, HINT_FONT_SIZE)
	theme.set_type_variation(PROBLEM_LABEL, "Label")
	theme.set_color("font_color", PROBLEM_LABEL, PROBLEM)

	var focus := _flat(Color.TRANSPARENT, TRIM.lightened(0.35), 2, 6)
	focus.draw_center = false
	focus.set_expand_margin_all(3.0)
	var teak := ArtPalette.TEAK
	var normal := _flat(Color(teak.darkened(0.55), 0.95), TRIM.darkened(0.35), 1, 3)
	var hover := _flat(teak.darkened(0.3), TRIM, 1, 3)
	var pressed := _flat(teak.darkened(0.7), TRIM, 1, 3)
	# Disabled: no teak, no brass, faint type — nothing to press.
	var disabled := _flat(Color(OUTLINE, 0.45), Color(TEXT, 0.2), 1, 3)
	for style: StyleBoxFlat in [normal, hover, pressed, disabled]:
		_margins(style, 18.0, 7.0)
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		theme.set_font("font", type, button_font)
		theme.set_font_size("font_size", type, BUTTON_FONT_SIZE)
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_hover_color", type, TRIM.lightened(0.45))
		theme.set_color("font_pressed_color", type, TRIM.lightened(0.2))
		theme.set_color("font_hover_pressed_color", type, TRIM.lightened(0.2))
		theme.set_color("font_disabled_color", type, Color(TEXT, 0.35))
	# A choice's arrow takes its type's colour, so a disabled one fades with it.
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	theme.set_type_variation(GUARDED_BUTTON, "Button")
	theme.set_stylebox("disabled", GUARDED_BUTTON, normal)
	theme.set_color("font_disabled_color", GUARDED_BUTTON, Color(TEXT, 0.75))
	theme.set_type_variation(CODE_SLOT, "Button")
	theme.set_font("font", CODE_SLOT, _serif(800))
	theme.set_font_size("font_size", CODE_SLOT, CODE_SLOT_FONT_SIZE)

	var popup := _flat(PLATE, TRIM.darkened(0.2), 1, 3)
	_margins(popup, 6.0, 6.0)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _flat(teak.darkened(0.3), TRIM, 1, 2))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TRIM.lightened(0.45))
	theme.set_font_size("font_size", "PopupMenu", FONT_SIZE)

	var field := _flat(Color(OUTLINE, 0.9), TRIM.darkened(0.35), 0, 2)
	field.border_width_bottom = 2
	_margins(field, 10.0, 6.0)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(TEXT, 0.4))
	theme.set_color("caret_color", "LineEdit", TRIM.lightened(0.35))
	theme.set_color("selection_color", "LineEdit", Color(TRIM, 0.4))

	var track := _flat(Color(OUTLINE, 0.9), TRIM.darkened(0.45), 1, 3)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var filled := _flat(TRIM.darkened(0.1), Color.TRANSPARENT, 0, 3)
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	var filled_lit := filled.duplicate() as StyleBoxFlat
	filled_lit.bg_color = TRIM.lightened(0.2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	# A slider draws no focus ring: its lit grabber and fill are what show it has focus.
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_lit)
	theme.set_icon("grabber", "HSlider", _knob(TEXT, TRIM.darkened(0.2)))
	theme.set_icon("grabber_highlight", "HSlider", _knob(TRIM.lightened(0.35), Color.WHITE))
	theme.set_icon("grabber_disabled", "HSlider", _knob(MUTED, TRIM.darkened(0.4)))

	# A CheckButton would otherwise take the Button's plate round its switch.
	var bare := StyleBoxEmpty.new()
	_margins(bare, 4.0, 4.0)
	for style: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(style, "CheckButton", bare)
	theme.set_stylebox("focus", "CheckButton", focus)
	var off := _switch(teak.darkened(0.55), false)
	var on := _switch(TRIM, true)
	for icon: String in ["", "_disabled", "_mirrored", "_disabled_mirrored"]:
		theme.set_icon("unchecked" + icon, "CheckButton", off)
		theme.set_icon("checked" + icon, "CheckButton", on)
	return theme


static func _flat(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


static func _margins(style: StyleBox, across: float, down: float) -> void:
	style.content_margin_left = across
	style.content_margin_right = across
	style.content_margin_top = down
	style.content_margin_bottom = down


## A slider's grabber: a [param fill] disc ringed in [param ring].
static func _knob(fill: Color, ring: Color) -> ImageTexture:
	var image := Image.create_empty(GRABBER, GRABBER, false, Image.FORMAT_RGBA8)
	var centre := Vector2(GRABBER, GRABBER) * 0.5
	var radius := GRABBER * 0.5 - 1.0
	for y in GRABBER:
		for x in GRABBER:
			var from := Vector2(x + 0.5, y + 0.5).distance_to(centre)
			var colour := fill if from < radius - 2.5 else ring
			image.set_pixel(x, y, Color(colour, colour.a * clampf(radius - from + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## A toggle switch: a brass-rimmed [param track] pill with a cream knob at its left,
## or its right when [param on].
static func _switch(track: Color, on: bool) -> ImageTexture:
	var image := Image.create_empty(SWITCH.x, SWITCH.y, false, Image.FORMAT_RGBA8)
	var half := SWITCH.y * 0.5
	var knob := Vector2(SWITCH.x - half if on else half, half)
	var ends := [Vector2(half, half), Vector2(SWITCH.x - half, half)]
	for y in SWITCH.y:
		for x in SWITCH.x:
			var at := Vector2(x + 0.5, y + 0.5)
			var along := Vector2(clampf(at.x, ends[0].x, ends[1].x), half)
			var inside := half - at.distance_to(along)
			var rim := clampf(1.5 - inside, 0.0, 1.0)
			var disc := clampf(half - 4.0 - at.distance_to(knob) + 0.5, 0.0, 1.0)
			var colour := track.lerp(TRIM.darkened(0.2), rim).lerp(TEXT, disc)
			image.set_pixel(x, y, Color(colour, clampf(inside + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
