extends GutTest
## The sea leaves out every one of her cells whose water is drawn as its own
## (SeaAndSky.cell_mask): however many there are — the Titanic draws more than the 16
## the sea once took, and every cell drawn makes it 84 (#148) — each box is in the mask
## the sea's shader reads, in order along her so it can stop past a point.

const TITANIC := "res://data/ships/titanic.tres"
const STEAMER := "res://data/ships/steamer.tres"
## How far inside a room's walls, floor and ceiling its points are read — clear of a
## box's INSET from her side (CellBoxes) — and how far apart.
const INWARD := 0.3
const STEP := 0.5
const UNDER_E_DECK: Array[StringName] = [
	&"F deck working corridor, boiler room 4",
	&"F deck working corridor, boiler room 5",
	&"Turkish bath",
	&"swimming bath",
	&"boiler room 4",
	&"boiler room 5",
]
const UNDER_THE_POOP: Array[StringName] = [&"steering gear"]


func test_every_drawn_cell_of_the_titanic_is_in_the_mask() -> void:
	var layout: ShipLayout = load(TITANIC)
	var drawn: Array[AABB] = []
	for box: AABB in CellBoxes.boxes(layout.structure, layout.rooms):
		if box.size != Vector3.ZERO:
			drawn.append(box)
	assert_gt(drawn.size(), 16, "more cells than the sea once took")
	var mask := SeaAndSky.cell_mask(drawn)
	assert_eq(mask.get_width(), drawn.size() * 2, "a low and a high texel a box")
	assert_eq(mask.get_height(), 1)
	var found := {}
	for index in drawn.size():
		var low := mask.get_pixel(index * 2, 0)
		var high := mask.get_pixel(index * 2 + 1, 0)
		var box := AABB(
			Vector3(low.r, low.g, low.b), Vector3(high.r - low.r, high.g - low.g, high.b - low.b)
		)
		found[_key(box)] = true
		if index > 0:
			assert_gte(low.r, mask.get_pixel(index * 2 - 2, 0).r, "in order along her")
	for box: AABB in drawn:
		assert_true(found.has(_key(box)), "box at %s" % box.position)


## The F deck rooms over boiler rooms 4 and 5, and the stokeholds under them, never look
## up into her and see the sea: every point of them, from the floor to whatever roofs it,
## inside one of her cells, is in a box the sea leaves out — they once stood open to the
## void over them, the sea drawn in it as she sank by the head.
func test_the_rooms_over_boiler_rooms_4_and_5_never_look_up_into_the_sea() -> void:
	assert_eq(
		_open_points(load(TITANIC), UNDER_E_DECK), [], "points of her rooms the sea is drawn in"
	)


## The steamer's steering gear stands up into the space under her poop with no deck
## between them: every point of it, from its floor to the poop deck, inside one of her
## cells, is in a box the sea leaves out — its top once stood in that space, a void the
## sea's mask left out, and as she sank by the stern the sea was drawn across the room
## there, ending in a line over its dry floor.
func test_the_steamers_steering_gear_never_looks_up_into_the_sea() -> void:
	assert_eq(_open_points(load(STEAMER), UNDER_THE_POOP), [], "points of it the sea is drawn in")


## Per room of [param layout] named in [param names], the first point found of it, from
## its floor to whatever roofs it, inside one of her cells but in no box the sea leaves
## out (CellBoxes.boxes and stacked); every one of the rooms hers.
func _open_points(layout: ShipLayout, names: Array[StringName]) -> Array:
	var masked := CellBoxes.boxes(layout.structure, layout.rooms)
	for stack: Array in CellBoxes.stacked(layout.structure, layout.rooms):
		masked.append(stack[1])
	var space := ShipSpace.new(layout)
	var open := []
	var checked := 0
	for room: ShipRoom in layout.rooms:
		if not room.name in names:
			continue
		checked += 1
		var area := room.area.grow(-INWARD)
		if not area.has_area():
			continue
		for x: float in _steps(area.position.x, area.end.x):
			for z: float in _steps(area.position.y, area.end.y):
				var top := space.ceiling(room, x, z) - INWARD
				for y: float in _steps(room.floor_height + INWARD, top):
					var point := Vector3(x, y, z)
					if _in_a_cell(layout.structure, point) and not _in_any(masked, point):
						open.append("%s at %s" % [room.name, point.snappedf(0.01)])
						break
	assert_eq(checked, names.size(), "every one of the rooms is hers")
	return open


func test_a_ship_with_no_drawn_cell_masks_nothing() -> void:
	var none: Array[AABB] = [AABB()]
	assert_eq(SeaAndSky.cell_mask(none).get_width(), 1, "one empty texel, never a zero image")
	assert_eq(SeaAndSky.cell_count(none), 0)


func _key(box: AABB) -> String:
	return "%s %s" % [box.position.snappedf(0.001), box.end.snappedf(0.001)]


## From [param from] to [param to], STEP apart, and [param to] itself.
func _steps(from: float, to: float) -> Array[float]:
	var found: Array[float] = []
	var at := from
	while at < to:
		found.append(at)
		at += STEP
	if to >= from:
		found.append(to)
	return found


func _in_a_cell(structure: ShipStructure, point: Vector3) -> bool:
	for cell: FloodCell in structure.cells:
		if _in_any([AABB(cell.low, cell.high - cell.low)], point):
			return true
	return false


func _in_any(boxes: Array, point: Vector3) -> bool:
	for box: AABB in boxes:
		if box.size != Vector3.ZERO and box.has_point(point):
			return true
	return false
