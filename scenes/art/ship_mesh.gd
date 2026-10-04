class_name ShipMesh
extends RefCounted
## The dressed ship's faces in ship space, gathered by paint, and indoors by chunk
## too. An axis-aligned face is cut at every room's edge and each piece is classed
## indoors or out on its own. Outdoor pieces share one mesh per paint on
## OUTDOOR_LAYER, which no lamp lights (ShipLamp), so no lamp leaks through a wall
## onto a deck. Indoor pieces cast no shadow — the outdoor shell does — and go in
## one mesh per chunk: a lamp lights only the meshes its range reaches, and
## Compatibility lights a mesh with eight at most, so no indoor mesh spans more
## than a few rooms. Each face's rim fades toward the crew's ink
## (ship.gdshaderinc), so a box reads bevelled. A mesh told which pieces fade out
## near the eye (fading) gives each vertex its piece's box, for the shader to fade
## the piece by.

## What a face is painted with (ship.gdshaderinc's finishes, then the glass, then
## the rooms' own: riveted steel and rough timber).
enum Finish { PLAIN, DECK, HULL, HOUSE, CABIN, FUNNEL, GLASS_IN, GLASS_OUT, PLATE, ROUGH }

## The rims of a face: the edges at u = 0, u = 1, v = 0 and v = 1.
const RIM_U0 := 1
const RIM_U1 := 2
const RIM_V0 := 4
const RIM_V1 := 8
const RIM_ALL := 15
## The faces of a box.
const TOP := 1
const BOTTOM := 2
const POS_X := 4
const NEG_X := 8
const POS_Z := 16
const NEG_Z := 32
const ALL_FACES := 63
const SIDES := POS_X | NEG_X | POS_Z | NEG_Z
## How wide a face's darkened rim is, at most.
const RIM := 0.045
## The chunk a face's mesh belongs to, in ship metres.
const CHUNK := Vector3(4.0, 2.5, 5.0)
## How far in front of a face its indoors-or-out is judged.
const PROBE := 0.15
## A face narrower than this — a beam, a rail, a wall's end — is never cut: it
## lies along one room or none.
const NARROW := 0.3
## The render layer outdoor pieces are drawn on, alone.
const OUTDOOR_LAYER := 3
## Lengths below this are float noise.
const SLIVER := 0.005


## What a face is painted with outdoors, and indoors.
class Paint:
	var finish: int
	var colour: Color
	var finish_in: int
	var colour_in: Color

	## Indoors the same as outdoors unless [param in_finish] and [param in_colour]
	## say otherwise.
	func _init(
		out_finish: int, out_colour: Color, in_finish := -1, in_colour := Color(0, 0, 0, 0)
	) -> void:
		finish = out_finish
		colour = out_colour
		finish_in = out_finish if in_finish == -1 else in_finish
		colour_in = out_colour if in_colour.a == 0.0 else in_colour


## One mesh's arrays.
class Batch:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	## Per vertex when its mesh is fading: its piece's middle and 1 when the piece
	## fades, else 0; and its piece's half size.
	var pieces := PackedFloat32Array()
	var halves := PackedFloat32Array()


## Ship-local height: a piece wholly at or above it is not drawn — the observer's
## cut-away; ship.gdshaderinc trims what straddles it.
var cut_above := INF
## (piece: AABB) -> bool, ship space, when set: whether a piece — what one call
## draws, a box, a cylinder, a face — fades out near the eye (ship_near.gdshader).
var fading := Callable()

## (point: Vector3) -> bool: whether a ship-space point stands outdoors.
var _outdoors: Callable
## Every line an axis-aligned face is cut at, per axis.
var _cuts: Array[PackedFloat32Array] = []
## "finish out" or "finish in x y z" -> Batch
var _batches := {}
## The same keys -> Finish
var _finishes := {}
## Whether the piece _batch_for() last placed stands outdoors.
var _last_outdoors := true
## While fading: how many calls deep the piece being drawn is, its box so far, and
## the batches it has reached.
var _depth := 0
var _piece := AABB()
var _reached: Array[Batch] = []


## [param outdoors] says whether a ship point is outdoors; [param room_cuts] holds,
## per axis x, y, z, the lines a face is cut at besides the chunk lines.
func _init(outdoors: Callable, room_cuts: Array[PackedFloat32Array]) -> void:
	_outdoors = outdoors
	for axis in 3:
		var lines := room_cuts[axis].duplicate()
		lines.sort()
		_cuts.append(lines)


