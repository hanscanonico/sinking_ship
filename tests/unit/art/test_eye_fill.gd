extends GutTest

const MAIN := ShipPower.Power.MAIN
const EMERGENCY := ShipPower.Power.EMERGENCY
const DARK := ShipPower.Power.DARK


func test_a_lit_room_lends_the_eye_no_fill() -> void:
	assert_eq(EyeFill.share(MAIN, false), 0.0)


func test_a_dark_room_lends_the_eye_all_of_it() -> void:
	assert_eq(EyeFill.share(DARK, false), 1.0)


func test_emergency_power_lends_the_eye_some() -> void:
	var some := EyeFill.share(EMERGENCY, false)
	assert_eq(some, EyeFill.EMERGENCY_SHARE)
	assert_between(some, 0.1, 0.9, "some, never none nor all")


func test_under_the_water_the_eye_has_no_fill() -> void:
	for power: int in [MAIN, EMERGENCY, DARK]:
		assert_eq(EyeFill.share(power, true), 0.0)


func test_the_fill_stays_faint() -> void:
	# A floor of light, not a lamp: dimmer than a room's lamp, and never shadowed.
	assert_lt(EyeFill.ENERGY, ShipLamp.ENERGY * ShipLamp.EMERGENCY_GLOW)
	assert_gt(EyeFill.ENERGY, 0.0)


func test_the_fill_fades_in_over_its_fade_and_holds() -> void:
	var share := 0.0
	var steps := 0
	while share < 1.0:
		share = EyeFill.faded(share, 1.0, 1.0 / 30.0)
		steps += 1
	assert_almost_eq(steps / 30.0, EyeFill.FADE, 1.0 / 30.0)
	assert_eq(EyeFill.faded(1.0, 1.0, 1.0 / 30.0), 1.0, "holds")
	assert_lt(EyeFill.faded(1.0, 0.0, 1.0 / 30.0), 1.0, "and fades out")
