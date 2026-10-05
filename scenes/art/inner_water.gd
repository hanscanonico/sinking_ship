class_name InnerWater
extends Node3D
## The water inside her (§5b.1, D7), drawn as the sinking has it at the moment drawn:
## each cell's at its own level — the sea's own material, indoors — the watertight
## doors the ship slides shut at the hit, water pouring through an opening wherever one
## side's water stands over its bottom and higher than the other side's, and air blown
## out of an opening as the water reaches its top. Presentation only (D5): it reads the
## poses it is handed and the openings water can pass, and moves no water. It lives in
## ship space, under the drawn ship.

## How far a cell's water stands in from a face of its box at her side or an outside
## wall — inside the wall's thickness, never out past the hull — and the side of a cell
## of its surface's grid, which the sea's ripple moves.
const INSET := 0.15
const GRID := 0.5
## How deep over its floor and how far under its ceiling a cell's water is drawn: not on
## a dry floor, where it would fight the planks, nor in a full cell, which has no
## surface.
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
## The air a cell blows out through an opening as its water reaches the top: how many
## bubbles, for how long — short, so they break at the surface rather than float on up
## the room — how wide a puff.
const BUBBLES := 14
const BUBBLE_SECONDS := 0.8
const PUFF := 0.2
## The sea's material's numbers a cell's water copies each frame, so it is the same
## water under the same dusk.
const SHARED: Array[StringName] = [
	&"gloom",
	&"sun_direction",
	&"fine_share",
	&"under_fog_colour",
	&"under_fog_end",
	&"under_fog_curve",
]
const SPILL_SHADER := preload("res://scenes/art/spill.gdshader")

var _structure: ShipStructure
var _sea: ShaderMaterial
var _water: ShaderMaterial
var _boxes: Array[AABB] = []
## Per cell, its surface, or null for a cell whose water is not drawn.
var _surfaces: Array[MeshInstance3D] = []
## Per watertight door the ship shuts, its leaf, by name, and the width it slides.
var _leaves := {}
var _leaf_widths := {}
## The openings water can pass, and a pour per opening, hidden while it does not —
## and a second across the first, for water falling through a hole in a deck, so it
## is seen from every side.
var _passages: Array[ShipOpening] = []
var _pours: Array[MeshInstance3D] = []
var _crossings: Array[MeshInstance3D] = []
## Per opening, the heads of its two sides last drawn: a side reaching its top blows
## its air out.
var _last_heads: Array[Vector2] = []
var _puffs: Array[CPUParticles3D] = []
var _next_puff := 0


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
	_water = sea.duplicate()
	_water.set_shader_parameter(&"indoors", true)
	_water.set_shader_parameter(&"cell_count", 0)
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
	_last_heads.clear()
	for opening: ShipOpening in _passages:
		_pours.append(_pour())
		_crossings.append(_pour() if opening.facing() == 1 else null)
		_last_heads.append(Vector2(-INF, -INF))
	_puffs.clear()
	for _puff in 4:
		_puffs.append(_air())


## Shows the water [param alpha] of the way from [param then] to [param now].
func show_water(then: ShipPose, now: ShipPose, alpha: float) -> void:
	if _structure == null:
		return
	for key: StringName in SHARED:
		_water.set_shader_parameter(key, _sea.get_shader_parameter(key))
	var heads := PackedFloat64Array()
	for cell in _structure.cells.size():
		heads.append(lerpf(_head(then, cell), _head(now, cell), alpha))
	for cell in _surfaces.size():
		var surface := _surfaces[cell]
		if surface == null:
			continue
		var box := _boxes[cell]
		var head := heads[cell]
		surface.visible = head > box.position.y + SHOWS and head < box.end.y - SHOWS
		surface.position.y = head
	for door: StringName in _leaves:
		var shut: float = lerpf(
			then.doors_shut.get(door, 0.0), now.doors_shut.get(door, 0.0), alpha
		)
		var leaf: Node3D = _leaves[door]
		leaf.visible = shut > 0.0
		leaf.position = _slide(door) * (shut - 1.0)
	var sea := lerpf(_outside(then), _outside(now), alpha)
	for index in _passages.size():
		_show_pour(index, heads, sea, now)


## The ship-local height cell [param cell]'s water stands at under [param pose].
func _head(pose: ShipPose, cell: int) -> float:
	var box := _structure.cells[cell]
	var inside := Vector3(
		(box.low.x + box.high.x) * 0.5, box.low.y + SHOWS * 0.5, (box.low.z + box.high.z) * 0.5
	)
	if pose.cell_at(inside) != cell:
		return box.low.y
	return pose.water_height(inside)


## The ship-local height of the sea up her under [param pose].
func _outside(pose: ShipPose) -> float:
	return pose.water_height(Vector3(0.0, 0.0, 1e3))


## A cell's surface over [param box], a grid the sea's ripple can move.
func _surface(box: AABB) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(box.size.x, box.size.z)
	plane.subdivide_width = maxi(0, ceili(box.size.x / GRID) - 1)
	plane.subdivide_depth = maxi(0, ceili(box.size.z / GRID) - 1)
	var surface := MeshInstance3D.new()
	surface.mesh = plane
	surface.material_override = _water
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position = Vector3(box.get_center().x, box.position.y, box.get_center().z)
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


