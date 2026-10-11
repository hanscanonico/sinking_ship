class_name UndersideCheck
extends RefCounted
## `make art-lint`'s check that every deck has an underside (ShipArt): under each
## platform below the cut-away, straight over every point of its area, a drawn face
## looking down within the planking's depth (ShipArt.PLANK) and a tolerance under the
## deck — whatever lies beneath it, so no deck shows the sky through it from below.


## The platforms of [param layout] under [param cut_above] against the triangles of
## [param faces] (ship space, filed in [param cells] by FaceCells), sampled over each
## one's area by [param samples] ((Rect2) -> PackedVector2Array), the face allowed
## [param tolerance] under the planking; [param file] names the ship: the problems.
static func check(
	layout: ShipLayout,
	cut_above: float,
	file: String,
	faces: PackedVector3Array,
	cells: Dictionary,
	samples: Callable,
	tolerance: float
) -> PackedStringArray:
	var problems := PackedStringArray()
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		if platform.height >= cut_above:
			continue
		var points: PackedVector2Array = samples.call(platform.area)
		var low := platform.height - ShipArt.PLANK - tolerance
		var bare := PackedVector2Array()
		for point in points:
			var from := Vector3(point.x, low, point.y)
			if not _faced_down_over(faces, cells, from, platform.height):
				bare.append(point)
		if not bare.is_empty():
			problems.append(
				(
					"art-lint: %s platform %d: no underside at %d of %d points, first at %s"
					% [file, index, bare.size(), points.size(), bare[0]]
				)
			)
	return problems


## Whether a face looking down lies straight over [param from], at or under
## [param high].
static func _faced_down_over(
	faces: PackedVector3Array, cells: Dictionary, from: Vector3, high: float
) -> bool:
	for index: int in FaceCells.at(cells, from):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.UP, a, b, c)
		if hit != null and (hit as Vector3).y <= high and FaceCells.facing(a, b, c) < -0.5:
			return true
	return false
