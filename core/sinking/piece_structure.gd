class_name PieceStructure
extends RefCounted
## A piece of a broken hull as the physics sees it (§5b.3, "Pieces"; SH33): her structure
## cut to the stretch of her length the piece spans, in the same ship-local metres — so a
## piece's space is her ship space, turned and set down by the piece's own pose (D6). A
## section across the cut is shortened to its part; a cell across it is cut in two, each
## half its own cell under the cell's name; a watertight wall standing on the cut is torn
## away with every opening in it; an opening along her keeps its part and the share of its
## area that goes with it; a mass item bearing across the cut keeps the share of its mass
## that bears on the piece, spread evenly as the girder spreads it (HullGirder) — one wholly
## on the piece keeps its own place; her fittings go with the piece they stand on — the
## same fittings, but for an emergency power losing the cells it lit off it — and her
## weak spots with the piece they lie inside. Every cell the cut opens has a TORN opening to
## the sea over its whole face there: the cut face is a huge opening (§5b.1). Her radius of
## gyration for a pitch shrinks with her length, est. Pure: (structure, from, to) in, the
## piece out, so the bake that breaks her and the schedule that draws the pieces cut her
## alike.

## A stretch shorter than this, in metres, is none.
const SLIVER := 1e-6


## [param structure] cut to the stretch from [param from] to [param to] along her: every
## end that is not one of hers is torn.
static func cut(structure: ShipStructure, from: float, to: float) -> ShipStructure:
	var ends := span_of(structure)
	var piece := ShipStructure.new()
	piece.waterline_y = structure.waterline_y
	piece.keel_y = structure.keel_y
	for section: HullSection in structure.sections:
		var low := maxf(section.x - section.length * 0.5, from)
		var high := minf(section.x + section.length * 0.5, to)
		if high - low <= SLIVER:
			continue
		var made := HullSection.new()
		made.x = (low + high) * 0.5
		made.length = high - low
		made.outline = section.outline
		piece.sections.append(made)
	for cell: FloodCell in structure.cells:
		var made := _cell(cell, from, to)
		if made != null:
			piece.cells.append(made)
	for wall: ShipWall in structure.walls:
		var made := _wall(wall, piece, from, to)
		if made != null:
			piece.walls.append(made)
	for opening: ShipOpening in structure.openings:
		var made := clipped(opening, piece, from, to)
		if made != null:
			piece.openings.append(made)
	for at: float in [from, to]:
		if at > ends.x + SLIVER and at < ends.y - SLIVER:
			piece.openings.append_array(_torn(piece, at))
	for item: MassItem in structure.mass:
		var made := _mass(item, from, to)
		if made != null:
			piece.mass.append(made)
	piece.roll_radius = structure.roll_radius
	piece.pitch_radius = structure.pitch_radius * (to - from) / (ends.y - ends.x)
	piece.added_mass = structure.added_mass
	piece.heave_damping = structure.heave_damping
	piece.roll_damping = structure.roll_damping
	piece.pitch_damping = structure.pitch_damping
	for fitting: ShipFitting in structure.fittings:
		var along := _place_of(fitting, structure)
		if along < from or along >= to:
			continue
		var cells := _present(fitting.emergency_cells, piece)
		if cells.size() == fitting.emergency_cells.size():
			piece.fittings.append(fitting)
			continue
		var made := fitting.duplicate() as ShipFitting
		made.emergency_cells = cells
		piece.fittings.append(made)
	if structure.strength != null:
		var spots: Array[WeakSpot] = []
		for spot: WeakSpot in structure.strength.weak:
			if spot.x > from + SLIVER and spot.x < to - SLIVER:
				spots.append(spot)
		piece.strength = structure.strength.duplicate() as GirderStrength
		piece.strength.weak = spots
	piece.hit_zone_x = structure.hit_zone_x
	piece.hit_zone_y = structure.hit_zone_y
	piece.sure_hit = structure.sure_hit
	return piece


## What [param damage] did to the piece [param piece] of her from [param from] to
## [param to]: its gash's part there, and the rest of what the hit found as it was.
static func damaged(damage: HitDamage, piece: ShipStructure, from: float, to: float) -> HitDamage:
	var made := HitDamage.new()
	made.from_x = damage.from_x
	made.to_x = damage.to_x
	made.trace = damage.trace
	made.weakened = damage.weakened
	made.weakened_to = damage.weakened_to
	made.jammed = damage.jammed
	made.left_open = damage.left_open
	made.wave_height = damage.wave_height
	made.sea_depth = damage.sea_depth
	for opening: ShipOpening in damage.openings:
		var kept := clipped(opening, piece, from, to)
		if kept != null:
			made.openings.append(kept)
	return made


## Where her hull starts and ends along her: the aft end of her first section and the
## fore end of her last.
static func span_of(structure: ShipStructure) -> Vector2:
	var first := structure.sections[0]
	var last := structure.sections[structure.sections.size() - 1]
	return Vector2(first.x - first.length * 0.5, last.x + last.length * 0.5)


## Per cell of [param piece], the index in [param structure] of the cell it is (part of).
static func sources(structure: ShipStructure, piece: ShipStructure) -> PackedInt32Array:
	var found := PackedInt32Array()
	for cell: FloodCell in piece.cells:
		found.append(structure.cell_named(cell.name))
	return found


