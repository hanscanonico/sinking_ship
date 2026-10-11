class_name UndersideCheck
extends RefCounted
## `make art-lint`'s check that every deck has an underside (ShipArt): under each
## platform below the cut-away, straight over every point of its area, a drawn face
## looking down within the planking's depth (ShipArt.PLANK) and TOLERANCE under the
## deck — whatever lies beneath it, so no deck shows the sky through it from below.

## How far under the planking's underside the face may stand.
const TOLERANCE := 0.02
## The side of the squares of the ship plane the downward faces are filed by.
const CELL := 0.5


## The platforms of [param layout] under [param cut_above] against the triangles of
## [param faces] (ship space), sampled over each one's area by [param samples]
## ((Rect2) -> PackedVector2Array); [param file] names the ship: the problems found.
static func check(
	layout: ShipLayout, cut_above: float, file: String, faces: PackedVector3Array, samples: Callable
) -> PackedStringArray:
	var cells := _downward(faces)
	var problems := PackedStringArray()
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		if platform.height >= cut_above:
			continue
		var points: PackedVector2Array = samples.call(platform.area)
		var low := platform.height - ShipArt.PLANK - TOLERANCE
		var bare := PackedVector2Array()
		for point in points:
			if not _closed(faces, cells, Vector3(point.x, low, point.y), platform.height):
				bare.append(point)
		if not bare.is_empty():
			problems.append(
				(
					"art-lint: %s platform %d: no underside at %d of %d points, first at %s"
					% [file, index, bare.size(), points.size(), bare[0]]
				)
			)
	return problems


## Whether a face of [param cells] lies straight over [param from], at or under
## [param high].
static func _closed(
	faces: PackedVector3Array, cells: Dictionary, from: Vector3, high: float
) -> bool:
	for index: int in cells.get(Vector2i(floori(from.x / CELL), floori(from.z / CELL)), []):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			from, Vector3.UP, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit != null and (hit as Vector3).y <= high:
			return true
	return false


## The triangles of [param faces] that look down, filed by the CELL-sized squares of
## the ship plane their bounds cover: Vector2i -> Array of first-corner indices.
static func _downward(faces: PackedVector3Array) -> Dictionary:
	var cells := {}
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		# Godot's front faces wind clockwise: their normal is the cross reversed.
		if -(b - a).cross(c - a).normalized().y > -0.5:
			continue
		var low := Vector2(minf(minf(a.x, b.x), c.x), minf(minf(a.z, b.z), c.z))
		var high := Vector2(maxf(maxf(a.x, b.x), c.x), maxf(maxf(a.z, b.z), c.z))
		for x in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
			for z in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells[cell] = []
				(cells[cell] as Array).append(index)
	return cells
