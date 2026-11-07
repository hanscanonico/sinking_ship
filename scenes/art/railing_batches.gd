class_name RailingBatches
extends RefCounted
## The breakable railings of one dressed ship drawn together (ShipArt.pack): every span on
## a deck that stays put drawn into a few shared meshes rather than under a node of its
## own, as every node of hers moves as she does. Indoors, a span's faces in a chunk ride
## in the chunk's own instance where they lie inside the box of what it draws already
## (PackedChunks), so the chunk meets the lamps it met before; past that box, they keep an
## instance of their own, as before. Outdoors, where no lamp lights a face
## (ShipMesh.OUTDOOR_LAYER), every span's faces share a few instances along her. A span
## broken draws nothing: each of its triangles' indices is made to name one corner, and
## given back as it mends — no instance added, rebuilt or moved (show). A surface of
## railings holds at most MOST_CORNERS corners, so its indices are 16-bit (INDEX_BYTES).

## The most corners one surface of railings holds: under 2^16, so its indices are 16-bit.
const MOST_CORNERS := 60000
## The bytes of one index.
const INDEX_BYTES := 2
## The name of a surface of railings.
const SURFACE := &"railings"

## Per chunk's group ("out", or "in x y z": ShipMesh.commit), the faces of the spans in it
## not yet drawn: each a Part.
var _waiting := {}
## Per span taken (add), by its index: each run of its triangles' indices drawn (Run), and
## whether it is drawn now.
var _runs := {}
var _drawn := {}
## Per instance drawing spans, by its instance id: per surface, each run of a span's
## triangles in it, [first triangle, triangles, span] (spans_of).
var _spans := {}


## One span's faces in one batch: their arrays, format and material, and their box.
class Part:
	var span: int
	var arrays: Array
	var format: int
	var material: Material
	var box: AABB


## Where one span's triangles lie in a surface: its mesh and surface, where in its
## indices they begin, and their indices as drawn.
class Run:
	var mesh: RID
	var surface: int
	var first: int
	var indices: PackedInt32Array


## Takes span [param span]'s faces from [param mesh], its own, painted from
## [param materials] by finish: drawn once its chunks are (PackedChunks.commit).
func add(span: int, mesh: ShipMesh, materials: Dictionary) -> void:
	_drawn[span] = true
	_runs[span] = []
	for batch: Array in mesh.taken():
		var key: String = batch[0]
		var part := Part.new()
		part.span = span
		part.arrays = batch[2]
		part.format = batch[3]
		part.material = materials[batch[1]]
		part.box = PackedChunks.box_of(part.arrays[Mesh.ARRAY_VERTEX])
		var group := key.substr(key.find(" ") + 1)
		if not _waiting.has(group):
			_waiting[group] = []
		(_waiting[group] as Array).append(part)


## Whether it draws span [param span].
func holds(span: int) -> bool:
	return _drawn.has(span)


## Whether span [param span] is drawn now: held, and not hidden (show).
func drawn(span: int) -> bool:
	return _drawn.get(span, false)


## Draws into [param instance], chunk [param group]'s (PackedChunks.commit), the spans'
## faces in that chunk that lie inside its [param box]: a surface a paint.
func into_chunk(group: String, instance: MeshInstance3D, box: AABB) -> void:
	var inside: Array = []
	var past: Array = []
	for part: Part in _waiting.get(group, []):
		(inside if box.encloses(part.box) else past).append(part)
	if past.is_empty():
		_waiting.erase(group)
	else:
		_waiting[group] = past
	_draw(instance, inside)


## Draws the spans' faces no chunk took (into_chunk) under [param parent]: outdoors, all
## of them together in a few instances along her from aft; indoors, a span's faces in a
## chunk an instance of their own, as ShipMesh.commit draws one. Returns the instances.
func commit(parent: Node3D) -> Array[MeshInstance3D]:
	var hung: Array[MeshInstance3D] = []
	var outdoors: Array = _waiting.get("out", [])
	_waiting.erase("out")
	outdoors.sort_custom(_aft_first)
	var held: Array = []
	var corners := {}
	for part: Part in outdoors:
		var count := _corners(part)
		if not held.is_empty() and corners.get(part.material, 0) + count > MOST_CORNERS:
			hung.append(_hang(parent, "Railings%d" % _spans.size(), held, true))
			held = []
			corners.clear()
		held.append(part)
		corners[part.material] = corners.get(part.material, 0) + count
	if not held.is_empty():
		hung.append(_hang(parent, "Railings%d" % _spans.size(), held, true))
	for group: String in _waiting:
		for part: Part in _waiting[group]:
			var name := "Railing%d_%s" % [part.span, group.replace(" ", "_")]
			hung.append(_hang(parent, name, [part], false))
	_waiting.clear()
	return hung


## Shows span [param span] or hides it: its triangles drawn as they are, or each of its
## indices made to name the first corner of its run, so it draws nothing.
func show(span: int, shown: bool) -> void:
	if not _drawn.has(span) or _drawn[span] == shown:
		return
	_drawn[span] = shown
	for run: Run in _runs[span]:
		RenderingServer.mesh_surface_update_index_region(
			run.mesh, run.surface, run.first * INDEX_BYTES, index_bytes(run.indices, shown)
		)


