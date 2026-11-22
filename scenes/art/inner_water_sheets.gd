class_name InnerWaterSheets
extends RefCounted
## The sheets the water inside her is drawn in (InnerWater): each cell's surface and its
## stacks' (CellBoxes.stacked), made the first time one shows water rather than all up
## front — the Titanic has thousands, and making them froze her first frames (#640) —
## each told, as it is made, all its cell's sheets were told before it (tell): drawn, it
## is the sheet it would have been had it been there all along. What is kept of each is
## InnerWater's.

## The room of a pour that falls into the sea: everywhere.
const ANYWHERE := AABB(Vector3.ONE * -1e9, Vector3.ONE * 2e9)


## [param water]'s cell [param cell]'s surface — its stack [param stack]'s, by index into
## InnerWater._stacks, where not -1 — made the first time it is asked for.
static func made(water: InnerWater, cell: int, stack: int) -> MeshInstance3D:
	var sheet: MeshInstance3D = water._surfaces[cell] if stack == -1 else water._stacks[stack][2]
	if sheet != null:
		return sheet
	if stack == -1:
		var under_sky := water._structure.cells[cell].kind == FloodCell.Kind.OPEN_WELL
		sheet = surface(water, water._boxes[cell], under_sky)
		water._surfaces[cell] = sheet
	else:
		sheet = surface(water, water._stacks[stack][1], false)
		water._stacks[stack][2] = sheet
	if not water._padded.is_empty():
		show_waders_on(sheet, water._padded, water._waders.size())
	var told: Dictionary = water._told[cell]
	for parameter: StringName in told:
		InnerWater._param(sheet, parameter, told[parameter])
	return sheet


## A cell's surface in [param water] over [param box] (CellSurface), told the box it is
## clipped to and whether it lies [param under_sky], as an open well's does, lit by the sun.
static func surface(water: InnerWater, box: AABB, under_sky: bool) -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.mesh = CellSurface.sheet()
	sheet.material_override = water._water.duplicate()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	InnerWater._param(sheet, &"clip_low", box.position)
	InnerWater._param(sheet, &"clip_high", box.end)
	InnerWater._param(sheet, &"outdoor", 1.0 if under_sky else 0.0)
	sheet.visible = false
	# Hidden, it stands apart from her (top level), so her moving every frame spends
	# nothing on it: on the Titanic most of her two thousand sheets are dry.
	sheet.top_level = true
	water.add_child(sheet)
	return sheet


## Every sheet made so far that [param water]'s cell [param cell] is drawn in: its
## surface and its stacks'.
static func of(water: InnerWater, cell: int) -> Array[MeshInstance3D]:
	var sheets: Array[MeshInstance3D] = []
	if water._surfaces[cell] != null:
		sheets.append(water._surfaces[cell])
	for index: int in water._stacks_of(cell):
		if water._stacks[index][2] != null:
			sheets.append(water._stacks[index][2])
	return sheets


## Tells [param water]'s cell [param cell]'s sheets made so far, and every one made later
## (made), that [param parameter] is [param value].
static func tell(water: InnerWater, cell: int, parameter: StringName, value: Variant) -> void:
	water._told[cell][parameter] = value
	for sheet: MeshInstance3D in of(water, cell):
		InnerWater._param(sheet, parameter, value)


## Tells [param sheet] the waders [param padded] (SeaAndSky.padded_waders), [param count]
## of them.
static func show_waders_on(sheet: MeshInstance3D, padded: PackedVector4Array, count: int) -> void:
	InnerWater._param(sheet, &"waders", padded)
	InnerWater._param(sheet, &"wader_count", count)


## Per side of each of [param passages] in [param structure] — the cell [param sides] has
## there, -1 for the sea or the sky — the box a pour falling into that side is drawn in,
## ship space: the cell's own and its opening's span [param spans], which stands on the
## cell's face or, a ventilator's or a pipe's, off it — to its faces and no further, as a
## deck's planks lie on its top and a sliver over them would show; everywhere for the
## sea. A sheet is hung level with the world across its opening's whole width and falls
## along the world's down, so as she leans a wide opening's sheet leaves the cell — a
## hatch's stands over the deck at its low end, a hold's lining's 40 m of it runs out
## through her deck and her bottom, into the sea.
static func rooms(
	structure: ShipStructure, passages: int, sides: PackedInt32Array, spans: Array[AABB]
) -> Array[AABB]:
	var found: Array[AABB] = []
	for at in passages * 2:
		var side := sides[at]
		if side == -1:
			found.append(ANYWHERE)
			continue
		var cell := structure.cells[side]
		# A span's size is as its opening was written: a screen's runs down from its top.
		found.append(AABB(cell.low, cell.high - cell.low).merge(spans[at >> 1].abs()))
	return found


## Keeps the pour through [param water]'s passage [param index], its crossing and its
## landing, as drawn this frame, inside the side it falls into: the one whose water
## stands lower, the sea at 0 (InnerWater._show_pour).
static func keep(water: InnerWater, index: int) -> void:
	var first := water._sides[index * 2]
	var second := water._sides[index * 2 + 1]
	var head := 0.0 if first == -1 else water._levels[first]
	var other := 0.0 if second == -1 else water._levels[second]
	var room := water._rooms[index * 2 + (1 if head >= other else 0)]
	_keep(water, water._pours[index], room)
	_keep(water, water._landings[index], room)
	if water._crossings[index] != null:
		_keep(water, water._crossings[index], room)


static func _keep(water: InnerWater, sheet: WaterSheet, room: AABB) -> void:
	sheet.keep_in(room)
	if water._slot == -1:
		InnerWater._param(sheet, &"world_to_ship", water._ship.affine_inverse())
