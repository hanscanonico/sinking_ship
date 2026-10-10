extends GutTest
## The spatial index (SH18): a uniform grid in ship space behind Surfaces, the bodies'
## contacts and the shoves' candidates, whose answers are a scan's in a scan's order —
## it changes how fast the sim answers, never what (D4).

const LEVELS: Array[float] = [-5.6, -2.8, 0.0, 2.8, 5.6]
## The grids the brute-force check builds, metres a cell: finer than the bodies, the
## data's, and coarser than the steamer's rooms.
const SIDES: Array[float] = [0.5, 1.0, 2.5]
## Their bands, metres high: finer than a step, about a deck, and one band.
const BANDS: Array[float] = [0.5, 3.0, INF]
## How many cells a query reaches before it scans: always, a short line's, never.
const SCANS: Array[float] = [0.0, 8.0, INF]

var _index: IndexRules
var _cells: Array[float] = []


func before_each() -> void:
	_index = IndexRules.load_default()
	_cells = [_index.surface_cell, _index.body_cell, _index.surface_band, _index.scan_over]


func after_each() -> void:
	_index.surface_cell = _cells[0]
	_index.body_cell = _cells[1]
	_index.surface_band = _cells[2]
	_index.scan_over = _cells[3]


## The data's grid with every cell [param side] metres square — INF for one cell — in
## bands [param band] high, scanning past [param scan] cells.
func _grid(side: float, band := INF, scan := INF) -> IndexRules:
	var made := IndexRules.new()
	made.surface_cell = side
	made.body_cell = side
	made.surface_band = band
	made.scan_over = scan
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


## A point of [param dice]'s over the layout and past its edges, above and below its
## decks, on a quarter-metre one time in two and level with a deck one time in four.
func _point(dice: RandomNumberGenerator) -> Vector3:
	var point := Vector3(
		dice.randf_range(-24.0, 24.0), dice.randf_range(-7.0, 9.0), dice.randf_range(-12.0, 12.0)
	)
	if dice.randi_range(0, 3) == 0:
		point.y = LEVELS[dice.randi_range(0, LEVELS.size() - 1)]
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
	var kinds: Array[String] = []
	for side: float in SIDES:
		for band: float in BANDS:
			for scan: float in SCANS:
				kinds.append("%s m cells, %s m bands, scan over %s" % [side, band, scan])
	for layout_count in 6:
		var layout := _random_layout(dice)
		var scan := Surfaces.new(layout, _grid(INF))
		var grids: Array[Surfaces] = []
		for side: float in SIDES:
			for band: float in BANDS:
				for over: float in SCANS:
					grids.append(Surfaces.new(layout, _grid(side, band, over)))
		for query in 150:
			var from := _point(dice)
			var to := from + Vector3(dice.randf_range(-6.0, 6.0), 0.0, dice.randf_range(-6.0, 6.0))
			if dice.randi_range(0, 3) == 0:
				to.y = LEVELS[dice.randi_range(0, LEVELS.size() - 1)]
			var expected := _answers(scan, from, to, pose)
			for grid in grids.size():
				var answered := _answers(grids[grid], from, to, pose)
				assert_eq(
					answered, expected, "layout %d, %s: %s" % [layout_count, kinds[grid], from]
				)
	# The grid itself against a scan of every item: near() holds every item whose area
	# meets the box and whose heights meet the query's, and they are a scan's, in a scan's
	# order.
	for side: float in SIDES:
		for band: float in BANDS:
			for over: float in SCANS:
				var index := SpatialIndex.new(
					Rect2(-20.0, -8.0, 40.0, 16.0), side, Vector2(-6.0, 6.0), band, over
				)
				var areas: Array[Rect2] = []
				var heights: Array[Vector2] = []
				for item in 80:
					var corner := Vector2(_quarter(dice, -26.0, 26.0), _quarter(dice, -12.0, 12.0))
					var size := Vector2(_quarter(dice, 0.0, 4.0), _quarter(dice, 0.0, 4.0))
					var bottom := _quarter(dice, -8.0, 8.0)
					areas.append(Rect2(corner, size))
					heights.append(Vector2(bottom, bottom + _quarter(dice, 0.0, 4.0)))
					index.insert(item, areas[item], heights[item].x, heights[item].y)
				for query in 300:
					var corner := Vector2(_quarter(dice, -28.0, 28.0), _quarter(dice, -14.0, 14.0))
					var size := Vector2(_quarter(dice, 0.0, 8.0), _quarter(dice, 0.0, 3.0))
					var box := Rect2(corner, size)
					var low := _quarter(dice, -9.0, 9.0)
					var high := low + _quarter(dice, 0.0, 3.0)
					var scanned := PackedInt32Array()
					for item in areas.size():
						var meets := heights[item].x <= high and heights[item].y >= low
						if meets and areas[item].intersects(box, true):
							scanned.append(item)
					var met := PackedInt32Array()
					for item: int in index.near(box, low, high):
						var meets := heights[item].x <= high and heights[item].y >= low
						if meets and areas[item].intersects(box, true):
							met.append(item)
					assert_eq(met, scanned, "%s m, %s m, %s: box %s" % [side, band, over, box])


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
		_index.surface_band = _cells[2] if way == 0 else INF
		_index.scan_over = _cells[3] if way == 0 else INF
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
	# A shove at nearly its full reach lands on a body whose square is wholly in the next
	# cell: the candidates come from a box grown by the reach, not by a body alone.
	var far := SimFixtures.sim(2)
	SimFixtures.place(far, 0, Vector3(line - 0.6, 0.0, 0.0))
	SimFixtures.place(far, 1, Vector3(line + 1.0, 0.0, 0.0))
	var reached := SimFixtures.step(far, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	reached.append_array(SimFixtures.step(far, {0: SimFixtures.frame(0)}, 12))
	var far_landed := reached.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.SHOVE_LANDED
	)
	assert_eq(far_landed.size(), 1, "a shove 0.8 m past both edges lands in the next cell")


