extends GutTest
## The sea leaves out every one of her cells whose water is drawn as its own
## (SeaAndSky.cell_mask): however many there are — the Titanic draws more than the 16
## the sea once took, and every cell drawn makes it 84 (#148) — each box is in the mask
## the sea's shader reads, in order along her so it can stop past a point; and no
## doorway through a bulkhead between two of her cells shows it.

const TITANIC := "res://data/ships/titanic.tres"
const STEAMER := "res://data/ships/steamer.tres"
## Her smaller sister keeps the rooms by name that these looked at on her before her
## decks were laid as her plates draw them.
const SMALL_TITANIC := "res://data/ships/small_titanic.tres"
## How far inside a room's walls, floor and ceiling its points are read — clear of a
## box's INSET from her side (CellBoxes) — and how far apart.
const INWARD := 0.3
const STEP := 0.5
## How far over a room's floor the cells and boxes it may stand in are looked for: past
## the highest any deck roofs one of hers.
const OVER_ANY_ROOF := 40.0
## The Titanic, her smaller sister and her sisters, by name (Fleet).
const TITANICS: Array[StringName] = [
	&"titanic", &"small_titanic", &"titanic_olympic_1913", &"titanic_britannic"
]
## How far in from a doorway's edges its points are read, and how far apart through
## its bulkhead; and how far past a door the room it leads into is looked for, past
## any bulkhead's walls — and its floor walked, where it leads into none.
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
	&"squash court gallery",
	&"E deck working passage, turbine room",
]
const UNDER_THE_STEERING_GEAR: Array[StringName] = [&"aft stores"]
## The traced Titanic's rooms whose box ends on a joint between two of her sections: B
## deck's corridor at her forward well's, the third-class entrance at her poop's front.
const ON_A_JOINT: Array[StringName] = [
	&"B deck corridor",
	&"third-class entrance, C deck",
	&"third-class entrance",
	&"greasers' mess",
]
## The traced Titanic's rooms at her bow's and stern's taper whose box, held to her
## shell's narrowest over all of it, left out part of them: over a joint to a wider
## section, or where her shell leans out over their floors (#318).
const ON_HER_TAPER: Array[StringName] = [
	&"after hold",
	&"deck men's berths",
	&"firemen's W.C.s, E deck",
	&"firemen's W.C.s, F deck aft",
	&"firemen's wash place, E deck",
	&"lamp trimmer's and storekeeper's berths",
	&"men's lavatory, E deck aft of B",
	&"passage, F deck aft of B",
	&"passage, F deck aft of P",
	&"passage, G deck, aft of N",
	&"six-berth third-class room, D deck",
]
## Her smaller sister's forecastle stores, wider aft than her shell at their forward end.
const UNDER_HER_FORECASTLE: Array[StringName] = [&"forecastle stores"]
## The traced Titanic's firemen's W.C.s on D deck, under the crew's stair up into her
## forecastle with no room of it over the stairwell.
const UNDER_HER_STAIRS: Array[StringName] = [&"firemen's W.C.s"]
## The traced Titanic's rooms once laid out past her sections at her taper, each
## section's shell taken at its middle and held all along it (#318): her sections cut
## finer there, they stand inside them and are drawn whole — her windlass machinery room,
## forward of her forecastle's sheer, once held to nothing.
const PAST_HER_SECTIONS: Array[StringName] = [
	&"steering gear room",
	&"seamen's mess",
	&"firemen's mess",
	&"windlass machinery room",
	&"store, D deck aft of P",
	&"firemen's quarters, D deck forward of A",
	&"trimmers' quarters, E deck forward of A",
	&"store, F deck",
	&"four-berth third-class room, G deck, aft of O",
	&"passage, G deck, aft of B",
]


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
		_open_points(load(SMALL_TITANIC), UNDER_E_DECK),
		[],
		"points of her rooms the sea is drawn in"
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
## into either side, or onto the floor there where it leads into none, is in a box the
## sea leaves out. The Titanic's No. 3 hold's rooms stop short of bulkheads D and C by
## the bulkheads' thickness, and the box round them once stopped there too: as she sank
## by the head the sea was drawn across her F deck watertight doors, a strip at its own
## height foaming at their jambs, seen from boiler room 6's working corridor through
## the door into the third-class berths. Bulkhead C's door opens onto the squash court
## gallery's side, once in no room and so in no box: the sea showed past it there.
func test_no_doorway_through_a_bulkhead_shows_the_sea() -> void:
	for ship_name: String in Fleet.names():
		var open := _open_doorways(Fleet.layout(ship_name))
		assert_eq(open, [], "%s's doorways the sea is drawn in" % ship_name)