## An axis-aligned box over [param area] (x/z) from [param bottom] to [param top]:
## [param faces] says which of its six. [param foot] and [param head] are the heights
## its paint's bands are measured from — its own bottom and top unless given.
func box(
	area: Rect2,
	bottom: float,
	top: float,
	paint: Paint,
	faces := ALL_FACES,
	foot := NAN,
	head := NAN
) -> void:
	if top - bottom < SLIVER or area.size.x < SLIVER or area.size.y < SLIVER:
		return
	foot = bottom if is_nan(foot) else foot
	head = top if is_nan(head) else head
	_open()
	var x0 := area.position.x
	var x1 := area.end.x
	var z0 := area.position.y
	var z1 := area.end.y
	var dx := Vector3(area.size.x, 0.0, 0.0)
	var dy := Vector3(0.0, top - bottom, 0.0)
	var dz := Vector3(0.0, 0.0, area.size.y)
	if faces & TOP:
		face(Vector3(x0, top, z0), dz, dx, paint, RIM_ALL, foot, head)
	if faces & BOTTOM:
		face(Vector3(x0, bottom, z0), dx, dz, paint, RIM_ALL, foot, head)
	if faces & POS_X:
		face(Vector3(x1, bottom, z0), dy, dz, paint, RIM_ALL, foot, head)
	if faces & NEG_X:
		face(Vector3(x0, bottom, z0), dz, dy, paint, RIM_ALL, foot, head)
	if faces & POS_Z:
		face(Vector3(x0, bottom, z1), dx, dy, paint, RIM_ALL, foot, head)
	if faces & NEG_Z:
		face(Vector3(x0, bottom, z0), dy, dx, paint, RIM_ALL, foot, head)
	_close()


## A box of [param size] placed by [param place] (its centre and turn), uncut, the
## edges [param rims] names on each face darkened — none where a rim would not show,
## a bevel too small or on a paint too dark to see.
func turned_box(place: Transform3D, size: Vector3, paint: Paint, rims := RIM_ALL) -> void:
	var half := size * 0.5
	var b := place.basis
	var x := b.x * size.x
	var y := b.y * size.y
	var z := b.z * size.z
	var low := place * (-half)
	var high := place * half
	var foot := low.y
	var head := high.y
	_open()
	quad(low, low + z, low + z + x, low + x, -b.y, paint, rims, foot, head)
	quad(high, high - x, high - x - z, high - z, b.y, paint, rims, foot, head)
	quad(low, low + y, low + y + z, low + z, -b.x, paint, rims, foot, head)
	quad(high, high - z, high - z - y, high - y, b.x, paint, rims, foot, head)
	quad(low, low + x, low + x + y, low + y, -b.z, paint, rims, foot, head)
	quad(high, high - y, high - y - x, high - x, b.z, paint, rims, foot, head)
	_close()


## A beam of [param section] from [param from] to [param to], uncut, its faces'
## [param rims] darkened (turned_box()).
func beam(from: Vector3, to: Vector3, section: Vector2, paint: Paint, rims := RIM_ALL) -> void:
	var length := from.distance_to(to)
	if length < SLIVER:
		return
	var y := (to - from) / length
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	turned_box(
		Transform3D(Basis(x, y, z), (from + to) * 0.5),
		Vector3(section.x, length, section.y),
		paint,
		rims
	)


## An upright cylinder round [param centre] (x/z) from [param bottom] to [param top]
## in [param segments] flat facets, its sides cut at the room lines, with its top
## capped when [param cap] says so.
func cylinder(
	centre: Vector2,
	radius: float,
	bottom: float,
	top: float,
	segments: int,
	paint: Paint,
	cap := true
) -> void:
	var heights := _between(_cuts[1], bottom, top)
	_open()
	for index in segments:
		var a := TAU * index / segments
		var b := TAU * (index + 1) / segments
		var from := Vector3(centre.x + cos(a) * radius, 0.0, centre.y + sin(a) * radius)
		var to := Vector3(centre.x + cos(b) * radius, 0.0, centre.y + sin(b) * radius)
		var out := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
		for band in heights.size() - 1:
			var y0 := heights[band]
			var y1 := heights[band + 1]
			var rims := (RIM_V0 if band == 0 else 0) | (RIM_V1 if band == heights.size() - 2 else 0)
			quad(
				from + Vector3.UP * y0,
				to + Vector3.UP * y0,
				to + Vector3.UP * y1,
				from + Vector3.UP * y1,
				out,
				paint,
				rims,
				bottom,
				top
			)
	if cap:
		var ring := PackedVector3Array()
		for index in segments:
			var a := TAU * index / segments
			ring.append(Vector3(centre.x + cos(a) * radius, top, centre.y + sin(a) * radius))
		polygon(ring, Vector3.UP, paint, bottom, top)
	_close()


