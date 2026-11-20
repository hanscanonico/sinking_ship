extends GutTest
## CellMap.cell_at answered by the extension (NativeCellMap) is the GDScript's answer
## (cell_at_by_script) at every point, on every ship, in her frame and turned along
## another axis (Faces): her cells' corners and middles, points a hair either side of
## them, points across the boxes that poke outside her hull — some in her shell, some
## past it — and points outside every cell. Where the extension is not loaded there is
## nothing to hold it to, and CI sets SINKING_NATIVE_REQUIRED, so a missing library
## there fails.

const SHIPS: Array[ShipLayout] = [
	preload("res://data/ships/titanic.tres"),
	preload("res://data/ships/small_titanic.tres"),
	preload("res://data/ships/steamer.tres"),
	preload("res://data/ships/trawler.tres"),
	preload("res://data/ships/tug.tres"),
	preload("res://data/ships/barque.tres"),
]
## How many points are tried anywhere in (and a little past) her box round her cells.
const SCATTERED := 1500
## How many points are tried in each box that pokes outside her hull.
const PER_POKING := 12


func test_every_ship_answers_natively_as_the_script_does() -> void:
	if not _loaded():
		return
	for ship: ShipLayout in SHIPS:
		var cells := CellMap.new(ship.structure)
		assert_eq(
			_first_wrong(cells, _points(ship.structure, Basis.IDENTITY)), "", ship.resource_path
		)


func test_a_turned_frame_answers_natively_as_the_script_does() -> void:
	if not _loaded():
		return
	for to_ship: Basis in [Basis(Vector3.FORWARD, PI * 0.5), Basis(Vector3.RIGHT, -PI * 0.5)]:
		for ship: ShipLayout in [SHIPS[0], SHIPS[2], SHIPS[3]]:
			var cells := CellMap.new(ship.structure, to_ship)
			assert_eq(_first_wrong(cells, _points(ship.structure, to_ship)), "", ship.resource_path)


func test_the_points_reach_past_her_shell_and_inside_it() -> void:
	if not _loaded():
		return
	var structure := SHIPS[0].structure
	var cells := CellMap.new(structure)
	var kept := 0
	var cut := 0
	var outside := 0
	for point: Vector3 in _points(structure, Basis.IDENTITY):
		var found := cells.cell_at_by_script(point)
		if found == CellMap.NONE:
			outside += 1
			if _in_poking_box(structure, point):
				cut += 1
		elif structure.cells[found].shape < 1.0:
			kept += 1
	assert_gt(kept, 100, "points kept in a box poking past her hull")
	assert_gt(cut, 100, "points in a poking box cut off by her shell")
	assert_gt(outside, 100, "points outside every cell")


## Every cell's corners and middle, a point a hair over and one a hair outside each
## corner, points across every box poking outside her hull, and points scattered through
## and past the box round them all — in the frame [param to_ship] takes to ship space.
func _points(structure: ShipStructure, to_ship: Basis) -> PackedVector3Array:
	var points := PackedVector3Array()
	var box := AABB()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1912
	for cell: FloodCell in structure.cells:
		var low := cell.low
		var high := cell.high
		box = AABB(low, high - low) if points.is_empty() else box.merge(AABB(low, high - low))
		for corner: Vector3 in [
			low,
			Vector3(high.x, low.y, low.z),
			Vector3(low.x, low.y, high.z),
			Vector3(high.x, low.y, high.z),
			Vector3(low.x, high.y, high.z),
		]:
			points.append(corner)
			points.append(corner + Vector3(0.0, 0.004, 0.0))
			points.append(corner - Vector3(0.001, 0.0, 0.001))
		points.append((low + high) * 0.5)
		if cell.shape < 1.0:
			for index in PER_POKING:
				points.append(low + (high - low) * Vector3(rng.randf(), rng.randf(), rng.randf()))
	box = box.grow(2.0)
	for index in SCATTERED:
		points.append(box.position + box.size * Vector3(rng.randf(), rng.randf(), rng.randf()))
	var to_frame := to_ship.transposed()
	for index in points.size():
		points[index] = to_frame * points[index]
	return points


## The first point where the extension's cell_at differs from the GDScript's, or "".
func _first_wrong(cells: CellMap, points: PackedVector3Array) -> String:
	for point: Vector3 in points:
		var native := cells.cell_at(point)
		var script := cells.cell_at_by_script(point)
		if native != script:
			return "%s: %d, not %d" % [point, native, script]
	return ""


func _in_poking_box(structure: ShipStructure, point: Vector3) -> bool:
	for cell: FloodCell in structure.cells:
		if cell.shape >= 1.0:
			continue
		var low := cell.low
		var high := cell.high
		if point.x >= low.x and point.x < high.x and point.y >= low.y and point.y < high.y:
			if point.z >= low.z and point.z < high.z:
				return true
	return false


func _loaded() -> bool:
	if NativeVersion.has(&"NativeCellMap"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
