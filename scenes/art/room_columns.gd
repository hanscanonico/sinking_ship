class_name RoomColumns
extends RefCounted
## What of her rooms, each from its floor up to the deck over it, stands in one of her
## cells drawn round its rooms or over a room under it (CellBoxes) but in none of the
## boxes her cells are drawn in (#318): a room laid past the cell its floor is in — into
## the cell aft or forward of it (her sisters' D deck grand staircase), out into a wing
## space (their G deck stores and passages by the engine room's wings) — or standing up
## into the cell over it with no deck between (her smaller sister's E deck working
## passages, under the voids at her after holds; her turbine engine room, up into the
## tween over it). Each such part is drawn as the cell's it stands in, which holds its
## water (D7), and is left out of the sea (SeaAndSky): where it was in no box the open
## sea was drawn inside the room, cut off in a straight line where a drawn box began.
## Read off her structure and layout alone (D6).

## How long a stretch of her the boxes and platforms near a room are gathered by.
const SLOT := 2.0


## [param stacks], [param structure]'s cells' stacks (CellBoxes.stacked), with each part
## of [param layout]'s rooms, from its floor to whatever roofs it there
## (ShipSpace.ceiling), that stands in a cell drawn round its rooms but in none of
## [param boxes] or the stacks: as [cell, box], each cell's together and the cells in
## order, as the stacks.
static func joined(
	structure: ShipStructure, layout: ShipLayout, boxes: Array[AABB], stacks: Array
) -> Array:
	var masked: Array[AABB] = []
	for box: AABB in boxes:
		if box.size != Vector3.ZERO:
			masked.append(box)
	for stack: Array in stacks:
		masked.append(stack[1])
	var open := _open(structure, layout, masked)
	if open.is_empty():
		return stacks
	var by_cell := {}
	for stack: Array in stacks + open:
		if not by_cell.has(stack[0]):
			by_cell[stack[0]] = []
		by_cell[stack[0]].append(stack[1])
	var cells: Array = by_cell.keys()
	cells.sort()
	var found := []
	for cell: int in cells:
		for box: AABB in by_cell[cell]:
			found.append([cell, box])
	return found


## The parts of [param layout]'s rooms (joined) standing in no box of [param masked],
## merged where two of one cell's meet face to face; each as [cell, box].
static func _open(structure: ShipStructure, layout: ShipLayout, masked: Array[AABB]) -> Array:
	var rooms := layout.rooms
	var space: ShipSpace = null
	var platforms := layout.platforms
	var platform_slots := {}
	for index in platforms.size():
		var area := platforms[index].area
		_slot_in(platform_slots, index, area.position.x, area.end.x)
	var columns := {}
	var found := []
	for index in structure.cells.size():
		var cell := structure.cells[index]
		if cell.shape >= CellBoxes.WHOLE or cell.kind == FloodCell.Kind.OPEN_WELL:
			continue
		var cell_box := AABB(cell.low, cell.high - cell.low)
		var footprint := Rect2(cell.low.x, cell.low.z, cell_box.size.x, cell_box.size.z)
		# The boxes reaching into the cell, filed along her by SLOT.
		var held: Array[AABB] = []
		var slots := {}
		for box: AABB in masked:
			if box.intersects(cell_box):
				_slot_in(slots, held.size(), box.position.x, box.end.x)
				held.append(box)
		var parts: Array[AABB] = []
		for at in rooms.size():
			var room := rooms[at]
			var area := room.area.grow(-CellBoxes.INSET)
			# A room no wider or deeper than twice INSET holds none: a sliver a piece's
			# layout keeps where a cut runs through a room (#538), grown in to less than
			# nothing.
			if not area.has_area() or room.floor_height >= cell.high.y:
				continue
			if not area.intersects(footprint):
				continue
			# The most of the room the cell may hold, from its floor to the cell's top: most
			# often in one of its boxes whole, whatever roofs the room.
			var low := Vector3(area.position.x, room.floor_height, area.position.y)
			var most := cell_box.intersection(
				AABB(low, Vector3(area.end.x, cell.high.y, area.end.y) - low)
			)
			if not CellBoxes._kept(most) or most.size.y <= 2.0 * CellBoxes.MEET:
				continue
			var holding := _reaching(held, _near(slots, most.position.x, most.end.x), most)
			if holding.size() == 1 and holding[0].grow(CellBoxes.MEET).encloses(most):
				continue
			if _roofed_under(room, CellBoxes._less(most, holding), platforms, platform_slots):
				continue
			if not columns.has(at):
				if space == null:
					space = ShipSpace.new(layout)
				columns[at] = _columns(space, room, area)
			for column: AABB in columns[at]:
				var part := cell_box.intersection(column)
				if not CellBoxes._kept(part) or part.size.y <= 2.0 * CellBoxes.MEET:
					continue
				var near := _reaching(held, _near(slots, part.position.x, part.end.x), part)
				if near.is_empty() or not near[0].grow(CellBoxes.MEET).encloses(part):
					part = CellBoxes._held(structure, part)
					if CellBoxes._kept(part):
						near.append_array(parts)
						parts.append_array(CellBoxes._less(part, near))
		for part: AABB in _merged(parts):
			found.append([index, part])
	return found


