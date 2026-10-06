class_name SeaAndSky
extends Node3D
## The sea and the dusk over it (sea_and_sky.tscn). The sea is drawn on the world
## plane y = 0, the sea outside her (D7) — leaving out her cells, whose water
## InnerWater draws at each one's own level — as a fine grid round the eye that steps
## after it a whole cell at a time, so its ripple never swims, ringed by a skirt that
## widens out past the far plane, so the sea meets the sky at the horizon wherever the
## eye stands. As the sinking advances the dusk dims a little
## and the sea churns where the bow meets it (show_sinking): read off the snapshot's
## tick and the ship as drawn, presentation only (D5).

## The fine grid: CELLS cells of CELL metres a side, round the eye.
const CELL := 2.0
const CELLS := 120
## Each ring of the skirt is this much wider than the one inside it, out to REACH
## metres from the eye: past any camera's far plane.
const RING_GROWTH := 1.45
const REACH := 1200.0
## The dusk's gloom (dusk.gdshaderinc) by the sinking's end, and the steps it takes
## there: each step draws the sky's radiance again.
const GLOOM := 0.7
const GLOOM_STEP := 1.0 / 48.0
## The share of the sun's light the full gloom takes away.
const SUN_DIMMING := 0.3
## The bow's churn: how far it spreads round where the stem meets the sea, and the
## trim it is at its strongest by.
const CHURN_RADIUS := 7.0
const CHURN_TRIM_DEG := 10.0
## How far the stem reaches below the waterline of a level, unsunk ship (ShipHull).
const STEM_DRAFT := 0.5
## A bottom shallower than this, in metres, is drawn: a coast's (SH32), where she can
## come to rest; and it is drawn this wide round the eye, stepping after it as the sea
## does.
const BOTTOM_SHOWN := 60.0
const BOTTOM_SIZE := 600.0
## The side, in metres, of a cell of the rooms' maps (room_map, room_edges); how far
## in or out of a room the edges' map tells apart; and how far past its walls it
## takes a room to reach, so its corners, read between texels — which round a
## corner by up to a quarter of a cell — keep in it: the sea by the hull gives up no
## more of its sky than that, under the hull's own foam.
const ROOM_CELL := 0.5
const EDGE_REACH := 1.0
const EDGE_GRACE := ROOM_CELL * 0.25

var _end_tick := 0
## The stem, ship space: its head at the bow's deck, its foot under the waterline;
## and the stern at the head's height, so the line aft from the head is the one the
## sea crosses once the head is under.
var _stem_head := Vector3.ZERO
var _stem_foot := Vector3.ZERO
var _stern := Vector3.ZERO
var _dusk: Environment
var _sky: ShaderMaterial
var _water: ShaderMaterial
var _sun_energy: float
var _fog: Color
var _gloom := -1.0
## What the sea was last told of the churn.
var _churn := 0.0
var _churn_centre := Vector2.ZERO
var _churn_axis := Vector2.RIGHT
## From ship space to the rooms' map: x and z to its UV, y kept; and the ship as
## last drawn, so the sea is told where the rooms are only when it moves.
var _ship_to_rooms := Transform3D()
var _ship_to_world := Transform3D()
## The bottom under a coast's shallow water, or null in the open sea.
var _bottom: MeshInstance3D

@onready var _world: WorldEnvironment = $Environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _sea: MeshInstance3D = $Sea


func _ready() -> void:
	# Its own copies, so dimming one match's dusk never reaches the next match's.
	_dusk = _world.environment.duplicate(true)
	_world.environment = _dusk
	_sky = _dusk.sky.sky_material
	_water = _sea.material_override.duplicate()
	_sea.material_override = _water
	_sea.mesh = sea_mesh()
	_sun_energy = _sun.light_energy
	_fog = _dusk.fog_light_color
	_water.set_shader_parameter(&"sun_direction", sun())
	_water.set_shader_parameter(&"churn_radius", CHURN_RADIUS)
	_show_gloom(0.0)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var eye := camera.global_position
		_sea.global_position = Vector3(snappedf(eye.x, CELL), 0.0, snappedf(eye.z, CELL))
		if _bottom != null:
			_bottom.global_position = Vector3(
				snappedf(eye.x, CELL), _bottom.global_position.y, snappedf(eye.z, CELL)
			)


