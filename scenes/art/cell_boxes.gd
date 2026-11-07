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
## How far two of a cell's boxes may run into each other and still only meet: a room's
## far side is its corner plus its size in single precision (Rect2), a hair off the next
## room's corner where its own is no multiple of a power of two — on her side, on a
## bulkhead's line (the Titanic's C and D decks).
const MEET := 1e-4
## How far her shell may lean out or in over a band of a room's box held inside it
## (_bands), held to its narrowest at the band's top or bottom.
const LEAN := 0.05

## Per structure, [its rooms, its boxes, its cells' stacks] and then [its layout, its
## stacks with her rooms' columns (RoomColumns)], made the first time they are asked for
## (boxes, stacked), on whatever thread asks: her sea, her water and her effects each
## ask, and a liner's take seconds (#492). Read off her structure and layout
## alone, so the same however often asked.
static var _made := {}
static var _made_guard := Mutex.new()


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
	found.assign(_made_of(structure, rooms)[1])
	return found


## Both of [param structure]'s lists for [param rooms] (_made): [rooms, boxes, stacks].
static func _made_of(structure: ShipStructure, rooms: Array[ShipRoom]) -> Array:
	_made_guard.lock()
	var made: Array = _made.get(structure, [])
	_made_guard.unlock()
	if made.is_empty() or not is_same(made[0], rooms):
		made = [rooms, _boxes(structure, rooms), _stacked(structure, rooms)]
		_made_guard.lock()
		_made[structure] = made
		_made_guard.unlock()
	return made


static func _boxes(structure: ShipStructure, rooms: Array[ShipRoom]) -> Array[AABB]:
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
## the first in boxes(), and out to the bulkheads it shares (_to_bulkheads), then what
## her shell's narrowest over each leaves out of it and its stairwells (_room_boxes),
## less what the cell's other boxes hold (_less); and each part of [param layout]'s
## rooms, from its floor to whatever roofs it, standing in such a cell but in no box of
## it (RoomColumns); each as [cell, box], each cell's together, in her cells' order.
## [param rooms] are [param layout]'s.
static func stacked(structure: ShipStructure, rooms: Array[ShipRoom], layout: ShipLayout) -> Array:
	var made := _made_of(structure, rooms)
	if made.size() < 5 or not is_same(made[3], layout):
		var joined := RoomColumns.joined(structure, layout, made[1], made[2])
		made = [made[0], made[1], made[2], layout, joined]
		_made_guard.lock()
		_made[structure] = made
		_made_guard.unlock()
	return (made[4] as Array).duplicate(true)


static func _stacked(structure: ShipStructure, rooms: Array[ShipRoom]) -> Array:
	var found := []
	for index in structure.cells.size():
		var cell := structure.cells[index]
		if cell.shape >= WHOLE or cell.rooms.is_empty() or cell.kind == FloodCell.Kind.OPEN_WELL:
			continue
		var rest: Array[AABB] = []
		var drawn := _room_boxes(structure, cell, rooms, rest)
		var kept: Array[AABB] = [_to_bulkheads(structure, cell, drawn, 0)]
		for at in range(1, drawn.size()):
			kept.append(_to_bulkheads(structure, cell, drawn, at))
			found.append([index, kept[-1]])
		for box: AABB in rest:
			for part: AABB in _less(box, kept):
				kept.append(part)
				found.append([index, part])
	return found


## What of [param box] none of [param others] holds, but a hair (MEET), in boxes: so no
## two of a cell's boxes draw its water over each other.
static func _less(box: AABB, others: Array[AABB]) -> Array[AABB]:
	var left: Array[AABB] = [box]
	for other: AABB in others:
		var held := other.grow(-MEET)
		var rest: Array[AABB] = []
		for part: AABB in left:
			if not held.intersects(part):
				rest.append(part)
				continue
			var low := part.position
			var high := part.end
			for axis in 3:
				if other.position[axis] > low[axis]:
					var end := high
					end[axis] = other.position[axis]
					rest.append(AABB(low, end - low))
					low[axis] = other.position[axis]
				if other.end[axis] < high[axis]:
					var start := low
					start[axis] = other.end[axis]
					rest.append(AABB(start, high - start))
					high[axis] = other.end[axis]
		left = rest
	var found: Array[AABB] = []
	for part: AABB in left:
		if _kept(part) and part.size.y > 2.0 * MEET:
			found.append(part)
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
## other boxes holds any of it but a hair (MEET), and it stands inside
## [param structure]'s shell — read over the sections it stands in, not the one past the
## bulkhead it ends at, which her sections' rounded ends can have it touch by a few
## millimetres (bulkhead C's, the Titanic's No. 3 hold's forward one).
static func _gains(structure: ShipStructure, drawn: Array[AABB], at: int, gained: AABB) -> bool:
	var held := gained.grow(-MEET)
	# A strip no thicker than the hair either side (a room ending that near a bulkhead)
	# holds nothing of another box's.
	if held.size.x > 0.0 and held.size.y > 0.0 and held.size.z > 0.0:
		for other in drawn.size():
			if other != at and drawn[other].intersects(held):
				return false
	return _within(structure, gained, SHELL_NEAR)


