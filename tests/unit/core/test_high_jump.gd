extends GutTest
## High jump (#307, #316): a seat that took it jumps as high as its kind says — 1.5 m as
## shipped (test_bonus_rules holds the data to it), where the brawl rules' jump stays under
## a railing's top — at the stamina any jump costs. Nothing about railings is its own: a
## railing holds back a body in the air only while its feet are under the rail's top, so a
## high jumper running at one clears it, and a shove landing on one in mid-air, its feet
## over the top, carries it over; a jumper without it is caught by the same rail.

const JUMP := InputFrame.JUMP
const SHOVE := InputFrame.SHOVE
const AIRBORNE := PlayerState.Body.AIRBORNE
const GROUNDED := PlayerState.Body.GROUNDED
const SWIMMING := PlayerState.Body.SWIMMING
## Longer than any jump, or a fall from one into the sea, is in the air.
const FLIGHT_LIMIT := 3 * Ticks.RATE
## Where seat 0 jumps from, along the flat deck: well aft of the gap in its railings.
const ALONG := -8.0
## The ticks from a jump's press to a shove's press that lands on the jumper a windup later,
## at about a high jump's apex — a jump without it already coming down, but still in the air.
const SHOVE_AFTER := 8


## A match of [param seats] on the flat deck played with High jump, seat 0 with one when
## [param high] says so.
func _sim(seats: int, high: bool) -> MatchSim:
	return SimFixtures.kind_sim(SimFixtures.high_jump(), high, seats, SimFixtures.deck())


## Steps [param sim], seat 0 sending [param frame], until it is out of the air.
func _land(sim: MatchSim, frame: InputFrame) -> void:
	var flown := 0
	while sim.state.seats[0].body == AIRBORNE and flown < FLIGHT_LIMIT:
		SimFixtures.step(sim, {0: frame})
		flown += 1


## A seat with High jump jumps as high as its kind says, over a railing's top; a seat
## without it as high as the brawl rules do, under it; and the jump costs both the same.
func test_a_high_jump_rises_to_its_kind_s_height_at_the_stamina_any_jump_costs() -> void:
	var rules := SimFixtures.rules()
	for high: bool in [false, true]:
		var sim := _sim(1, high)
		SimFixtures.place(sim, 0, Vector3.ZERO)
		var jumper := sim.state.seats[0]
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
		var spent := rules.stamina_max - jumper.stamina
		assert_almost_eq(spent, rules.jump_cost, 0.0001, "high %s: a jump's cost" % high)
		var apex := jumper.pos.y
		while jumper.body == AIRBORNE:
			SimFixtures.step(sim, {0: SimFixtures.frame(0)})
			apex = maxf(apex, jumper.pos.y)
		var height := SimFixtures.high_jump().jump_height if high else rules.jump_height
		assert_almost_eq(apex, height, 0.02, "high %s: its height" % high)
		assert_eq(apex > rules.railing_height, high, "high %s: over a railing's top" % high)
		assert_eq([jumper.body, jumper.pos.y], [GROUNDED, 0.0], "high %s: down again" % high)


## Running at the starboard rail and jumping a stride and a half short of it: a seat with
## High jump goes over it, its feet over the rail's top as it crosses, and down into the
## sea; a seat without it is held by the rail and comes down on deck inside it.
func test_a_high_jumper_clears_a_railing_a_jumper_without_it_is_caught() -> void:
	var edge := SimFixtures.deck().platforms[0].area.end.y
	for high: bool in [false, true]:
		var sim := _sim(1, high)
		SimFixtures.place(sim, 0, Vector3(ALONG, 0.0, edge - 2.0), 90.0)
		var run := SimFixtures.frame(0, Vector2.DOWN)
		SimFixtures.step(sim, {0: run}, 4)
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.DOWN, JUMP)})
		_land(sim, run)
		var jumper := sim.state.seats[0]
		if high:
			assert_eq(jumper.body, SWIMMING, "with High jump: over the rail, into the sea")
			assert_gt(jumper.pos.z, edge, "outside the rail")
		else:
			assert_eq(jumper.body, GROUNDED, "without: back on deck")
			assert_lt(jumper.pos.z, edge, "inside the rail")


## A shove landing on a jumper in mid-air sends it on as a shove sends anyone — here
## aslant toward the rail, slower across it than a vault, which nothing would hold back: a
## jumper with High jump, its feet over the rail's top as the shove lands, is carried over it
## and down into the sea; a jumper without it, its feet never that high, is caught by the
## rail and comes down on deck.
func test_a_mid_air_shove_carries_a_high_jumper_over_a_railing() -> void:
	var rules := SimFixtures.rules()
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var at := Vector3(ALONG, 0.0, edge - rules.body_radius - 0.05)
	for high: bool in [false, true]:
		var sim := _sim(2, high)
		SimFixtures.place(sim, 0, at)
		SimFixtures.place(sim, 1, at - Vector3(0.85, 0.0, 0.85), 45.0)
		var jumper := sim.state.seats[0]
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
		SimFixtures.step(sim, {}, SHOVE_AFTER - 1)
		SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, SHOVE)})
		var feet := NAN
		for _tick in Ticks.RATE:
			for event: SimEvent in SimFixtures.step(sim, {1: SimFixtures.frame(1)}):
				if event.kind == SimEvent.Kind.SHOVE_LANDED and event.target == 0:
					feet = jumper.pos.y
			if not is_nan(feet):
				break
		assert_false(is_nan(feet), "high %s: the shove landed" % high)
		assert_eq(jumper.body, AIRBORNE, "high %s: in mid-air" % high)
		var into := SimFixtures.sent(jumper).dot(Vector2(0.0, 1.0))
		assert_between(into, 0.0, rules.vault_speed, "high %s: slower than a vault" % high)
		assert_eq(feet > rules.railing_height, high, "high %s: over the rail's top" % high)
		_land(sim, SimFixtures.frame(0))
		if high:
			assert_eq(jumper.body, SWIMMING, "with High jump: carried over, into the sea")
			assert_gt(jumper.pos.z, edge, "outside the rail")
		else:
			assert_eq(jumper.body, GROUNDED, "without: caught, down on deck")
			assert_lt(jumper.pos.z, edge, "inside the rail")
