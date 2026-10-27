class_name CellBoxes
extends RefCounted
## The boxes in her, ship space, that the water in her cells is drawn in (InnerWater)
## and the sea is left out of (SeaAndSky), so the sea is never drawn where she holds
## water of her own: each cell's where people go or see into, held inside her shell.
## Read off her structure and rooms alone (D6).

## How far a cell's water stands in from a face of its box at her side or an outside
## wall — inside the wall's thickness, never out past the hull.
const INSET := 0.15
## A cell's shape at or over which its box counts as inside her: her generator rounds a
## box the hull's curve barely touches to just under 1 (the steamer's lower rooms).
const WHOLE := 0.999
## How far past her shell a box round a cell's rooms may stand and count as inside her;
## how far inside its top and bottom her shell is read, where her outline ends at a
## box's top on her sheer.
const SHELL_NEAR := 0.01
const SHELL_IN := 1e-3


## The boxes of [param structure]'s cells whose water is drawn — every cell wholly
## inside her, where people go: a room's, the deckhouse's, an open well's deck — each
## standing in by INSET from any face no other cell's box shares, so its water ends
## inside the wall there; a cell whose box pokes out of her, round its [param rooms]
## only (_round_rooms), so neither its water nor the sea's mask (SeaAndSky) reaches past
## her shell — the top of its stack where one box round them would (stacked) — and out
## to the bulkheads it shares (_to_bulkheads); a void's over a room under it that
## stands up into it (_opened); a zero box for a cell whose water is not drawn — a void
## nobody sees into, a peak — in her cells' order.
static func boxes(structure: ShipStructure, rooms: Array[ShipRoom]) -> Array[AABB]:
	var found: Array[AABB] = []
	for cell: FloodCell in structure.cells:
		var open := cell.kind == FloodCell.Kind.OPEN_WELL
		if cell.shape < 1.0 and cell.rooms.is_empty() and not open:
			found.append(_opened(structure, cell))
			continue
		if cell.shape < WHOLE and not open:
			found.append(_to_bulkheads(structure, cell, _room_boxes(structure, cell, rooms), 0))
			continue
		var low := cell.low
		var high := cell.high
		for axis: int in [0, 2]:
			if not _shared(structure, cell, axis, cell.low[axis]):
				low[axis] += INSET
			if not _shared(structure, cell, axis, cell.high[axis]):
				high[axis] -= INSET
		found.append(AABB(low, high - low))
	return found


## The rest of each cell drawn round its [param rooms] whose one box round them would
## reach past [param structure]'s shell — rooms stacked down her run, the lower the
## narrower (the steamer's aft peak, #148): each of its rooms in boxes of its own, from
## its floor up to the floor of the one over each part of it or the cell's top (_under),
## the first in boxes(), and out to the bulkheads it shares (_to_bulkheads); each as
## [cell, box].
static func stacked(structure: ShipStructure, rooms: Array[ShipRoom]) -> Array:
	var found := []
	for index in structure.cells.size():
		var cell := structure.cells[index]
		if cell.shape >= WHOLE or cell.rooms.is_empty() or cell.kind == FloodCell.Kind.OPEN_WELL:
			continue
		var drawn := _room_boxes(structure, cell, rooms)
		for at in range(1, drawn.size()):
			found.append([index, _to_bulkheads(structure, cell, drawn, at)])
	return found


## [param drawn]'s box [param at], one of [param cell]'s boxes round its rooms, carried
## out to each of the cell's own faces another of [param structure]'s cells shares —
## the bulkhead between them, which her rooms stop short of where it is thick, and the
## doorway through it — wherever all it gains stands inside her shell (_within) and in
## none of the cell's other boxes: so the water either side of a bulkhead meets inside
## it, as a whole cell's does (boxes), and the sea is never drawn across a doorway
## through it.
static func _to_bulkheads(
	structure: ShipStructure, cell: FloodCell, drawn: Array[AABB], at: int
) -> AABB:
	var low := drawn[at].position
	var high := drawn[at].end
	for axis: int in [0, 2]:
		if low[axis] > cell.low[axis] and _shared(structure, cell, axis, cell.low[axis]):
			var gained_high := high
			gained_high[axis] = low[axis]
			var gained_low := low
			gained_low[axis] = cell.low[axis]
			if _gains(structure, drawn, at, AABB(gained_low, gained_high - gained_low)):
				low[axis] = cell.low[axis]
		if high[axis] < cell.high[axis] and _shared(structure, cell, axis, cell.high[axis]):
			var gained_low := low
			gained_low[axis] = high[axis]
			var gained_high := high
			gained_high[axis] = cell.high[axis]
			if _gains(structure, drawn, at, AABB(gained_low, gained_high - gained_low)):
				high[axis] = cell.high[axis]
	return AABB(low, high - low)


