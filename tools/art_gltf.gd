class_name ArtGltf
extends RefCounted
## `make preview`'s ship (tools/art_preview.gd): her dressed art (ShipArt), dressed at
## rest as the menu's backdrop is (ShipDressing.at_rest), as plain meshes a glTF holds —
## every surface's material swapped for one showing its vertex colours, a surface with
## none painted its material's colour — so Blender can draw her with no game window.
##
## Kept to a stretch along her (span), a mesh wholly on it is kept whole, one wholly off
## it dropped, and one across an end of it cut there, triangle by triangle: the geometry
## the glTF holds lies on the stretch alone, where the game's piece paints (PieceClip)
## only hide what lies off it. All of it is placed into ship space and merged into one
## mesh, which the glTF writer writes in a second where thousands of meshes take minutes.

## The colour of a surface with neither vertex colours nor a colour its material says.
const BARE := Color(0.8, 0.8, 0.8)
## The shader parameters a ShaderMaterial's colour is looked for under, in this order.
const TINTS: Array[StringName] = [&"colour", &"color", &"albedo", &"tint"]


## [param layout] dressed at rest to [param rules], cut away above [param cut] as the
## observer's view is (ShipArt.cut_above): her ShipArt, outside the tree, for the caller
## to free.
static func dressed(layout: ShipLayout, rules: BrawlRules, cut: float = INF) -> ShipArt:
	var dressing := ShipDressing.at_rest(layout, rules)
	dressing.art.cut_above = cut
	dressing.dress_now()
	return dressing.art


## Every visible mesh under [param art], in ship space, as one plain vertex-coloured
## mesh under a node named [param name], kept to [param span] along her: every mesh's
## triangles placed into ship space and merged. Godot's glTF writer weighs each new buffer
## view against every one before it, so thousands of small meshes write in time growing
## with the square of their number (#413: 2,087 of the Titanic's took 19 minutes) where
## one large one takes a second. The meshes are merged last first, as Blender's Workbench
## settles two faces at one depth between objects, so the picture stays the one each mesh
## as its own object drew.
static func flattened(art: Node3D, name: String, span := Vector2(-INF, INF)) -> Node3D:
	var holder := Node3D.new()
	holder.name = name
	var merged := Merged.new()
	_gather(art, merged, Transform3D.IDENTITY, span)
	var mesh := merged.mesh()
	if mesh != null:
		var copy := MeshInstance3D.new()
		copy.name = "%s_merged" % name
		copy.mesh = mesh
		holder.add_child(copy)
	return holder