## Rooms standing up to a bulkhead their cell shares with the next never look into the
## sea there — the Titanic's No. 3 hold, squash court and its gallery, and E deck's
## working passage by the turbine room where it stands up into D deck's cell; and the
## steamer's aft stores, forward of her steering gear: the box round their cell's rooms
## reaches the bulkhead, as a whole cell's does, where it once stopped at the rooms and
## left the sea a strip of them; and a room another stands over only part of — the
## court under its gallery, the aft stores under the steering gear — is drawn up past
## it, where a box per room once stopped at that room's floor the room's whole length.
func test_rooms_at_a_bulkhead_never_look_into_the_sea() -> void:
	assert_eq(
		_open_points(load(SMALL_TITANIC), AT_HER_BULKHEADS),
		[],
		"points of her rooms the sea is drawn in"
	)
	assert_eq(
		_open_points(load(STEAMER), UNDER_THE_STEERING_GEAR), [], "points of it the sea is drawn in"
	)


## A room whose box ends on a joint between two of her sections never looks into the sea:
## her shell over the box is read over the sections it stands in, not the one past that
## end, which her sections' rounded ends have it touch by a hair. B deck's corridor, out
## to her forward well's section — whose sheer stands under B deck's top, her shell read
## as nothing there — was once held to no width at all, the sea drawn the whole length
## of the corridor once it reached B deck (#318).
func test_rooms_ending_on_a_joint_never_look_into_the_sea() -> void:
	assert_eq(
		_open_points(load(TITANIC), ON_A_JOINT), [], "points of her rooms the sea is drawn in"
	)


## A room at her taper never looks into the sea where her shell is wider than at its
## narrowest over the room: its box is held to her shell section by section and band by
## band up it, where it was once held to her narrowest over all of it — the seamen's
## mess to her forecastle's narrower section forward of the one it mostly stands in,
## her after hold to her shell at its floor — and the sea was drawn along their sides.
func test_rooms_on_her_taper_never_look_into_the_sea() -> void:
	assert_eq(
		_open_points(load(TITANIC), ON_HER_TAPER), [], "points of her rooms the sea is drawn in"
	)
	assert_eq(
		_open_points(load(SMALL_TITANIC), UNDER_HER_FORECASTLE),
		[],
		"points of her sister's rooms the sea is drawn in"
	)


## A room once laid out past her sections at her taper never looks into the sea: her
## windlass machinery room, aft of where her forecastle's sheer stands under its top,
## was once held to nothing there, the sea drawn through it; and where her sections stood
## inside her lines, only the part of each room inside them was drawn.
func test_rooms_once_past_her_sections_never_look_into_the_sea() -> void:
	assert_eq(
		_open_points(load(TITANIC), PAST_HER_SECTIONS),
		[],
		"points of her rooms the sea is drawn in"
	)


## A room under a stairwell up into the cell over it, where no room of that cell stands
## over the stairwell, never looks up it into the sea: the stairwell is drawn from the
## cell's floor to its top, where it was once in no box — the sea drawn up the Titanic's
## crew's stairs from her D deck forward into her forecastle (#318).
func test_rooms_under_a_stairwell_never_look_up_it_into_the_sea() -> void:
	assert_eq(
		_open_points(load(TITANIC), UNDER_HER_STAIRS), [], "points of her rooms the sea is drawn in"
	)


## No room of the Titanic's, her smaller sister's or her sisters' ever looks into the
## sea, wherever in her it stands: every point of every room, from its floor to whatever
## roofs it, inside one of her cells, is in a box the sea leaves out (#318). A room laid
## past its cell — her sisters' D deck grand staircase into the cell forward of it, their
## G deck stores out into the engine room's wing — or standing up into the cell over it
## with no deck between — her smaller sister's E deck working passages into the voids
## over her after holds, her turbine engine room into the tween over it, her D deck
## saloons' sides up past C deck's edge — is drawn there up to the deck over it
## (RoomColumns), where the sea was once drawn inside the room.
func test_no_room_of_a_titanic_looks_into_the_sea() -> void:
	for ship: StringName in TITANICS:
		assert_eq(
			_open_points(Fleet.layout(ship)), [], "points of %s's rooms the sea is drawn in" % ship
		)