## [param indices] as a surface's 16-bit index bytes: as they are when [param shown],
## else each the first of them, so their triangles draw nothing.
static func index_bytes(indices: PackedInt32Array, shown: bool) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(indices.size() * INDEX_BYTES)
	for index in indices.size():
		bytes.encode_u16(index * INDEX_BYTES, indices[index if shown else 0])
	return bytes


## Per triangle of [param instance]'s mesh, in the order Mesh.get_faces() reads them, the
## span it draws, -1 for a triangle of no span; empty for an instance drawing none.
func spans_of(instance: MeshInstance3D) -> PackedInt32Array:
	var surfaces: Dictionary = _spans.get(instance.get_instance_id(), {})
	if surfaces.is_empty():
		return PackedInt32Array()
	var found := PackedInt32Array()
	var mesh := instance.mesh
	for surface in mesh.get_surface_count():
		var own := PackedInt32Array()
		own.resize(mesh.surface_get_array_index_len(surface) / 3)
		own.fill(-1)
		for run: PackedInt32Array in surfaces.get(surface, []):
			for triangle in range(run[0], run[0] + run[1]):
				own[triangle] = run[2]
		found.append_array(own)
	return found


## [param parts] in a new instance named [param name] under [param parent]: on the
## outdoor layer when [param outdoors], else casting no shadow, as ShipMesh.commit draws
## an instance; and returns it.
func _hang(parent: Node3D, name: String, parts: Array, outdoors: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = ArrayMesh.new()
	if outdoors:
		instance.layers = 1 << (ShipMesh.OUTDOOR_LAYER - 1)
	else:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_draw(instance, parts)
	parent.add_child(instance)
	return instance


## [param parts] drawn into [param instance]'s mesh: a surface per material and format,
## in the order they come, each part's faces whole in one under MOST_CORNERS corners;
## where each part's triangles lie kept (Run, _spans).
func _draw(instance: MeshInstance3D, parts: Array) -> void:
	if parts.is_empty():
		return
	var mesh := instance.mesh as ArrayMesh
	var lots: Array = []
	var lot_of := {}
	for part: Part in parts:
		var kind := "%d %d" % [part.material.get_instance_id(), part.format]
		var at: int = lot_of.get(kind, -1)
		if at == -1 or (lots[at][1] as int) + _corners(part) > MOST_CORNERS:
			at = lots.size()
			lots.append([[], 0])
			lot_of[kind] = at
		(lots[at][0] as Array).append(part)
		lots[at][1] += _corners(part)
	var surfaces: Dictionary = _spans.get(instance.get_instance_id(), {})
	for lot: Array in lots:
		var kept: Array = lot[0]
		var first: Part = kept[0]
		var arrays := _joined(kept)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, first.format)
		var surface := mesh.get_surface_count() - 1
		mesh.surface_set_material(surface, first.material)
		mesh.surface_set_name(surface, String(SURFACE))
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var runs: Array[PackedInt32Array] = []
		var at := 0
		for part: Part in kept:
			var length: int = (part.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
			var run := Run.new()
			run.mesh = mesh.get_rid()
			run.surface = surface
			run.first = at
			run.indices = indices.slice(at, at + length)
			(_runs[part.span] as Array).append(run)
			runs.append(PackedInt32Array([at / 3, length / 3, part.span]))
			at += length
		surfaces[surface] = runs
	_spans[instance.get_instance_id()] = surfaces


## How many corners [param part]'s faces have.
static func _corners(part: Part) -> int:
	return (part.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


## Whether [param a] stands aft of [param b] along her, by its box's middle; the lower
## span first at one.
static func _aft_first(a: Part, b: Part) -> bool:
	var x := a.box.get_center().x
	var other := b.box.get_center().x
	return x < other or (x == other and a.span < b.span)


## [param parts]' arrays as one surface's, each part's indices moved past the corners
## of those before it.
static func _joined(parts: Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var slots: Array[int] = [
		Mesh.ARRAY_VERTEX,
		Mesh.ARRAY_NORMAL,
		Mesh.ARRAY_COLOR,
		Mesh.ARRAY_TEX_UV,
		Mesh.ARRAY_TEX_UV2,
		Mesh.ARRAY_CUSTOM0,
		Mesh.ARRAY_CUSTOM1,
	]
	var indices := PackedInt32Array()
	var base := 0
	for part: Part in parts:
		for slot in slots:
			var values: Variant = part.arrays[slot]
			if values == null:
				continue
			if arrays[slot] == null:
				arrays[slot] = values.duplicate()
			else:
				arrays[slot].append_array(values)
		var from := indices.size()
		indices.append_array(part.arrays[Mesh.ARRAY_INDEX])
		if base > 0:
			for index in range(from, indices.size()):
				indices[index] += base
		base += _corners(part)
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
