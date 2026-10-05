class_name CellOverlay
extends Node3D
## The ship's cells for the observer (--observer-cells, SH24): every cell of the
## layout's structure drawn from the data as a box and its name — a tool, never a
## player's view (D14). A cell people walk in has solid edges and a tint in its kind's
## colour; a void nobody walks in, grey dashed edges and none. Drawn over everything,
## so the cells under the decks and inside the hull show through them, each set a
## little inside its box, so no edge lies along a deck or a wall.

## Per FloodCell.Kind, the colour of a cell people walk in; VOID's is a void's.
const KIND_COLOURS: Array[Color] = [
	Color(0.38, 0.72, 1.0),
	Color(1.0, 0.62, 0.2),
	Color(0.5, 0.92, 0.42),
	Color(0.95, 0.82, 0.3),
	Color(0.72, 0.74, 0.78),
	Color(0.62, 0.48, 0.36),
	Color(0.4, 0.9, 0.9),
]
## An edge's thickness and how far inside its box a cell is drawn, in metres; a
## void's dashes and the gaps between them.
const EDGE := 0.06
const INSET := 0.08
const DASH := 0.4
const GAP := 0.25
## How much a walk-in cell's tint shows, and a void's edges against a walk-in's.
const TINT := 0.1
const VOID_ALPHA := 0.75
## Names: the font's size in pixels, how large a pixel of it stands, the outline's
## size, and the share of the font a void's takes.
const NAME_FONT := 22
const NAME_PIXEL := 0.0009
const NAME_OUTLINE := 9
const VOID_NAME := 0.8
## Cells narrower than this along the hull, in metres, side by side on one deck, stand
## their names this share of their height above and below their middles in turn; two
## faces nearer than TOUCH meet.
const NARROW := 4.0
const STAGGER := 0.25
const TOUCH := 0.01
const INK := Color(0.04, 0.06, 0.09)
## Drawn after the ship's transparent faces and the sea: tints, then edges, then
## names over them.
const TINT_PRIORITY := 10
const EDGE_PRIORITY := 11
const NAME_PRIORITY := 12


## Draws every cell of [param structure], replacing what was drawn before.
func build(structure: ShipStructure) -> void:
	for child: Node in get_children():
		child.queue_free()
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tints := SurfaceTool.new()
	tints.begin(Mesh.PRIMITIVE_TRIANGLES)
	var names := _name_spots(structure)
	for index in structure.cells.size():
		var cell := structure.cells[index]
		var walked := cell.kind != FloodCell.Kind.VOID
		var colour := KIND_COLOURS[cell.kind]
		var low := cell.low + Vector3.ONE * INSET
		var high := cell.high - Vector3.ONE * INSET
		for edge: PackedVector3Array in _edges(low, high):
			if walked:
				_bar(edges, edge[0], edge[1], colour)
			else:
				_dashes(edges, edge[0], edge[1], Color(colour, VOID_ALPHA))
		if walked:
			_box_faces(tints, low, high, Color(colour, TINT))
		_name(cell, names[index], colour, walked)
	_add_mesh(edges, EDGE_PRIORITY)
	_add_mesh(tints, TINT_PRIORITY)


## Per cell of [param structure], where its name stands: its middle, but that the
## names of cells over one stretch of the hull — a compartment's room, its bilge,
## its side voids — are spread along it, port to starboard and top to bottom, so
## none stands over another.
func _name_spots(structure: ShipStructure) -> PackedVector3Array:
	var cells := structure.cells
	var stretches := {}
	for index in cells.size():
		var stretch := Vector2(cells[index].low.x, cells[index].high.x)
		if not stretches.has(stretch):
			stretches[stretch] = []
		(stretches[stretch] as Array).append(index)
	var spots := PackedVector3Array()
	for cell: FloodCell in cells:
		var stretch := Vector2(cell.low.x, cell.high.x)
		var along: Array = stretches[stretch].duplicate()
		along.sort_custom(
			func(a: int, b: int) -> bool:
				if cells[a].low.z != cells[b].low.z:
					return cells[a].low.z < cells[b].low.z
				return cells[a].high.y > cells[b].high.y
		)
		var spot := (cell.low + cell.high) * 0.5
		var share := float(along.find(cells.find(cell)) + 1) / (along.size() + 1)
		spot.x = lerpf(stretch.x, stretch.y, share)
		spots.append(spot)
	# Narrow cells side by side on one deck — the deckhouse's rooms — take turns
	# standing their names low and high, aft to fore, so two names never run into one.
	var order := range(cells.size())
	order.sort_custom(func(a: int, b: int) -> bool: return cells[a].low.x < cells[b].low.x)
	var raised := {}
	for index: int in order:
		var cell := cells[index]
		var aft := _narrow_beside(cells, cell, true)
		if aft == -1 and _narrow_beside(cells, cell, false) == -1:
			continue
		raised[index] = aft != -1 and not raised.get(aft, false)
		var spot := spots[index]
		spot.y = lerpf(cell.low.y, cell.high.y, 0.5 + (STAGGER if raised[index] else -STAGGER))
		spots[index] = spot
	return spots