func test_surface_spanning_bands_is_found_from_either() -> void:
	var index := SpatialIndex.new(Rect2(0.0, 0.0, 10.0, 10.0), 2.0, Vector2(0.0, 6.0), 3.0)
	# Bands every 3 m from 0, the last at 6 m and over: the first item reaches from the
	# lowest into the next, the second from the next into the last, the third the lowest.
	index.insert(0, Rect2(1.0, 1.0, 2.0, 2.0), 2.0, 4.0)
	index.insert(1, Rect2(1.0, 1.0, 2.0, 2.0), 5.0, 6.0)
	index.insert(2, Rect2(1.0, 1.0, 2.0, 2.0), 0.0, 1.0)
	var box := Rect2(1.5, 1.5, 0.0, 0.0)
	assert_eq(index.near(box, 0.5, 1.5), PackedInt32Array([0, 2]), "from the lower band")
	assert_eq(index.near(box, 4.5, 5.5), PackedInt32Array([0, 1]), "from the upper band")
	assert_eq(index.near(box, 2.5, 3.5), PackedInt32Array([0, 1, 2]), "from both, each once")
	assert_eq(index.near(box, -9.0, -8.0), PackedInt32Array([0, 2]), "under them all: the lowest")
	assert_eq(index.near(box, 9.0, INF), PackedInt32Array([1]), "over them all: the highest")
	# A caller's own sum may round a hair past a band's foot: a query starting just over it
	# still meets an item whose top is just under it.
	index.insert(3, Rect2(1.0, 1.0, 2.0, 2.0), 2.9999999, 2.9999999)
	assert_has(index.near(box, 3.0000004, 3.5), 3, "a hair under the query's foot, a band down")
	# A stair from a deck up to the next crosses the bands between, and a wall stands
	# through them: a body finds the stair under its feet from either end, and the wall
	# holds it back with its feet at the wall's foot or a jump up its face.
	var layout := ShipLayout.new()
	for height: float in [0.0, 2.8]:
		var deck := ShipPlatform.new()
		deck.name = StringName("deck %s" % height)
		deck.area = Rect2(-6.0 if height == 0.0 else 4.0, -2.0, 2.0, 4.0)
		deck.height = height
		layout.platforms.append(deck)
	var stair := ShipRamp.new()
	stair.area = Rect2(-4.0, -1.0, 8.0, 2.0)
	stair.axis = ShipRamp.Axis.X
	stair.start_height = 0.0
	stair.end_height = 2.8
	layout.ramps.append(stair)
	var wall := ShipBlocker.new()
	wall.area = Rect2(-4.0, 6.0, 8.0, 0.2)
	wall.bottom = 0.0
	wall.top = 2.8
	layout.blockers.append(wall)
	var rules := SimFixtures.rules()
	var banded := Surfaces.new(layout, _grid(1.0, 0.5))
	for x: float in [-3.9, 3.9]:
		var feet := Vector3(x, stair.height_at(x, 0.0), 0.0)
		assert_eq(banded.under(feet, rules.step_height), banded.ramp_surface(0), "on it at %s" % x)
	for y: float in [0.0, 2.0]:
		var beside := Vector3(0.0, y, 6.0 - rules.body_radius * 0.5)
		var contacts := banded.obstacle_contacts(
			beside, rules.body_radius, rules.body_height, rules.step_height
		)
		assert_eq(contacts.size(), 1, "the wall holds back feet at %s m" % y)


