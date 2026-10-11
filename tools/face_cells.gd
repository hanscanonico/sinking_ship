class_name FaceCells
extends RefCounted
## Drawn triangles filed by the CELL-sized squares of the ship plane their bounds
## cover, so `make art-lint`'s rays look only at the faces near them: Vector2i ->
## Array of first-corner indices (an Array, which a Dictionary holds by reference,
## where a packed array would be copied out).

## The side of the squares, in metres.
const CELL := 0.5


## The triangles of [param faces], filed.
static func file(faces: PackedVector3Array) -> Dictionary:
	var cells := {}
	for index in range(0, faces.size(), 3):
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for corner in 3:
			var at := faces[index + corner]
			low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
			high = Vector2(maxf(high.x, at.x), maxf(high.y, at.z))
		for x in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
			for z in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells[cell] = []
				(cells[cell] as Array).append(index)
	return cells


## The square [param point] stands in.
static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


## The triangles of [param cells] filed where [param point] stands.
static func at(cells: Dictionary, point: Vector3) -> Array:
	return cells.get(cell_of(point), [])


## How far up the triangle [a, b, c] faces: its normal's y.
static func facing(a: Vector3, b: Vector3, c: Vector3) -> float:
	# Godot's front faces wind clockwise: their normal is the cross reversed.
	return -(b - a).cross(c - a).normalized().y
