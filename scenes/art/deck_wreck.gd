class_name DeckWreck
extends RefCounted
## A deck the scenario can collapse (ShipArt), drawn to break as it lands. Whole, it is
## planked over a ceiling on beams like any deck; it is drawn as a rim RIM wide round
## its edge — what stands on the walls under it — and, inside, three shards split on
## jagged lines. Once it starts to fall the rim is gone and the walls' tops show torn
## plank and beam ends; as it lands the shards come apart: the after one lies on its
## beams on the floor, the two forward ones — their beams torn off — lie tipped up onto
## it, with loose planks and a broken beam among them.
## Wherever it lands it lies within a step of the floor beneath, inside the room under
## it and clear of its walls' fittings, so a body walking there treads on wreckage
## rather than through a deck (the rules have only the floor there now).

## The rim over the walls; how far the shards keep in along x from the after wall and
## from the forward one (clear of a wheel wall's fittings standing on the floor), and
## how far apart they draw along z.
const RIM := 0.2
const SLIDE := Vector2(0.01, 0.15)
const GAP := 0.07
## The jagged breaks: a tooth every TOOTH along them, standing out up to JAG.
const TOOTH := 0.22
const JAG := 0.07
## How far each shard tips up across the ship: the after one at its starboard side, the
## forward ones at their outer sides (after, forward port, forward starboard); and how
## far the forward ones clear the after one as they ride up onto it.
const TIPS := Vector3(0.03, 0.015, 0.015)
const RIDE_CLEAR := 0.01
## Splinters off a break: one every SPLINTER apart or so, up to SPLINTER_REACH out;
## a torn end on a wall's top droops up to DROOP.
const SPLINTER := 0.22
const SPLINTER_REACH := 0.18
const DROOP := 0.25
## How far into the fall (0…1) the shards begin to come apart.
const BREAK_AT := 0.5

var _platform: ShipPlatform
var _dressing: RoomDressing
## The shards' nodes and the pose each comes to rest at, in the falling deck's frame;
## the rim's node, the loose planks', and the torn ends' on the walls.
var _shards: Array[Node3D] = []
## Per shard, the node its splinters hang from: shown once it breaks away.
var _splintered: Array[Node3D] = []
var _rests: Array[Transform3D] = []
var _rim: Node3D
var _debris: Node3D
var _torn: Node3D
## Per shard, the middle of its outline and the breaks along it.
var _middles := PackedVector2Array()
var _breaks: Array[Array] = []
## Under the deck: whether it roofs a room (a ceiling on beams), and how deep it is.
var _ceiled: bool
var _depth: float


func _init(space: ShipSpace, platform: ShipPlatform, dressing: RoomDressing) -> void:
	_platform = platform
	_dressing = dressing
	_ceiled = space.stands_over_a_platform(platform)
	_depth = ShipArt.PLANK + (ShipArt.BEAM_DEPTH if _ceiled else 0.0)