## Whether [param drawn]'s box [param at] may take [param gained] on: none of the cell's
## other boxes holds any of it, and it stands inside [param structure]'s shell — read
## over the sections it stands in, not the one past the bulkhead it ends at, which her
## sections' rounded ends can have it touch by a few millimetres (bulkhead C's, the
## Titanic's No. 3 hold's forward one).
static func _gains(structure: ShipStructure, drawn: Array[AABB], at: int, gained: AABB) -> bool:
	for other in drawn.size():
		if other != at and drawn[other].intersects(gained):
			return false
	return _within(structure, gained, SHELL_NEAR)


## [param cell]'s boxes round its [param rooms]: the one round them all
## (_round_rooms) where it stands inside [param structure]'s shell, else per room,
## stacked, a box for each part of it up to the floor of the room over it there or the
## cell's top (_under), each held inside her shell — none her shell closes to nothing —
## the one up to the cell's top — the largest such — first.
static func _room_boxes(
	structure: ShipStructure, cell: FloodCell, rooms: Array[ShipRoom]
) -> Array[AABB]:
	var round := _round_rooms(cell, rooms)
	var own: Array[ShipRoom] = []
	for room: ShipRoom in rooms:
		if room.name in cell.rooms:
			own.append(room)
	if own.size() < 2 or _within(structure, round):
		return [round]
	var found: Array[AABB] = []
	for room: ShipRoom in own:
		for part: Array in _under(room, own, cell.high.y):
			var area: Rect2 = part[0]
			var top: float = part[1]
			var low := Vector3(area.position.x, room.floor_height, area.position.y)
			var box := _held(structure, AABB(low, Vector3(area.end.x, top, area.end.y) - low))
			if box.size.z > 0.0:
				found.append(box)
	if found.is_empty():
		return [round]
	found.sort_custom(
		func(a: AABB, b: AABB) -> bool:
			if not is_equal_approx(a.end.y, b.end.y):
				return a.end.y > b.end.y
			return a.get_volume() > b.get_volume()
	)
	return found


## [param room]'s area in parts, each as [area, top]: its top the floor of the lowest of
## [param own] standing over that part, else [param top] — so a room another stands
## over only part of is drawn up past it there, as the Titanic's squash court is, two
## decks high, forward of its gallery. Split only where a room over it lowers its top,
## the lowest first.
static func _under(room: ShipRoom, own: Array[ShipRoom], top: float) -> Array:
	var over_it: Array[ShipRoom] = []
	for other: ShipRoom in own:
		if other.floor_height > room.floor_height:
			over_it.append(other)
	over_it.sort_custom(
		func(a: ShipRoom, b: ShipRoom) -> bool: return a.floor_height < b.floor_height
	)
	var parts := [[room.area, top]]
	for other: ShipRoom in over_it:
		var split := []
		for part: Array in parts:
			var area: Rect2 = part[0]
			var part_top: float = part[1]
			var over := area.intersection(other.area)
			if other.floor_height >= part_top or not over.has_area():
				split.append(part)
				continue
			split.append([over, other.floor_height])
			for rest: Rect2 in _around(area, over):
				split.append([rest, part_top])
		parts = split
	return parts


## [param area] less [param over], a part of it: the strips aft and forward of it,
## [param area]'s whole width, and to port and starboard of it, its length.
static func _around(area: Rect2, over: Rect2) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for strip: Rect2 in [
		Rect2(area.position.x, area.position.y, over.position.x - area.position.x, area.size.y),
		Rect2(over.end.x, area.position.y, area.end.x - over.end.x, area.size.y),
		Rect2(over.position.x, area.position.y, over.size.x, over.position.y - area.position.y),
		Rect2(over.position.x, over.end.y, over.size.x, area.end.y - over.end.y),
	]:
		if strip.has_area():
			found.append(strip)
	return found


