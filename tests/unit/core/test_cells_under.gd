extends GutTest
## CellMap.cells_under() walks a point's column down once (its cells picked out, its hull
## section found once): it answers exactly what asking cell_at() under each floor in turn
## answers, on every ship, in her frame and in one turned along another axis (Faces).
## Natively (NativeWater.chains_under, and NativeWater.cells_at for cell_at itself),
## every point at once, they answer the same bit for bit; where the extension is not loaded there is nothing to hold it to, and CI sets
## SINKING_NATIVE_REQUIRED, so a missing library there fails.

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


func test_every_ship_chains_natively_as_cells_under_does() -> void:
	if not _loaded():
		return
	var water := StillPoints.native_water()
	for ship: ShipLayout in SHIPS:
		var cells := CellMap.new(ship.structure)
		var points := _points(ship.structure, Basis.IDENTITY)
		var chained := cells.chains_under(water, points)
		assert_eq(chained.size(), 3, ship.resource_path)
		var from := PackedInt32Array([0])
		var found := PackedInt32Array()
		var floors := PackedVector3Array()
		for point: Vector3 in points:
			for cell: int in cells.cells_under(point):
				found.append(cell)
				floors.append(Vector3(point.x, cells.floor_of(cell), point.z))
			from.append(found.size())
		assert_eq(chained[0], from, ship.resource_path)
		assert_eq(chained[1], found, ship.resource_path)
		assert_eq(chained[2], floors, ship.resource_path)


func test_a_turned_frame_leaves_its_chains_to_cells_under() -> void:
	var cells := CellMap.new(SHIPS[2].structure, Basis(Vector3.FORWARD, PI * 0.5))
	assert_eq(cells.chains_under(null, PackedVector3Array([Vector3.ZERO])), [])


func test_every_ship_locates_natively_as_cell_at_does() -> void:
	if not _loaded():
		return
	var water := StillPoints.native_water()
	for ship: ShipLayout in SHIPS:
		var cells := CellMap.new(ship.structure)
		var points := _points(ship.structure, Basis.IDENTITY)
		var located := cells.cells_at(water, points)
		assert_eq(located.size(), 2, ship.resource_path)
		var found := PackedInt32Array()
		var floors := PackedVector3Array()
		for point: Vector3 in points:
			var cell := cells.cell_at(point)
			found.append(cell)
			floors.append(
				point if cell == CellMap.NONE else Vector3(point.x, cells.floor_of(cell), point.z)
			)
		assert_eq(located[0], found, ship.resource_path)
		assert_eq(located[1], floors, ship.resource_path)


func test_a_turned_frame_leaves_its_cells_to_cell_at() -> void:
	var cells := CellMap.new(SHIPS[2].structure, Basis(Vector3.FORWARD, PI * 0.5))
	assert_eq(cells.cells_at(null, PackedVector3Array([Vector3.ZERO])), [])


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


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeWater"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
