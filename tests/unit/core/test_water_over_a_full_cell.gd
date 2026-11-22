extends GutTest
## The water over a point in a full cell (ShipPose.water_height): where the cell over it —
## or the sea, over her topmost — stands lower than the full cell's ceiling there, its top
## is that ceiling, never the lower water's level under the very floor asked about. A
## trimmed ship fills a room at its low end first, under a deck still dry: a chair afloat
## there rides under that ceiling and is not set down on the floor.

## Her trim, in degrees, down by the stern (-x), and how far she has sunk, in metres.
const TRIM_DEG := 9.0
const SUNK := 6.0
## How long and wide her cells are — the flat deck's — and how high each one stands.
const HALF_LONG := 15.0
const HALF_WIDE := 4.0
const TALL := 2.5
## The world height the room's water stands at: over its ceiling aft of x = 9.79, a
## free surface under it forward of there.
const ROOM_LEVEL := -2.0
## Where the room is full under a deck dry there, and where it has a surface of its own.
const FULL_X := 5.0
const FREE_X := 12.0
## How far over the room's ceiling the deck's planks lie in the chair's test: clear of a
## chair riding water that tops at the ceiling, so it floats free of the slab.
const CLEAR := 0.7


static func _cell(cell_name: StringName, floor_y: float) -> FloodCell:
	var made := FloodCell.new()
	made.name = cell_name
	made.low = Vector3(-HALF_LONG, floor_y, -HALF_WIDE)
	made.high = Vector3(HALF_LONG, floor_y + TALL, HALF_WIDE)
	return made


## The trimmed pose of [param count] cells stacked from the flat deck up, the room first,
## their water at world heights [param levels], she [param sunk] metres down.
static func _pose(count: int, levels: PackedFloat64Array, sunk := SUNK) -> ShipPose:
	var structure := ShipStructure.new()
	var cells: Array[FloodCell] = []
	for index in count:
		cells.append(_cell(StringName("cell_%d" % index), index * TALL))
	structure.cells = cells
	var turned := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(TRIM_DEG))
	var pose := ShipPose.new(sunk, TRIM_DEG, 0.0, Transform3D(turned, Vector3(0.0, -sunk, 0.0)))
	pose.cells = CellMap.new(structure)
	pose.levels = levels
	var pockets := PackedFloat64Array()
	pockets.resize(count)
	pose.pockets = pockets
	return pose


## The level of a dry cell whose floor is [param floor_y], she SUNK metres down: its floor's
## lowest corner in the world, as the physics leaves a cell holding nothing.
static func _dry(floor_y: float) -> float:
	var turned := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(TRIM_DEG))
	return (Transform3D(turned, Vector3(0.0, -SUNK, 0.0)) * Vector3(-HALF_LONG, floor_y, 0.0)).y


func test_the_water_over_a_full_cell_under_a_dry_one_tops_at_its_ceiling() -> void:
	var pose := _pose(2, PackedFloat64Array([ROOM_LEVEL, _dry(TALL)]))
	var at := Vector3(FULL_X, 0.5, 0.0)
	assert_gt(ROOM_LEVEL, pose.world_height(Vector3(FULL_X, TALL, 0.0)), "the room is full there")
	assert_lt(_dry(TALL), pose.world_height(Vector3(FULL_X, TALL, 0.0)), "the deck over it dry")
	assert_almost_eq(pose.water_height(at), TALL, 1e-9, "the room's ceiling")


func test_the_water_is_never_under_the_floor_asked_about_and_runs_on_across_the_line() -> void:
	var pose := _pose(2, PackedFloat64Array([ROOM_LEVEL, _dry(TALL)]))
	var before := pose.water_height(Vector3(-14.9, 0.5, 0.0))
	var x := -14.8
	while x < 14.95:
		var water := pose.water_height(Vector3(x, 0.5, 0.0))
		assert_gt(water, 0.0, "over the room's floor at x %.1f" % x)
		assert_almost_eq(water, before, 0.05, "no step in the water at x %.1f" % x)
		before = water
		x += 0.1
	var free := Vector3(FREE_X, 0.5, 0.0)
	assert_almost_eq(pose.water_height(free), pose.height_of(ROOM_LEVEL, free), 1e-9, "its own")
	assert_lt(pose.water_height(free), TALL, "a free surface under the ceiling, forward")


