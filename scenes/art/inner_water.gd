class_name InnerWater
extends Node3D
## The water inside her (§5b.1, D7), drawn as the sinking has it at the moment drawn:
## each cell's at its own level, level with the world however she leans and drawn only
## inside its cell (CellSurface) — in the sea's colours, lit as the room it stands in is
## (inner_water.gdshader) — the watertight doors the ship slides shut at the hit, water
## pouring through an opening wherever one side's water stands over its bottom and
## higher than the other side's, falling along the world's down (spill.gdshader),
## boiling into froth where it lands, and air blown out of an opening as the water
## reaches its top, bursting the surface in bubbles there (froth.gdshader).
## Presentation only (D5): it reads the poses it is handed and the openings water can
## pass, and moves no water. It lives in ship space, under the drawn ship.

## How far a cell's water stands in from a face of its box at her side or an outside
## wall — inside the wall's thickness, never out past the hull.
const INSET := 0.15
## How deep over its lowest corner and how far under its highest a cell's water is
## drawn: not on a dry floor, where it would fight the planks, nor in a full cell, which
## has no surface.
const SHOWS := 0.02
## The least difference across an opening that is drawn pouring, in metres, and the
## difference at which a pour is a solid sheet.
const POURS := 0.03
const FLOOD := 1.0
## How far into the lower side a pour hangs off its opening, so its sheet is seen
## clear of the wall it pours through: a wall's half thickness and a little, and for an
## opening in her shell, the shell and the room's lining inside it as the art draws them.
const OFF_WALL := 0.12
const OFF_SHELL := 0.4
## The furthest a pour is thrown out from its opening as it falls, in metres.
const MOST_THROW := 1.6
## A watertight door's leaf: how thick, of the doorway's wall.
const LEAF := 0.06
## The air a cell blows out through an opening as its water reaches the top: a burst
## of bubbles this wide on the water there, breaking for so many seconds, so many at
## once at most, standing this far into the side it comes out of.
const BURST := 1.4
const BURST_SECONDS := 2.2
const BURSTS := 4
const BURST_IN := 0.4
## The froth where a pour lands: how far out along its fall it spreads, at the least
## and at a full flood, and how much wider than the pour; and how far over the water it
## lies, so the water's own surface never hides it.
const LANDING := Vector2(0.5, 1.1)
const LANDING_WIDER := 0.4
const FROTH_LIFT := 0.015
## The sea's colours the water inside her takes.
const COLOURS: Array[StringName] = [&"deep_colour", &"shallow_colour", &"foam_colour"]
const WATER_SHADER := preload("res://scenes/art/inner_water.gdshader")
const SPILL_SHADER := preload("res://scenes/art/spill.gdshader")
const FROTH_SHADER := preload("res://scenes/art/froth.gdshader")

var _structure: ShipStructure
var _sea: ShaderMaterial
var _water: ShaderMaterial
var _boxes: Array[AABB] = []
## Per cell, its surface, or null for a cell whose water is not drawn.
var _surfaces: Array[MeshInstance3D] = []
## The ship as drawn at the moment last shown — her rotation and place, the poses'
## between them — the world's up in her axes, and a basis that lays a sheet level with
## the world in her space.
var _ship := Transform3D.IDENTITY
var _up := Vector3.UP
var _level := Basis.IDENTITY
## Per watertight door the ship shuts, its leaf, by name, and the width it slides.
var _leaves := {}
var _leaf_widths := {}
## The openings water can pass, and a pour per opening, hidden while it does not —
## and a second across the first, for water falling through a hole in a deck, so it
## is seen from every side. Per opening, worked out once: its two sides' cells (-1 for
## the sea) and floors, its box, and whether water through it is drawn pouring and
## blowing air — never through the gash, a deck's gaps or a leak.
var _passages: Array[ShipOpening] = []
var _pours: Array[MeshInstance3D] = []
var _crossings: Array[MeshInstance3D] = []
## Per opening, the froth where its pour lands.
var _landings: Array[MeshInstance3D] = []
var _sides := PackedInt32Array()
var _floors := PackedFloat64Array()
var _spans: Array[AABB] = []
var _drawn := PackedByteArray()
## Per opening, the world levels of its two sides' water last drawn: a side reaching
## its top blows its air out.
var _last_heads: Array[Vector2] = []
## The bursts of air on the water: each one's froth, the cell it breaks the water of and
## the point in her it lies over, and its seconds gone, or a negative number while it is
## not bursting.
var _bursts: Array[MeshInstance3D] = []
var _burst_cells := PackedInt32Array()
var _burst_at := PackedVector3Array()
var _burst_ages := PackedFloat32Array()
var _next_burst := 0


