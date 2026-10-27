extends GutTest
## The sea leaves out every one of her cells whose water is drawn as its own
## (SeaAndSky.cell_mask): however many there are — the Titanic draws more than the 16
## the sea once took, and every cell drawn makes it 84 (#148) — each box is in the mask
## the sea's shader reads, in order along her so it can stop past a point; and no
## doorway through a bulkhead between two of her cells shows it.

const TITANIC := "res://data/ships/titanic.tres"
const STEAMER := "res://data/ships/steamer.tres"
## How far inside a room's walls, floor and ceiling its points are read — clear of a
## box's INSET from her side (CellBoxes) — and how far apart.
const INWARD := 0.3
const STEP := 0.5
## How far in from a doorway's edges its points are read, and how far apart through
## its bulkhead; and how far past a door the room it leads into is looked for, past
## any bulkhead's walls.
const DOOR_IN := 0.05
const DOOR_STEP := 0.1
const PAST_DOOR := 0.8
const UNDER_E_DECK: Array[StringName] = [
	&"F deck working corridor, boiler room 4",
	&"F deck working corridor, boiler room 5",
	&"Turkish bath",
	&"swimming bath",
	&"boiler room 4",
	&"boiler room 5",
]
const UNDER_THE_POOP: Array[StringName] = [&"steering gear"]
const AT_HER_BULKHEADS: Array[StringName] = [
	&"No. 3 hold",
	&"squash court",
	&"E deck working passage, turbine room",
]
const UNDER_THE_STEERING_GEAR: Array[StringName] = [&"aft stores"]


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


## A door through a bulkhead between two of her cells never shows the sea: every point
## of its doorway, from the plane the cells share out to the wall of the room it leads
## into either side, is in a box the sea leaves out. The Titanic's No. 3 hold's rooms
## stop short of bulkheads D and C by the bulkheads' thickness, and the box round them
## once stopped there too: as she sank by the head the sea was drawn across her F deck
## watertight doors, a strip at its own height foaming at their jambs, seen from boiler
## room 6's working corridor through the door into the third-class berths.
func test_no_doorway_through_a_bulkhead_shows_the_sea() -> void:
	for ship_name: String in Fleet.names():
		var open := _open_doorways(Fleet.layout(ship_name))
		assert_eq(open, [], "%s's doorways the sea is drawn in" % ship_name)


## Rooms standing up to a bulkhead their cell shares with the next never look into the
## sea there — the Titanic's No. 3 hold and squash court, and E deck's working passage
## by the turbine room where it stands up into D deck's cell; and the steamer's aft
## stores, forward of her steering gear, whose box stops at the steering gear's floor:
## the box round their cell's rooms reaches the bulkhead, as a whole cell's does, where
## it once stopped at the rooms and left the sea a strip of them.
func test_rooms_at_a_bulkhead_never_look_into_the_sea() -> void:
	assert_eq(
		_open_points(load(TITANIC), AT_HER_BULKHEADS), [], "points of her rooms the sea is drawn in"
	)
	assert_eq(
		_open_points(load(STEAMER), UNDER_THE_STEERING_GEAR), [], "points of it the sea is drawn in"
	)


## Per room of [param layout] named in [param names], the first point found of it, from
## its floor to whatever roofs it, inside one of her cells but in no box the sea leaves
## out (CellBoxes.boxes and stacked); every one of the rooms hers.
func _open_points(layout: ShipLayout, names: Array[StringName]) -> Array:
	var masked := _masked(layout)
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


## Per door of [param layout]'s in a wall between two of her cells, the first point
## found of its doorway in no box the sea leaves out: each side, from the plane the
## cells share out to the wall of the room the door leads into on its floor — none
## where no room stands past it, which is the rooms' own walk's (_open_points) — across
## its width and up its height, DOOR_IN in from its edges.
func _open_doorways(layout: ShipLayout) -> Array:
	var masked := _masked(layout)
	var doors := [ShipOpening.Kind.DOOR, ShipOpening.Kind.WATERTIGHT_DOOR]
	var open := []
	for opening: ShipOpening in layout.structure.openings:
		var axis := opening.facing()
		var outside := ShipOpening.SEA in opening.joins or ShipOpening.SKY in opening.joins
		if not opening.kind in doors or outside or axis == -1 or axis == 1:
			continue
		var along := 2 - axis
		var half := opening.size * 0.5
		var bottom := opening.centre.y - half.y
		var top := opening.centre.y + half.y
		for side: float in [-1.0, 1.0]:
			var past := opening.centre
			past[axis] += side * PAST_DOOR
			var room := _room_on(layout, past, bottom)
			if room == null:
				continue
			var wall := room.area.position if side > 0.0 else room.area.end
			var through := absf((wall.x if axis == 0 else wall.y) - opening.centre[axis])
			var found := ""
			for depth: float in _steps(DOOR_IN, through - DOOR_IN, DOOR_STEP):
				for across: float in _steps(DOOR_IN - half[along], half[along] - DOOR_IN):
					for height: float in _steps(bottom + DOOR_IN, top - DOOR_IN):
						var point := opening.centre
						point[axis] += side * depth
						point[along] += across
						point.y = height
						if found.is_empty() and not _in_any(masked, point):
							found = "%s at %s" % [opening.name, point.snappedf(0.01)]
			if not found.is_empty():
				open.append(found)
	return open


## The room of [param layout]'s with its floor at [param floor_height] whose area holds
## [param point]; null for none.
func _room_on(layout: ShipLayout, point: Vector3, floor_height: float) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		var on := is_equal_approx(room.floor_height, floor_height)
		if on and room.area.has_point(Vector2(point.x, point.z)):
			return room
	return null


## The boxes [param layout]'s sea leaves out (CellBoxes.boxes and stacked).
func _masked(layout: ShipLayout) -> Array[AABB]:
	var masked := CellBoxes.boxes(layout.structure, layout.rooms)
	for stack: Array in CellBoxes.stacked(layout.structure, layout.rooms):
		masked.append(stack[1])
	return masked


func test_a_ship_with_no_drawn_cell_masks_nothing() -> void:
	var none: Array[AABB] = [AABB()]
	assert_eq(SeaAndSky.cell_mask(none).get_width(), 1, "one empty texel, never a zero image")
	assert_eq(SeaAndSky.cell_count(none), 0)


func _key(box: AABB) -> String:
	return "%s %s" % [box.position.snappedf(0.001), box.end.snappedf(0.001)]


## From [param from] to [param to], [param step] apart, and [param to] itself.
func _steps(from: float, to: float, step := STEP) -> Array[float]:
	var found: Array[float] = []
	var at := from
	while at < to:
		found.append(at)
		at += step
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