## [param cell]'s boxes round its [param rooms]: the one round them all
## (_round_rooms) where it stands inside [param structure]'s shell — read over the
## sections it stands in, not one past the end it shares with a section's, which her
## sections' rounded ends can have it touch (the Titanic's C deck at her B deck's after
## end) — else per room, stacked, a box for each part of it up to the floor of the room
## over it there or the cell's top (_under), each held inside her shell — none her
## shell closes to nothing — the one up to the cell's top — the largest such — first;
## and into [param rest], for those, what they leave out inside her shell (_wings) and
## the cell's stairwells no room of its stands over (_stairwells), as they are: none
## carried out to a bulkhead, none in the way of a box that is.
static func _room_boxes(
	structure: ShipStructure, cell: FloodCell, rooms: Array[ShipRoom], rest: Array[AABB] = []
) -> Array[AABB]:
	var round := _round_rooms(cell, rooms)
	var own: Array[ShipRoom] = []
	for room: ShipRoom in rooms:
		if room.name in cell.rooms:
			own.append(room)
	if own.size() < 2 or _within(structure, round, SHELL_NEAR):
		return [round]
	var found: Array[AABB] = []
	var wings: Array[AABB] = []
	for room: ShipRoom in own:
		for part: Array in _under(room, own, cell.high.y):
			var area: Rect2 = part[0]
			var top: float = part[1]
			var low := Vector3(area.position.x, room.floor_height, area.position.y)
			var whole := AABB(low, Vector3(area.end.x, top, area.end.y) - low)
			var box := _held(structure, whole)
			if _kept(box):
				found.append(box)
			else:
				box = AABB()
			wings.append_array(_wings(structure, whole, box))
	for area: Rect2 in _stairwells(structure, cell, own):
		var low := Vector3(area.position.x, cell.low.y, area.position.y)
		var whole := AABB(low, Vector3(area.end.x, cell.high.y, area.end.y) - low)
		var box := _held(structure, whole)
		if _kept(box):
			wings.append(box)
		else:
			box = AABB()
		wings.append_array(_wings(structure, whole, box))
	if found.is_empty():
		return [round]
	found.sort_custom(
		func(a: AABB, b: AABB) -> bool:
			if not is_equal_approx(a.end.y, b.end.y):
				return a.end.y > b.end.y
			return a.get_volume() > b.get_volume()
	)
	rest.append_array(wings)
	return found


## Whether [param box] holds more than a hair across (MEET).
static func _kept(box: AABB) -> bool:
	return box.size.x > 2.0 * MEET and box.size.z > 2.0 * MEET


## The parts of [param whole], a room's part, its box [param box] (_held) leaves out
## inside [param structure]'s shell: [param whole] held per section it stands in and
## band by band up it (_bands), less [param box] — where the room spans a joint to a
## wider section (the Titanic's seamen's mess, aft of her forecastle's taper), where her
## shell leans out over its floor (her after hold), or where it stands up past a
## section's sheer that held its box to nothing (her windlass machinery room).
static func _wings(structure: ShipStructure, whole: AABB, box: AABB) -> Array[AABB]:
	var found: Array[AABB] = []
	for index in range(_first_past(structure, whole.position.x), structure.sections.size()):
		var section := structure.sections[index]
		var half := section.length * 0.5
		if section.x - half >= whole.end.x:
			break
		var from := maxf(whole.position.x, section.x - half)
		var to := minf(whole.end.x, section.x + half)
		if to - from <= 2.0 * SHELL_NEAR:
			continue
		var piece := AABB(
			Vector3(from, whole.position.y, whole.position.z),
			Vector3(to - from, whole.size.y, whole.size.z)
		)
		var port: Array[AABB] = []
		var starboard: Array[AABB] = []
		for band: AABB in _bands(structure, section, piece):
			if box.size == Vector3.ZERO:
				_stack_on(port, band)
				continue
			if band.position.z < box.position.z - MEET:
				var end := band.end
				end.z = box.position.z
				_stack_on(port, AABB(band.position, end - band.position))
			if band.end.z > box.end.z + MEET:
				var start := band.position
				start.z = box.end.z
				_stack_on(starboard, AABB(start, band.end - start))
		found.append_array(port)
		found.append_array(starboard)
	return found