## The boxes of [param structure]'s cells whose water is drawn — every cell wholly
## inside her, where people go: a room's, the deckhouse's — each standing in by INSET
## from any face no other cell's box shares, so its water ends inside the wall there;
## a zero box for a cell whose water is not drawn — a void, a peak — in her cells'
## order.
static func boxes(structure: ShipStructure) -> Array[AABB]:
	var found: Array[AABB] = []
	for cell: FloodCell in structure.cells:
		if cell.shape < 1.0 and cell.rooms.is_empty():
			found.append(AABB())
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


## Draws the water in [param structure] with [param sea]'s material, pouring through
## [param passages] — the openings water can pass after the hit — and its doors' leaves
## in [param paints] (ShipArt.paints), none without them.
func setup(
	structure: ShipStructure, passages: Array[ShipOpening], sea: ShaderMaterial, paints: Dictionary
) -> void:
	for child: Node in get_children():
		child.queue_free()
	_structure = structure
	_sea = sea
	_water = ShaderMaterial.new()
	_water.shader = WATER_SHADER
	for colour: StringName in COLOURS:
		_water.set_shader_parameter(colour, sea.get_shader_parameter(colour))
	_boxes = boxes(structure)
	_surfaces.clear()
	for box: AABB in _boxes:
		_surfaces.append(null if box.size == Vector3.ZERO else _surface(box))
	_leaves.clear()
	_leaf_widths.clear()
	if not paints.is_empty():
		for opening: ShipOpening in structure.openings:
			if opening.shuts_at_hit:
				_leaf(opening, paints)
	_passages = passages
	_pours.clear()
	_crossings.clear()
	_landings.clear()
	_last_heads.clear()
	_sides.clear()
	_floors.clear()
	_spans.clear()
	_drawn.clear()
	var unseen := [ShipOpening.Kind.GASH, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.LEAK]
	for opening: ShipOpening in _passages:
		_pours.append(_pour())
		var round := opening.kind == ShipOpening.Kind.PORTHOLE
		_crossings.append(_pour() if opening.facing() == 1 or round else null)
		_landings.append(_froth())
		_last_heads.append(Vector2(-INF, -INF))
		for place: StringName in opening.joins:
			var cell := structure.cell_named(place)
			_sides.append(cell)
			_floors.append(-INF if cell == -1 else structure.cells[cell].low.y)
		_spans.append(AABB(opening.centre - opening.size * 0.5, opening.size))
		_drawn.append(0 if opening.kind in unseen else 1)
	_bursts.clear()
	_burst_cells.clear()
	_burst_at.clear()
	_burst_ages.clear()
	for _burst in BURSTS:
		_bursts.append(_froth())
		_burst_cells.append(-1)
		_burst_at.append(Vector3.ZERO)
		_burst_ages.append(-1.0)
	set_process(false)


## Shows the water [param alpha] of the way from [param then] to [param now], on the
## ship drawn between them as MatchView draws her.
func show_water(then: ShipPose, now: ShipPose, alpha: float) -> void:
	if _structure == null:
		return
	_ship = then.transform.interpolate_with(now.transform, alpha)
	_level = _ship.basis.inverse().orthonormalized()
	_up = _level * Vector3.UP
	_water.set_shader_parameter(&"world_to_ship", _ship.affine_inverse())
	var levels := PackedFloat64Array()
	levels.resize(_surfaces.size())
	for cell in _surfaces.size():
		var level := lerpf(_level_of(then, cell), _level_of(now, cell), alpha)
		levels[cell] = level
		var surface := _surfaces[cell]
		if surface == null:
			continue
		var box := _boxes[cell]
		var reach := CellSurface.reach(_ship, box)
		var showing := level > reach.x + SHOWS and level < reach.y - SHOWS
		if surface.visible != showing:
			surface.visible = showing
		if showing:
			surface.transform = CellSurface.placed(_ship, _level, box, level)
	for door: StringName in _leaves:
		var shut: float = lerpf(
			then.doors_shut.get(door, 0.0), now.doors_shut.get(door, 0.0), alpha
		)
		var leaf: Node3D = _leaves[door]
		leaf.visible = shut > 0.0
		if shut > 0.0:
			leaf.position = _slide(door) * (shut - 1.0)
	for index in _passages.size():
		_show_pour(index, levels, now)
	for burst in BURSTS:
		if _burst_ages[burst] >= 0.0:
			var level := levels[_burst_cells[burst]] + FROTH_LIFT
			_bursts[burst].position = _at_height(_burst_at[burst], level)