func test_a_partly_filled_cell_over_a_full_one_gives_its_own_surface_where_it_is_wet() -> void:
	# The deck over the room holds water aft of x = 3.39, its floor bare forward of there.
	var pose := _pose(2, PackedFloat64Array([ROOM_LEVEL, -3.0]))
	var wet := Vector3(0.0, 0.5, 0.0)
	assert_almost_eq(pose.water_height(wet), pose.height_of(-3.0, wet), 1e-9, "the deck's water")
	assert_gt(pose.water_height(wet), TALL, "over the room's ceiling")
	assert_almost_eq(pose.water_height(Vector3(FULL_X, 0.5, 0.0)), TALL, 1e-9, "bare: the ceiling")


func test_a_full_stack_tops_at_the_highest_full_cell_s_ceiling_under_a_dry_one() -> void:
	var pose := _pose(3, PackedFloat64Array([ROOM_LEVEL, ROOM_LEVEL, _dry(2.0 * TALL)]))
	# Both are full aft of x = -6.0: the second's ceiling is under their water there.
	var at := Vector3(-10.0, 0.5, 0.0)
	assert_almost_eq(pose.water_height(at), 2.0 * TALL, 1e-9, "the second cell's ceiling")
	var wet := _pose(3, PackedFloat64Array([ROOM_LEVEL, ROOM_LEVEL, -1.0]))
	assert_almost_eq(wet.water_height(at), wet.height_of(-1.0, at), 1e-9, "the third's own water")


func test_a_full_topmost_cell_tops_at_its_ceiling_over_the_sea_and_at_the_sea_under_it() -> void:
	# Water held 1.5 m over the sea, as a stern lifting out carries it.
	var pose := _pose(1, PackedFloat64Array([1.5]))
	var under := Vector3(0.0, 0.5, 0.0)
	assert_lt(pose.world_height(Vector3(0.0, TALL, 0.0)), 0.0, "its ceiling under the sea there")
	assert_almost_eq(pose.water_height(under), pose.height_of(0.0, under), 1e-9, "the sea's")
	var lifted := _pose(1, PackedFloat64Array([5.0]), 0.0)
	var over := Vector3(10.0, 0.5, 0.0)
	assert_gt(lifted.world_height(Vector3(10.0, TALL, 0.0)), 0.0, "its ceiling over the sea")
	assert_almost_eq(lifted.water_height(over), TALL, 1e-9, "full to its ceiling")


func test_a_chair_afloat_in_a_full_room_under_a_dry_deck_is_not_set_down() -> void:
	var chairs: Array[ShipProp] = [SimFixtures.chair(Vector3(FULL_X, 0.0, 0.0))]
	var layout := SimFixtures.crated(chairs)
	layout.platforms = layout.platforms.duplicate()
	var roof := ShipPlatform.new()
	roof.name = &"roof"
	roof.area = Rect2(-HALF_LONG, -HALF_WIDE, 2.0 * HALF_LONG, 2.0 * HALF_WIDE)
	roof.height = TALL + CLEAR
	layout.platforms.append(roof)
	var sim := SimFixtures.sim(1, null, layout)
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -2.0))
	var hazards := Hazards.new(sim.config, sim.surfaces)
	var pose := _pose(2, PackedFloat64Array([ROOM_LEVEL, _dry(TALL)]))
	var chair := sim.state.props[0]
	chair.body = PropState.Body.FLOATING
	chair.pos.y = TALL - chairs[0].prop_kind().draft
	var events: Array[SimEvent] = []
	for tick in Ticks.RATE:
		hazards.step(sim.state, pose, tick, events)
		if chair.body != PropState.Body.FLOATING:
			break
	assert_eq(chair.body, PropState.Body.FLOATING, "afloat still")
	assert_almost_eq(chair.pos.y, TALL - chairs[0].prop_kind().draft, 1e-5, "riding its water")
	assert_lt(chair.pos.x, 9.0, "in the room's full end")
	assert_eq(events.size(), 0, "nothing lifts it again")
