class_name InnerWaterNative
extends RefCounted
## InnerWater's loops over every cell and opening of hers in the game's extension
## (native/, #410), a NativeWaterFx working each to the GDScript's answers bit for bit
## (test_water_fx_native): which sheets to show and hide a frame, and which openings may
## pour a tick. It lays her out for the
## extension once and keeps which sheets show; InnerWater keeps the rest and draws every
## node. None where the extension is not loaded, and InnerWater's GDScript runs instead.

var _fx: Object
## Per drawn cell surface, its cell, its box's middle and half size, and 1 while it
## shows; the same per stack, and per stacked cell where its stacks start and its
## bounds' middle and half size.
var _surface_cells := PackedInt32Array()
var _surface_middles := PackedVector3Array()
var _surface_halves := PackedVector3Array()
var _surface_shown := PackedByteArray()
var _stack_cells := PackedInt32Array()
var _stack_middles := PackedVector3Array()
var _stack_halves := PackedVector3Array()
var _stack_shown := PackedByteArray()
var _stacks_from := PackedInt32Array()
var _bound_middles := PackedVector3Array()
var _bound_halves := PackedVector3Array()


func _init(fx: Object) -> void:
	_fx = fx


## The extension's loops where it is loaded, else null.
static func made() -> InnerWaterNative:
	var fx := WaterFxNative.made()
	return InnerWaterNative.new(fx) if fx != null else null


## Lays out her cells in [param boxes], their surfaces [param surfaces],
## and [param stacks] (InnerWater._stacks), each run of them a cell of
## [param stack_cells] in [param stack_bounds].
func lay_out(
	boxes: Array[AABB],
	surfaces: Array[MeshInstance3D],
	stacks: Array,
	stack_cells: PackedInt32Array,
	cell_stacks: Array[PackedInt32Array],
	stack_bounds: Array[AABB]
) -> void:
	_surface_cells.clear()
	_surface_middles.clear()
	_surface_halves.clear()
	for cell in boxes.size():
		if surfaces[cell] != null:
			_surface_cells.append(cell)
			_surface_middles.append(boxes[cell].get_center())
			_surface_halves.append(boxes[cell].size * 0.5)
	_surface_shown.resize(_surface_cells.size())
	_surface_shown.fill(0)
	_stack_middles.clear()
	_stack_halves.clear()
	for stack: Array in stacks:
		var box: AABB = stack[1]
		_stack_middles.append(box.get_center())
		_stack_halves.append(box.size * 0.5)
	_stack_shown.resize(stacks.size())
	_stack_shown.fill(0)
	_stack_cells = stack_cells
	_stacks_from.clear()
	_bound_middles.clear()
	_bound_halves.clear()
	for at in stack_cells.size():
		_stacks_from.append(cell_stacks[at][0])
		_bound_middles.append(stack_bounds[at].get_center())
		_bound_halves.append(stack_bounds[at].size * 0.5)
	_stacks_from.append(stacks.size())


## Each cell's water at world heights lerped [param alpha] of the way from
## [param then]'s levels to [param now]'s.
func levels_between(then: ShipPose, now: ShipPose, alpha: float) -> PackedFloat64Array:
	return _fx.levels_between(then.levels, now.levels, alpha)


## The cell surfaces to show and to hide with her water at world heights [param levels],
## drawn as [param ship], given first, from [param first] water (InnerWater.shows): each
## cell as cell * 2 + 1 to show and cell * 2 to hide; then the stacks the same way, by
## index into InnerWater._stacks, and how many of each stacked cell's show, from
## [param stacks_shown] last.
func surfaces(
	levels: PackedFloat64Array, ship: Transform3D, first: float, stacks_shown: PackedInt32Array
) -> Array:
	var basis := ship.basis
	var spread := PackedFloat64Array(
		[
			absf(basis.x.y),
			absf(basis.y.y),
			absf(basis.z.y),
			first,
			InnerWater.SHOWS,
			InnerWater.STACK_SLACK
		]
	)
	var touched: PackedInt32Array = _fx.surfaces(
		levels, _surface_cells, ship * _surface_middles, _surface_halves, spread, _surface_shown
	)
	var cells := PackedInt32Array()
	for each in touched:
		_surface_shown[each >> 1] = each & 1
		cells.append(_surface_cells[each >> 1] * 2 + (each & 1))
	var found: Array = _fx.stacks(
		levels,
		_stack_cells,
		_stacks_from,
		ship * _bound_middles,
		_bound_halves,
		stacks_shown,
		ship * _stack_middles,
		_stack_halves,
		spread,
		_stack_shown
	)
	for each: int in found[0]:
		_stack_shown[each >> 1] = each & 1
	return [cells, found[0], found[1]]


## InnerWater._find_wet for [param water], the extension walking its openings from
## [param then] to [param now], its water at world heights [param levels] now: those shut
## until they fail given their pours as they open, in order, then each pour hidden that
## was wet and is no longer — only a pour once wet is ever shown — and each air blown
## out, in order.
func find_wet(water: InnerWater, then: ShipPose, now: ShipPose, levels: PackedFloat64Array) -> void:
	var unmade := PackedInt32Array()
	for index in water._unmade:
		if water._made[index] == 1:
			continue
		if now.opened.get(water._passages[index].name, 0) == 0:
			unmade.append(index)
			continue
		water._pour_for(index)
	water._unmade = unmade
	var heads := levels.duplicate()
	heads.append(0.0)
	var rises := PackedFloat64Array(
		[then.transform.origin.y, now.transform.origin.y, InnerWater.SHOWS, InnerWater.POURS]
	)
	# Each middle's dot with the turn's row of heights, as the y of the turn alone.
	var found: Array = _fx.find_wet(
		then.levels,
		now.levels,
		heads,
		water._slots,
		water._made,
		water._drawn,
		Transform3D(then.transform.basis, Vector3.ZERO) * water._centres,
		Transform3D(now.transform.basis, Vector3.ZERO) * water._centres,
		rises,
		water._reaches,
		water._last_heads,
		water._wet
	)
	water._wet = found[0]
	for index: int in found[1]:
		if water._pours[index].visible:
			water._hide_pour(index)
	water._last_heads = found[3]
	var slots := water._slots
	for index: int in found[2]:
		var told := PackedFloat64Array([heads[slots[index * 2]], heads[slots[index * 2 + 1]]])
		var top := CellSurface.reach(water._ship, water._spans[index]).y
		water._blow(index, told, top, water._passages[index])