## [param opening] as the piece [param piece] from [param from] to [param to] has it, or
## null where it has none of it: both its places must be on the piece; flat across her
## length, it must stand inside the stretch, never on a cut; along her, its part inside
## the stretch, with that share of its area.
static func clipped(
	opening: ShipOpening, piece: ShipStructure, from: float, to: float
) -> ShipOpening:
	for place: StringName in opening.joins:
		if not place in [ShipOpening.SEA, ShipOpening.SKY] and piece.cell_named(place) == -1:
			return null
	var low := opening.centre.x - opening.size.x * 0.5
	var high := opening.centre.x + opening.size.x * 0.5
	if opening.size.x == 0.0:
		return opening if low > from + SLIVER and low < to - SLIVER else null
	var kept_low := maxf(low, from)
	var kept_high := minf(high, to)
	if kept_high - kept_low <= SLIVER:
		return null
	if kept_low == low and kept_high == high:
		return opening
	var made := opening.duplicate() as ShipOpening
	made.centre.x = (kept_low + kept_high) * 0.5
	made.size.x = kept_high - kept_low
	made.area = opening.area * (kept_high - kept_low) / (high - low)
	return made


## [param cell] cut to the stretch from [param from] to [param to], or null where none of
## it lies there; itself where all of it does.
static func _cell(cell: FloodCell, from: float, to: float) -> FloodCell:
	var low := maxf(cell.low.x, from)
	var high := minf(cell.high.x, to)
	if high - low <= SLIVER:
		return null
	if low == cell.low.x and high == cell.high.x:
		return cell
	var made := cell.duplicate() as FloodCell
	made.low.x = low
	made.high.x = high
	var edges := PackedVector3Array()
	for at in range(0, cell.shipping_edges.size(), 2):
		var a := cell.shipping_edges[at]
		var b := cell.shipping_edges[at + 1]
		var kept := _segment(a, b, low, high)
		if not kept.is_empty():
			edges.append_array(kept)
	made.shipping_edges = edges
	return made


## The part of the line from [param a] to [param b] between [param from] and [param to]
## along her, as its two ends; empty where none of it is.
static func _segment(a: Vector3, b: Vector3, from: float, to: float) -> PackedVector3Array:
	if a.x == b.x:
		return PackedVector3Array([a, b]) if a.x >= from and a.x <= to else PackedVector3Array()
	var start := clampf(minf(a.x, b.x), from, to)
	var end := clampf(maxf(a.x, b.x), from, to)
	if end - start <= SLIVER:
		return PackedVector3Array()
	var first := a.lerp(b, (start - a.x) / (b.x - a.x))
	var last := a.lerp(b, (end - a.x) / (b.x - a.x))
	return PackedVector3Array([first, last])


## [param wall] as [param piece], from [param from] to [param to], has it: across her,
## standing inside the stretch — torn away on a cut; along her, its part there; each
## parting only the cells the piece has. Null where none of it stands.
static func _wall(wall: ShipWall, piece: ShipStructure, from: float, to: float) -> ShipWall:
	var made := wall.duplicate() as ShipWall
	made.cells = _present(wall.cells, piece)
	if made.cells.size() < 2:
		return null
	if wall.axis == ShipWall.Axis.ACROSS:
		return made if wall.at > from + SLIVER and wall.at < to - SLIVER else null
	made.span = Vector2(maxf(wall.span.x, from), minf(wall.span.y, to))
	return made if made.span.y - made.span.x > SLIVER else null


## [param names] that are cells of [param piece], in their order.
static func _present(names: Array[StringName], piece: ShipStructure) -> Array[StringName]:
	var found: Array[StringName] = []
	for named: StringName in names:
		if piece.cell_named(named) != -1:
			found.append(named)
	return found


## A TORN opening to the sea for every cell of [param piece] the cut at [param at] opens:
## over the cell's whole face there.
static func _torn(piece: ShipStructure, at: float) -> Array[ShipOpening]:
	var made: Array[ShipOpening] = []
	for cell: FloodCell in piece.cells:
		if not is_equal_approx(cell.low.x, at) and not is_equal_approx(cell.high.x, at):
			continue
		var opening := ShipOpening.new()
		opening.name = StringName("torn_%s" % cell.name)
		opening.kind = ShipOpening.Kind.TORN
		opening.joins = [cell.name, ShipOpening.SEA]
		opening.centre = Vector3(
			at, (cell.low.y + cell.high.y) * 0.5, (cell.low.z + cell.high.z) * 0.5
		)
		opening.size = Vector3(0.0, cell.high.y - cell.low.y, cell.high.z - cell.low.z)
		opening.starts = ShipOpening.Start.OPEN
		made.append(opening)
	return made


## [param item]'s part bearing on the stretch from [param from] to [param to], or null
## for none: itself where it bears on nothing else; across a cut, the share of its mass
## the stretch bears, spread evenly along it, about its part's middle.
static func _mass(item: MassItem, from: float, to: float) -> MassItem:
	var low := item.along.x
	var high := item.along.y
	if low >= from and high <= to:
		return item
	var kept_low := maxf(low, from)
	var kept_high := minf(high, to)
	if kept_high - kept_low <= SLIVER:
		return null
	var made := item.duplicate() as MassItem
	made.mass = item.mass * (kept_high - kept_low) / (high - low)
	made.along = Vector2(kept_low, kept_high)
	made.centre.x = (kept_low + kept_high) * 0.5
	return made


## Where along her [param fitting] stands: a lifeboat at its x, a funnel or a generator
## at its foot, a pump at the middle of its cell.
static func _place_of(fitting: ShipFitting, structure: ShipStructure) -> float:
	match fitting.kind:
		ShipFitting.Kind.LIFEBOAT:
			return fitting.x
		ShipFitting.Kind.FUNNEL, ShipFitting.Kind.GENERATOR:
			return fitting.base.x
	var cell := structure.cells[structure.cell_named(fitting.cell)]
	return (cell.low.x + cell.high.x) * 0.5
