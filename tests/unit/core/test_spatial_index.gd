extends GutTest
## The spatial index (SH18): a uniform grid in ship space behind Surfaces, the bodies'
## contacts and the shoves' candidates, whose answers are a scan's in a scan's order —
## it changes how fast the sim answers, never what (D4).

const LEVELS: Array[float] = [-2.8, 0.0, 2.8]
## The grids the brute-force check builds, metres a cell: finer than the bodies, the
## data's, and coarser than the steamer's rooms.
const SIDES: Array[float] = [0.5, 1.0, 2.5]

var _index: IndexRules
var _cells: Array[float] = []


func before_each() -> void:
	_index = IndexRules.load_default()
	_cells = [_index.surface_cell, _index.body_cell]


func after_each() -> void:
	_index.surface_cell = _cells[0]
	_index.body_cell = _cells[1]


## The data's grid with every cell [param side] metres square — INF for one cell.
func _grid(side: float) -> IndexRules:
	var made := IndexRules.new()
	made.surface_cell = side
	made.body_cell = side
	return made


## [param dice]'s draw from [param low] to [param high] on a quarter-metre: edges and
## points on the grid's lines and on each other's.
func _quarter(dice: RandomNumberGenerator, low: float, high: float) -> float:
	return snappedf(dice.randf_range(low, high), 0.25)


## A layout of [param dice]'s: decks, stairs, walls and funnels anywhere, overlapping,
## with railings along some of the decks' edges.
func _random_layout(dice: RandomNumberGenerator) -> ShipLayout:
	var made := ShipLayout.new()
	for count in 12:
		var platform := ShipPlatform.new()
		platform.name = StringName("p%d" % count)
		var corner := Vector2(_quarter(dice, -20.0, 15.0), _quarter(dice, -8.0, 5.0))
		platform.area = Rect2(corner, Vector2(_quarter(dice, 1.0, 8.0), _quarter(dice, 1.0, 6.0)))
		platform.height = LEVELS[dice.randi_range(0, LEVELS.size() - 1)]
		made.platforms.append(platform)
		if dice.randi_range(0, 1) == 0:
			var railing := ShipRailing.new()
			railing.platform = count
			railing.from = platform.area.position
			railing.to = Vector2(platform.area.end.x, platform.area.position.y)
			made.railings.append(railing)
	for count in 5:
		var ramp := ShipRamp.new()
		var corner := Vector2(_quarter(dice, -20.0, 15.0), _quarter(dice, -8.0, 5.0))
		ramp.area = Rect2(corner, Vector2(_quarter(dice, 1.0, 5.0), _quarter(dice, 1.0, 3.0)))
		ramp.axis = ShipRamp.Axis.X if dice.randi_range(0, 1) == 0 else ShipRamp.Axis.Z
		ramp.start_height = LEVELS[dice.randi_range(0, LEVELS.size() - 1)]
		ramp.end_height = ramp.start_height + _quarter(dice, 0.5, 2.8)
		made.ramps.append(ramp)
	for count in 15:
		var blocker := ShipBlocker.new()
		if dice.randi_range(0, 2) == 0:
			blocker.shape = ShipBlocker.Shape.CYLINDER
			blocker.centre = Vector2(_quarter(dice, -20.0, 20.0), _quarter(dice, -8.0, 8.0))
			blocker.radius = _quarter(dice, 0.25, 2.0)
		else:
			blocker.shape = ShipBlocker.Shape.BOX
			var corner := Vector2(_quarter(dice, -20.0, 18.0), _quarter(dice, -8.0, 6.0))
			var size := Vector2(_quarter(dice, 0.25, 6.0), _quarter(dice, 0.25, 3.0))
			blocker.area = Rect2(corner, size)
		blocker.bottom = LEVELS[dice.randi_range(0, LEVELS.size() - 1)]
		blocker.top = blocker.bottom + _quarter(dice, 0.25, 3.0)
		made.blockers.append(blocker)
	return made