## [param holder] written to [param path] as a glTF binary.
static func write(holder: Node3D, path: String) -> Error:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(holder, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	return error


## Every mesh under [param node], placed by [param place], added to [param merged].
static func _gather(node: Node, merged: Merged, place: Transform3D, span: Vector2) -> void:
	for child: Node in node.get_children():
		var at := place
		if child is Node3D:
			if not (child as Node3D).visible:
				continue
			at = place * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			_add((child as MeshInstance3D).mesh, at, span, merged)
		_gather(child, merged, at, span)


## [param source], placed by [param place] into ship space and kept to [param span],
## added to [param merged] as one piece; nothing when none of it lies on the stretch.
static func _add(source: Mesh, place: Transform3D, span: Vector2, merged: Merged) -> void:
	var reach := place * source.get_aabb()
	if reach.end.x < span.x or reach.position.x > span.y:
		return
	var cut := reach.position.x < span.x or reach.end.x > span.y
	var turn := place.basis.inverse().transposed()
	var piece: Array[Array] = []
	for surface in source.get_surface_count():
		if source is ArrayMesh:
			var primitive := (source as ArrayMesh).surface_get_primitive_type(surface)
			if primitive != Mesh.PRIMITIVE_TRIANGLES:
				continue
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		var colours: Variant = arrays[Mesh.ARRAY_COLOR]
		if colours == null or (colours as PackedColorArray).is_empty():
			var painted := PackedColorArray()
			painted.resize(points.size())
			painted.fill(_tint(source.surface_get_material(surface)))
			colours = painted
		if normals == null or (normals as PackedVector3Array).size() != points.size():
			var upward := PackedVector3Array()
			upward.resize(points.size())
			upward.fill(Vector3.UP)
			normals = upward
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if cut:
			var kept := _clipped(points, normals, colours, indices, place, span)
			if not kept[0].is_empty():
				piece.append([kept[0], kept[1], kept[2], null])
			continue
		var turned := PackedVector3Array()
		turned.resize(points.size())
		for corner in points.size():
			turned[corner] = (turn * (normals as PackedVector3Array)[corner]).normalized()
		piece.append([place * points, turned, colours, indices])
	if not piece.is_empty():
		merged.pieces.append(piece)


## The triangles of one surface — [param points], [param normals] and [param colours]
## by corner, [param indices] three to a triangle or null for one per three corners —
## placed by [param place] into ship space and cut to [param span] along x: its
## corners, normals and colours, three to a triangle, unindexed.
static func _clipped(
	points: PackedVector3Array,
	normals: PackedVector3Array,
	colours: PackedColorArray,
	indices: Variant,
	place: Transform3D,
	span: Vector2
) -> Array:
	var at := place * points
	var turn := place.basis.inverse().transposed()
	var out_points := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_colours := PackedColorArray()
	var order: PackedInt32Array
	if indices == null or (indices as PackedInt32Array).is_empty():
		order = PackedInt32Array(range(points.size()))
	else:
		order = indices
	for first in range(0, order.size() - 2, 3):
		var corners := [order[first], order[first + 1], order[first + 2]]
		var low := minf(at[corners[0]].x, minf(at[corners[1]].x, at[corners[2]].x))
		var high := maxf(at[corners[0]].x, maxf(at[corners[1]].x, at[corners[2]].x))
		if high < span.x or low > span.y:
			continue
		var polygon := [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
		for corner: int in corners:
			polygon[0].append(at[corner])
			polygon[1].append((turn * normals[corner]).normalized())
			polygon[2].append(colours[corner])
		if low < span.x:
			polygon = _cut(polygon, span.x, 1.0)
		if high > span.y:
			polygon = _cut(polygon, span.y, -1.0)
		var kept: PackedVector3Array = polygon[0]
		# A fan from the first corner: the polygon a cut leaves is convex.
		for corner in range(1, kept.size() - 1):
			for index: int in [0, corner, corner + 1]:
				out_points.append(kept[index])
				out_normals.append(polygon[1][index])
				out_colours.append(polygon[2][index])
	return [out_points, out_normals, out_colours]


## [param polygon] — its corners, normals and colours — cut at x = [param edge],
## keeping the side [param side] says: +1 at and past it, -1 at and before it.
static func _cut(polygon: Array, edge: float, side: float) -> Array:
	var points: PackedVector3Array = polygon[0]
	var normals: PackedVector3Array = polygon[1]
	var colours: PackedColorArray = polygon[2]
	var kept := [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	for index in points.size():
		var next := (index + 1) % points.size()
		var here := (points[index].x - edge) * side
		var there := (points[next].x - edge) * side
		if here >= 0.0:
			kept[0].append(points[index])
			kept[1].append(normals[index])
			kept[2].append(colours[index])
		if (here >= 0.0) != (there >= 0.0):
			var weight := here / (here - there)
			kept[0].append(points[index].lerp(points[next], weight))
			kept[1].append(normals[index].lerp(normals[next], weight).normalized())
			kept[2].append(colours[index].lerp(colours[next], weight))
	return kept


## A colour for a surface with no vertex colours, from its material when it says one.
static func _tint(material: Material) -> Color:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	if material is ShaderMaterial:
		for key: StringName in TINTS:
			var value: Variant = (material as ShaderMaterial).get_shader_parameter(key)
			if value is Color:
				return value
	return BARE


## Meshes in ship space, each a piece of surfaces — corners, normals and colours by
## corner, then indices three to a triangle or null for one per three corners — merged
## into one vertex-coloured mesh.
class Merged:
	extends RefCounted
	## Every piece, in the order the art holds them.
	var pieces: Array[Array] = []

	## Every piece merged last first, its surfaces in their order: null when there are none.
	func mesh() -> ArrayMesh:
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		var colours := PackedColorArray()
		var indices := PackedInt32Array()
		for piece in range(pieces.size() - 1, -1, -1):
			for surface: Array in pieces[piece]:
				var base := points.size()
				var corners: PackedVector3Array = surface[0]
				points.append_array(corners)
				normals.append_array(surface[1])
				colours.append_array(surface[2])
				var order: PackedInt32Array
				if surface[3] == null or (surface[3] as PackedInt32Array).is_empty():
					order = PackedInt32Array(range(base, base + corners.size()))
				else:
					order = surface[3]
					for index in order.size():
						order[index] += base
				indices.append_array(order)
		if points.is_empty():
			return null
		var plain := []
		plain.resize(Mesh.ARRAY_MAX)
		plain[Mesh.ARRAY_VERTEX] = points
		plain[Mesh.ARRAY_NORMAL] = normals
		plain[Mesh.ARRAY_COLOR] = colours
		plain[Mesh.ARRAY_INDEX] = indices
		var merged := ArrayMesh.new()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plain)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		merged.surface_set_material(0, material)
		return merged