## Per room of [param layout] named in [param names] — every room of hers, with none
## named — the first point found of it, from its floor to whatever roofs it, inside one of
## her cells but in no box the sea leaves out (CellBoxes.boxes and stacked); every one of
## the names a room of hers.
func _open_points(layout: ShipLayout, names: Array[StringName] = []) -> Array:
	var masked := _masked(layout)
	var cells: Array[AABB] = []
	for cell: FloodCell in layout.structure.cells:
		cells.append(AABB(cell.low, cell.high - cell.low))
	var space := ShipSpace.new(layout)
	var open := []
	var checked := {}
	for room: ShipRoom in layout.rooms:
		if not names.is_empty() and not room.name in names:
			continue
		checked[room.name] = true
		var area := room.area.grow(-INWARD)
		if not area.has_area():
			continue
		# Only the cells and boxes over its floor, up to well past any deck over it.
		var over := AABB(
			Vector3(area.position.x, room.floor_height, area.position.y),
			Vector3(area.size.x, OVER_ANY_ROOF, area.size.y)
		)
		var found := _first_open(space, room, _reaching(cells, over), _reaching(masked, over))
		if found != Vector3.INF:
			open.append("%s at %s" % [room.name, found.snappedf(0.01)])
	for name: StringName in names:
		assert_true(checked.has(name), "%s is hers" % name)
	return open


## The first point of [param room], INWARD in from its walls and floor and its roof in
## [param space], STEP apart, inside one of [param cells] but in none of [param masked];
## Vector3.INF for none.
func _first_open(
	space: ShipSpace, room: ShipRoom, cells: Array[AABB], masked: Array[AABB]
) -> Vector3:
	var area := room.area.grow(-INWARD)
	for x: float in _steps(area.position.x, area.end.x):
		for z: float in _steps(area.position.y, area.end.y):
			var top := space.ceiling(room, x, z) - INWARD
			for y: float in _steps(room.floor_height + INWARD, top):
				var point := Vector3(x, y, z)
				if _in_any(cells, point) and not _in_any(masked, point):
					return point
	return Vector3.INF


## Those of [param boxes] that reach into [param over], none of them zero.
func _reaching(boxes: Array[AABB], over: AABB) -> Array[AABB]:
	var found: Array[AABB] = []
	for box: AABB in boxes:
		if box.size != Vector3.ZERO and box.grow(DOOR_IN).intersects(over):
			found.append(box)
	return found


## Per door of [param layout]'s in a wall between two of her cells, the first point
## found of its doorway in no box the sea leaves out: each side, from the plane the
## cells share out to the wall of the room the door leads into on its floor — past
## that, the rooms' own walk's (_open_points) — or PAST_DOOR onto the floor there where
## it leads into none, across its width and up its height, DOOR_IN in from its edges.
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
			var through := PAST_DOOR
			var room := _room_on(layout, past, bottom)
			if room != null:
				var wall := room.area.position if side > 0.0 else room.area.end
				through = absf((wall.x if axis == 0 else wall.y) - opening.centre[axis])
			var found := ""
			if room == null and _filled_past(layout, opening, axis, side):
				continue
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


## Whether a solid of [param layout]'s fills [param opening]'s doorway PAST_DOOR on
## [param side] along [param axis]: a bunker door shut on her coal, nobody's room, no sea
## to see past it.
func _filled_past(layout: ShipLayout, opening: ShipOpening, axis: int, side: float) -> bool:
	var half := opening.size * 0.5
	var along := 2 - axis
	var deep := opening.centre[axis] + side * PAST_DOOR
	for blocker: ShipBlocker in layout.blockers:
		var low := blocker.area.position
		var high := blocker.area.end
		var lows := [low.x, 0.0, low.y]
		var highs := [high.x, 0.0, high.y]
		var reaches: bool = lows[axis] <= minf(opening.centre[axis] + side * DOOR_IN, deep)
		reaches = reaches and highs[axis] >= maxf(opening.centre[axis] + side * DOOR_IN, deep)
		var across: bool = lows[along] <= opening.centre[along] - half[along]
		across = across and highs[along] >= opening.centre[along] + half[along]
		var tall := blocker.bottom <= opening.centre.y - half.y
		if reaches and across and tall and blocker.top >= opening.centre.y + half.y:
			return true
	return false


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
	for stack: Array in CellBoxes.stacked(layout.structure, layout.rooms, layout):
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