## The world's environment, which Underwater swaps while the eye is under the sea.
func world() -> WorldEnvironment:
	return _world


## The dusk above the sea: the environment the world has while the eye is dry.
func dusk() -> Environment:
	return _dusk


## Toward the sun the scene's light comes from, in the world.
func sun() -> Vector3:
	return _sun.global_basis.z


## The sea's material, for Underwater to tell it what the view under the sea is.
func water() -> ShaderMaterial:
	return _water


## Dims the dusk toward [param end_tick], the tick the sinking ends by (none when
## not positive), churns the sea at [param layout]'s bow and keeps the open sea's sky,
## glint and whitecaps off the water in its rooms, and the sea out of her cells whose
## water is drawn as their own (InnerWater), from now on; under a sea
## [param sea_depth] deep, the bottom when it is a coast's.
func setup(end_tick: int, layout: ShipLayout, sea_depth: float = INF) -> void:
	_end_tick = end_tick
	_lay_bottom(sea_depth)
	_map_rooms(layout)
	if layout.structure != null:
		_mask_cells(InnerWater.boxes(layout.structure, layout.rooms))
	var bounds := layout.platforms[0].area
	var top := -INF
	for platform: ShipPlatform in layout.platforms:
		bounds = bounds.merge(platform.area)
	for platform: ShipPlatform in layout.platforms:
		if platform.area.end.x >= bounds.end.x:
			top = maxf(top, platform.height)
	var middle := bounds.get_center().y
	_stem_head = Vector3(bounds.end.x, top, middle)
	_stem_foot = Vector3(bounds.end.x, -layout.freeboard - STEM_DRAFT, middle)
	_stern = Vector3(bounds.position.x, top, middle)


## The bottom [param depth] under the still sea, drawn while it is shallower than
## BOTTOM_SHOWN: where a coast's wreck comes to rest.
func _lay_bottom(depth: float) -> void:
	if _bottom != null:
		_bottom.queue_free()
		_bottom = null
	if depth >= BOTTOM_SHOWN:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * BOTTOM_SIZE
	var sand := StandardMaterial3D.new()
	sand.albedo_color = ArtPalette.SEABED
	sand.roughness = 1.0
	plane.material = sand
	_bottom = MeshInstance3D.new()
	_bottom.name = "Bottom"
	_bottom.mesh = plane
	_bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bottom)
	_bottom.global_position = Vector3(0.0, -depth, 0.0)


## Draws the sun's shadows, the dusk's glow and the sea's fine detail as
## [param quality] says.
func show_graphics(quality: GraphicsQuality) -> void:
	_sun.directional_shadow_mode = quality.shadow_mode
	_sun.directional_shadow_max_distance = quality.shadow_distance
	_dusk.glow_enabled = quality.glow
	_water.set_shader_parameter(&"fine_share", quality.sea_detail)


## Shows the sinking at [param tick] with the ship drawn at [param ship_to_world].
func show_sinking(tick: int, ship_to_world: Transform3D) -> void:
	var progress := clampf(float(tick) / _end_tick, 0.0, 1.0) if _end_tick > 0 else 0.0
	_show_gloom(snappedf(GLOOM * progress * progress, GLOOM_STEP))
	_show_churn(ship_to_world)
	if ship_to_world != _ship_to_world:
		_ship_to_world = ship_to_world
		_water.set_shader_parameter(&"world_to_rooms", _ship_to_rooms * ship_to_world.inverse())
		_water.set_shader_parameter(&"world_to_ship", ship_to_world.affine_inverse())


func _show_gloom(gloom: float) -> void:
	if gloom == _gloom:
		return
	_gloom = gloom
	_sky.set_shader_parameter(&"gloom", gloom)
	_water.set_shader_parameter(&"gloom", gloom)
	_sun.light_energy = _sun_energy * (1.0 - SUN_DIMMING * gloom)
	_dusk.fog_light_color = _fog.darkened(SUN_DIMMING * gloom)