func test_long_line_scans_as_the_grid_gathers() -> void:
	# The fixture's surfaces, each from its foot to its top, on a grid of bands and on one
	# that scans every line past eight cells.
	var layout := TitanicScale.layout()
	var bounds := SpatialIndex.bounds_of(layout)
	var heights := SpatialIndex.heights_of(layout)
	var grid := SpatialIndex.new(bounds, 1.0, heights, 3.0)
	var scans := SpatialIndex.new(bounds, 1.0, heights, 3.0, 8.0)
	var areas: Array[Rect2] = []
	var extents: Array[Vector2] = []
	for platform: ShipPlatform in layout.platforms:
		areas.append(platform.area)
		extents.append(Vector2(platform.height, platform.height))
	for ramp: ShipRamp in layout.ramps:
		areas.append(ramp.area)
		extents.append(Vector2(ramp.start_height, ramp.end_height))
	for blocker: ShipBlocker in layout.blockers:
		var square := Vector2(blocker.radius, blocker.radius)
		var round := Rect2(blocker.centre - square, square * 2.0)
		areas.append(blocker.area if blocker.shape == ShipBlocker.Shape.BOX else round)
		extents.append(Vector2(blocker.bottom, blocker.top))
	for item in areas.size():
		grid.insert(item, areas[item], extents[item].x, extents[item].y)
		scans.insert(item, areas[item], extents[item].x, extents[item].y)
	var dice := RandomNumberGenerator.new()
	dice.seed = 1803
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	var eye := Vector3.UP * SimFixtures.rules().head_height()
	var scan := Surfaces.new(layout, _grid(INF))
	var banded := Surfaces.new(layout, _grid(1.0, 3.0))
	var falling_back := Surfaces.new(layout, _grid(1.0, 3.0, 8.0))
	for line in 60:
		var level := dice.randi_range(0, TitanicScale.DECKS - 1) - TitanicScale.MAIN
		var deck := level * TitanicScale.DECK_SPACING
		var from := Vector3(dice.randf_range(-130.0, 70.0), deck, dice.randf_range(-13.0, 13.0))
		var to := from + Vector3(dice.randf_range(10.0, 60.0), 0.0, dice.randf_range(-6.0, 6.0))
		var box := Rect2(Vector2(from.x, from.z), Vector2.ZERO).expand(Vector2(to.x, to.z))
		var scanned := scans.near(box, deck, deck + 1.7)
		assert_eq(scanned.size(), areas.size(), "a line past eight cells is handed everything")
		var met: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
		for way in 2:
			for item: int in grid.near(box, deck, deck + 1.7) if way == 0 else scanned:
				var meets := extents[item].x <= deck + 1.7 and extents[item].y >= deck
				if meets and areas[item].intersects(box, true):
					met[way].append(item)
		assert_eq(met[1], met[0], "a %.0f m line meets the same, in the same order" % box.size.x)
		var seen := scan.line_of_sight(from + eye, to + eye, pose)
		assert_eq(banded.line_of_sight(from + eye, to + eye, pose), seen, "through the grid")
		assert_eq(falling_back.line_of_sight(from + eye, to + eye, pose), seen, "scanning")