## A point of [param dice]'s over the layout and past its edges, on a quarter-metre one
## time in two.
func _point(dice: RandomNumberGenerator) -> Vector3:
	var point := Vector3(
		dice.randf_range(-24.0, 24.0), dice.randf_range(-4.0, 5.0), dice.randf_range(-12.0, 12.0)
	)
	return point.snappedf(0.25) if dice.randi_range(0, 1) == 0 else point


## [param contacts] as values to compare.
func _told(contacts: Array[Surfaces.Contact]) -> Array:
	var told := []
	for contact: Surfaces.Contact in contacts:
		told.append([contact.normal, contact.depth, contact.railing])
	return told


## Every query the index stands behind, asked of [param surfaces] at [param from] and
## [param to].
func _answers(surfaces: Surfaces, from: Vector3, to: Vector3, pose: ShipPose) -> Array:
	var rules := SimFixtures.rules()
	var step := rules.step_height
	var radius := rules.body_radius
	var tall := rules.body_height
	var eye := Vector3.UP * rules.head_height()
	return [
		surfaces.under(from, step),
		surfaces.landing(from),
		surfaces.ceiling(from, step),
		_told(surfaces.obstacle_contacts(from, radius, tall, step)),
		surfaces.blocked(from, to, tall, step),
		surfaces.line_of_sight(from + eye, to + eye, pose),
		_told(
			surfaces.airborne_rail_contacts(
				from, Vector2(to.x, to.z), radius, tall, rules.railing_height
			)
		),
	]


func test_queries_match_brute_force_on_random_layouts() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 1801
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	for layout_count in 6:
		var layout := _random_layout(dice)
		var scan := Surfaces.new(layout, _grid(INF))
		var grids: Array[Surfaces] = []
		for side: float in SIDES:
			grids.append(Surfaces.new(layout, _grid(side)))
		for query in 150:
			var from := _point(dice)
			var to := from + Vector3(dice.randf_range(-6.0, 6.0), 0.0, dice.randf_range(-6.0, 6.0))
			var expected := _answers(scan, from, to, pose)
			for grid in grids.size():
				var answered := _answers(grids[grid], from, to, pose)
				assert_eq(
					answered, expected, "layout %d, %s m: %s" % [layout_count, SIDES[grid], from]
				)
	# The grid itself against a scan of every item: near() holds every item whose area
	# meets the box, and they are a scan's, in a scan's order.
	for side: float in SIDES:
		var index := SpatialIndex.new(Rect2(-20.0, -8.0, 40.0, 16.0), side)
		var areas: Array[Rect2] = []
		for item in 80:
			var corner := Vector2(_quarter(dice, -26.0, 26.0), _quarter(dice, -12.0, 12.0))
			var size := Vector2(_quarter(dice, 0.0, 4.0), _quarter(dice, 0.0, 4.0))
			areas.append(Rect2(corner, size))
			index.insert(item, areas[item])
		for query in 300:
			var corner := Vector2(_quarter(dice, -28.0, 28.0), _quarter(dice, -14.0, 14.0))
			var box := Rect2(corner, Vector2(_quarter(dice, 0.0, 8.0), _quarter(dice, 0.0, 3.0)))
			var scanned := PackedInt32Array()
			for item in areas.size():
				if areas[item].intersects(box, true):
					scanned.append(item)
			var met := PackedInt32Array()
			for item: int in index.near(box):
				if areas[item].intersects(box, true):
					met.append(item)
			assert_eq(met, scanned, "%s m, box %s" % [side, box])


