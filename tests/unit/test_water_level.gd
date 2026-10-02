extends GutTest


func test_rises_at_its_rate_over_time() -> void:
	var water: WaterLevel = WaterLevel.new(0.0, 0.5, 10.0).advanced(4.0)
	assert_almost_eq(water.height, 2.0, 0.0001)
	assert_false(water.is_full())


func test_stops_at_its_maximum() -> void:
	var water: WaterLevel = WaterLevel.new(9.0, 1.0, 10.0).advanced(5.0)
	assert_eq(water.height, 10.0)
	assert_true(water.is_full())


func test_advancing_leaves_the_original_alone() -> void:
	var water: WaterLevel = WaterLevel.new(1.0, 1.0, 10.0)
	water.advanced(3.0)
	assert_eq(water.height, 1.0)


func test_time_never_runs_backwards() -> void:
	var water: WaterLevel = WaterLevel.new(2.0, 1.0, 10.0).advanced(-5.0)
	assert_eq(water.height, 2.0)
