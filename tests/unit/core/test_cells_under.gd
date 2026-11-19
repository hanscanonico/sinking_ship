extends GutTest
## CellMap.cells_under() walks a point's column down once (its cells picked out, its hull
## section found once): it answers exactly what asking cell_at() under each floor in turn
## answers, on every ship, in her frame and in one turned along another axis (Faces).

const SHIPS: Array[ShipLayout] = [
	preload("res://data/ships/titanic.tres"),
	preload("res://data/ships/small_titanic.tres"),
	preload("res://data/ships/steamer.tres"),
	preload("res://data/ships/trawler.tres"),
	preload("res://data/ships/tug.tres"),
	preload("res://data/ships/barque.tres"),
]
## How many points are tried anywhere in her box round her cells, besides her cells' own.
const SCATTERED := 600


func test_every_ship_answers_as_cell_at_does() -> void:
	for ship: ShipLayout in SHIPS:
		var cells := CellMap.new(ship.structure)
		assert_eq(
			_first_wrong(cells, _points(ship.structure, Basis.IDENTITY)), "", ship.resource_path
		)


func test_a_turned_frame_answers_as_cell_at_does() -> void:
	var to_ship := Basis(Vector3.FORWARD, PI * 0.5)
	for ship: ShipLayout in [SHIPS[1], SHIPS[2]]:
		var cells := CellMap.new(ship.structure, to_ship)
		assert_eq(_first_wrong(cells, _points(ship.structure, to_ship)), "", ship.resource_path)


## Every cell's floor corners and middle, a point a hair over each corner and one just
## outside it, and points scattered through the box round them all — in the frame
## [param to_ship] takes to ship space.
func _points(structure: ShipStructure, to_ship: Basis) -> PackedVector3Array:
	var points := PackedVector3Array()
	var box := AABB()
	for cell: FloodCell in structure.cells:
		var low := cell.low
		var high := cell.high
		box = AABB(low, high - low) if points.is_empty() else box.merge(AABB(low, high - low))
		for corner: Vector3 in [
			low,
			Vector3(high.x, low.y, low.z),
			Vector3(low.x, low.y, high.z),
			Vector3(high.x, low.y, high.z),
		]:
			points.append(corner)
			points.append(corner + Vector3(0.0, 0.004, 0.0))
			points.append(corner - Vector3(0.001, 0.0, 0.001))
		points.append((low + high) * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 635
	for index in SCATTERED:
		points.append(box.position + box.size * Vector3(rng.randf(), rng.randf(), rng.randf()))
	var to_frame := to_ship.transposed()
	for index in points.size():
		points[index] = to_frame * points[index]
	return points


## The first point whose cells_under differs from walking cell_at down, or "".
func _first_wrong(cells: CellMap, points: PackedVector3Array) -> String:
	for point: Vector3 in points:
		var walked := PackedInt32Array()
		var under := point
		var cell := cells.cell_at(under)
		while cell != CellMap.NONE:
			walked.append(cell)
			under.y = cells.floor_of(cell)
			under.y -= CellMap.DRY
			cell = cells.cell_at(under)
		var found := cells.cells_under(point)
		if found != walked:
			return "%s: %s, not %s" % [point, found, walked]
	return ""
