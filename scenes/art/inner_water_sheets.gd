class_name InnerWaterSheets
extends RefCounted
## The sheets the water inside her is drawn in (InnerWater): each cell's surface and its
## stacks' (CellBoxes.stacked), made the first time one shows water rather than all up
## front — the Titanic has thousands, and making them froze her first frames (#640) —
## each told, as it is made, all its cell's sheets were told before it (tell): drawn, it
## is the sheet it would have been had it been there all along. What is kept of each is
## InnerWater's.


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
