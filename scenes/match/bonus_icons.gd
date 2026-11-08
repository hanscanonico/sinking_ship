class_name BonusIcons
extends RefCounted
## How a bonus's kind is shown at a glance (#307): its badge — a dark disc ringed in its
## kind's colour, and on it the glyph its kind names (BonusKind.icon), a white shape in
## assets/ui/bonus/ICON.svg drawn in that colour. The same on the HUD, in its grab prompt
## and over every bonus aboard (BonusGreybox), so a kind reads alike wherever it shows: a
## heart for Double life, chevrons for High jump, an anchor for Steady, a flexed arm for
## Strong arms and a footprint for Sure footing.

const DIR := "res://assets/ui/bonus/"
## The disc behind the glyph, the width of its ring, and the glyph's share of its width.
const DISC := Color(0.06, 0.09, 0.13, 0.85)
const RING := 2.0
const GLYPH_SHARE := 0.66

## How many pixels across a badge's texture is (texture).
const TEXTURE_SIDE := 64

## Per icon, its glyph, loaded the first time it is drawn; per kind, its badge's texture,
## made the first time it is asked for.
static var _glyphs: Dictionary[StringName, Texture2D] = {}
static var _textures: Dictionary[BonusKind, Texture2D] = {}


## The glyph [param kind] is shown by (BonusKind.icon), or null for one with none.
static func glyph(kind: BonusKind) -> Texture2D:
	if kind.icon.is_empty():
		return null
	if not _glyphs.has(kind.icon):
		_glyphs[kind.icon] = load(DIR + String(kind.icon) + ".svg")
	return _glyphs[kind.icon]


## Draws [param kind]'s badge on [param canvas], [param radius] round about [param centre].
static func draw(canvas: CanvasItem, kind: BonusKind, centre: Vector2, radius: float) -> void:
	canvas.draw_circle(centre, radius, DISC)
	canvas.draw_arc(centre, radius - RING * 0.5, 0.0, TAU, 32, kind.mark, RING, true)
	var shown := glyph(kind)
	if shown != null:
		var side := Vector2.ONE * radius * 2.0 * GLYPH_SHARE
		canvas.draw_texture_rect(shown, Rect2(centre - side * 0.5, side), false, kind.mark)


## [param kind]'s badge as a texture TEXTURE_SIDE pixels across, mipmapped, for a sprite:
## the disc, its ring and its glyph, as draw() draws them.
static func texture(kind: BonusKind) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var side := TEXTURE_SIDE
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var middle := Vector2.ONE * side * 0.5
	var ring := RING * side / 26.0
	for y in side:
		for x in side:
			var out := Vector2(x + 0.5, y + 0.5).distance_to(middle)
			var colour := DISC if out < middle.x - ring else Color(kind.mark, 1.0)
			colour.a *= clampf(middle.x - out, 0.0, 1.0)
			image.set_pixel(x, y, colour)
	var shown := glyph(kind)
	var drawn := shown.get_image() if shown != null else null
	if drawn != null and not drawn.is_empty():
		if drawn.is_compressed():
			drawn.decompress()
		drawn.convert(Image.FORMAT_RGBA8)
		var fit := roundi(side * GLYPH_SHARE)
		drawn.resize(fit, fit, Image.INTERPOLATE_LANCZOS)
		var at := floori((side - fit) * 0.5)
		for y in fit:
			for x in fit:
				var under := image.get_pixel(at + x, at + y)
				image.set_pixel(
					at + x, at + y, under.lerp(Color(kind.mark, 1.0), drawn.get_pixel(x, y).a)
				)
	image.generate_mipmaps()
	_textures[kind] = ImageTexture.create_from_image(image)
	return _textures[kind]