## A flat convex polygon [param ring] facing [param normal], its rim darkened.
func polygon(
	ring: PackedVector3Array, normal: Vector3, paint: Paint, foot: float, head: float
) -> void:
	var middle := Vector3.ZERO
	for point: Vector3 in ring:
		middle += point
	middle /= ring.size()
	var count := ring.size()
	_open()
	for index in count:
		var a := ring[index]
		var b := ring[(index + 1) % count]
		var a_in := a.move_toward(middle, RIM)
		var b_in := b.move_toward(middle, RIM)
		quad(a, b, b_in, a_in, normal, paint, RIM_V0, foot, head)
		triangle(
			PackedVector3Array([a_in, b_in, middle]),
			PackedFloat32Array([0.0, 0.0, 0.0]),
			normal,
			paint,
			foot,
			head
		)
	_close()


## A face from [param origin] along [param u] and [param v] — unless it is narrow,
## its axis-aligned edges are cut at the chunk and room lines — facing
## [param u] × [param v].
func face(
	origin: Vector3, u: Vector3, v: Vector3, paint: Paint, rims := RIM_ALL, foot := NAN, head := NAN
) -> void:
	var normal := u.cross(v).normalized()
	var whole := PackedFloat32Array([0.0, 1.0])
	var narrow := minf(u.length(), v.length()) < NARROW
	var u_cuts := whole if narrow else _splits(origin, u)
	var v_cuts := whole if narrow else _splits(origin, v)
	_open()
	for i in u_cuts.size() - 1:
		for j in v_cuts.size() - 1:
			var a := origin + u * u_cuts[i] + v * v_cuts[j]
			var b := origin + u * u_cuts[i + 1] + v * v_cuts[j]
			var c := origin + u * u_cuts[i + 1] + v * v_cuts[j + 1]
			var d := origin + u * u_cuts[i] + v * v_cuts[j + 1]
			var edges := (
				(rims & RIM_U0 if i == 0 else 0)
				| (rims & RIM_U1 if i == u_cuts.size() - 2 else 0)
				| (rims & RIM_V0 if j == 0 else 0)
				| (rims & RIM_V1 if j == v_cuts.size() - 2 else 0)
			)
			quad(a, b, c, d, normal, paint, edges, foot, head)
	_close()


## The four corners a (u0 v0), b (u1 v0), c (u1 v1), d (u0 v1) of one flat piece,
## facing [param normal], with a darkened band along each edge [param rims] names.
func quad(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	paint: Paint,
	rims := RIM_ALL,
	foot := NAN,
	head := NAN
) -> void:
	if minf(minf(a.y, b.y), minf(c.y, d.y)) >= cut_above:
		return
	var batch := _batch_for((a + c) * 0.5, normal, paint)
	var outdoors: bool = _last_outdoors
	var colour := paint.colour if outdoors else paint.colour_in
	var flag := 1.0 if outdoors else 0.0
	var clockwise := (b - a).cross(d - a).dot(normal) < 0.0
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	if rims == 0:
		var corners := PackedVector3Array([a, b, c, d])
		for corner: Vector3 in corners:
			uvs.append(_bands(corner, foot, head))
			uv2s.append(Vector2(0.0, flag))
		normals.resize(4)
		normals.fill(normal)
		var order := PackedInt32Array([0, 1, 2, 0, 2, 3] if clockwise else [0, 2, 1, 0, 3, 2])
		_emit(batch, order, corners, normals, colour, uvs, uv2s)
		return
	var u_length := minf(a.distance_to(b), d.distance_to(c))
	var v_length := minf(a.distance_to(d), b.distance_to(c))
	var ru := minf(RIM, u_length / 3.0) / maxf(u_length, SLIVER)
	var rv := minf(RIM, v_length / 3.0) / maxf(v_length, SLIVER)
	var us := PackedFloat32Array([0.0])
	if rims & RIM_U0:
		us.append(ru)
	if rims & RIM_U1:
		us.append(1.0 - ru)
	us.append(1.0)
	var vs := PackedFloat32Array([0.0])
	if rims & RIM_V0:
		vs.append(rv)
	if rims & RIM_V1:
		vs.append(1.0 - rv)
	vs.append(1.0)
	var columns := us.size()
	var rows := vs.size()
	var points := PackedVector3Array()
	for j in rows:
		for i in columns:
			var point := a.lerp(b, us[i]).lerp(d.lerp(c, us[i]), vs[j])
			var on_edge := (
				(i == 0 and rims & RIM_U0)
				or (i == columns - 1 and rims & RIM_U1)
				or (j == 0 and rims & RIM_V0)
				or (j == rows - 1 and rims & RIM_V1)
			)
			points.append(point)
			uvs.append(_bands(point, foot, head))
			uv2s.append(Vector2(1.0 if on_edge else 0.0, flag))
	normals.resize(points.size())
	normals.fill(normal)
	var order := PackedInt32Array()
	for j in rows - 1:
		for i in columns - 1:
			var p00 := j * columns + i
			var p10 := p00 + 1
			var p01 := p00 + columns
			var p11 := p01 + 1
			if clockwise:
				order.append_array([p00, p10, p11, p00, p11, p01])
			else:
				order.append_array([p00, p11, p10, p00, p01, p11])
	_emit(batch, order, points, normals, colour, uvs, uv2s)


