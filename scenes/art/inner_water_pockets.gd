class_name InnerWaterPockets
extends RefCounted
## The pockets' air in the water inside her (SH29, InnerWater): bubbles over each pocket
## that leaks, a burst at the opening each goes free by, its water glowing faintly, and
## a light cast up into the pocket round an eye there. Frame by frame it walks only the
## cells holding air in the pose it shows, or that held it in the last (#410); the
## drawing and what it keeps of each cell are InnerWater's.

## The pose whose pockets were last found, the cells holding one in it, and those that
## held one in the pose last shown (pocket_walk).
var _pockets_of: ShipPose
var _held := PackedInt32Array()
var _last_held := PackedInt32Array()


## The pockets [param pose] has, its cells' water at world heights [param levels]:
## bubbles over each one that leaks into water standing over the middle of its top, and
## a burst at the opening of each that has just gone free with air to blow out.
func show(water: InnerWater, pose: ShipPose, levels: PackedFloat64Array) -> void:
	var leak := 0
	var lit := -1
	var camera := water.get_viewport().get_camera_3d() if water.is_inside_tree() else null
	var eye_cell := pose.cell_at(water.to_local(camera.global_position)) if camera != null else -1
	if pose != _pockets_of:
		_pockets_of = pose
		_held = _held_in(water, pose)
	for cell in _walk(water):
		var low := water._structure.cells[cell].low
		var box := AABB(low, water._structure.cells[cell].high - low)
		var held := cell < pose.pockets.size() and pose.pockets[cell] > 0.0
		var glow := InnerWater.POCKET_GLOW if held else 0.0
		if water._surfaces[cell] != null and water._glows[cell] != glow:
			InnerWater._param(water._surfaces[cell], &"pocket_glow", glow)
			for index: int in water._stacks_of(cell):
				InnerWater._param(water._stacks[index][2], &"pocket_glow", glow)
			water._glows[cell] = glow
		if held and cell == eye_cell:
			lit = cell
		if not held:
			if water._airs[cell] >= InnerWater.VENTS:
				_vent(water, cell, levels, pose)
			water._airs[cell] = -1.0
			continue
		water._airs[cell] = CellSurface.reach(water._ship, box).y - levels[cell]
		var top := box.get_center()
		top.y = box.end.y
		var over := pose.water_level(top + Vector3.UP * CellMap.DRY)
		if (
			leak >= InnerWater.LEAKS
			or water._structure.cells[cell].leak_area <= 0.0
			or over <= (water._ship * top).y
		):
			continue
		var flat := water._level * Basis.from_scale(Vector3(InnerWater.LEAK, 1.0, InnerWater.LEAK))
		var outside := pose.cell_at(top + Vector3.UP * CellMap.DRY) == CellMap.NONE
		water._lay(
			water._leaks[leak], flat, water._at_height(top, over + InnerWater.FROTH_LIFT), 1.0, 0.0
		)
		InnerWater._param(water._leaks[leak], &"outdoor", 1.0 if outside else 0.0)
		leak += 1
	for unused in range(leak, InnerWater.LEAKS):
		water._leaks[unused].visible = false
	_last_held = _held
	water._pocket_light.visible = lit != -1
	if lit != -1:
		var low := water._structure.cells[lit].low
		var box := AABB(low, water._structure.cells[lit].high - low)
		var middle := box.get_center()
		middle.y = box.position.y
		water._pocket_light.position = water._at_height(middle, levels[lit] + InnerWater.FROTH_LIFT)
		var reach := maxf(box.size.x, box.size.z) * InnerWater.POCKET_SPAN
		water._pocket_light.omni_range = clampf(
			reach, InnerWater.POCKET_REACH.x, InnerWater.POCKET_REACH.y
		)


## The cells show walks of [param water]'s, ascending (pocket_walk).
func _walk(_water: InnerWater) -> PackedInt32Array:
	return pocket_walk(_held, _last_held)


## The cells show walks, ascending: those [param held] in the pose it shows and
## those [param last_held] in the pose it showed last, each ascending. Any other cell's
## water glows not, holds no air and has none to vent, as a walk of every cell would
## leave it.
static func pocket_walk(held: PackedInt32Array, last_held: PackedInt32Array) -> PackedInt32Array:
	if last_held == held:
		return held
	var cells := PackedInt32Array()
	var at := 0
	var last := 0
	while at < held.size() or last < last_held.size():
		var now_held := held[at] if at < held.size() else 1 << 30
		var was := last_held[last] if last < last_held.size() else 1 << 30
		cells.append(mini(now_held, was))
		at += 1 if now_held <= was else 0
		last += 1 if was <= now_held else 0
	return cells


## The cells of hers holding a pocket's air in [param pose], ascending.
static func _held_in(water: InnerWater, pose: ShipPose) -> PackedInt32Array:
	var count := mini(pose.pockets.size(), water._airs.size())
	if water.native != null:
		return water.native.held(pose.pockets, count)
	var held := PackedInt32Array()
	var pockets := pose.pockets
	for cell in count:
		if pockets[cell] > 0.0:
			held.append(cell)
	return held


## Bursts the air of [param cell]'s pocket out as it goes free, its cells' water at world
## heights [param levels] under [param pose]: on the water at the top of the opening it
## goes out by (AirVents.way_out, the match's blast's too), over whichever side's water
## stands higher there.
static func _vent(water: InnerWater, cell: int, levels: PackedFloat64Array, pose: ShipPose) -> void:
	var best := water._vents.way_out(cell, pose)
	if best == -1:
		return
	var opening := water._passages[best]
	var beyond := water._vents.beyond(best, cell)
	var beyond_level := 0.0 if beyond == -1 else levels[beyond]
	var under := cell if levels[cell] >= beyond_level else beyond
	var level := maxf(levels[cell], beyond_level)
	# On the water the air comes up through, clear of the wall or the shell it is in.
	var at := opening.centre
	var axis := opening.facing()
	if axis != 1:
		var out := signf(water._middle(cell, axis) - at[axis]) * (1.0 if under == cell else -1.0)
		at[axis] += out * InnerWater.VENT_BURST * 0.4
	var burst := water._next_burst
	water._next_burst = (water._next_burst + 1) % InnerWater.BURSTS
	var flat := (
		water._level * Basis.from_scale(Vector3(InnerWater.VENT_BURST, 1.0, InnerWater.VENT_BURST))
	)
	water._lay(
		water._bursts[burst], flat, water._at_height(at, level + InnerWater.FROTH_LIFT), 1.0, 0.0
	)
	InnerWater._param(water._bursts[burst], &"outdoor", 1.0 if under == -1 else 0.0)
	water._burst_cells[burst] = under
	water._burst_at[burst] = at
	water._burst_ages[burst] = 0.0
	water.set_process(true)