## Churns the sea where the waterline crosses the stem — or, once the stem's head is
## under, the centreline aft from it — harder as the bow goes down.
func _show_churn(ship_to_world: Transform3D) -> void:
	# The bow (+x) dips by the trim; a heel turns about x and leaves it be.
	var trim_deg := rad_to_deg(asin(clampf(-ship_to_world.basis.x.normalized().y, -1.0, 1.0)))
	var head := ship_to_world * _stem_head
	var at := _crossing(ship_to_world * _stem_foot, head)
	if is_nan(at.x):
		at = _crossing(head, ship_to_world * _stern)
	# Where the sea crosses neither, nothing churns and the centre keeps its last
	# finite value: a NaN would reach the shader's mix(), which GLSL leaves undefined.
	var churn := 0.0 if is_nan(at.x) else clampf(trim_deg / CHURN_TRIM_DEG, 0.0, 1.0)
	if churn > 0.0 and Vector2(at.x, at.z) != _churn_centre:
		_churn_centre = Vector2(at.x, at.z)
		_water.set_shader_parameter(&"churn_centre", _churn_centre)
	# The stem's line on the sea, which the churn streams along; kept while the ship
	# stands near on end and it has no line on the sea to speak of.
	var along := Vector2(ship_to_world.basis.x.x, ship_to_world.basis.x.z)
	if churn > 0.0 and along.length() > 0.1 and along.normalized() != _churn_axis:
		_churn_axis = along.normalized()
		_water.set_shader_parameter(&"churn_axis", _churn_axis)
	if churn != _churn:
		_churn = churn
		_water.set_shader_parameter(&"churn", churn)


## Hands the sea [param layout]'s rooms as a map (room_map), and how to find a
## point of the world on it.
func _map_rooms(layout: ShipLayout) -> void:
	if layout.rooms.is_empty():
		return
	var bounds := room_bounds(layout)
	_ship_to_rooms = Transform3D(
		Basis.from_scale(Vector3(1.0 / bounds.size.x, 1.0, 1.0 / bounds.size.y)),
		Vector3(-bounds.position.x / bounds.size.x, 0.0, -bounds.position.y / bounds.size.y)
	)
	_ship_to_world = Transform3D()
	_water.set_shader_parameter(&"rooms", ImageTexture.create_from_image(room_map(layout)))
	var edges := ImageTexture.create_from_image(room_edges(layout))
	_water.set_shader_parameter(&"room_edges", edges)
	_water.set_shader_parameter(&"world_to_rooms", _ship_to_rooms)


## Leaves the sea out of [param boxes] (ship space), and the box round them all.
func _mask_cells(boxes: Array[AABB]) -> void:
	var lows := PackedVector4Array()
	var highs := PackedVector4Array()
	var around := AABB()
	for box: AABB in boxes:
		if box.size == Vector3.ZERO:
			continue
		lows.append(Vector4(box.position.x, box.position.y, box.position.z, 0.0))
		highs.append(Vector4(box.end.x, box.end.y, box.end.z, 0.0))
		around = box if lows.size() == 1 else around.merge(box)
	_water.set_shader_parameter(&"cell_low", lows)
	_water.set_shader_parameter(&"cell_high", highs)
	_water.set_shader_parameter(&"cell_count", lows.size())
	_water.set_shader_parameter(&"cells_low", around.position)
	_water.set_shader_parameter(&"cells_high", around.end)


## What the rooms' map covers, ship x/z: every room and a cell of nothing round
## them, in whole cells.
static func room_bounds(layout: ShipLayout) -> Rect2:
	var bounds := layout.rooms[0].area
	for room: ShipRoom in layout.rooms:
		bounds = bounds.merge(room.area)
	bounds = bounds.grow(ROOM_CELL)
	return Rect2(bounds.position, (bounds.size / ROOM_CELL).ceil() * ROOM_CELL)