## The deck drawn in pieces: its shards and rim under [param wreck] — the rim carrying,
## while the deck stands, what of its beams the after shard does not — and what it
## leaves when it falls — splinters, loose planks, the torn ends on [param walls] —
## hidden till then; each piece's faces into a mesh of its own, made by [param new_mesh]
## (() -> ShipMesh) and filed in [param pieces] under its node. All of it is built up
## front: meshes added to the scene as the deck falls stall the renderer for good.
func build(wreck: Node3D, walls: Node3D, pieces: Dictionary, new_mesh: Callable) -> void:
	var area := _platform.area
	var inner := area.grow_individual(-RIM, -RIM - GAP, -RIM, -RIM - GAP)
	var height := _platform.height
	var top := ShipMesh.TOP | ShipMesh.SIDES | ShipMesh.BOTTOM
	_rim = _node(wreck, "Rim", pieces, new_mesh)
	if not inner.has_area():
		# Too small to break up: whole until it falls, gone once it does.
		(pieces[_rim] as ShipMesh).box(area, height - ShipArt.PLANK, height, ShipPaints.deck, top)
		return
	var across := _break_across(inner)
	var junction := across.size() / 2
	var along := _break_along(inner, across[junction])
	var after := PackedVector2Array([inner.position])
	after.append_array(across)
	after.append(Vector2(inner.position.x, inner.end.y))
	var port := PackedVector2Array([across[0], Vector2(inner.end.x, inner.position.y)])
	var starboard := PackedVector2Array(along)
	starboard.append(inner.end)
	for index in range(across.size() - 1, junction, -1):
		starboard.append(across[index])
	var reversed := along.duplicate()
	reversed.reverse()
	port.append_array(reversed)
	for index in range(junction - 1, 0, -1):
		port.append(across[index])
	var reach := -INF
	for point: Vector2 in across:
		reach = maxf(reach, point.x)
	var outlines: Array[PackedVector2Array] = [after, port, starboard]
	for index in outlines.size():
		var node := _node(wreck, "Shard%d" % index, pieces, new_mesh)
		_shards.append(node)
		_rests.append(_rest(index, outlines[index], reach + SLIDE.x))
		var breaks := [across] if index == 0 else [across, along]
		_shard(pieces[node], outlines[index], breaks, index == 0)
		_breaks.append(breaks)
	for strip: Rect2 in _frame(area, inner):
		(pieces[_rim] as ShipMesh).box(strip, height - ShipArt.PLANK, height, ShipPaints.deck, top)
	if _ceiled:
		_whole_beams(pieces[_rim], after)
	# Clear of the walls wherever a shard comes to rest.
	var within := inner.grow_individual(-0.01, -GAP, -0.06, -GAP)
	for index in _shards.size():
		var splinters := _node(_shards[index], "Splinters", pieces, new_mesh)
		_splintered.append(splinters)
		_splinters(pieces[splinters], outlines[index], _breaks[index], within)
	_debris = _node(wreck, "Debris", pieces, new_mesh)
	_loose(pieces[_debris])
	_torn = _node(walls, "Torn", pieces, new_mesh)
	_torn_ends(pieces[_torn], area.grow(-RIM))
	show(0.0)


## Poses the pieces [param fallen] (0…1) of the way down (ShipArt.show_sinking): the rim
## until the deck starts to go, the shards coming apart from BREAK_AT and their
## splinters showing then, the loose planks once down, the torn ends once it has gone.
func show(fallen: float) -> void:
	if _rim == null:
		return
	var apart := smoothstep(BREAK_AT, 1.0, fallen)
	for index in _shards.size():
		_shards[index].transform = Transform3D.IDENTITY.interpolate_with(_rests[index], apart)
	_rim.visible = fallen <= 0.0
	if _torn == null:
		return
	_debris.visible = fallen >= 1.0
	for splinters: Node3D in _splintered:
		splinters.visible = fallen > BREAK_AT
	_torn.visible = fallen > 0.0


## A node named [param piece_name] under [param parent] with a mesh of its own, filed
## in [param pieces].
func _node(parent: Node3D, piece_name: String, pieces: Dictionary, new_mesh: Callable) -> Node3D:
	var node := Node3D.new()
	node.name = piece_name
	parent.add_child(node)
	pieces[node] = new_mesh.call()
	return node


## The break across the ship, from [param inner]'s port edge to its starboard through
## its middle: jagged, a point every TOOTH.
func _break_across(inner: Rect2) -> PackedVector2Array:
	var line := PackedVector2Array()
	var middle := inner.get_center().x
	var count := maxi(2, ceili(inner.size.y / TOOTH))
	if count % 2 == 1:
		count += 1
	for index in count + 1:
		var jag := 0.0 if index == 0 or index == count else _jag(index) * JAG
		line.append(
			Vector2(middle + jag, lerpf(inner.position.y, inner.end.y, float(index) / count))
		)
	return line


