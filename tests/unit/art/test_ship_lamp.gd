extends GutTest

## A minute of a lamp's clock, sampled finer than it flickers.
const SAMPLES := 1800


func _dimmed(lamp_height: float, floor_height: float) -> int:
	var dimmed := 0
	for sample in SAMPLES:
		if ShipLamp.glow(lamp_height, floor_height, sample / 30.0) < 1.0:
			dimmed += 1
	return dimmed


func test_a_lamp_burns_steady_while_its_room_is_dry() -> void:
	assert_eq(_dimmed(2.4, 0.1), 0)


func test_a_lamp_is_out_once_the_sea_is_over_it() -> void:
	for sample in SAMPLES:
		assert_eq(ShipLamp.glow(-0.01, -2.2, sample / 30.0), 0.0)


func test_a_flooding_room_s_lamp_flickers_more_as_the_sea_climbs_to_it() -> void:
	var water_at_the_floor := _dimmed(2.1, -0.05)
	var water_near_the_lamp := _dimmed(0.2, -1.9)
	assert_gt(water_at_the_floor, 0)
	assert_lt(water_near_the_lamp, SAMPLES)
	assert_gt(water_near_the_lamp, water_at_the_floor * 2)