## The world height cell [param cell]'s water stands at under [param pose]: its box's
## lowest corner's, dry, for a pose that keeps no cells.
func _level_of(pose: ShipPose, cell: int) -> float:
	if pose.levels.is_empty():
		return pose.world_height(_structure.cells[cell].low)
	return pose.levels[cell]


## [param point] in her moved along the world's up to world height [param height] on
## the ship as drawn.
func _at_height(point: Vector3, height: float) -> Vector3:
	return point + _up * (height - (_ship * point).y)


## A cell's surface over [param box] (CellSurface), told the box it is clipped to.
func _surface(box: AABB) -> MeshInstance3D:
	var surface := MeshInstance3D.new()
	surface.mesh = CellSurface.sheet()
	surface.material_override = _water
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.set_instance_shader_parameter(&"clip_low", box.position)
	surface.set_instance_shader_parameter(&"clip_high", box.end)
	surface.visible = false
	add_child(surface)
	return surface


## [param door]'s leaf: a steel plate in the doorway's wall, built shut, slid back into
## the wall beside it by however far it stands open.
func _leaf(door: ShipOpening, paints: Dictionary) -> void:
	var axis := door.facing()
	var along := 2 if axis == 0 else 0
	var width: float = door.size[along]
	var plan := Rect2()
	if axis == 0:
		plan = Rect2(door.centre.x - LEAF * 0.5, door.centre.z - width * 0.5, LEAF, width)
	else:
		plan = Rect2(door.centre.x - width * 0.5, door.centre.z - LEAF * 0.5, width, LEAF)
	var bottom := door.centre.y - door.size.y * 0.5
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, no_rooms)
	mesh.box(plan, bottom, bottom + door.size.y, ShipPaints.bulkhead)
	# A dogged handle and the rubber seal round its edge, the art's dark.
	var handle := Vector3(door.centre.x, bottom + 1.0, door.centre.z)
	handle[along] += width * 0.3
	for side: float in [-1.0, 1.0]:
		var at := handle
		at[axis] += side * (LEAF * 0.5 + 0.02)
		mesh.turned_box(Transform3D(Basis.IDENTITY, at), Vector3(0.05, 0.05, 0.05), ShipPaints.dark)
	var leaf := Node3D.new()
	leaf.name = String(door.name)
	add_child(leaf)
	mesh.commit(leaf, paints)
	leaf.visible = false
	_leaves[door.name] = leaf
	var slide := Vector3.ZERO
	slide[along] = width
	_leaf_widths[door.name] = slide


## How far [param door]'s leaf slides from shut to open, along its doorway.
func _slide(door: StringName) -> Vector3:
	return _leaf_widths[door]


## A pour's sheet: upright, a unit square cut across its fall so it can arc.
func _pour() -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = SPILL_SHADER
	material.set_shader_parameter(&"water_colour", _sea.get_shader_parameter(&"shallow_colour"))
	material.set_shader_parameter(&"foam_colour", _sea.get_shader_parameter(&"foam_colour"))
	# Over the water it pours into, whichever is nearer the eye.
	material.render_priority = 1
	var pour := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.orientation = PlaneMesh.FACE_Z
	sheet.size = Vector2.ONE
	sheet.subdivide_depth = 10
	pour.mesh = sheet
	pour.material_override = material
	pour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pour.visible = false
	add_child(pour)
	return pour