## The break along the ship forward of the one across, from [param from] on it to
## [param inner]'s forward edge: jagged, a point every TOOTH.
func _break_along(inner: Rect2, from: Vector2) -> PackedVector2Array:
	var line := PackedVector2Array()
	var count := maxi(2, ceili((inner.end.x - from.x) / TOOTH))
	for index in count + 1:
		var jag := 0.0 if index == 0 or index == count else _jag(index + 7) * JAG
		line.append(Vector2(lerpf(from.x, inner.end.x, float(index) / count), from.y + jag))
	return line


## A fixed jag (-1…1) for tooth [param index]: alternating, uneven.
static func _jag(index: int) -> float:
	var sign := 1.0 if index % 2 == 0 else -1.0
	return sign * (0.45 + 0.55 * fposmod(sin(index * 12.9898) * 43758.5453, 1.0))


## Where shard [param index] (after, forward port, forward starboard) of
## [param outline] comes to rest in the falling deck's frame, as ShipArt.wrecked lands
## it: the after one in from the after wall on its beams, tipped up to starboard; each
## forward one, its beams torn off, in from the forward wall and out from the other,
## tipped up toward its outer side and its after edge ridden up over the after one,
## whose forward edge stands at [param reach].
func _rest(index: int, outline: PackedVector2Array, reach: float) -> Transform3D:
	var box := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		box = box.expand(point)
	_middles.append(box.get_center())
	var landed := Vector3.DOWN * (ShipArt.WRECK_LIFT - _depth)
	var bottom := _platform.height - _depth
	if index == 0:
		var hinge := Vector3(box.position.x, bottom, box.position.y)
		# Godot turns right-handed: about x, a positive turn takes +z down.
		var tip := Transform3D(Basis(Vector3.RIGHT, -TIPS.x / box.size.y), Vector3.ZERO)
		var slid := landed + Vector3(SLIDE.x, 0.0, 0.0)
		return Transform3D(Basis.IDENTITY, slid) * _about(hinge, tip)
	# Its beams torn off, it lies on its ceiling where the after one lies on its beams.
	var underside := _platform.height - ShipArt.PLANK
	var out := -1.0 if index == 1 else 1.0
	var inner := box.end.y if index == 1 else box.position.y
	var hinge := Vector3(box.get_center().x, underside, inner)
	var raise := TIPS.y if index == 1 else TIPS.z
	var roll := Transform3D(Basis(Vector3.RIGHT, -out * raise / box.size.y), Vector3.ZERO)
	var shift := Vector3(-SLIDE.y, bottom - underside, out * (GAP - 0.01))
	var moved := Transform3D(Basis.IDENTITY, shift) * _about(hinge, roll)
	var forward := Vector3(box.end.x - SLIDE.y, bottom, box.get_center().y)
	var clear := _platform.height + TIPS.x + RIDE_CLEAR - bottom
	var ride := atan(clear / maxf(forward.x - reach, 0.1))
	var tip := Transform3D(Basis(Vector3.BACK, -ride), Vector3.ZERO)
	return Transform3D(Basis.IDENTITY, landed) * _about(forward, tip) * moved


## [param turn] about [param pivot].
static func _about(pivot: Vector3, turn: Transform3D) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) * turn * Transform3D(Basis.IDENTITY, -pivot)


