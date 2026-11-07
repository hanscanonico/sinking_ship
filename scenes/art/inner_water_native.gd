class_name InnerWaterNative
extends RefCounted
## InnerWater's loops over every cell and opening of hers in the game's extension
## (native/, #410), a NativeWaterFx working each to the GDScript's answers bit for bit
## (test_water_fx_native): which sheets to show and hide a frame, and which openings may
## pour a tick. It lays her out for the
## extension once and keeps which sheets show; InnerWater keeps the rest and draws every
## node. None where the extension is not loaded, and InnerWater's GDScript runs instead.

## Her axes, then the same turned back: each one laid level with the world
## (InnerWater._flat) for the pours (show_pours).
const AXES: Array[Vector3] = [
	Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD
]

## How many numbers the extension reckons of each pour it draws (_draw_pour).
const POUR_VALUES := 10

var _fx: Object
## Per drawn cell surface, its cell, its box's middle and half size, and 1 while it
## shows; the same per stack, and per stacked cell where its stacks start and its
## bounds' middle and half size.
var _surface_cells := PackedInt32Array()
var _surface_middles := PackedVector3Array()
var _surface_halves := PackedVector3Array()
var _surface_shown := PackedByteArray()
var _stack_cells := PackedInt32Array()
## Per stack, the cell it is drawn for.
var _stack_cell_of := PackedInt32Array()
var _stack_middles := PackedVector3Array()
var _stack_halves := PackedVector3Array()
var _stack_shown := PackedByteArray()
var _stacks_from := PackedInt32Array()
var _bound_middles := PackedVector3Array()
var _bound_halves := PackedVector3Array()
## Per opening, for the pours (show_pours): its size, which way it faces, its box's middle
## and half size, and per side the point under its middle on that side's floor; per cell
## its corners and its middle; and per opening InnerWater._wet names, how far open it
## stands and the water through it (_opens).
var _sizes := PackedVector3Array()
var _facings := PackedInt32Array()
var _span_centres := PackedVector3Array()
var _span_halves := PackedVector3Array()
var _unders := PackedVector3Array()
var _cell_lows := PackedVector3Array()
var _cell_highs := PackedVector3Array()
var _cell_middles := PackedVector3Array()
var _wet_open := PackedFloat64Array()
var _wet_flow := PackedFloat64Array()


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
	_stack_cell_of.clear()
	for stack: Array in stacks:
		var box: AABB = stack[1]
		_stack_cell_of.append(stack[0])
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


## Lays out [param structure]'s cells and the openings [param passages] for the pours,
## each in its box [param spans], its sides' floors at [param floors].
func lay_out_openings(
	structure: ShipStructure,
	passages: Array[ShipOpening],
	spans: Array[AABB],
	floors: PackedFloat64Array
) -> void:
	_sizes.clear()
	_facings.clear()
	_span_centres.clear()
	_span_halves.clear()
	_unders.clear()
	_wet_open.clear()
	_wet_flow.clear()
	for index in passages.size():
		var opening := passages[index]
		_sizes.append(opening.size)
		_facings.append(opening.facing())
		_span_centres.append(spans[index].get_center())
		_span_halves.append(spans[index].size * 0.5)
		for side in 2:
			var under := opening.centre
			under.y = floors[index * 2 + side]
			_unders.append(under)
	_cell_lows.clear()
	_cell_highs.clear()
	_cell_middles.clear()
	for cell: FloodCell in structure.cells:
		_cell_lows.append(cell.low)
		_cell_highs.append(cell.high)
		_cell_middles.append(cell.low.lerp(cell.high, 0.5))


## Each cell's water at world heights lerped [param alpha] of the way from
## [param then]'s levels to [param now]'s.
func levels_between(then: ShipPose, now: ShipPose, alpha: float) -> PackedFloat64Array:
	return _fx.levels_between(then.levels, now.levels, alpha)


