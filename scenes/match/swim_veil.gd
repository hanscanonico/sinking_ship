class_name SwimVeil
extends Control
## What the water does to a swimmer's eyes (FirstPersonHud): frost grown in from the
## screen's edges as its cold meter empties; the dark closing in as its breath runs out
## with its head under the water (#861); and, while that breath is not full, a bar of it
## under the crosshair. The two never read as one: the cold is white and comes from the
## edges while the eyes swim, the breath is dark and has a bar of its own. It stands under
## the HUD's canvas, so the readouts stay legible through both.

const FROST_SHADER := preload("res://scenes/match/frost.gdshader")
const BREATHLESS_SHADER := preload("res://scenes/match/breathless.gdshader")
## The frost's crystal texture: its side in pixels, and how many crystals across it.
const CRYSTAL_SIZE := 512
const CRYSTAL_CELLS := 9.0
## The breath's bar: its size, how far under the crosshair its middle stands — under the
## prompts there (FirstPersonHud.PROMPT_BELOW) — and how far over it its name.
const BAR := Vector2(180.0, 10.0)
const BAR_BELOW := 108.0
const NAME_OVER := 8.0
const FONT_SIZE := 16
const TEXT := Color(1.0, 1.0, 1.0)
const INK := Color(0.06, 0.09, 0.13, 0.9)
## The breath reads as air, pale until under BREATH_LOW of a full one, then GASPING.
const AIR := Color(0.78, 0.93, 1.0)
const GASPING := Color(1.0, 0.3, 0.25)
const BREATH_LOW := 0.35

var _frost: ColorRect
var _dark: ColorRect
var _bar: Control
## The share of a full breath the bar shows.
var _breath := 1.0


## Over the whole screen from before it is in the tree: anchored once in it, a Control
## keeps the empty rect it had.
func _init() -> void:
	name = "SwimVeil"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_frost = _veil("Frost", FROST_SHADER)
	(_frost.material as ShaderMaterial).set_shader_parameter(&"crystals", _crystals())
	_dark = _veil("Breathless", BREATHLESS_SHADER)
	_bar = Control.new()
	_bar.name = "Breath"
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.hide()
	add_child(_bar)
	_bar.draw.connect(_draw_bar)


## A hidden pass over the whole screen named [param title], drawn by [param shader].
func _veil(title: String, shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = title
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.hide()
	add_child(rect)
	return rect


## Shows what the water has done to [param entry], a seat's in a snapshot of a match
## under [param rules] — nothing for an empty one, the eyes not a seat's still in.
func show_for(entry: Dictionary, rules: BrawlRules) -> void:
	var cold := cold_gone(entry, rules)
	_frost.visible = cold > 0.0
	if _frost.visible:
		(_frost.material as ShaderMaterial).set_shader_parameter(&"cold", cold)
	var breath := breath_left(entry, rules)
	_dark.visible = breath < 1.0
	if _dark.visible:
		(_dark.material as ShaderMaterial).set_shader_parameter(&"gone", 1.0 - breath)
	if _bar.visible != _dark.visible or breath != _breath:
		_breath = breath
		_bar.visible = _dark.visible
		_bar.queue_redraw()


## How far the frost has come over [param entry]'s eyes, 0…1: the share of its cold
## meter gone while it swims; none on its feet, out, or for an empty entry.
static func cold_gone(entry: Dictionary, rules: BrawlRules) -> float:
	if entry.is_empty() or entry["out"] or entry["state"] != PlayerState.Body.SWIMMING:
		return 0.0
	return 1.0 - entry["cold"] / rules.cold_meter


## The share of a full breath [param entry] has left, 0…1 — on its feet too, getting it
## back: a full one for a seat that is out, or for an empty entry.
static func breath_left(entry: Dictionary, rules: BrawlRules) -> float:
	if entry.is_empty() or entry["out"]:
		return 1.0
	return clampf(entry["breath"] / rules.breath_meter, 0.0, 1.0)


## The breath's colour at [param share] of a full one.
static func breath_colour(share: float) -> Color:
	return GASPING if share < BREATH_LOW else AIR


## Where the breath's bar stands on a screen of [param screen]: centred under the
## crosshair.
static func bar_rect(screen: Vector2) -> Rect2:
	return Rect2(screen * 0.5 + Vector2(-BAR.x * 0.5, BAR_BELOW), BAR)


func _draw_bar() -> void:
	var bar := bar_rect(_bar.size)
	var font := ThemeDB.fallback_font
	var at := Vector2(bar.position.x, bar.position.y - NAME_OVER)
	var word := Language.t("Breath")
	var centred := HORIZONTAL_ALIGNMENT_CENTER
	_bar.draw_string_outline(font, at, word, centred, bar.size.x, FONT_SIZE, 5, INK)
	_bar.draw_string(font, at, word, centred, bar.size.x, FONT_SIZE, Color(TEXT, 0.8))
	_bar.draw_rect(bar, INK)
	var fill := Rect2(bar.position, Vector2(bar.size.x * _breath, bar.size.y))
	_bar.draw_rect(fill, breath_colour(_breath))
	_bar.draw_rect(bar, Color(TEXT, 0.35), false, 1.5)


## The frost's crystals: the edges between the cells of a seamless cellular noise,
## white on black.
static func _crystals() -> NoiseTexture2D:
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.frequency = CRYSTAL_CELLS / CRYSTAL_SIZE
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.76, 0.93])
	ramp.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color.WHITE])
	var texture := NoiseTexture2D.new()
	texture.width = CRYSTAL_SIZE
	texture.height = CRYSTAL_SIZE
	texture.seamless = true
	texture.invert = true
	texture.generate_mipmaps = true
	texture.color_ramp = ramp
	texture.noise = cells
	return texture
