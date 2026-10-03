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


## Rooms of the steamer, floor to ceiling: three on the lower deck, the saloon over
## the engine room.
const ENGINE_ROOM := AABB(Vector3(-3.0, -2.6, -4.8), Vector3(7.0, 2.6, 9.6))
const FORWARD_HOLD := AABB(Vector3(4.0, -2.6, -3.8), Vector3(11.0, 2.6, 7.6))
const AFT_PORT_CABIN := AABB(Vector3(-13.0, -2.6, -4.8), Vector3(4.6, 2.6, 4.1))
const SALOON := AABB(Vector3(0.0, 0.0, -3.3), Vector3(2.9, 2.5, 6.6))


func test_a_lamp_lights_the_room_the_eye_stands_in() -> void:
	assert_true(ShipLamp.relevant(Vector3(0.5, -1.0, 0.0), ENGINE_ROOM, true))


func test_a_lamp_lights_the_next_room_through_its_doorway() -> void:
	# In the engine room's forward doorway, looking into the hold.
	assert_true(ShipLamp.relevant(Vector3(3.8, -1.0, 0.0), FORWARD_HOLD, true))


func test_a_lamp_far_off_or_a_deck_away_is_out() -> void:
	assert_false(ShipLamp.relevant(Vector3(12.0, -1.0, 0.0), AFT_PORT_CABIN, true))
	assert_false(ShipLamp.relevant(Vector3(1.5, 1.6, 0.0), AFT_PORT_CABIN, true))


func test_a_lamp_lights_nothing_through_the_deck_over_or_under_the_eye() -> void:
	assert_false(ShipLamp.relevant(Vector3(1.0, -1.0, 0.0), SALOON, true))
	assert_false(ShipLamp.relevant(Vector3(1.0, 1.6, 0.0), ENGINE_ROOM, true))


func test_a_wrecked_lamp_stays_out_wherever_the_eye_is() -> void:
	assert_false(ShipLamp.relevant(Vector3(0.5, -1.0, 0.0), ENGINE_ROOM, false))