## Whether each of [param left], what of [param room] its cell's boxes leave out, stands
## on or over one of [param platforms] over the room's floor and under all of it: over
## the room's roof, which no deck stands higher than (ShipSpace.ceiling) — none left out.
static func _roofed_under(
	room: ShipRoom, left: Array[AABB], platforms: Array[ShipPlatform], slots: Dictionary
) -> bool:
	for part: AABB in left:
		var footprint := Rect2(part.position.x, part.position.z, part.size.x, part.size.z)
		var under := false
		for index: int in _near(slots, part.position.x, part.end.x):
			var platform := platforms[index]
			var over_floor := platform.height > room.floor_height + ShipSpace.SLIVER
			if over_floor and platform.height <= part.position.y + CellBoxes.MEET:
				if platform.area.grow(CellBoxes.MEET).encloses(footprint):
					under = true
					break
		if not under:
			return false
	return true


## Those of [param boxes] by [param indices] that reach into [param part] — first, one
## that holds all of it, where one does.
static func _reaching(boxes: Array[AABB], indices: PackedInt32Array, part: AABB) -> Array[AABB]:
	var found: Array[AABB] = []
	var held := part.grow(-CellBoxes.MEET)
	for index: int in indices:
		var box := boxes[index]
		if not box.intersects(held):
			continue
		if box.grow(CellBoxes.MEET).encloses(part):
			return [box]
		found.append(box)
	return found


## [param room]'s [param area] in columns, each from its floor up to whatever roofs it
## there in [param space] (ShipSpace.ceiling): split where the edges of what may roof it
## cross the area, where alone its roof changes.
static func _columns(space: ShipSpace, room: ShipRoom, area: Rect2) -> Array[AABB]:
	var xs := PackedFloat32Array([area.position.x, area.end.x])
	var zs := PackedFloat32Array([area.position.y, area.end.y])
	for edges: Rect2 in space._roof_edges(room):
		var over := edges.intersection(area)
		if over.has_area():
			xs.append_array([over.position.x, over.end.x])
			zs.append_array([over.position.y, over.end.y])
	xs = _edges(xs)
	zs = _edges(zs)
	var found: Array[AABB] = []
	for i in xs.size() - 1:
		var from := zs[0]
		var run_top := NAN
		for j in zs.size() - 1:
			var top := space.ceiling(room, (xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
			if is_nan(run_top):
				run_top = top
			elif top != run_top:
				found.append(
					_column(room, Rect2(xs[i], from, xs[i + 1] - xs[i], zs[j] - from), run_top)
				)
				from = zs[j]
				run_top = top
		found.append(_column(room, Rect2(xs[i], from, xs[i + 1] - xs[i], zs[-1] - from), run_top))
	return found


static func _column(room: ShipRoom, area: Rect2, top: float) -> AABB:
	var low := Vector3(area.position.x, room.floor_height, area.position.y)
	return AABB(low, Vector3(area.end.x, top, area.end.y) - low)


## [param values] sorted, those a hair (CellBoxes.MEET) from the one before left out.
static func _edges(values: PackedFloat32Array) -> PackedFloat32Array:
	values.sort()
	var found := PackedFloat32Array()
	for value: float in values:
		if found.is_empty() or value - found[-1] > CellBoxes.MEET:
			found.append(value)
	return found


## [param boxes] with any two that meet face to face, as wide and as high, merged.
static func _merged(boxes: Array[AABB]) -> Array[AABB]:
	var found := boxes.duplicate()
	var merging := true
	while merging:
		merging = false
		for a in found.size():
			for b in range(a + 1, found.size()):
				if _meet(found[a], found[b]):
					found[a] = found[a].merge(found[b])
					found.remove_at(b)
					merging = true
					break
			if merging:
				break
	return found


## Whether [param a] and [param b] meet face to face, alike across that face.
static func _meet(a: AABB, b: AABB) -> bool:
	for axis in 3:
		var touching := absf(a.end[axis] - b.position[axis]) <= CellBoxes.MEET
		touching = touching or absf(b.end[axis] - a.position[axis]) <= CellBoxes.MEET
		if not touching:
			continue
		var alike := true
		for other in 3:
			if other == axis:
				continue
			alike = alike and absf(a.position[other] - b.position[other]) <= CellBoxes.MEET
			alike = alike and absf(a.end[other] - b.end[other]) <= CellBoxes.MEET
		if alike:
			return true
	return false


## [param index] filed under each SLOT of her length from [param from] to [param to].
static func _slot_in(slots: Dictionary, index: int, from: float, to: float) -> void:
	for slot in range(floori(from / SLOT), floori(to / SLOT) + 1):
		if not slots.has(slot):
			slots[slot] = []
		slots[slot].append(index)


## Every index filed (_slot_in) under a SLOT from [param from] to [param to], once each.
static func _near(slots: Dictionary, from: float, to: float) -> PackedInt32Array:
	var first := floori(from / SLOT)
	if first == floori(to / SLOT):
		return PackedInt32Array(slots.get(first, []))
	var seen := {}
	for slot in range(first, floori(to / SLOT) + 1):
		for index: int in slots.get(slot, []):
			seen[index] = true
	var found := PackedInt32Array(seen.keys())
	found.sort()
	return found