## The rooms seen from above, a cell of ROOM_CELL metres a texel over room_bounds():
## red the lowest floor, green the highest ceiling (ShipSpace) of the rooms reaching
## into the cell — of both sides where a wall runs through it, so the water in a room
## by its wall never takes the sky — and both zero where no room is. A point of the
## ship between the two, and in a room by room_edges(), stands in a room.
static func room_map(layout: ShipLayout) -> Image:
	var space := ShipSpace.new(layout)
	var bounds := room_bounds(layout)
	var size := _cells(bounds)
	var map := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGF)
	for row in size.y:
		for column in size.x:
			var cell := Rect2(bounds.position + Vector2(column, row) * ROOM_CELL, Vector2.ONE)
			cell.size *= ROOM_CELL
			var span := Vector2(INF, -INF)
			for room: ShipRoom in layout.rooms:
				if room.area.intersects(cell):
					var at := cell.get_center().clamp(room.area.position, room.area.end)
					span.x = minf(span.x, room.floor_height)
					span.y = maxf(span.y, space.ceiling(room, at.x, at.y))
			if span.x < span.y:
				map.set_pixel(column, row, Color(span.x, span.y, 0.0))
	return map


## How far inside the rooms each cell's middle of room_bounds() stands, in metres,
## past EDGE_GRACE — less than nothing outside them, held within EDGE_REACH; half floats, which a
## browser's GPU reads between texels. Read between the cells' middles, as the sea
## reads it, a wall runs where it stands rather than along the cells', so no strip of
## a room by its wall takes the sky, nor of the sea by the hull loses it.
static func room_edges(layout: ShipLayout) -> Image:
	var bounds := room_bounds(layout)
	var size := _cells(bounds)
	var edges := Image.create_empty(size.x, size.y, false, Image.FORMAT_RH)
	for row in size.y:
		for column in size.x:
			var at := bounds.position + (Vector2(column, row) + Vector2(0.5, 0.5)) * ROOM_CELL
			var inside := -EDGE_REACH
			for room: ShipRoom in layout.rooms:
				inside = maxf(inside, _inside(room.area, at))
			edges.set_pixel(column, row, Color(minf(inside + EDGE_GRACE, EDGE_REACH), 0.0, 0.0))
	return edges


## How far [param at] stands inside [param area], less than nothing outside it —
## off a corner as far as off the nearer of its walls' lines, so a corner read
## between texels stays square.
static func _inside(area: Rect2, at: Vector2) -> float:
	var out := (area.position - at).max(at - area.end)
	return -maxf(out.x, out.y)


static func _cells(bounds: Rect2) -> Vector2i:
	return Vector2i((bounds.size / ROOM_CELL).round())


## Where the segment from [param a] to [param b] crosses the sea plane, or NaNs.
static func _crossing(a: Vector3, b: Vector3) -> Vector3:
	if signf(a.y) == signf(b.y):
		return Vector3(NAN, NAN, NAN)
	return a.lerp(b, a.y / (a.y - b.y))


## The sea's mesh, about its own origin: the fine grid, then the skirt's rings, each
## with as many points round it as the grid's edge, so none leaves a crack.
static func sea_mesh() -> ArrayMesh:
	var points := PackedVector3Array()
	var indices := PackedInt32Array()
	var half := CELL * CELLS / 2.0
	for row in CELLS + 1:
		for column in CELLS + 1:
			points.append(Vector3(column * CELL - half, 0.0, row * CELL - half))
			if row > 0 and column > 0:
				var here := row * (CELLS + 1) + column
				_quad(indices, here - CELLS - 2, here - CELLS - 1, here - 1, here)
	var around := CELLS * 4
	var inner := _ring(points, half)
	var size := half
	while size < REACH:
		size *= RING_GROWTH
		var outer := _ring(points, size)
		for step in around:
			var next := (step + 1) % around
			_quad(indices, inner + next, inner + step, outer + next, outer + step)
		inner = outer
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A square of [param half] round the origin, CELLS points a side, going round the
## same way as the grid's edge; returns the index of its first point.
static func _ring(points: PackedVector3Array, half: float) -> int:
	var first := points.size()
	var step := half * 2.0 / CELLS
	for index in CELLS:
		points.append(Vector3(-half + index * step, 0.0, -half))
	for index in CELLS:
		points.append(Vector3(half, 0.0, -half + index * step))
	for index in CELLS:
		points.append(Vector3(half - index * step, 0.0, half))
	for index in CELLS:
		points.append(Vector3(-half, 0.0, half - index * step))
	return first


## Two triangles facing up for the cell a b d c: b follows a along one edge and c
## lies across the cell from a, so that a b c turns clockwise seen from above, the
## way Godot draws a face's front.
static func _quad(indices: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
