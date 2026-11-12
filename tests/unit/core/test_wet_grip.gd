extends GutTest
## Wet grip (#620): a body standing in water holds a tilted deck less — its wet soles keep
## wet_grip of their dry friction, and the water carries the share of its weight the
## depth is of its height — at its grip angle and at its stand limit alike.

## How far the flat deck stands out of the sea in these matches, in metres.
const FREEBOARD := 0.4
const START_X := -8.0


func _rules() -> BrawlRules:
	return SimFixtures.rules()


## A match of one seat on the flat deck standing FREEBOARD out of the sea, heeled
## [param heel_deg] and sunk by as much again as [param sunk], the seat with Sure footing
## when [param sure] says so.
func _sim(heel_deg: float, sunk: float, sure := false) -> MatchSim:
	var sinking := SimFixtures.scenario([[0.0, FREEBOARD + sunk, 0.0, heel_deg]])
	var layout := SimFixtures.low_deck(FREEBOARD)
	return SimFixtures.kind_sim(SimFixtures.sure_footing(), sure, 1, layout, sinking)


## Where on the deck at x START_X the sea stands [param depth] deep over it under
## [param sim]'s pose, to a centimetre; fails the test when nowhere does.
func _spot(sim: MatchSim, depth: float) -> Vector3:
	var deck := SimFixtures.low_deck(FREEBOARD).platforms[0]
	var best := Vector3.INF
	var off := INF
	var z := deck.area.position.y + _rules().body_radius
	while z < deck.area.end.y - _rules().body_radius:
		var at := Vector3(START_X, deck.height, z)
		var over := sim.pose().water_height(at) - deck.height
		if absf(over - depth) < off:
			off = absf(over - depth)
			best = at
		z += 0.01
	assert_lt(off, 0.01, "the sea stands %s m deep somewhere on the deck" % depth)
	return best


## Seat 0 of [param sim] placed at [param at] and left idle a second: how far it went.
func _idle(sim: MatchSim, at: Vector3) -> float:
	SimFixtures.place(sim, 0, at)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	var player := sim.state.seats[0]
	assert_eq(player.body, PlayerState.Body.GROUNDED, "on its feet")
	return player.pos.distance_to(at)


func test_a_body_holds_a_deck_dry_that_it_slides_on_in_water() -> void:
	var heel := 12.0
	assert_lt(heel, _rules().grip_angle_deg, "under the dry grip angle")
	var dry := _sim(heel, -1.0)
	assert_eq(_idle(dry, Vector3(START_X, 0.0, 0.0)), 0.0, "dry, it holds")
	var wet := _sim(heel, 0.0)
	assert_gt(_idle(wet, _spot(wet, 0.1)), 0.01, "0.1 m deep, it slides")


## Past the wet stand limit a walker uphill only slides into the corner (Movement._slid):
## at 21° a body walks up out of a film of water but not out of water 0.25 m deep.
func test_deeper_water_lowers_the_slope_a_body_holds_at() -> void:
	var rules := _rules()
	assert_gt(
		rules.wet_angle(rules.grip_angle_deg, 0.1), rules.wet_angle(rules.grip_angle_deg, 0.25)
	)
	var heel := 21.0
	assert_lt(heel, rules.wet_angle(rules.stand_limit_deg, 0.05), "a film holds it")
	assert_gt(heel, rules.wet_angle(rules.stand_limit_deg, 0.25), "0.25 m deep does not")
	var climbed := {}
	for depth: float in [0.05, 0.25]:
		var sim := _sim(heel, 0.0)
		var at := _spot(sim, depth)
		SimFixtures.place(sim, 0, at)
		var gravity := sim.pose().ship_gravity(rules.gravity)
		var uphill := -Vector2(gravity.x, gravity.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, uphill)}, 5)
		var player := sim.state.seats[0]
		assert_eq(player.body, PlayerState.Body.GROUNDED, "%s m deep: on its feet" % depth)
		var moved := player.pos - at
		climbed[depth] = Vector2(moved.x, moved.z).dot(uphill)
	assert_gt(climbed[0.05], 0.0, "it walks up out of a film of water")
	assert_lt(climbed[0.25], 0.0, "it slides down in water 0.25 m deep")


func test_sure_footing_still_holds_steeper_in_the_same_water() -> void:
	var heel := 12.5
	for sure: bool in [false, true]:
		var sim := _sim(heel, 0.0, sure)
		var went := _idle(sim, _spot(sim, 0.1))
		if sure:
			assert_eq(went, 0.0, "with Sure footing it holds 0.1 m deep")
		else:
			assert_gt(went, 0.01, "without, it slides there")


func test_the_rules_hold_wet_grip_within_0_to_1() -> void:
	assert_eq(_rules().problems(), PackedStringArray(), "the shipped numbers hold")
	for grip: float in [-0.1, 1.1]:
		var rules: BrawlRules = _rules().duplicate()
		rules.wet_grip = grip
		assert_eq(
			rules.problems(),
			PackedStringArray(["brawl rules: wet_grip must be within 0…1"]),
			"wet_grip %s" % grip
		)
