extends GutTest
## FloorClearances finds each platform's clearance from the rest of its cell — the
## nearest height of the other surfaces there, a ramp anywhere between its ends — as
## trying every other surface of the cell finds it, to the last bit: on cells crowded
## with platforms and blockers at shared heights, ramps between them, as a ship on her
## side has.

const SLACK := 0.000001


## The clearances found the long way: every platform against every other surface of
## its cell.
static func _all_against_all(
	grid: SpatialIndex,
	tops: PackedFloat64Array,
	bottoms: PackedFloat64Array,
	first_ramp: int,
	first_top: int
) -> Array[PackedFloat64Array]:
	var found: Array[PackedFloat64Array] = []
	for cell in grid.cell_count():
		var near := grid.in_cell(cell)
		var clearances := PackedFloat64Array()
		for surface: int in near:
			if surface >= first_ramp:
				continue
			var height := tops[surface]
			var clearance := INF
			for other: int in near:
				if other == surface:
					continue
				var ramp := other >= first_ramp and other < first_top
				var low := bottoms[other] if ramp else tops[other]
				clearance = minf(clearance, maxf(low - height, height - tops[other]))
			clearances.append(clearance - SLACK)
		found.append(clearances)
	return found


func test_each_platform_clears_the_rest_as_trying_them_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var platforms := 300
	var ramps := 40
	var blockers := 260
	var tops := PackedFloat64Array()
	var bottoms := PackedFloat64Array()
	var areas: Array[Rect2] = []
	for surface in platforms + ramps + blockers:
		# Heights on a coarse grid of a few values, so many surfaces share one, and a few
		# off it.
		var top := rng.randi_range(0, 12) * 0.5 + (0.0 if rng.randf() < 0.8 else rng.randf())
		var bottom := top - rng.randf_range(0.2, 3.0)
		tops.append(top)
		bottoms.append(bottom)
		var at := Vector2(rng.randf_range(0.0, 30.0), rng.randf_range(0.0, 12.0))
		areas.append(Rect2(at, Vector2(rng.randf_range(0.5, 9.0), rng.randf_range(0.5, 4.0))))
	var grid := SpatialIndex.new(Rect2(0.0, 0.0, 40.0, 16.0), 2.0)
	for surface in tops.size():
		grid.insert(surface, areas[surface], bottoms[surface], tops[surface])
	var first_ramp := platforms
	var first_top := platforms + ramps
	var index := FloorClearances.new(grid, tops, bottoms, first_ramp, first_top, SLACK)
	var expected := _all_against_all(grid, tops, bottoms, first_ramp, first_top)
	var crowded := 0
	for cell in grid.cell_count():
		assert_eq(index.clearances[cell], expected[cell], "cell %d's clearances" % cell)
		var on := PackedInt32Array()
		for surface: int in grid.in_cell(cell):
			if surface < first_ramp:
				on.append(surface)
		assert_eq(index.floors[cell], on, "cell %d's platforms, in its order" % cell)
		crowded += 1 if grid.in_cell(cell).size() > 50 else 0
	assert_gt(crowded, 10, "a good many crowded cells")


func test_a_platform_alone_has_its_cell_clear() -> void:
	var grid := SpatialIndex.new(Rect2(0.0, 0.0, 4.0, 4.0), 2.0)
	grid.insert(0, Rect2(0.5, 0.5, 1.0, 1.0), 0.0, 1.0)
	var index := FloorClearances.new(
		grid, PackedFloat64Array([1.0]), PackedFloat64Array([0.0]), 1, 1, SLACK
	)
	assert_eq(index.clearances[0], PackedFloat64Array([INF]), "nothing else over its cell")