## Shows the pour through passage [param index], the cells' water at world heights
## [param levels] and the sea at 0, under [param pose]: a sheet from where the water
## leaves the higher side to where it meets the lower, or the floor there, falling along
## the world's down; and air blown out of the side whose water has just reached the
## opening's top.
func _show_pour(index: int, levels: PackedFloat64Array, pose: ShipPose) -> void:
	var opening := _passages[index]
	var sides := PackedInt32Array([_sides[index * 2], _sides[index * 2 + 1]])
	var heights := PackedFloat64Array()
	for side: int in sides:
		heights.append(0.0 if side == -1 else levels[side])
	var span := CellSurface.reach(_ship, _spans[index])
	var bottom := span.x
	var top := span.y
	if _drawn[index] == 1:
		_blow(index, heights, top, opening)
	var pour := _pours[index]
	var crossing := _crossings[index]
	var landing := _landings[index]
	if _drawn[index] == 0 or maxf(heights[0], heights[1]) <= bottom + SHOWS:
		# Dry, or never drawn pouring: nothing to do but keep it hidden.
		if pour.visible:
			pour.visible = false
			landing.visible = false
		if crossing != null and crossing.visible:
			crossing.visible = false
		return
	pour.visible = false
	landing.visible = false
	if crossing != null:
		crossing.visible = false
	var axis := opening.facing()
	var open := 1.0 - float(pose.doors_shut.get(opening.name, 0.0))
	var high := 0 if heights[0] >= heights[1] else 1
	var low := 1 - high
	# The floor of the lower side under the opening, as high as it stands in the world.
	var under := opening.centre
	under.y = _floors[index * 2 + low]
	var floor_under := -INF if sides[low] == -1 else (_ship * under).y
	var drop := heights[high] - maxf(heights[low], floor_under)
	if open <= 0.0 or heights[high] <= bottom + SHOWS or heights[high] - heights[low] < POURS:
		return
	var from := minf(heights[high], top)
	var to := maxf(heights[low], floor_under)
	var strength := clampf(drop / FLOOD, 0.15, 1.0)
	var centre := opening.centre
	var width := 0.0
	var across := Vector3.ZERO
	var normal := Vector3.ZERO
	if axis == 1:
		# A hole in a deck: water falls through it from over the hole, if the higher
		# side is over it, down the hole's longer way.
		if not _over(sides[high], opening.centre.y):
			return
		from = (_ship * centre).y
		var long := 0 if opening.size.x >= opening.size.z else 2
		width = opening.size[long]
		across[long] = 1.0
		normal[2 - long] = 1.0
	else:
		var along := 2 if axis == 0 else 0
		width = opening.size[along] * open
		across[along] = 1.0
		normal[axis] = signf(_middle(sides[low], axis) - centre[axis])
		centre += normal * (OFF_SHELL if sides[high] == -1 else OFF_WALL)
		# A sliding door's opening is what its leaf has not covered.
		centre[along] += opening.size[along] * (1.0 - open) * 0.5
	if from - to < POURS or width <= 0.0:
		return
	var tall := from - to
	# Through a wall it leaves at the speed the head over it drives and arcs on into the
	# lower side as it falls: thrown 2 √(head × fall) out, a jet from a porthole under
	# the sea, barely a lip off a weir. Pouring in through a deck from the open sky, the
	# sky lights it. It falls along the world's down, its sheet and its landing turned
	# level with the world.
	var thrown := 0.0
	if axis != 1:
		var head := maxf(heights[high] - (from + maxf(bottom, heights[low])) * 0.5, 0.0)
		thrown = minf(2.0 * sqrt(head * tall), MOST_THROW)
	var short := opening.size[int(normal.abs().max_axis_index())]
	across = _flat(across)
	normal = _flat(normal)
	var outdoor := 1.0 if axis == 1 and sides[high] == -1 else 0.0
	var middle := _at_height(centre, (from + to) * 0.5)
	var falling := Basis(across * width, _up * tall, normal)
	_hang(pour, falling, middle, strength, Vector3(0.0, 0.0, thrown), outdoor)
	var lands := _at_height(centre + normal * thrown, to + FROTH_LIFT)
	var spread := lerpf(LANDING.x, LANDING.y, strength)
	var patch := Basis(across * (width + LANDING_WIDER), _up, normal * spread)
	if crossing != null and axis == 1:
		var through := Basis(normal * short, _up * tall, across)
		_hang(crossing, through, middle, strength, Vector3.ZERO, outdoor)
		var wide := short + LANDING_WIDER
		patch = Basis(across * (width + LANDING_WIDER), _up, normal * wide)
	elif crossing != null:
		# A round jet: a second sheet edge-on to the first, arcing out the same way, so
		# it has a body seen from beside it too.
		var edge_on := Basis(normal * width, _up * tall, across)
		_hang(crossing, edge_on, middle, strength, Vector3(thrown / width, 0.0, 0.0), outdoor)
	_lay(landing, patch, lands, strength, -1.0)


