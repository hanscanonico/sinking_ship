class_name PieceClip
extends RefCounted
## The dressed art of one piece of a broken hull (SH33, R27): her art is cut at the
## places along her she breaks — her weak spots — by drawing a whole ShipArt per piece
## and keeping each to its stretch along her (ShipArt.span): its paints in their piece
## variants (ship_piece*.gdshader), which draw nothing outside it and the inside of the
## torn end dark, its glass the same. A ship that never breaks is drawn as she always was.

const SHADER := preload("res://scenes/art/ship_piece.gdshader")
const CUT_SHADER := preload("res://scenes/art/ship_piece_cut.gdshader")
const NEAR_SHADER := preload("res://scenes/art/ship_piece_near.gdshader")
## Past this along her, in metres, a stretch runs on for ever.
const FAR := 1e6


## Whether [param span] keeps a piece to a stretch of her: a broken hull's.
static func cuts(span: Vector2) -> bool:
	return is_finite(span.x) or is_finite(span.y)


## Whether [param x] along her lies on the stretch [param span].
static func holds(span: Vector2, x: float) -> bool:
	return x >= span.x and x <= span.y


## The paint shader of a piece kept to [param span] — the cut-away's where [param cut] —
## or [param otherwise] where the span keeps it to nothing.
static func shader_for(span: Vector2, cut: bool, otherwise: Shader) -> Shader:
	if not cuts(span):
		return otherwise
	return CUT_SHADER if cut else SHADER


## Keeps every ShaderMaterial among [param materials] — each a dictionary of them, by
## finish — to [param span].
static func show(materials: Array[Dictionary], span: Vector2) -> void:
	var kept := Vector2(maxf(span.x, -FAR), minf(span.y, FAR))
	for paints: Dictionary in materials:
		for material: Variant in paints.values():
			if material is ShaderMaterial:
				(material as ShaderMaterial).set_shader_parameter(&"piece_span", kept)
