extends GutTest
## §5b.2's structure lint, run over every ship under data/ships/ that has a structure:
## the shape of the physics' view of a ship, not any one ship's numbers.

const SHIPS := "res://data/ships"
## How far apart two faces or a point and a face may stand and still meet, in metres.
const TOUCH := 0.01
## How much the cells' volume may differ from the sections' (est.).
const ENCLOSED := 0.02
## How far past an opening a point is out of its cell; how far apart along a wall its
## top is checked against the deck over it.
const STEP_OUT := 0.05
const ALONG_WALL := 0.5


## Every layout under data/ships/ with a structure, by path.
func _structured() -> Dictionary:
	var found := {}
	for file: String in DirAccess.get_files_at(SHIPS):
		if not file.ends_with(".tres"):
			continue
		var layout: ShipLayout = load("%s/%s" % [SHIPS, file])
		if layout.structure != null:
			found["%s/%s" % [SHIPS, file]] = layout
	return found


## Whether ship point [param point] stands inside [param cell]'s box, within
## [param margin] of it.
func _in_box(cell: FloodCell, point: Vector3, margin: float) -> bool:
	for axis in 3:
		if point[axis] < cell.low[axis] - margin or point[axis] > cell.high[axis] + margin:
			return false
	return true


## The cells of [param structure] whose boxes hold [param point].
func _cells_at(structure: ShipStructure, point: Vector3) -> Array[FloodCell]:
	var found: Array[FloodCell] = []
	for cell: FloodCell in structure.cells:
		if _in_box(cell, point, -TOUCH * 0.1):
			found.append(cell)
	return found


## Whether [param opening]'s rectangle lies within [param cell]'s box.
func _rect_in(opening: ShipOpening, cell: FloodCell) -> bool:
	var half := opening.size * 0.5
	return (
		_in_box(cell, opening.centre - half, TOUCH) and _in_box(cell, opening.centre + half, TOUCH)
	)


## Whether ship point [param point] stands inside the hull: inside the outline of the
## section whose stretch holds its x.
func _in_hull(structure: ShipStructure, point: Vector3) -> bool:
	for section: HullSection in structure.sections:
		if absf(point.x - section.x) > section.length * 0.5:
			continue
		var inside := false
		var outline := section.outline
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			if (a.y > point.y) != (b.y > point.y):
				var z := a.x + (point.y - a.y) / (b.y - a.y) * (b.x - a.x)
				if point.z < z:
					inside = not inside
		return inside
	return false


func test_the_steamer_has_a_structure() -> void:
	assert_true(_structured().has(SimFixtures.STEAMER), "the steamer has a structure")


func test_every_room_lies_in_exactly_one_cell() -> void:
	var layouts := _structured()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var structure := layout.structure
		var room_names: Array[StringName] = []
		for room: ShipRoom in layout.rooms:
			room_names.append(room.name)
			var middle := room.area.get_center()
			var floor_point := Vector3(middle.x, room.floor_height + TOUCH, middle.y)
			var holding := _cells_at(structure, floor_point)
			assert_eq(holding.size(), 1, "%s: room %s stands in one cell" % [path, room.name])
			var listing := structure.cells.filter(
				func(cell: FloodCell) -> bool: return room.name in cell.rooms
			)
			assert_eq(listing.size(), 1, "%s: one cell lists room %s" % [path, room.name])
			if holding.size() != 1 or listing.size() != 1:
				continue
			var cell: FloodCell = holding[0]
			assert_eq(listing[0], cell, "%s: room %s is listed by its cell" % [path, room.name])
			for corner: Vector2 in [room.area.position, room.area.end]:
				assert_true(
					_in_box(cell, Vector3(corner.x, room.floor_height, corner.y), TOUCH),
					"%s: room %s lies wholly in %s" % [path, room.name, cell.name]
				)
		for cell: FloodCell in structure.cells:
			for room_name: StringName in cell.rooms:
				assert_has(
					room_names, room_name, "%s: %s lists a room there is" % [path, cell.name]
				)


func test_cells_do_not_overlap() -> void:
	var layouts := _structured()
	for path: String in layouts:
		var cells := (layouts[path] as ShipLayout).structure.cells
		for i in cells.size():
			for j in range(i + 1, cells.size()):
				var overlap := 1.0
				for axis in 3:
					var from := maxf(cells[i].low[axis], cells[j].low[axis])
					var to := minf(cells[i].high[axis], cells[j].high[axis])
					overlap *= maxf(to - from, 0.0)
				assert_almost_eq(
					overlap,
					0.0,
					1e-6,
					"%s: %s and %s overlap" % [path, cells[i].name, cells[j].name]
				)


func test_every_enclosed_volume_is_in_a_cell() -> void:
	var layouts := _structured()
	var everything := Hydrostatics.level(INF)
	for path: String in layouts:
		var structure := (layouts[path] as ShipLayout).structure
		var enclosed := Hydrostatics.cut_hull(structure.sections, everything).volume
		var in_cells := 0.0
		for cell: FloodCell in structure.cells:
			in_cells += cell.volume()
		var off := (in_cells - enclosed) / enclosed
		gut.p(
			(
				"%s: sections %.2f m³, cells %.2f m³ (%+.3f%%)"
				% [path, enclosed, in_cells, off * 100.0]
			)
		)
		assert_almost_eq(off, 0.0, ENCLOSED, "%s: the cells hold what the hull encloses" % path)