func test_iteration_order_is_deterministic() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 1802
	var built: Array[SpatialIndex] = []
	for count in 2:
		built.append(SpatialIndex.new(Rect2(0.0, 0.0, 30.0, 10.0), 2.0))
	for item in 60:
		var corner := Vector2(dice.randf_range(-2.0, 30.0), dice.randf_range(-2.0, 10.0))
		var area := Rect2(corner, Vector2(dice.randf_range(0.0, 5.0), dice.randf_range(0.0, 5.0)))
		for index: SpatialIndex in built:
			index.insert(item, area)
	for cell in built[0].cell_count():
		var listed := built[0].in_cell(cell)
		for at in range(1, listed.size()):
			assert_lt(listed[at - 1], listed[at], "a cell lists its items as they went in")
	for query in 200:
		var corner := Vector2(dice.randf_range(-4.0, 32.0), dice.randf_range(-4.0, 12.0))
		var box := Rect2(corner, Vector2(dice.randf_range(0.0, 9.0), dice.randf_range(0.0, 4.0)))
		var first := built[0].near(box).duplicate()
		for at in range(1, first.size()):
			assert_lt(first[at - 1], first[at], "ascending, each once")
		assert_eq(built[1].near(box), first, "a second grid built the same answers the same")
		assert_eq(built[0].near(box), first, "asked again — a block it keeps — the same")
	# Bodies pressed together push apart pair by pair in seat order, each push moving the
	# next pair: a crowd on a grid of the data's cells ends every tick exactly where it
	# ends with one cell, a scan of every pair. Each pair below stands across a line of the
	# grid, out of touch as the pass begins. Of the first three, the first two overlap by
	# 0.1 m, and pushing apart carries the second into the third, a hair farther than
	# touching; the next three stand on one spot, and their first two pushes carry the
	# second 0.7 m into the fourth, 1.25 m off. The last walks and shoves.
	var line := -15.0 + 8.0 * _cells[1]
	var spot := Vector3(line - 0.825, 0.0, 0.0)
	var next := line + _cells[1] * 2.0
	var spots: Array[Vector3] = [
		Vector3(next - 1.115, 0.0, 3.0),
		Vector3(next - 0.415, 0.0, 3.0),
		Vector3(next + 0.415, 0.0, 3.0),
		spot,
		spot,
		spot,
		spot + Vector3(1.25, 0.0, 0.0),
		Vector3(next + 4.0, 0.0, -2.0),
	]
	var snapshots: Array[Array] = [[], []]
	for way in 2:
		_index.surface_cell = _cells[0] if way == 0 else INF
		_index.body_cell = _cells[1] if way == 0 else INF
		var sim := SimFixtures.sim(8)
		for seat in 8:
			SimFixtures.place(sim, seat, spots[seat], 90.0 * seat)
		var frames := {}
		frames[7] = SimFixtures.frame(7, Vector2.LEFT, InputFrame.SHOVE)
		for tick in 45:
			SimFixtures.step(sim, frames)
			snapshots[way].append(sim.snapshot())
	assert_eq(snapshots[0], snapshots[1], "the crowd moves, pushes and shoves as without the index")


func test_body_crossing_cells_is_found_from_both() -> void:
	var index := SpatialIndex.new(Rect2(0.0, 0.0, 10.0, 10.0), 2.0)
	# Its circle's square from 3.7 to 4.5 along x crosses the line at 4, and the corner
	# at (4, 6) too.
	index.insert(0, Rect2(3.7, 5.7, 0.8, 0.8))
	index.insert(1, Rect2(8.0, 8.0, 0.8, 0.8))
	for box: Rect2 in [
		Rect2(3.0, 5.0, 0.5, 0.5),
		Rect2(4.5, 5.0, 0.5, 0.5),
		Rect2(3.0, 6.5, 0.5, 0.5),
		Rect2(4.5, 6.5, 0.5, 0.5),
	]:
		assert_eq(index.near(box), PackedInt32Array([0]), "found from the cell of %s" % box)
	# Two bodies touching across a line of the bodies' grid — the flat deck's cells run
	# from x -15, every 2 m — are pushed apart, and a shove from one side lands across it.
	var sim := SimFixtures.sim(2)
	var line := -15.0 + 8.0 * _index.body_cell
	SimFixtures.place(sim, 0, Vector3(line - 0.3, 0.0, 0.0))
	SimFixtures.place(sim, 1, Vector3(line + 0.3, 0.0, 0.0))
	SimFixtures.step(sim)
	var apart := sim.state.seats[1].pos.x - sim.state.seats[0].pos.x
	assert_almost_eq(apart, SimFixtures.rules().body_radius * 2.0, 0.0001, "pushed apart")
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	events.append_array(SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 12))
	var landed := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.SHOVE_LANDED
	)
	assert_eq(landed.size(), 1, "the shove lands across the line")
