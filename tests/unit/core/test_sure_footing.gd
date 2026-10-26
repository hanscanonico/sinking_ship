extends GutTest
## Sure footing (#307, #317): a seat that took it holds idle on a tilted deck up to its
## kind's grip angle — 22° as shipped, where the brawl rules' give way past 14° — and walks
## a deck up to its kind's stand limit — 45°, where theirs stops at 35° (test_bonus_rules
## holds the data to them). The brace's hold, and the floor her walls become past it, stay
## the brawl rules' (brace_holds_to, 55°), the same for every seat: past its own stand limit
## a seat with it slides into the corner as anyone does, unless it braces.

## Where on the flat deck each seat stands: seat 0, with Sure footing, well aft; seat 1,
## without, as far forward; each 2 m starboard of her middle line, room to walk up a list
## to starboard and to slide down it to her rail.
const SURE_AT := Vector3(-8.0, 0.0, 2.0)
const BASE_AT := Vector3(8.0, 0.0, 2.0)
## Up the slope of a deck listing to starboard: toward port.
const UPHILL := Vector2(0.0, -1.0)
const BRACE := InputFrame.BRACE


## A match of two on the flat deck lifted clear of the sea and held at [param heel_deg] of
## list, starboard down, played with Sure footing: seat 0 with one standing at SURE_AT,
## seat 1 without at BASE_AT.
func _listing(heel_deg: float) -> MatchSim:
	var sinking := SimFixtures.tilted(0.0, heel_deg)
	var deck := SimFixtures.deck()
	var sim := SimFixtures.kind_sim(SimFixtures.sure_footing(), true, 2, deck, sinking)
	SimFixtures.place(sim, 0, SURE_AT)
	SimFixtures.place(sim, 1, BASE_AT)
	return sim


## On a deck listing past the brawl rules' grip angle and under its kind's — 20° as shipped
## — a seat with Sure footing standing idle holds where it stands, while one without it
## slides down to starboard.
func test_a_sure_footed_seat_holds_idle_where_a_seat_without_it_slides() -> void:
	var heel := SimFixtures.sure_footing().grip_angle_deg - 2.0
	assert_gt(heel, SimFixtures.rules().grip_angle_deg, "past the brawl rules' grip angle")
	var sim := _listing(heel)
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)}, 2 * Ticks.RATE)
	var sure := sim.state.seats[0]
	var base := sim.state.seats[1]
	assert_eq([sure.pos, sure.vel], [SURE_AT, Vector3.ZERO], "Sure footing: held where it stood")
	assert_gt(base.pos.z, BASE_AT.z + 1.0, "without it: slid down to starboard")
	assert_eq(base.body, PlayerState.Body.GROUNDED, "sliding, not falling")


## On a deck listing past the brawl rules' stand limit and under its kind's — 40° as shipped
## — a seat with Sure footing walks up the slope, the deck pulling at it all the way, while
## one without it walking the same way slides down it.
func test_a_sure_footed_seat_walks_up_a_deck_too_steep_for_a_seat_without_it() -> void:
	var heel := SimFixtures.sure_footing().stand_limit_deg - 5.0
	assert_gt(heel, SimFixtures.rules().stand_limit_deg, "past the brawl rules' stand limit")
	var sim := _listing(heel)
	var up := {0: SimFixtures.frame(0, UPHILL), 1: SimFixtures.frame(1, UPHILL)}
	SimFixtures.step(sim, up, Ticks.RATE)
	var sure := sim.state.seats[0]
	var base := sim.state.seats[1]
	assert_lt(sure.pos.z, SURE_AT.z - 3.0, "Sure footing: up the slope, toward port")
	assert_gt(base.pos.z, BASE_AT.z + 1.0, "without it: down the slope, however it walks")
	for player: PlayerState in [sure, base]:
		assert_eq(player.body, PlayerState.Body.GROUNDED, "seat %d on its feet" % player.seat)


## Past its kind's stand limit and under the brace's hold — 50° as shipped — a seat with
## Sure footing slides as one without it does, idle or walking up the slope: the same way,
## as fast. Braced, each holds where it stands: the brace holds to the brawl rules' angle
## for every seat, and her deck stays the floor for both until she tilts past it.
func test_past_its_stand_limit_a_sure_footed_seat_slides_as_any_does_unless_braced() -> void:
	var heel := SimFixtures.sure_footing().stand_limit_deg + 5.0
	assert_lt(heel, SimFixtures.rules().brace_holds_to, "under the brace's hold")
	# What both seats do, their walk and their buttons.
	var cases := [
		["idle", Vector2.ZERO, 0],
		["walking up", UPHILL, 0],
		["braced", Vector2.ZERO, BRACE],
	]
	for case: Array in cases:
		var sim := _listing(heel)
		var press := {0: SimFixtures.frame(0, case[1], case[2])}
		press[1] = SimFixtures.frame(1, case[1], case[2])
		SimFixtures.step(sim, press, Ticks.RATE / 2)
		var sure := sim.state.seats[0]
		var base := sim.state.seats[1]
		assert_eq(sim.state.up[0], Faces.Up.DECK, "%s: her deck the floor for both" % case[0])
		if case[2] == BRACE:
			assert_eq([sure.pos, base.pos], [SURE_AT, BASE_AT], "braced: both held")
		else:
			assert_gt(base.pos.z, BASE_AT.z + 0.5, "%s: without it, down the slope" % case[0])
			assert_almost_eq(sure.pos.z, base.pos.z, 1e-5, "%s: with it, as far" % case[0])
			assert_almost_eq(sure.vel, base.vel, Vector3.ONE * 1e-5, "%s: as fast" % case[0])