## The index of the cell of [param cells] narrower than NARROW that stands beside
## [param cell] on its deck — aft of it when [param aft], else fore — when [param cell]
## is narrow too; -1 when none does.
func _narrow_beside(cells: Array[FloodCell], cell: FloodCell, aft: bool) -> int:
	if cell.high.x - cell.low.x >= NARROW:
		return -1
	for index in cells.size():
		var other := cells[index]
		var meets := (
			absf(other.high.x - cell.low.x) < TOUCH
			if aft
			else absf(other.low.x - cell.high.x) < TOUCH
		)
		if (
			meets
			and other.high.x - other.low.x < NARROW
			and absf(other.low.y - cell.low.y) < TOUCH
			and absf(other.high.y - cell.high.y) < TOUCH
		):
			return index
	return -1


## The twelve edges of the box from [param low] to [param high], end to end.
func _edges(low: Vector3, high: Vector3) -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	for axis in 3:
		var other := (axis + 1) % 3
		var third := (axis + 2) % 3
		for corner in 4:
			var from := low
			from[other] = high[other] if corner & 1 else low[other]
			from[third] = high[third] if corner & 2 else low[third]
			var to := from
			to[axis] = high[axis]
			found.append(PackedVector3Array([from, to]))
	return found


## [param from] to [param to] in dashes DASH long, GAP apart, a dash at each end.
func _dashes(tool: SurfaceTool, from: Vector3, to: Vector3, colour: Color) -> void:
	var length := from.distance_to(to)
	var count := maxi(1, roundi((length + GAP) / (DASH + GAP)))
	var dash := (length - GAP * (count - 1)) / count
	for index in count:
		var start := (dash + GAP) * index / length
		_bar(tool, from.lerp(to, start), from.lerp(to, start + dash / length), colour)


## A square bar EDGE thick from [param from] to [param to], along one axis.
func _bar(tool: SurfaceTool, from: Vector3, to: Vector3, colour: Color) -> void:
	var half := Vector3.ONE * EDGE * 0.5
	_box_faces(tool, from.min(to) - half, from.max(to) + half, colour)


## The six faces of the box from [param low] to [param high], seen from either side.
func _box_faces(tool: SurfaceTool, low: Vector3, high: Vector3, colour: Color) -> void:
	tool.set_color(colour)
	for axis in 3:
		var other := (axis + 1) % 3
		var third := (axis + 2) % 3
		for side: float in [low[axis], high[axis]]:
			var corners: Array[Vector3] = []
			for corner: Vector2i in [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
			]:
				var point := Vector3.ZERO
				point[axis] = side
				point[other] = high[other] if corner.x else low[other]
				point[third] = high[third] if corner.y else low[third]
				corners.append(point)
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(corners[index])


## [param cell]'s name at [param spot], in [param colour], smaller and greyer for a
## void.
func _name(cell: FloodCell, spot: Vector3, colour: Color, walked: bool) -> void:
	var label := Label3D.new()
	# Its first word over the rest, so names side by side stay narrow.
	var words := String(cell.name).split("_")
	label.text = "\n".join([words[0], " ".join(words.slice(1))]) if words.size() > 1 else words[0]
	label.position = spot
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.shaded = false
	label.double_sided = true
	label.font_size = NAME_FONT if walked else roundi(NAME_FONT * VOID_NAME)
	label.outline_size = NAME_OUTLINE
	label.pixel_size = NAME_PIXEL
	label.modulate = colour.lightened(0.55) if walked else Color(colour, VOID_ALPHA)
	label.outline_modulate = INK
	label.render_priority = NAME_PRIORITY + 1
	label.outline_render_priority = NAME_PRIORITY
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


## [param tool]'s triangles as one mesh drawn over everything, unlit, both sides, its
## vertex colours its paint, after what [param priority] says.
func _add_mesh(tool: SurfaceTool, priority: int) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = priority
	var drawn := MeshInstance3D.new()
	drawn.mesh = tool.commit()
	drawn.material_override = material
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drawn)