## [param direction] in her laid level with the world, a unit long.
func _flat(direction: Vector3) -> Vector3:
	return (direction - _up * direction.dot(_up)).normalized()


## Hangs [param pour] as [param basis] at [param middle], pouring as hard as
## [param strength] says, thrown out of its opening by its foot by [param thrown] in its
## own units (spill.gdshader), lit by the sky by [param outdoor].
func _hang(
	pour: MeshInstance3D,
	basis: Basis,
	middle: Vector3,
	strength: float,
	thrown: Vector3,
	outdoor: float
) -> void:
	pour.transform = Transform3D(basis, middle)
	pour.set_instance_shader_parameter(&"extent", Vector2(basis.x.length(), basis.y.length()))
	pour.set_instance_shader_parameter(&"strength", strength)
	pour.set_instance_shader_parameter(&"thrown", thrown)
	pour.set_instance_shader_parameter(&"outdoor", outdoor)
	pour.visible = true


## Lays [param froth] flat as [param basis] at [param at], boiling as hard as
## [param strength] says — a burst of air [param burst] of the way through, or below 0
## for a pour's landing.
func _lay(froth: MeshInstance3D, basis: Basis, at: Vector3, strength: float, burst: float) -> void:
	froth.transform = Transform3D(basis, at)
	froth.set_instance_shader_parameter(&"extent", Vector2(basis.x.length(), basis.z.length()))
	froth.set_instance_shader_parameter(&"strength", strength)
	froth.set_instance_shader_parameter(&"burst", burst)
	froth.visible = true


## Whether cell [param side] — or the sea, for -1 — stands over height [param at].
func _over(side: int, at: float) -> bool:
	return side == -1 or _structure.cells[side].low.y >= at - 0.01


## The middle of cell [param side] along [param axis]; far out for the sea.
func _middle(side: int, axis: int) -> float:
	if side == -1:
		return 1e3
	var cell := _structure.cells[side]
	return (cell.low[axis] + cell.high[axis]) * 0.5


## Bursts the air out of [param opening] (passage [param index]) on the water of a
## side whose water, at world heights [param levels], has just reached its [param top] since last
## drawn: bubbles breaking its surface beside the opening.
func _blow(index: int, levels: PackedFloat64Array, top: float, opening: ShipOpening) -> void:
	var last := _last_heads[index]
	_last_heads[index] = Vector2(levels[0], levels[1])
	for side in 2:
		var cell := _sides[index * 2 + side]
		if cell == -1 or not (last[side] < top and levels[side] >= top and is_finite(last[side])):
			continue
		var burst := _next_burst
		_next_burst = (_next_burst + 1) % BURSTS
		var at := opening.centre
		var axis := opening.facing()
		if axis != 1:
			at[axis] += signf(_middle(cell, axis) - at[axis]) * BURST_IN
		var flat := _level * Basis.from_scale(Vector3(BURST, 1.0, BURST))
		_lay(_bursts[burst], flat, _at_height(at, levels[side] + FROTH_LIFT), 1.0, 0.0)
		_burst_cells[burst] = cell
		_burst_at[burst] = at
		_burst_ages[burst] = 0.0
		set_process(true)


## A patch of froth lying on the water (froth.gdshader), hidden till laid.
func _froth() -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = FROTH_SHADER
	material.set_shader_parameter(&"water_colour", _sea.get_shader_parameter(&"shallow_colour"))
	material.set_shader_parameter(&"foam_colour", _sea.get_shader_parameter(&"foam_colour"))
	material.render_priority = 1
	var patch := PlaneMesh.new()
	patch.size = Vector2.ONE
	var froth := MeshInstance3D.new()
	froth.mesh = patch
	froth.material_override = material
	froth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	froth.visible = false
	add_child(froth)
	return froth


## Ages the bursts of air on the water, each gone once it has broken; idle while none
## is bursting.
func _process(delta: float) -> void:
	var bursting := false
	for burst in BURSTS:
		if _burst_ages[burst] < 0.0:
			continue
		_burst_ages[burst] += delta
		if _burst_ages[burst] >= BURST_SECONDS:
			_burst_ages[burst] = -1.0
			_bursts[burst].visible = false
			continue
		bursting = true
		var through := _burst_ages[burst] / BURST_SECONDS
		_bursts[burst].set_instance_shader_parameter(&"burst", through)
	set_process(bursting)
