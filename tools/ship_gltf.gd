class_name ShipGltf
extends RefCounted
## A ship authored in Blender (#125): authoring/NAME/NAME.blend, exported to glTF, read
## back into the scene of marked pieces ShipSceneBake reads — so a .blend bakes with the
## very baker a .tscn does, into the ShipLayout the sim loads (D6). Blender authors the
## data only; the hull the game draws stays generated from it.
##
## Two ways across. pieces() lays a drawn scene (ShipSceneDraw) out as plain data that
## tools/ship_blend.py builds Blender objects from: `make ship-blend`. read() takes the
## glTF Blender exports, every object's custom properties carried as its node's extras,
## and redraws it as the drawn scene's nodes: `make bake-blend`, `make bake-check`.
##
## In Blender a piece is an object whose custom property `ship` says what it is, its
## other custom properties its fields, as in a scene (ShipSceneBake). A box, a cylinder,
## a wedge or a section is a mesh, read from its own vertices in its object's frame; a
## point is an empty. A number and a space before an object's name order it among its
## siblings — the glTF lists them by name — and are not part of the name.
## authoring/README.md says how a ship is authored there.

## Decimals of a metre two vertices are told apart to.
const GRAIN := 1e-4
## The scene the glTF draws, rooted at the piece tagged layout; null when none is.
var root: Node3D
## Every reason the glTF could not be redrawn as a scene; empty when it could.
var problems := PackedStringArray()


## [param root] — a scene ShipSceneDraw drew — as a list of its nodes, each a
## Dictionary of plain values JSON holds: name, parent (an index into the list, -1 for
## the root), shape (empty, marker, box, cylinder, wedge or section), basis (its x, y
## and z columns) and origin, the numbers its shape takes, visible, colour and meta.
static func pieces(scene_root: Node3D) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_lay_out(scene_root, -1, true, found)
	return found


## The glTF at [param path], read and redrawn as a scene.
static func read(path: String) -> ShipGltf:
	var gltf := ShipGltf.new()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var status := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if status != OK:
		gltf.problems.append("%s: not a glTF: %s" % [path, error_string(status)])
		return gltf
	var scene := document.generate_scene(state)
	var top := _layout_of(scene)
	if top == null:
		gltf.problems.append("%s: no object has the custom property ship = layout" % path)
	else:
		gltf.root = gltf._redrawn(top) as Node3D
	scene.free()
	return gltf


static func _lay_out(node: Node, parent: int, shown: bool, found: Array[Dictionary]) -> void:
	var visible := shown and (not node is Node3D or (node as Node3D).visible)
	var piece := {
		"name": String(node.name),
		"parent": parent,
		"shape": "empty",
		"visible": visible,
		"meta": {},
	}
	if node is Node3D:
		var place := (node as Node3D).transform
		piece["basis"] = _numbers([place.basis.x, place.basis.y, place.basis.z])
		piece["origin"] = _numbers([place.origin])
	for key: StringName in node.get_meta_list():
		piece["meta"][String(key)] = _plain(node.get_meta(key))
	if node is Marker3D:
		piece["shape"] = "marker"
	elif node is CSGBox3D:
		piece["shape"] = "box"
		piece["size"] = _numbers([(node as CSGBox3D).size])
	elif node is CSGCylinder3D:
		piece["shape"] = "cylinder"
		piece["radius"] = (node as CSGCylinder3D).radius
		piece["height"] = (node as CSGCylinder3D).height
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh is PrismMesh:
		var wedge := (node as MeshInstance3D).mesh as PrismMesh
		piece["shape"] = "wedge"
		piece["size"] = _numbers([wedge.size])
		piece["apex"] = wedge.left_to_right
	elif node is CSGPolygon3D:
		var loft := node as CSGPolygon3D
		piece["shape"] = "section"
		piece["depth"] = loft.depth
		var outline: Array[float] = []
		for corner: Vector2 in loft.polygon:
			outline.append_array([corner.x, corner.y])
		piece["outline"] = outline
	if node is GeometryInstance3D:
		var material := _material_of(node as GeometryInstance3D)
		if material != null:
			var colour := material.albedo_color
			piece["colour"] = [colour.r, colour.g, colour.b, colour.a]
	found.append(piece)
	var index := found.size() - 1
	for child: Node in node.get_children():
		_lay_out(child, index, visible, found)


static func _material_of(node: GeometryInstance3D) -> StandardMaterial3D:
	if node is CSGPrimitive3D:
		return (node as CSGPrimitive3D).get(&"material") as StandardMaterial3D
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is PrimitiveMesh:
		return ((node as MeshInstance3D).mesh as PrimitiveMesh).material as StandardMaterial3D
	return null


static func _numbers(vectors: Array[Vector3]) -> Array[float]:
	var found: Array[float] = []
	for vector: Vector3 in vectors:
		found.append_array([vector.x, vector.y, vector.z])
	return found