func test_every_opening_joins_two_cells_or_a_cell_and_the_outside() -> void:
	var layouts := _structured()
	for path: String in layouts:
		var structure := (layouts[path] as ShipLayout).structure
		for opening: ShipOpening in structure.openings:
			var what := "%s: opening %s" % [path, opening.name]
			assert_eq(opening.problems(), PackedStringArray(), what)
			var cells: Array[FloodCell] = []
			var outside: Array[StringName] = []
			for place: StringName in opening.joins:
				var index := structure.cell_named(place)
				if index != -1:
					cells.append(structure.cells[index])
				elif place in [ShipOpening.SEA, ShipOpening.SKY]:
					outside.append(place)
			assert_eq(cells.size() + outside.size(), 2, what + " joins places there are")
			assert_ne(cells.size(), 0, what + " joins a cell")
			var across := opening.facing()
			if cells.is_empty() or across == -1:
				continue
			for cell: FloodCell in cells:
				assert_true(_rect_in(opening, cell), "%s lies in %s" % [what, cell.name])
			if cells.size() == 2:
				var at: float = opening.centre[across]
				var shared := (
					(
						absf(cells[0].high[across] - at) < TOUCH
						and absf(cells[1].low[across] - at) < TOUCH
					)
					or (
						absf(cells[0].low[across] - at) < TOUCH
						and absf(cells[1].high[across] - at) < TOUCH
					)
				)
				assert_true(shared, what + " lies on the face its cells share")
				continue
			# Past the rectangle: the sea outside the hull, away from her middle — a box
			# may stand out of the hull's curve —, or the sky outside every cell, away
			# from its cell's middle.
			var cell := cells[0]
			var out := Vector3.ZERO
			var middle: float = (cell.low[across] + cell.high[across]) * 0.5
			if outside[0] == ShipOpening.SEA:
				middle = 0.0
			out[across] = STEP_OUT if opening.centre[across] > middle else -STEP_OUT
			var beyond := opening.centre + out
			if outside[0] == ShipOpening.SEA:
				assert_false(_in_hull(structure, beyond), what + " opens out of the hull")
			else:
				assert_eq(_cells_at(structure, beyond).size(), 0, what + " opens to the sky")


func test_every_watertight_door_sits_in_a_wall() -> void:
	var layouts := _structured()
	for path: String in layouts:
		var structure := (layouts[path] as ShipLayout).structure
		for opening: ShipOpening in structure.openings:
			if opening.kind != ShipOpening.Kind.WATERTIGHT_DOOR:
				continue
			var holding: ShipWall = null
			for wall: ShipWall in structure.walls:
				var across := 0 if wall.axis == ShipWall.Axis.ACROSS else 2
				var along := 2 - across
				var half := opening.size * 0.5
				if (
					opening.facing() == across
					and absf(opening.centre[across] - wall.at) < TOUCH
					and opening.centre[along] - half[along] >= wall.span.x - TOUCH
					and opening.centre[along] + half[along] <= wall.span.y + TOUCH
					and opening.centre.y - half.y >= wall.bottom - TOUCH
					and opening.centre.y + half.y <= wall.top + TOUCH
				):
					holding = wall
			assert_not_null(holding, "%s: %s sits in a watertight wall" % [path, opening.name])
			if holding != null:
				for place: StringName in opening.joins:
					assert_has(
						holding.cells,
						place,
						"%s: %s joins cells its wall parts" % [path, opening.name]
					)


func test_every_wall_top_is_at_or_under_the_deck_above() -> void:
	var layouts := _structured()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var structure := layout.structure
		for wall: ShipWall in structure.walls:
			# The deck above: the lowest one over the wall higher than every floor of
			# the cells it parts.
			var floors := -INF
			for cell_name: StringName in wall.cells:
				floors = maxf(floors, structure.cells[structure.cell_named(cell_name)].low.y)
			var steps := maxi(1, ceili((wall.span.y - wall.span.x) / ALONG_WALL))
			for step in steps + 1:
				var along := lerpf(wall.span.x + TOUCH, wall.span.y - TOUCH, float(step) / steps)
				var x := wall.at if wall.axis == ShipWall.Axis.ACROSS else along
				var z := along if wall.axis == ShipWall.Axis.ACROSS else wall.at
				var deck := INF
				for platform: ShipPlatform in layout.platforms:
					if platform.height > floors + TOUCH and platform.contains(x, z):
						deck = minf(deck, platform.height)
				assert_true(
					wall.top <= deck + TOUCH * 0.1,
					(
						"%s: %s's top at %.2f under the deck over (%.2f, %.2f)"
						% [path, wall.name, wall.top, x, z]
					)
				)
				assert_ne(deck, INF, "%s: a deck over %s at (%.2f, %.2f)" % [path, wall.name, x, z])


func test_every_cell_leaks_its_air() -> void:
	# A pocket loses its air through its cell's rivets and seams, by construction (est.
	# 10⁻³ m² per 1 000 m³, §5b.1): every cell has a leak, none rounded away to nothing,
	# or a pocket there would hold its air for ever (SH29).
	var layouts := _structured()
	for path: String in layouts:
		var structure := (layouts[path] as ShipLayout).structure
		for cell: FloodCell in structure.cells:
			var per_volume := cell.leak_area / cell.volume()
			assert_almost_eq(
				per_volume, 1e-6, 1e-8, "%s: %s's leak by its volume" % [path, cell.name]
			)