## One shard over [param outline]: planks on top, the ceiling under, its edges planked
## but those on [param breaks] — fresh wood — and, when [param beamed], its share of
## the beams.
func _shard(mesh: ShipMesh, outline: PackedVector2Array, breaks: Array, beamed: bool) -> void:
	var top := _platform.height
	var under := top - ShipArt.PLANK
	var triangles := Geometry2D.triangulate_polygon(outline)
	var flat := PackedFloat32Array([0.0, 0.0, 0.0])
	var ceiling := _overhead(outline[0], under)
	for index in range(0, triangles.size(), 3):
		var corners := PackedVector3Array()
		for corner in 3:
			var point := outline[triangles[index + corner]]
			corners.append(Vector3(point.x, top, point.y))
		mesh.triangle(corners, flat, Vector3.UP, ShipPaints.deck)
		for corner in 3:
			corners[corner].y = under
		if _ceiled:
			mesh.triangle(corners, flat, Vector3.DOWN, ceiling)
	var middle := Vector2.ZERO
	for point: Vector2 in outline:
		middle += point
	middle /= outline.size()
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var normal := Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
		if normal.dot(Vector3(a.x - middle.x, 0.0, a.y - middle.y)) < 0.0:
			normal = -normal
		var paint := ShipPaints.splinter if _on_breaks(a, b, breaks) else ShipPaints.deck
		mesh.quad(
			Vector3(a.x, under, a.y),
			Vector3(b.x, under, b.y),
			Vector3(b.x, top, b.y),
			Vector3(a.x, top, a.y),
			normal,
			paint,
			ShipMesh.RIM_V0 | ShipMesh.RIM_V1
		)
	if not (_ceiled and beamed):
		return
	var x := ceilf((_platform.area.position.x + ShipArt.BEAM_WIDTH) / ShipArt.BEAM_SPACING)
	x *= ShipArt.BEAM_SPACING
	while x < _platform.area.end.x - ShipArt.BEAM_WIDTH:
		var span := _beam_span(outline, x)
		if span.y - span.x > 0.2:
			var beam := Rect2(
				x - ShipArt.BEAM_WIDTH * 0.5, span.x, ShipArt.BEAM_WIDTH, span.y - span.x
			)
			var lining := _dressing.lining(
				Vector3(x, under - 0.2, middle.y), RoomDressing.Part.BEAM
			)
			var paint := ShipPaints.beam if lining == null else lining
			mesh.box(
				beam, under - ShipArt.BEAM_DEPTH, under, paint, ShipMesh.ALL_FACES & ~ShipMesh.TOP
			)
		x += ShipArt.BEAM_SPACING


## The ceiling paint the room under the deck at [param point] lines it with.
func _overhead(point: Vector2, under: float) -> ShipMesh.Paint:
	var at := Vector3(point.x, under - ShipMesh.PROBE, point.y)
	var lining := _dressing.lining(at, RoomDressing.Part.OVERHEAD)
	return ShipPaints.ceiling if lining == null else lining


