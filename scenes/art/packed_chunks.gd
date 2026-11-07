class_name PackedChunks
extends RefCounted
## The indoor chunks of one dressed ship (ShipArt.pack), gathered from every ShipMesh that
## draws her still art — her decks, walls and fittings, and her rooms' furnishings — and
## drawn as one MeshInstance3D a chunk (ShipMesh.CHUNK), a surface for each mesh's finish:
## a chunk's furnishings ride with its walls, so a moving ship moves half the instances,
## and each chunk is lit, culled and drawn as before. A surface keeps the name its mesh
## gave it (ShipMesh.packed_as), for what reads one mesh's faces back (FurnishingCheck).
## Her own glass, unshaded, and her railings (RailingBatches) ride in a chunk's instance
## too, but only where they lie inside the box of what it draws already: so the chunk
## meets the very lamps it met before — a lamp lights the meshes its range reaches, and
## Compatibility lights a mesh with so many at most, which a crowded chunk already meets —
## and what lies past that box keeps an instance of its own.

## The name of a surface of her glass in a chunk's instance.
const GLASS := &"glass"

## Per chunk, by its group name (ShipMesh.commit), its surfaces in the order they came:
## each [arrays, format, material, name].
var _chunks := {}
var _order: Array[String] = []
## Per chunk, by its group name, her glass in it: each [key, arrays, material, parent,
## box] — its batch's key (ShipMesh.commit), and the node its own instance hangs under
## where it lies past the chunk's box.
var _glass := {}


## Files a surface of [param group]'s chunk: [param arrays] in [param format]
## (Mesh.ARRAY_FORMAT_*), drawn in [param material], named [param surface_name].
func add(
	group: String, arrays: Array, format: int, material: Material, surface_name: StringName
) -> void:
	if not _chunks.has(group):
		_chunks[group] = []
		_order.append(group)
	(_chunks[group] as Array).append([arrays, format, material, surface_name])


## Files her glass in [param group]'s chunk, the batch [param key] (ShipMesh.commit) of
## [param arrays] drawn in [param material]: a surface of the chunk's instance where it
## lies inside the chunk's box, else an instance of its own under [param parent], as
## ShipMesh.commit draws glass.
func add_glass(
	group: String, key: String, arrays: Array, material: Material, parent: Node3D
) -> void:
	if not _glass.has(group):
		_glass[group] = []
	var box := box_of(arrays[Mesh.ARRAY_VERTEX])
	(_glass[group] as Array).append([key, arrays, material, parent, box])


## Every chunk filed as an instance under [param parent], as ShipMesh draws an indoor one:
## no shadow cast, named for its group, with the glass and the [param railings] lying
## inside its box; then each batch of glass lying past its chunk's box an instance of its
## own, and the rest of [param railings] (RailingBatches.commit). Returns the chunks'
## instances and the railings' hung under [param parent], none of which moves under her.
func commit(parent: Node3D, railings: RailingBatches = null) -> Array[MeshInstance3D]:
	var hung: Array[MeshInstance3D] = []
	var apart: Array = []
	for group: String in _order:
		var mesh := ArrayMesh.new()
		for surface: Array in _chunks[group]:
			_add_surface(mesh, surface[0], surface[1], surface[2], surface[3])
		var box := mesh.get_aabb()
		for glass: Array in _glass.get(group, []):
			if box.encloses(glass[4]):
				_add_surface(mesh, glass[1], 0, glass[2], GLASS)
			else:
				apart.append(glass)
		_glass.erase(group)
		var instance := MeshInstance3D.new()
		instance.name = group.replace(" ", "_")
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if railings != null:
			railings.into_chunk(group, instance, box)
		parent.add_child(instance)
		hung.append(instance)
	for group: String in _glass:
		apart.append_array(_glass[group])
	for glass: Array in apart:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, glass[1])
		mesh.surface_set_material(0, glass[2])
		var instance := MeshInstance3D.new()
		instance.name = (glass[0] as String).replace(" ", "_")
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(glass[3] as Node3D).add_child(instance)
	if railings != null:
		hung.append_array(railings.commit(parent))
	_chunks.clear()
	_order.clear()
	_glass.clear()
	return hung


## The box holding every point of [param points]; an empty one at the origin for none.
static func box_of(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


static func _add_surface(
	mesh: ArrayMesh, arrays: Array, format: int, material: Material, surface_name: StringName
) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	var index := mesh.get_surface_count() - 1
	mesh.surface_set_material(index, material)
	mesh.surface_set_name(index, String(surface_name))
