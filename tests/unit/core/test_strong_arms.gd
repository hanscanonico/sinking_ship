extends GutTest
## Strong arms (#307, #316): a seat that took it climbs out of the sea onto a ledge as high
## as its kind's reach — 1.2 m as shipped, twice the brawl rules' — and up a ladder at its
## kind's times their pace, 1.5 as shipped. The climb's least time and the cold a climber
## knocked back in loses stay the brawl rules'.

const TOWARD_PORT := Vector2(0.0, -1.0)
## Just past the flat deck's starboard edge, outside its hull.
const OUTSIDE_Z := 4.6
## Where along the flat deck seat 0 swims, and the boarding ladder hangs when it has one.
const ALONG := -8.0


## A match of two on the flat deck standing [param freeboard] out of the sea — a boarding
## ladder down its starboard side at ALONG when [param ladder] says so — played with Strong
## arms: seat 0 afloat just outside that side, with them when [param strong] says so, and
## seat 1 standing well clear.
func _beside(freeboard: float, strong: bool, ladder := false) -> MatchSim:
	var layout := SimFixtures.low_deck(freeboard)
	if ladder:
		var hung := ShipLadder.new()
		hung.platform = 0
		hung.from = Vector2(ALONG - 1.0, layout.platforms[0].area.end.y)
		hung.to = Vector2(ALONG + 1.0, layout.platforms[0].area.end.y)
		var ladders: Array[ShipLadder] = [hung]
		layout.ladders = ladders
	var sim := SimFixtures.kind_sim(SimFixtures.strong_arms(), strong, 2, layout)
	SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(ALONG, 0.0, OUTSIDE_Z))
	return sim


## The tick seat 0 of [param sim] climbs out on, pressing toward the deck for up to
## [param ticks] ticks; -1 if it never does.
func _climbed_out(sim: MatchSim, ticks: int) -> int:
	for _tick in ticks:
		for event: SimEvent in SimFixtures.step(sim, {0: SimFixtures.frame(0, TOWARD_PORT)}):
			if event.kind == SimEvent.Kind.CLIMBED_OUT and event.seat == 0:
				return event.tick
	return -1


## A seat with Strong arms climbs onto a deck edge a hair under its kind's reach out of the
## sea — one at the reach exactly stands a rounding past it, the ship's pose being single
## precision, as one at the brawl rules' own reach does — and not onto one a little higher.
## Without them, an edge a hair under the brawl rules' reach is in reach, and one a hair
## under Strong arms' is not.
func test_a_strong_arms_seat_climbs_onto_a_ledge_as_high_as_its_reach() -> void:
	var reach := SimFixtures.strong_arms().climb_reach
	var theirs := SimFixtures.rules().climb_reach
	assert_gt(reach, theirs, "Strong arms reach higher than the brawl rules")
	# How high the edge stands, whether the swimmer has Strong arms, and whether it climbs.
	var cases := [
		[theirs - 0.05, false, true],
		[reach - 0.01, false, false],
		[reach - 0.01, true, true],
		[reach + 0.05, true, false],
	]
	for case: Array in cases:
		var sim := _beside(case[0], case[1])
		var out := _climbed_out(sim, 3 * Ticks.RATE)
		var swimmer := sim.state.seats[0]
		var what := "a %.2f m edge, Strong arms %s" % [case[0], case[1]]
		if case[2]:
			assert_gt(out, -1, "%s: up onto the deck" % what)
			assert_eq([swimmer.body, swimmer.pos.y], [PlayerState.Body.GROUNDED, 0.0], what)
		else:
			assert_eq(out, -1, "%s: out of reach" % what)
			assert_eq(swimmer.body, PlayerState.Body.SWIMMING, "%s: still in the sea" % what)


## Up a ladder 3 m out of the sea a climb takes the rise over the climber's pace: 2 s, 60
## ticks, at the brawl rules' 1.5 m/s; with Strong arms, at its kind's times that — 1.5 as
## shipped — 1⅓ s, 40 ticks.
func test_a_strong_arms_seat_climbs_a_ladder_at_its_kind_s_pace() -> void:
	var rules := SimFixtures.rules()
	var pace := SimFixtures.strong_arms().ladder_speed_mult
	var took: Array[int] = []
	for strong: bool in [false, true]:
		var sim := _beside(3.0, strong, true)
		var speed := rules.ladder_speed * (pace if strong else 1.0)
		took.append(_climbed_out(sim, 3 * Ticks.RATE))
		assert_eq(took[-1], Ticks.from_seconds(3.0 / speed), "Strong arms %s" % strong)
		assert_eq(sim.state.seats[0].body, PlayerState.Body.GROUNDED, "Strong arms %s" % strong)
	assert_lt(took[1], took[0], "faster with Strong arms")


## Onto a ledge 0.4 m out of the sea, Strong arms climbs no quicker than anyone: the climb
## takes climb_time whoever climbs. And a shove landing on a climber with them knocks it
## back in colder by climb_penalty, as it does anyone.
func test_the_climb_s_least_time_and_the_cost_of_being_knocked_back_in_stay_the_same() -> void:
	var rules := SimFixtures.rules()
	var least := Ticks.from_seconds(rules.climb_time)
	for strong: bool in [false, true]:
		var sim := _beside(0.4, strong)
		assert_eq(_climbed_out(sim, 3 * Ticks.RATE), least, "Strong arms %s" % strong)

		var shoved := _beside(0.4, strong)
		SimFixtures.place(shoved, 1, Vector3(ALONG, 0.0, OUTSIDE_Z - 1.2), 90.0)
		var climber := shoved.state.seats[0]
		var press := {0: SimFixtures.frame(0, TOWARD_PORT), 1: SimFixtures.frame(1)}
		SimFixtures.step(shoved, press, 4)
		assert_true(climber.is_climbing(), "Strong arms %s: it started up" % strong)
		var cold := climber.cold
		var shove := SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)
		SimFixtures.step(shoved, {0: press[0], 1: shove})
		var knocked := false
		for _tick in least:
			for event: SimEvent in SimFixtures.step(shoved, press):
				knocked = knocked or event.kind == SimEvent.Kind.KNOCKED_BACK_IN
			if knocked:
				break
		assert_true(knocked, "Strong arms %s: knocked back in" % strong)
		var lost := cold - climber.cold
		assert_almost_eq(lost, rules.climb_penalty, 0.0001, "Strong arms %s: its cost" % strong)