## Where along z a beam at [param x] first crosses [param outline] and leaves it,
## kept a beam's width in from its edges; zero length where it does not cross it.
static func _beam_span(outline: PackedVector2Array, x: float) -> Vector2:
	var hits := PackedFloat32Array()
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if (a.x - x) * (b.x - x) <= 0.0 and not is_equal_approx(a.x, b.x):
			hits.append(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	if hits.size() < 2:
		return Vector2.ZERO
	hits.sort()
	return Vector2(hits[0] + ShipArt.BEAM_WIDTH, hits[1] - ShipArt.BEAM_WIDTH)


## Whether the edge [param a]…[param b] lies on one of [param breaks].
static func _on_breaks(a: Vector2, b: Vector2, breaks: Array) -> bool:
	for line: PackedVector2Array in breaks:
		var at_a := false
		var at_b := false
		for point: Vector2 in line:
			at_a = at_a or point.is_equal_approx(a)
			at_b = at_b or point.is_equal_approx(b)
		if at_a and at_b:
			return true
	return false


## Splinters standing out of [param outline]'s edges along [param breaks]: thin fresh
## plank ends, uneven, in the planking's depth, none reaching out of [param within].
func _splinters(mesh: ShipMesh, outline: PackedVector2Array, breaks: Array, within: Rect2) -> void:
	var middle := Vector2.ZERO
	for point: Vector2 in outline:
		middle += point
	middle /= outline.size()
	var count := 0
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if not _on_breaks(a, b, breaks):
			continue
		var length := a.distance_to(b)
		var along := (b - a) / length
		var out := along.orthogonal()
		if out.dot(a - middle) < 0.0:
			out = -out
		var at := SPLINTER * 0.5 * absf(_jag(index))
		while at < length:
			count += 1
			var reach := SPLINTER_REACH * (0.3 + 0.7 * absf(_jag(count)))
			var edge := a + along * at
			var root := Vector3(edge.x, _platform.height - ShipArt.PLANK * 0.5, edge.y)
			# Drooping no lower than the planks' underside, nor out past the deck's ends.
			var droop := asin(minf((ShipArt.PLANK - 0.03) * 0.5 / reach, 1.0))
			var splinter := ShipPaints.splinter
			_jut(mesh, root, Vector3(out.x, 0.0, out.y), reach, count, splinter, droop, within)
			at += SPLINTER * (0.6 + 0.8 * absf(_jag(count + 13)))


## A torn plank end from [param root] (the middle of its root) jutting [param reach]
## along [param out], [param width] wide or a splinter's, turned and drooping by up to
## [param droop] by [param count]: under its root, never over it — and none at all
## whose tip would stand out of [param within] (x/z).
static func _jut(
	mesh: ShipMesh,
	root: Vector3,
	out: Vector3,
	reach: float,
	count: int,
	paint: ShipMesh.Paint,
	droop: float,
	within: Rect2,
	width := 0.03
) -> void:
	var yaw := Basis(Vector3.UP, 0.3 * _jag(count + 17))
	var along := yaw * out
	var tilt := Basis(along.cross(Vector3.UP).normalized(), -droop * absf(_jag(count + 23)))
	along = tilt * along
	var tip := root + along * reach
	if not within.has_point(Vector2(tip.x, tip.z)):
		return
	var side := along.cross(Vector3.UP).normalized()
	var up := side.cross(along).normalized()
	var place := Transform3D(Basis(side, up, along), root + along * reach * 0.5)
	mesh.turned_box(
		place, Vector3(width * (0.7 + 0.6 * absf(_jag(count + 2))), 0.03, reach), paint, 0
	)


## The beams a whole deck has wall to wall, as ShipArt beams any deck, but for what
## of them lies under [param after] — the after shard carries that as it falls; the
## rest, the forward shards' share and the after one's ends, is torn off with the rim.
func _whole_beams(mesh: ShipMesh, after: PackedVector2Array) -> void:
	var area := _platform.area
	var under := _platform.height - ShipArt.PLANK
	var x := ceilf((area.position.x + ShipArt.BEAM_WIDTH) / ShipArt.BEAM_SPACING)
	x *= ShipArt.BEAM_SPACING
	while x < area.end.x - ShipArt.BEAM_WIDTH:
		var probe := Vector3(x, under - ShipArt.BEAM_DEPTH - ShipMesh.PROBE, area.get_center().y)
		var lining := _dressing.lining(probe, RoomDressing.Part.BEAM)
		var paint := ShipPaints.beam if lining == null else lining
		var spans: Array[Vector2] = [Vector2(area.position.y, area.end.y)]
		var carried := _beam_span(after, x)
		if carried.y - carried.x > 0.2:
			spans = [Vector2(area.position.y, carried.x), Vector2(carried.y, area.end.y)]
		for span: Vector2 in spans:
			var beam := Rect2(
				x - ShipArt.BEAM_WIDTH * 0.5, span.x, ShipArt.BEAM_WIDTH, span.y - span.x
			)
			var faces := ShipMesh.BOTTOM | ShipMesh.POS_X | ShipMesh.NEG_X
			mesh.box(beam, under - ShipArt.BEAM_DEPTH, under, paint, faces)
		x += ShipArt.BEAM_SPACING


## The rim of [param area] outside [param inner], as four strips.
static func _frame(area: Rect2, inner: Rect2) -> Array[Rect2]:
	var strips: Array[Rect2] = [
		Rect2(area.position.x, area.position.y, area.size.x, inner.position.y - area.position.y),
		Rect2(area.position.x, inner.end.y, area.size.x, area.end.y - inner.end.y),
		Rect2(area.position.x, inner.position.y, inner.position.x - area.position.x, inner.size.y),
		Rect2(inner.end.x, inner.position.y, area.end.x - inner.end.x, inner.size.y),
	]
	return strips


## Loose planks on the shards as they come to rest, and a beam torn from a forward
## one lying across the after one.
func _loose(mesh: ShipMesh) -> void:
	var top := _platform.height
	var turns := PackedFloat32Array([0.5, -0.9, 1.9])
	var offsets: Array[Vector2] = [Vector2(0.25, 0.45), Vector2(0.1, -0.1), Vector2(0.1, 0.15)]
	for index in _rests.size():
		var at := _middles[index] + offsets[index]
		var place := Transform3D(Basis(Vector3.UP, turns[index]), Vector3(at.x, top + 0.02, at.y))
		var size := Vector3(0.14, 0.04, 0.7 + 0.15 * index)
		var paint := ShipPaints.splinter if index == 1 else ShipPaints.teak
		mesh.turned_box(_rests[index] * place, size, paint)
	if not _ceiled or _rests.is_empty():
		return
	var at := _middles[0] + Vector2(-0.15, -0.45)
	var lying := Vector3(at.x, top + ShipArt.BEAM_DEPTH * 0.5, at.y)
	var beam := Transform3D(Basis(Vector3.UP, -0.6), lying)
	var size := Vector3(ShipArt.BEAM_WIDTH, ShipArt.BEAM_DEPTH, 1.1)
	mesh.turned_box(_rests[0] * beam, size, ShipPaints.beam)


## Torn ends round [param edge], the walls' tops the deck tore away from: plank ends
## jutting in over the room, uneven, and the beams' ends broken off at the walls along
## the ship's sides — all under the deck's height, which the rules no longer have.
func _torn_ends(mesh: ShipMesh, edge: Rect2) -> void:
	var under := _platform.height - ShipArt.PLANK
	var count := 0
	for side in 4:
		var along_x := side % 2 == 0
		var length := edge.size.x if along_x else edge.size.y
		var at := 0.06
		while at < length - 0.06:
			count += 1
			var reach := 0.03 + 0.25 * absf(_jag(count + 31))
			var point := Vector2(edge.position.x + at, edge.position.y)
			var inward := Vector2.DOWN
			match side:
				1:
					point = Vector2(edge.end.x, edge.position.y + at)
					inward = Vector2.LEFT
				2:
					point = Vector2(edge.position.x + at, edge.end.y)
					inward = Vector2.UP
				3:
					point = Vector2(edge.position.x, edge.position.y + at)
					inward = Vector2.RIGHT
			var on_top := Vector3(point.x, under + 0.015, point.y)
			var root := on_top - Vector3(inward.x, 0.0, inward.y) * RIM * 0.6
			var paint := ShipPaints.deck if count % 3 != 0 else ShipPaints.splinter
			var into := Vector3(inward.x, 0.0, inward.y)
			var anywhere := _platform.area.grow(RIM)
			_jut(mesh, root, into, reach + RIM * 0.6, count, paint, DROOP, anywhere, 0.12)
			at += 0.28 + 0.3 * absf(_jag(count + 5))
	if not _ceiled:
		return
	var x := ceilf((_platform.area.position.x + ShipArt.BEAM_WIDTH) / ShipArt.BEAM_SPACING)
	x *= ShipArt.BEAM_SPACING
	while x < _platform.area.end.x - ShipArt.BEAM_WIDTH:
		for side: float in [-1.0, 1.0]:
			var wall := edge.position.y if side < 0.0 else edge.end.y
			var reach := 0.12 + 0.12 * absf(_jag(roundi(x * 10.0) + int(side)))
			var stub := Rect2(x - ShipArt.BEAM_WIDTH * 0.5, wall, ShipArt.BEAM_WIDTH, -side * reach)
			mesh.box(stub.abs(), under - ShipArt.BEAM_DEPTH, under, ShipPaints.beam)
		x += ShipArt.BEAM_SPACING