## One piece of a curved surface: [param corners] a, b, c, d as quad()'s, each
## shaded by its own of [param normals], with no darkened rim; [param heads] holds
## each corner's height for its paint's bands under the top, or is empty for none.
func smooth_quad(
	corners: PackedVector3Array,
	normals: PackedVector3Array,
	paint: Paint,
	heads := PackedFloat32Array()
) -> void:
	var lowest := minf(minf(corners[0].y, corners[1].y), minf(corners[2].y, corners[3].y))
	if lowest >= cut_above:
		return
	var facing := (normals[0] + normals[1] + normals[2] + normals[3]).normalized()
	var batch := _batch_for((corners[0] + corners[2]) * 0.5, facing, paint)
	var colour := paint.colour if _last_outdoors else paint.colour_in
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for index in 4:
		var head := NAN if heads.is_empty() else heads[index]
		uvs.append(_bands(corners[index], NAN, head))
		uv2s.append(Vector2(0.0, 1.0 if _last_outdoors else 0.0))
	var order := PackedInt32Array([0, 1, 2, 0, 2, 3])
	if (corners[1] - corners[0]).cross(corners[3] - corners[0]).dot(facing) > 0.0:
		order = PackedInt32Array([0, 2, 1, 0, 3, 2])
	_emit(batch, order, corners, normals, colour, uvs, uv2s)


## A triangle of [param corners] facing [param normal], its corners' rim weights
## [param weights].
func triangle(
	corners: PackedVector3Array,
	weights: PackedFloat32Array,
	normal: Vector3,
	paint: Paint,
	foot := NAN,
	head := NAN
) -> void:
	if minf(corners[0].y, minf(corners[1].y, corners[2].y)) >= cut_above:
		return
	var batch := _batch_for((corners[0] + corners[1] + corners[2]) / 3.0, normal, paint)
	var colour := paint.colour if _last_outdoors else paint.colour_in
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for index in 3:
		normals.append(normal)
		uvs.append(_bands(corners[index], foot, head))
		uv2s.append(Vector2(weights[index], 1.0 if _last_outdoors else 0.0))
	var order := PackedInt32Array([0, 1, 2])
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) > 0.0:
		order = PackedInt32Array([0, 2, 1])
	_emit(batch, order, corners, normals, colour, uvs, uv2s)