func _pour() -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = SPILL_SHADER
	material.set_shader_parameter(&"water_colour", _sea.get_shader_parameter(&"shallow_colour"))
	var pour := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	pour.mesh = quad
	pour.material_override = material
	pour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pour.visible = false
	add_child(pour)
	return pour


## Shows the pour through passage [param index], the cells' heads [param heads] and
## the sea at [param sea], under [param pose]: a sheet from where the water leaves the
## higher side to where it meets the lower, or the floor there; and air blown out of
## the side whose water has just reached the opening's top.
func _show_pour(index: int, heads: PackedFloat64Array, sea: float, pose: ShipPose) -> void:
	var opening := _passages[index]
	var pour := _pours[index]
	pour.visible = false
	var crossing := _crossings[index]
	if crossing != null:
		crossing.visible = false
	var sides := PackedInt32Array()
	var levels := PackedFloat64Array()
	var floors := PackedFloat64Array()
	for place: StringName in opening.joins:
		var cell := _structure.cell_named(place)
		sides.append(cell)
		levels.append(sea if cell == -1 else heads[cell])
		floors.append(-INF if cell == -1 else _structure.cells[cell].low.y)
	var axis := opening.facing()
	var bottom := opening.centre.y - opening.size.y * 0.5
	var top := opening.centre.y + opening.size.y * 0.5
	_blow(index, levels, top, opening)
	if opening.kind in [ShipOpening.Kind.GASH, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.LEAK]:
		return
	var open := 1.0 - float(pose.doors_shut.get(opening.name, 0.0))
	var high := 0 if levels[0] >= levels[1] else 1
	var low := 1 - high
	var drop := levels[high] - maxf(levels[low], floors[low])
	if open <= 0.0 or levels[high] <= bottom + SHOWS or levels[high] - levels[low] < POURS:
		return
	var from := minf(levels[high], top)
	var to := maxf(levels[low], floors[low])
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
		from = opening.centre.y
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
	# the sea, barely a lip off a weir.
	var throw := Vector3.ZERO
	if axis != 1:
		var head := maxf(levels[high] - (from + maxf(bottom, levels[low])) * 0.5, 0.0)
		throw = normal * minf(2.0 * sqrt(head * tall), MOST_THROW)
	var middle := Vector3(centre.x, (from + to) * 0.5, centre.z) + throw * 0.5
	_hang(pour, Basis(across * width, Vector3.UP * tall - throw, normal), middle, strength)
	if crossing != null:
		var short := opening.size[int(normal.abs().max_axis_index())]
		_hang(crossing, Basis(normal * short, Vector3.UP * tall, across), middle, strength)


## Hangs [param pour] as [param basis] at [param middle], pouring as hard as
## [param strength] says.
func _hang(pour: MeshInstance3D, basis: Basis, middle: Vector3, strength: float) -> void:
	pour.transform = Transform3D(basis, middle)
	pour.set_instance_shader_parameter(&"extent", Vector2(basis.x.length(), basis.y.length()))
	pour.set_instance_shader_parameter(&"strength", strength)
	pour.visible = true


## Whether cell [param side] — or the sea, for -1 — stands over height [param at].
func _over(side: int, at: float) -> bool:
	return side == -1 or _structure.cells[side].low.y >= at - 0.01


## The middle of cell [param side] along [param axis]; far out for the sea.
func _middle(side: int, axis: int) -> float:
	if side == -1:
		return 1e3
	var cell := _structure.cells[side]
	return (cell.low[axis] + cell.high[axis]) * 0.5


## Blows a puff of air out of [param opening] (passage [param index]) where a side's
## water, at [param levels], has just reached its [param top] since last drawn.
func _blow(index: int, levels: PackedFloat64Array, top: float, opening: ShipOpening) -> void:
	var last := _last_heads[index]
	_last_heads[index] = Vector2(levels[0], levels[1])
	if opening.kind in [ShipOpening.Kind.GASH, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.LEAK]:
		return
	for side in 2:
		if last[side] < top and levels[side] >= top and is_finite(last[side]):
			var puff := _puffs[_next_puff]
			_next_puff = (_next_puff + 1) % _puffs.size()
			puff.position = Vector3(opening.centre.x, top, opening.centre.z)
			puff.restart()
			puff.emitting = true


## A burst of air bubbling up out of an opening: one shot, started where it is put.
func _air() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.amount = BUBBLES
	puff.lifetime = BUBBLE_SECONDS
	puff.one_shot = true
	puff.explosiveness = 0.6
	puff.emitting = false
	puff.local_coords = false
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = PUFF
	puff.direction = Vector3.UP
	puff.spread = 25.0
	puff.initial_velocity_min = 0.3
	puff.initial_velocity_max = 0.8
	puff.gravity = Vector3(0.0, 0.6, 0.0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.6
	var bead := SphereMesh.new()
	bead.radius = 0.035
	bead.height = 0.07
	bead.radial_segments = 8
	bead.rings = 4
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.9, 0.98, 1.0, 0.75)
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bead.material = white
	puff.mesh = bead
	add_child(puff)
	return puff