## [param value], a piece's metadata, as JSON holds it: names as text, a vector or a
## list of vectors as its numbers in a row.
static func _plain(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Vector2:
		return [(value as Vector2).x, (value as Vector2).y]
	if value is Vector3:
		return _numbers([value as Vector3])
	if value is PackedVector3Array:
		var points: Array[Vector3] = []
		points.assign(Array(value))
		return _numbers(points)
	if value is PackedVector2Array:
		var flat := []
		for point: Vector2 in value as PackedVector2Array:
			flat.append_array([point.x, point.y])
		return flat
	if value is Array:
		var plain := []
		for item: Variant in value:
			plain.append(_plain(item))
		return plain
	return value


static func _layout_of(node: Node) -> Node3D:
	if node is Node3D and _extras(node).get(ShipSceneBake.TAG, "") == "layout":
		return node as Node3D
	for child: Node in node.get_children():
		var found := _layout_of(child)
		if found != null:
			return found
	return null


static func _extras(node: Node) -> Dictionary:
	var extras: Variant = node.get_meta(&"extras", {})
	return extras if extras is Dictionary else {}


## The glTF's [param node] and everything under it, redrawn as a scene's nodes.
func _redrawn(node: Node) -> Node:
	var extras := _extras(node)
	var kind := StringName(str(extras.get(ShipSceneBake.TAG, "")))
	var drawn := _drawn(node, kind)
	drawn.name = _name_of(node)
	for key: String in extras:
		drawn.set_meta(StringName(key), _typed(kind, key, extras[key]))
	for child: Node in node.get_children():
		drawn.add_child(_redrawn(child))
	return drawn


## [param node]'s name without the number that orders it.
static func _name_of(node: Node) -> String:
	var name := String(node.name)
	var ordered := RegEx.create_from_string("^\\d+ +")
	return ordered.sub(name, "")


## [param value], the extras key [param key] of a [param kind], as the field it sets
## takes it: JSON's numbers as the field's int, its lists of numbers as the field's
## vector or list of vectors.
static func _typed(kind: StringName, key: String, value: Variant) -> Variant:
	if key == String(ShipSceneBake.TAG) or key == "platform" and kind in [&"railing", &"ladder"]:
		return StringName(str(value))
	var blank := _blank(kind)
	if blank == null:
		return value
	for property: Dictionary in ShipSceneBake.stored(blank):
		if property["name"] != key:
			continue
		match property["type"]:
			TYPE_INT when value is float and is_equal_approx(value, roundf(value)):
				return int(value)
			TYPE_STRING_NAME when value is String:
				return StringName(value)
			TYPE_VECTOR2 when value is Array and (value as Array).size() == 2:
				return Vector2(value[0], value[1])
			TYPE_VECTOR3 when value is Array and (value as Array).size() == 3:
				return Vector3(value[0], value[1], value[2])
			TYPE_PACKED_VECTOR2_ARRAY when value is Array and (value as Array).size() % 2 == 0:
				var points := PackedVector2Array()
				for at in range(0, (value as Array).size(), 2):
					points.append(Vector2(value[at], value[at + 1]))
				return points
			TYPE_PACKED_VECTOR3_ARRAY when value is Array and (value as Array).size() % 3 == 0:
				var points := PackedVector3Array()
				for at in range(0, (value as Array).size(), 3):
					points.append(Vector3(value[at], value[at + 1], value[at + 2]))
				return points
	return value


## A blank of the resource a [param kind]'s fields are read into; null for a kind with
## no fields.
static func _blank(kind: StringName) -> Resource:
	match kind:
		&"layout":
			return ShipLayout.new()
		&"platform":
			return ShipPlatform.new()
		&"ramp":
			return ShipRamp.new()
		&"blocker":
			return ShipBlocker.new()
		&"railing":
			return ShipRailing.new()
		&"ladder":
			return ShipLadder.new()
		&"prop":
			return ShipProp.new()
		&"room":
			return ShipRoom.new()
		&"bonus_spot":
			return ShipBonusSpot.new()
		&"structure":
			return ShipStructure.new()
		&"section":
			return HullSection.new()
		&"cell":
			return FloodCell.new()
		&"wall":
			return ShipWall.new()
		&"opening":
			return ShipOpening.new()
		&"mass":
			return MassItem.new()
		&"fitting":
			return ShipFitting.new()
		&"strength":
			return GirderStrength.new()
		&"weak_spot":
			return WeakSpot.new()
		&"sure_hit":
			return IcebergHit.new()
	return null


## The scene node [param node] stands for: a shape for a mesh, a marker or a folder for
## an empty.
func _drawn(node: Node, kind: StringName) -> Node3D:
	var surfaces := _surfaces(node)
	var place := (node as Node3D).transform if node is Node3D else Transform3D.IDENTITY
	if surfaces.is_empty():
		var point := Marker3D.new() if not kind.is_empty() else Node3D.new()
		point.transform = place
		return point
	var turn := place.basis.orthonormalized()
	var scale := place.basis.get_scale()
	var corners := PackedVector3Array()
	var triangles := PackedInt32Array()
	for arrays in surfaces:
		var base := corners.size()
		for corner: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			corners.append(corner * scale)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array:
			for index: int in indices as PackedInt32Array:
				triangles.append(base + index)
	var bounds := AABB(corners[0], Vector3.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	var drawn: Node3D
	if kind == &"ramp":
		drawn = _wedge(node, corners, bounds)
	elif kind == &"section":
		drawn = _section(node, corners, triangles, bounds)
		bounds = AABB(Vector3(0, 0, bounds.end.z), Vector3.ZERO)
	elif _is_box(corners, bounds):
		drawn = CSGBox3D.new()
		(drawn as CSGBox3D).size = bounds.size
	else:
		drawn = CSGCylinder3D.new()
		(drawn as CSGCylinder3D).radius = bounds.size.x * 0.5
		(drawn as CSGCylinder3D).height = bounds.size.y
		if not is_equal_approx(bounds.size.x, bounds.size.z):
			problems.append("%s: is neither a box nor an upright cylinder" % _name_of(node))
	drawn.transform = Transform3D(turn, place.origin + turn * bounds.get_center())
	return drawn


## The surface arrays of [param node]'s mesh, as the glTF import left it; empty for an
## empty.
static func _surfaces(node: Node) -> Array[Array]:
	var found: Array[Array] = []
	if node is ImporterMeshInstance3D and (node as ImporterMeshInstance3D).mesh != null:
		var mesh := (node as ImporterMeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			found.append(mesh.get_surface_arrays(surface))
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			found.append(mesh.surface_get_arrays(surface))
	return found


## Whether every one of [param corners] stands at a corner of [param bounds].
static func _is_box(corners: PackedVector3Array, bounds: AABB) -> bool:
	for corner in corners:
		for axis in 3:
			var low := absf(corner[axis] - bounds.position[axis]) < GRAIN
			if not low and absf(corner[axis] - bounds.end[axis]) >= GRAIN:
				return false
	return true


## A wedge from its corners: its apex is the top edge, at one end of its local x.
func _wedge(node: Node, corners: PackedVector3Array, bounds: AABB) -> MeshInstance3D:
	var apex := -1.0
	for corner in corners:
		if absf(corner.y - bounds.end.y) >= GRAIN:
			continue
		var at := 0.5
		if absf(corner.x - bounds.position.x) < GRAIN:
			at = 0.0
		elif absf(corner.x - bounds.end.x) < GRAIN:
			at = 1.0
		apex = at if apex < 0.0 or apex == at else 0.5
	if apex != 0.0 and apex != 1.0:
		problems.append("%s: a wedge's top edge must be at one end of its x" % _name_of(node))
	var prism := PrismMesh.new()
	prism.size = bounds.size
	prism.left_to_right = apex
	var wedge := MeshInstance3D.new()
	wedge.mesh = prism
	return wedge


## A hull section from its corners: its outline is the face at its local +z end, read
## round from its lowest corner nearest the centreline as Blender winds the face —
## against the winding Godot's import turns its triangles to — extruded toward local -z.
func _section(
	node: Node, corners: PackedVector3Array, triangles: PackedInt32Array, bounds: AABB
) -> CSGPolygon3D:
	var loft := CSGPolygon3D.new()
	loft.mode = CSGPolygon3D.MODE_DEPTH
	loft.depth = bounds.size.z
	var keys := {}
	var points: Array[Vector2] = []
	var ids := PackedInt32Array()
	for corner in corners:
		var flat := Vector2(snappedf(corner.x, GRAIN), snappedf(corner.y, GRAIN))
		if not keys.has(flat):
			keys[flat] = points.size()
			points.append(Vector2(corner.x, corner.y))
		ids.append(keys[flat])
	var next := {}
	var edges := {}
	for start in range(0, triangles.size() - 2, 3):
		var face := [triangles[start], triangles[start + 1], triangles[start + 2]]
		if face.any(func(i: int) -> bool: return absf(corners[i].z - bounds.end.z) >= GRAIN):
			continue
		for side in 3:
			var edge := Vector2i(ids[face[side]], ids[face[(side + 1) % 3]])
			edges[edge] = true
	for edge: Vector2i in edges:
		if not edges.has(Vector2i(edge.y, edge.x)):
			next[edge.y] = edge.x
	if next.is_empty():
		problems.append("%s: a section needs a face at its local +z end" % _name_of(node))
		return loft
	var first: int = next.keys()[0]
	for id: int in next:
		var here := points[id]
		var best := points[first]
		if (
			absf(here.x) < absf(best.x) - GRAIN
			or (absf(here.x) < absf(best.x) + GRAIN and here.y < best.y)
		):
			first = id
	var outline := PackedVector2Array()
	var at := first
	while outline.size() <= next.size():
		outline.append(points[at])
		at = next.get(at, first)
		if at == first:
			break
	if outline.size() != next.size():
		problems.append("%s: a section's end face must be one outline" % _name_of(node))
	loft.polygon = outline
	return loft