## The part of [param cell] — a void, no room of its own — over the openings in its floor
## that join it to the cell under it with nothing between them (ShipOpening.Kind.OPEN),
## where a room under it stands up into it — the steamer's steering gear into the space
## under her poop: from its floor to its top, held inside [param structure]'s shell. A
## zero box where there is none: nobody sees into it.
static func _opened(structure: ShipStructure, cell: FloodCell) -> AABB:
	var found := AABB()
	var footprint := Rect2(
		cell.low.x, cell.low.z, cell.high.x - cell.low.x, cell.high.z - cell.low.z
	)
	for opening: ShipOpening in structure.openings:
		var flat := opening.kind == ShipOpening.Kind.OPEN and is_zero_approx(opening.size.y)
		if not flat or not cell.name in opening.joins:
			continue
		if not is_equal_approx(opening.centre.y, cell.low.y):
			continue
		var size := Vector2(opening.size.x, opening.size.z)
		var over := Rect2(Vector2(opening.centre.x, opening.centre.z) - size * 0.5, size)
		over = over.intersection(footprint)
		if not over.has_area():
			continue
		var low := Vector3(over.position.x, cell.low.y, over.position.y)
		var box := _held(structure, AABB(low, Vector3(over.end.x, cell.high.y, over.end.y) - low))
		if box.size.z > 0.0:
			found = box if found.size == Vector3.ZERO else found.merge(box)
	return found


## [param box] held inside [param structure]'s shell athwartships: no wider to either
## side than her shell stands at its narrowest over it.
static func _held(structure: ShipStructure, box: AABB) -> AABB:
	var shell := _shell(structure, box)
	var held := box
	held.position.z = maxf(box.position.z, -shell.x)
	held.end.z = minf(box.end.z, shell.y)
	return held


## Whether [param box] stands inside [param structure]'s shell at every height it spans,
## within SHELL_NEAR, read over the sections it reaches into by more than
## [param touching] (_shell).
static func _within(structure: ShipStructure, box: AABB, touching := 0.0) -> bool:
	var shell := _shell(structure, box, touching)
	return -box.position.z <= shell.x + SHELL_NEAR and box.end.z <= shell.y + SHELL_NEAR


## How far out [param structure]'s shell stands to port and to starboard at its narrowest
## over [param box] — 0 where her outline does not reach a height it spans: her shell is
## straight between its outline's points, so its narrowest is at one of them or at the
## box's top or bottom. A section the box reaches into by no more than [param touching]
## is not over it.
static func _shell(structure: ShipStructure, box: AABB, touching := 0.0) -> Vector2:
	var narrowest := Vector2(INF, INF)
	for section: HullSection in structure.sections:
		var half := section.length * 0.5
		if section.x + half <= box.position.x + touching:
			continue
		if section.x - half >= box.end.x - touching:
			continue
		var heights := PackedFloat32Array([box.position.y + SHELL_IN, box.end.y - SHELL_IN])
		for point: Vector2 in section.outline:
			if point.y > box.position.y and point.y < box.end.y:
				heights.append(point.y)
		for height: float in heights:
			var port := -section.shell_at(height, -1)
			var starboard := section.shell_at(height, 1)
			narrowest.x = minf(narrowest.x, 0.0 if is_nan(port) else port)
			narrowest.y = minf(narrowest.y, 0.0 if is_nan(starboard) else starboard)
	return narrowest


## The part of [param cell]'s box over the floors of its rooms among [param rooms]:
## their areas together, from the lowest floor to the cell's top. A room's area runs
## out to the middle of its walls, so its water already ends inside them.
static func _round_rooms(cell: FloodCell, rooms: Array[ShipRoom]) -> AABB:
	var area := Rect2()
	var floor_y := INF
	for room: ShipRoom in rooms:
		if room.name in cell.rooms:
			area = room.area if floor_y == INF else area.merge(room.area)
			floor_y = minf(floor_y, room.floor_height)
	var low := Vector3(area.position.x, floor_y, area.position.y)
	return AABB(low, Vector3(area.end.x, cell.high.y, area.end.y) - low)


## Whether another of [param structure]'s cells has a face on the plane where
## [param axis] is [param at], overlapping [param cell]'s face there.
static func _shared(structure: ShipStructure, cell: FloodCell, axis: int, at: float) -> bool:
	var across := 2 - axis
	for other: FloodCell in structure.cells:
		if other == cell:
			continue
		var touches := is_equal_approx(other.low[axis], at) or is_equal_approx(other.high[axis], at)
		if not touches:
			continue
		var overlaps := other.low.y < cell.high.y and other.high.y > cell.low.y
		overlaps = overlaps and other.low[across] < cell.high[across]
		overlaps = overlaps and other.high[across] > cell.low[across]
		if overlaps:
			return true
	return false