## Every batch as a mesh instance under [param parent].
func commit(parent: Node3D, materials: Dictionary) -> void:
	var keys := _batches.keys()
	keys.sort()
	for key: String in keys:
		var batch: Batch = _batches[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.vertices
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
		arrays[Mesh.ARRAY_COLOR] = batch.colours
		arrays[Mesh.ARRAY_TEX_UV] = batch.uvs
		arrays[Mesh.ARRAY_TEX_UV2] = batch.uv2s
		var format := 0
		if not batch.halves.is_empty():
			arrays[Mesh.ARRAY_CUSTOM0] = batch.pieces
			arrays[Mesh.ARRAY_CUSTOM1] = batch.halves
			format = (
				Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
				| Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
			)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
		mesh.surface_set_material(0, materials[_finishes[key]])
		var instance := MeshInstance3D.new()
		instance.name = key.replace(" ", "_")
		instance.mesh = mesh
		if key.contains("out"):
			instance.layers = 1 << (OUTDOOR_LAYER - 1)
		else:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_batches.clear()
	_finishes.clear()


## The batch a piece centred on [param middle] and facing [param normal] goes in:
## its paint's finish indoors or out, judged a step in front of it, and its chunk.
## [member _last_outdoors] keeps the verdict for the caller.
func _batch_for(middle: Vector3, normal: Vector3, paint: Paint) -> Batch:
	_last_outdoors = _outdoors.call(middle + normal * PROBE)
	var finish := paint.finish if _last_outdoors else paint.finish_in
	var key := "%d out" % finish
	if not _last_outdoors:
		var chunk := Vector3i((middle / CHUNK).floor())
		key = "%d in %d %d %d" % [finish, chunk.x, chunk.y, chunk.z]
	if not _batches.has(key):
		_batches[key] = Batch.new()
		_finishes[key] = finish
	return _batches[key]


## The corners of [param points] into [param batch] in [param order], three to a
## triangle, each with its own of [param normals], [param uvs] (its paint's bands)
## and [param uv2s] (its rim weight, and 1 outdoors). Godot's front faces are wound
## clockwise.
func _emit(
	batch: Batch,
	order: PackedInt32Array,
	points: PackedVector3Array,
	normals: PackedVector3Array,
	colour: Color,
	uvs: PackedVector2Array,
	uv2s: PackedVector2Array
) -> void:
	for index in order:
		batch.vertices.append(points[index])
		batch.normals.append(normals[index])
		batch.colours.append(colour)
		batch.uvs.append(uvs[index])
		batch.uv2s.append(uv2s[index])
	if not fading.is_valid():
		return
	if _reached.is_empty():
		_piece = AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		_piece = _piece.expand(point)
	if not batch in _reached:
		_reached.append(batch)
	if _depth == 0:
		_seal()


## Begins and ends a call that draws a piece out of several calls' faces: the
## outermost seals it.
func _open() -> void:
	_depth += 1


func _close() -> void:
	_depth -= 1
	if _depth == 0 and not _reached.is_empty():
		_seal()


## Gives every vertex of the piece just drawn its box, and whether it fades.
func _seal() -> void:
	var middle := _piece.get_center()
	var half := _piece.size * 0.5
	var fades := 1.0 if fading.call(_piece) else 0.0
	var piece := PackedFloat32Array([middle.x, middle.y, middle.z, fades])
	var size := PackedFloat32Array([half.x, half.y, half.z])
	for batch: Batch in _reached:
		for index in batch.vertices.size() - batch.halves.size() / 3:
			batch.pieces.append_array(piece)
			batch.halves.append_array(size)
	_reached.clear()


## How far [param point] stands over [param foot] and under [param head], its
## paint's bands; 0 for either that is NAN.
static func _bands(point: Vector3, foot: float, head: float) -> Vector2:
	return Vector2(0.0 if is_nan(foot) else point.y - foot, 0.0 if is_nan(head) else head - point.y)


## Where along [param edge] (a fraction 0…1 of it, from [param origin]) a face is
## cut: its ends, every chunk line and every room line it crosses — only along an
## axis-aligned edge.
func _splits(origin: Vector3, edge: Vector3) -> PackedFloat32Array:
	var length := edge.length()
	var fractions := PackedFloat32Array([0.0, 1.0])
	if length < SLIVER:
		return fractions
	var axis := -1
	for candidate in 3:
		if absf(edge[candidate]) >= length - SLIVER:
			axis = candidate
	if axis == -1:
		return fractions
	var start := origin[axis]
	var end := start + edge[axis]
	var low := minf(start, end)
	var high := maxf(start, end)
	var lines := _between(_cuts[axis], low, high)
	var step := CHUNK[axis]
	var line := ceilf(low / step) * step
	while line < high:
		lines.append(line)
		line += step
	lines.sort()
	var cut := PackedFloat32Array([0.0])
	for at: float in lines:
		var fraction := (at - start) / (end - start)
		if fraction * length > SLIVER and (1.0 - fraction) * length > SLIVER:
			cut.append(fraction)
	cut.append(1.0)
	cut.sort()
	var kept := PackedFloat32Array([cut[0]])
	for fraction: float in cut:
		if (fraction - kept[kept.size() - 1]) * length > SLIVER:
			kept.append(fraction)
	if kept[kept.size() - 1] < 1.0:
		kept[kept.size() - 1] = 1.0
	return kept


## [param low], every line of [param lines] strictly between, and [param high].
func _between(lines: PackedFloat32Array, low: float, high: float) -> PackedFloat32Array:
	var found := PackedFloat32Array([low])
	for at: float in lines:
		if at > low + SLIVER and at < high - SLIVER:
			found.append(at)
	found.append(high)
	return found
