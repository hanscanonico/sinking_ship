class_name PackedChunks
extends RefCounted
## The indoor chunks of one dressed ship (ShipArt.pack), gathered from every ShipMesh that
## draws her still art — her decks, walls and fittings, and her rooms' furnishings — and
## drawn as one MeshInstance3D a chunk (ShipMesh.CHUNK), a surface for each mesh's finish:
## a chunk's furnishings ride with its walls, so a moving ship moves half the instances,
## and each chunk is lit, culled and drawn as before. A surface keeps the name its mesh
## gave it (ShipMesh.packed_as), for what reads one mesh's faces back (FurnishingCheck).

## Per chunk, by its group name (ShipMesh.commit), its surfaces in the order they came:
## each [arrays, format, material, name].
var _chunks := {}
var _order: Array[String] = []


## Files a surface of [param group]'s chunk: [param arrays] in [param format]
## (Mesh.ARRAY_FORMAT_*), drawn in [param material], named [param surface_name].
func add(
	group: String, arrays: Array, format: int, material: Material, surface_name: StringName
) -> void:
	if not _chunks.has(group):
		_chunks[group] = []
		_order.append(group)
	(_chunks[group] as Array).append([arrays, format, material, surface_name])


## Every chunk filed as an instance under [param parent], as ShipMesh draws an indoor one:
## no shadow cast, named for its group.
func commit(parent: Node3D) -> void:
	for group: String in _order:
		var mesh := ArrayMesh.new()
		for surface: Array in _chunks[group]:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface[0], [], {}, surface[1])
			var index := mesh.get_surface_count() - 1
			mesh.surface_set_material(index, surface[2])
			mesh.surface_set_name(index, String(surface[3]))
		var instance := MeshInstance3D.new()
		instance.name = group.replace(" ", "_")
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_chunks.clear()
	_order.clear()