## The cell surfaces to show and to hide with her water at world heights [param levels],
## drawn as [param ship], given first, laid level by [param level], from [param first]
## water (InnerWater.shows): each cell as cell * 2 + 1 to show and cell * 2 to hide, and
## where each one shown is placed (CellSurface.placed); then the stacks the same way, by
## index into InnerWater._stacks, and how many of each stacked cell's show, from
## [param stacks_shown] last.
func surfaces(
	levels: PackedFloat64Array,
	ship: Transform3D,
	level: Basis,
	first: float,
	stacks_shown: PackedInt32Array
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
	var middles := ship * _surface_middles
	var touched: PackedInt32Array = _fx.surfaces(
		levels, _surface_cells, middles, _surface_halves, spread, _surface_shown
	)
	var placed: Array = _fx.placed(
		touched, _surface_cells, levels, _surface_middles, middles, _surface_halves, level
	)
	var cells := PackedInt32Array()
	for each in touched:
		_surface_shown[each >> 1] = each & 1
		cells.append(_surface_cells[each >> 1] * 2 + (each & 1))
	var stack_middles := ship * _stack_middles
	var found: Array = _fx.stacks(
		levels,
		_stack_cells,
		_stacks_from,
		ship * _bound_middles,
		_bound_halves,
		stacks_shown,
		stack_middles,
		_stack_halves,
		spread,
		_stack_shown
	)
	for each: int in found[0]:
		_stack_shown[each >> 1] = each & 1
	var stacks_placed: Array = _fx.placed(
		found[0], _stack_cell_of, levels, _stack_middles, stack_middles, _stack_halves, level
	)
	return [cells, placed, found[0], stacks_placed, found[1]]


## Each cell's churn as her water climbs it from [param then] to [param now] — over its
## middle — eased on from [param churns] (InnerWater._show_inflows): the cells whose
## churn changed, and their churns.
func inflows(then: ShipPose, now: ShipPose, churns: PackedFloat64Array) -> Array:
	return _fx.inflows(
		then.levels,
		now.levels,
		then.transform * _cell_middles,
		now.transform * _cell_middles,
		churns,
		Ticks.SECONDS_PER_TICK,
		InnerWater.INFLOW_FULL,
		InnerWater.INFLOW_EASE,
		InnerWater.INFLOW_CALM
	)


## Draws the pours of [param water]'s openings that may pour this tick (InnerWater._wet)
## as InnerWater._show_pour would, frame by frame: the extension reckons each one —
## hidden, dry or drawn, and where — and its air blown out, and InnerWater draws them.
func show_pours(water: InnerWater) -> void:
	var ship := water._ship
	var basis := ship.basis
	var flats := PackedVector3Array()
	for axis: Vector3 in AXES:
		flats.append(water._flat(axis))
	var spread := PackedFloat64Array(
		[
			absf(basis.x.y),
			absf(basis.y.y),
			absf(basis.z.y),
			InnerWater.SHOWS,
			InnerWater.POURS,
			InnerWater.FLOOD,
			InnerWater.FLOW_FULL,
			InnerWater.THINNEST,
			InnerWater.OFF_WALL,
			InnerWater.OFF_SHELL,
			InnerWater.MOST_THROW,
			InnerWater.LANDING.x,
			InnerWater.LANDING.y,
		]
	)
	var found: Array = _fx.pours(
		water._wet,
		water._levels,
		water._sides,
		water._centres,
		_sizes,
		_facings,
		water._drawn,
		water._crossed,
		ship * _span_centres,
		_span_halves,
		ship * water._centres,
		ship * _unders,
		water._last_heads,
		_wet_open,
		_wet_flow,
		_cell_lows,
		_cell_highs,
		flats,
		spread
	)
	var codes: PackedInt32Array = found[0]
	var points: PackedVector3Array = found[1]
	var world := ship * points
	var axes: PackedVector3Array = found[2]
	var values: PackedFloat64Array = found[3]
	water._last_heads = found[4]
	var wet := water._wet
	var drawn := 0
	for at in codes.size():
		var index := wet[at]
		var code := codes[at]
		if code == 0:
			water._hide_pour(index)
		elif code == 1:
			water._unshow(index)
		else:
			_draw_pour(water, index, drawn, [points, world, axes, values])
			drawn += 1
	var blown_at: PackedFloat64Array = found[6]
	var told := 0
	for each: int in found[5]:
		water._burst_out(each >> 1, each & 1, blown_at[told], water._passages[each >> 1])
		told += 1


## The first [param count] cells holding a pocket's air in [param pockets], ascending
## (InnerWater._held_in).
func held(pockets: PackedFloat64Array, count: int) -> PackedInt32Array:
	return _fx.held(pockets, count)


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
	_opens(water, now)
	for index: int in found[1]:
		if not water._pours[index].top_level:
			water._hide_pour(index)
	water._last_heads = found[3]
	var slots := water._slots
	for index: int in found[2]:
		var told := PackedFloat64Array([heads[slots[index * 2]], heads[slots[index * 2 + 1]]])
		var top := CellSurface.reach(water._ship, water._spans[index]).y
		water._blow(index, told, top, water._passages[index])


## How far each opening [param water]'s _wet names stands open under [param pose] — a
## door's leaf slid back, one shut until it fails a trickle while it leaks, none while it
## holds — and the water through it (InnerWater._flow_of), as _show_pour reads them.
func _opens(water: InnerWater, pose: ShipPose) -> void:
	var wet := water._wet
	_wet_open.resize(wet.size())
	_wet_flow.resize(wet.size())
	for at in wet.size():
		var index := wet[at]
		var opening := water._passages[index]
		var open := 1.0 - float(pose.doors_shut.get(opening.name, 0.0))
		var failed: int = pose.opened.get(opening.name, 0)
		if failed == 2:
			open = 1.0
		elif failed == 1:
			open = maxf(open if water._shut[index] == 0 else 0.0, InnerWater.TRICKLE)
		elif water._shut[index] == 1:
			open = 0.0
		_wet_open[at] = open
		_wet_flow[at] = water._flow_of(index, pose)


## Draws [param water]'s pour through passage [param index] as the extension reckoned
## it, the [param at]-th drawn, from [param reckoned]: its middle and the point its
## landing is thrown to, those in the world, its sheet's across and normal, and the rest
## of its reckoning (POUR_VALUES each) — the end of InnerWater._show_pour, line for line.
static func _draw_pour(water: InnerWater, index: int, at: int, reckoned: Array) -> void:
	var points: PackedVector3Array = reckoned[0]
	var world: PackedVector3Array = reckoned[1]
	var axes: PackedVector3Array = reckoned[2]
	var values: PackedFloat64Array = reckoned[3]
	var v := at * POUR_VALUES
	var from := values[v]
	var to := values[v + 1]
	var width := values[v + 2]
	var short := values[v + 3]
	var thrown := values[v + 4]
	var strength := values[v + 5]
	var spread := values[v + 6]
	var outdoor := values[v + 7]
	var crossing_kind := int(values[v + 8])
	var tall := values[v + 9]
	var up := water._up
	var across := axes[at * 2]
	var normal := axes[at * 2 + 1]
	var middle := points[at * 2] + up * ((from + to) * 0.5 - world[at * 2].y)
	var falling := Basis(across * width, up * tall, normal)
	water._hang(water._pours[index], falling, middle, strength, Vector3(0.0, 0.0, thrown), outdoor)
	var lands := points[at * 2 + 1] + up * (to + InnerWater.FROTH_LIFT - world[at * 2 + 1].y)
	var wider := InnerWater.LANDING_WIDER
	var patch := Basis(across * (width + wider), up, normal * spread)
	var crossing := water._crossings[index]
	if crossing_kind == 1:
		var through := Basis(normal * short, up * tall, across)
		water._hang(crossing, through, middle, strength, Vector3.ZERO, outdoor)
		patch = Basis(across * (width + wider), up, normal * (short + wider))
	elif crossing_kind == 2:
		var edge_on := Basis(normal * width, up * tall, across)
		var jet := Vector3(thrown / width, 0.0, 0.0)
		water._hang(crossing, edge_on, middle, strength, jet, outdoor)
	water._lay(water._landings[index], patch, lands, strength, -1.0)