## [param box] added to [param stack], boxes one on another up a band of a room
## (_wings): merged with the last where it stands on it as wide.
static func _stack_on(stack: Array[AABB], box: AABB) -> void:
	if not stack.is_empty():
		var last := stack[-1]
		var alike := is_equal_approx(last.end.y, box.position.y)
		alike = alike and is_equal_approx(last.position.z, box.position.z)
		if alike and is_equal_approx(last.end.z, box.end.z):
			stack[-1] = last.merge(box)
			return
	stack.append(box)


## [param piece], the part of a room's box over [param section], held inside her shell
## band by band up to where her outline ends: between the outline's points, where her
## shell is straight, each held to its narrowest at its top or bottom, and cut where its
## sides lean across [param piece]'s by more than LEAN.
static func _bands(structure: ShipStructure, section: HullSection, piece: AABB) -> Array[AABB]:
	var heights := PackedFloat32Array([piece.position.y])
	var top := -INF
	for point: Vector2 in section.outline:
		top = maxf(top, point.y)
		if point.y > piece.position.y + MEET and point.y < piece.end.y - MEET:
			heights.append(point.y)
	top = minf(top, piece.end.y)
	heights.append(top)
	heights.sort()
	var found: Array[AABB] = []
	for at in range(1, heights.size()):
		if heights[at] - heights[at - 1] <= 2.0 * MEET or heights[at] > top:
			continue
		var lean := 0.0
		for side: int in [-1, 1]:
			var reach := -piece.position.z if side == -1 else piece.end.z
			var below := minf(absf(section.shell_at(heights[at - 1] + SHELL_IN, side)), reach)
			var above := minf(absf(section.shell_at(heights[at] - SHELL_IN, side)), reach)
			if not is_nan(below) and not is_nan(above):
				lean = maxf(lean, absf(above - below))
		var bands := maxi(1, ceili(lean / LEAN - MEET))
		for step in bands:
			var bottom := lerpf(heights[at - 1], heights[at], float(step) / bands)
			var low := Vector3(piece.position.x, bottom, piece.position.z)
			var high := Vector3(
				piece.end.x,
				lerpf(heights[at - 1], heights[at], float(step + 1) / bands),
				piece.end.z
			)
			var band := _held(structure, AABB(low, high - low))
			if _kept(band):
				found.append(band)
	return found


## The parts of the stairwells and open floors into [param cell] from the cell under it
## (ShipOpening.Kind.STAIRWELL, OPEN) that none of [param own], its rooms, stands over:
## a room under one stands up into [param cell] there, with no deck between — the
## Titanic's crew's stairs from her D deck passages forward into her forecastle — and
## sees up it to the cell's top.
static func _stairwells(
	structure: ShipStructure, cell: FloodCell, own: Array[ShipRoom]
) -> Array[Rect2]:
	var footprint := Rect2(
		cell.low.x, cell.low.z, cell.high.x - cell.low.x, cell.high.z - cell.low.z
	)
	var found: Array[Rect2] = []
	for opening: ShipOpening in structure.openings:
		var up := opening.kind in [ShipOpening.Kind.STAIRWELL, ShipOpening.Kind.OPEN]
		up = up and is_zero_approx(opening.size.y) and cell.name in opening.joins
		if not up or not is_equal_approx(opening.centre.y, cell.low.y):
			continue
		var size := Vector2(opening.size.x, opening.size.z)
		var over := Rect2(Vector2(opening.centre.x, opening.centre.z) - size * 0.5, size)
		over = over.intersection(footprint)
		if not over.has_area():
			continue
		var left: Array[Rect2] = [over]
		for room: ShipRoom in own:
			var rest: Array[Rect2] = []
			for part: Rect2 in left:
				var under := part.intersection(room.area)
				if under.has_area():
					rest.append_array(_around(part, under))
				else:
					rest.append(part)
			left = rest
		found.append_array(left)
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
## side than her shell stands at its narrowest over it — read over the sections it
## stands in, not one past an end it shares with a section's, which her sections'
## rounded ends can have it touch: the Titanic's B deck corridor, ending on her forward
## well's section, once held to nothing by that well's lower sheer.
static func _held(structure: ShipStructure, box: AABB) -> AABB:
	var shell := _shell(structure, box, SHELL_NEAR)
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
	var from := box.position.x + touching
	for index in range(_first_past(structure, from), structure.sections.size()):
		var section := structure.sections[index]
		var half := section.length * 0.5
		if section.x + half <= from:
			continue
		if section.x - half >= box.end.x - touching:
			break
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


## The first of [param structure]'s sections that ends past [param from]: her sections
## run aft to fore end to end, so those over a stretch of her follow on from it, and a
## liner cut fine where she tapers has hundreds to pass over (#492).
static func _first_past(structure: ShipStructure, from: float) -> int:
	var sections := structure.sections
	var low := 0
	var high := sections.size()
	while low < high:
		var middle := (low + high) >> 1
		var section := sections[middle]
		if section.x + section.length * 0.5 <= from:
			low = middle + 1
		else:
			high = middle
	return low


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
