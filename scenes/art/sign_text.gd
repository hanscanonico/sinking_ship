class_name SignText
extends RefCounted
## How big a sign's letters come out, measured as a ship is dressed: on her worker thread
## (ShipDressing), while the main thread draws. A Font's own measures —
## get_string_size, get_multiline_string_size — shape through that font's one shared
## cache, a list no lock guards, and the fallback font every sign is lettered in is the
## one the HUD and the menus draw with at the same moment: two threads on the list left
## it corrupt, and the engine said so as it quit ("_data->size_cache", #455). So the
## letters are shaped here in a buffer of their own, freed as the measure returns.


## [param text] in the fallback font at [param font_size], one line, as
## Font.get_string_size measures it.
static func line_size(text: String, font_size: int) -> Vector2:
	var line := TextLine.new()
	line.add_string(text, ThemeDB.fallback_font, font_size)
	return line.get_size()


## [param text], its lines broken only where it breaks them, centred, as
## Font.get_multiline_string_size measures it unbounded.
static func lines_size(text: String, font_size: int) -> Vector2:
	var lines := TextParagraph.new()
	lines.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_string(text, ThemeDB.fallback_font, font_size)
	return lines.get_size()
