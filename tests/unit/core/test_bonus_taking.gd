extends GutTest
## Taking a bonus (#307, #310): a Grab press takes a bonus in reach before any prop, as it
## takes a prop — on its feet on her decks, idle, neither staggered nor frozen, within grab
## reach beyond the body's edge and the bonus's, in front, at a height it reaches, no
## blocker between — but with the hands full too. It is used up at once: gone from the
## snapshot and the seat's bonus, replacing any it had, until the seat is out.

const GRAB := InputFrame.GRAB
## Where below_decks' hold has its spot, and a body standing aft of it, facing it, its
## edge well within grab reach of the bonus's.
const SPOT := Vector3(-9.5, -2.0, 0.0)
const BESIDE := Vector3(-10.4, -2.0, 0.0)


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


func _grab(seat: int) -> InputFrame:
	return SimFixtures.frame(seat, Vector2.ZERO, GRAB)


## [param seats] seats in below_decks' hold — [param layout]'s when given — with a Double
## life lying at its spot and no plan to bring another, seat 0 beside it facing it.
func _with_a_bonus(seats := 1, layout: ShipLayout = null) -> MatchSim:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), seats, layout)
	SimFixtures.bring_aboard(sim, 0)
	SimFixtures.place(sim, 0, BESIDE, 0.0)
	return sim


func test_a_grab_press_takes_a_bonus_in_reach() -> void:
	assert_eq(SimFixtures.hold_spot(0), SPOT, "the hold's spot")
	assert_eq(SimFixtures.by_hold_spot(0), BESIDE, "and where a body takes its bonus")
	var sim := _with_a_bonus()
	var events := SimFixtures.step(sim, {0: _grab(0)})
	assert_true(sim.state.bonuses.is_empty(), "used up at once: no longer aboard")
	assert_eq(sim.state.seats[0].bonus, 0, "the seat's bonus: a Double life")
	var taken := _of(events, SimEvent.Kind.BONUS_TAKEN)
	assert_eq(taken.size(), 1, "and says so")
	if taken.size() == 1:
		assert_eq([taken[0].seat, taken[0].bonus, taken[0].spot], [0, 0, 0])
	var entry: Dictionary = sim.snapshot()["seats"][0]
	assert_eq(entry["bonus"], 0, "the snapshot holds it")
	assert_eq(sim.snapshot()["bonuses"], [], "and the bonus gone")


func test_a_grab_needs_the_bonus_in_reach_in_front_and_at_hand_height() -> void:
	var rules := SimFixtures.rules()
	var edge := rules.body_radius + SimFixtures.double_life().radius + rules.grab_reach
	var cone := rules.grab_cone_deg
	for case: Array in [
		[SPOT - Vector3(edge - 0.01, 0.0, 0.0), 0.0, 0, "within grab_reach of both edges"],
		[SPOT - Vector3(edge + 0.01, 0.0, 0.0), 0.0, -1, "beyond it"],
		[SPOT - Vector3(1.0, 0.0, 0.0), 180.0, -1, "behind"],
		[SPOT - Vector3(1.0, 0.0, 0.0), cone - 1.0, 0, "inside the cone"],
		[SPOT - Vector3(1.0, 0.0, 0.0), cone + 1.0, -1, "outside it"],
		[Vector3(SPOT.x - 0.8, 0.0, 0.0), 0.0, -1, "on the deck over it"],
	]:
		var sim := _with_a_bonus()
		SimFixtures.place(sim, 0, case[0], case[1])
		SimFixtures.step(sim, {0: _grab(0)})
		assert_eq(sim.state.seats[0].bonus, case[2], case[3])
		assert_eq(sim.state.bonuses.size(), 1 if case[2] == -1 else 0, case[3])


## The hands may be full: a seat holding a ring takes a bonus in reach and keeps its ring.
func test_full_hands_take_a_bonus_and_keep_the_prop() -> void:
	var ring := SimFixtures.lifebuoy(SPOT + Vector3(0.0, 0.0, 2.0))
	var sim := _with_a_bonus(1, SimFixtures.crated([ring], SimFixtures.below_decks()))
	SimFixtures.hand(sim, 0, 0)
	var events := SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.seats[0].bonus, 0, "the bonus taken")
	assert_eq(sim.state.props[0].holder, 0, "the ring still in its hands")
	assert_true(_of(events, SimEvent.Kind.PROP_LET_GO).is_empty(), "never let go of")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	events = SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.props[0].holder, -1, "with no bonus left, a press lets go")
	assert_eq(_of(events, SimEvent.Kind.PROP_LET_GO).size(), 1)


## A bonus in reach comes before a prop in reach, even a nearer one: one press does what
## the trip down was for, and the next takes the prop.
func test_a_bonus_comes_before_a_prop() -> void:
	var ring := SimFixtures.lifebuoy(BESIDE + Vector3(0.75, 0.0, -0.2))
	var sim := _with_a_bonus(1, SimFixtures.crated([ring], SimFixtures.below_decks()))
	var events := SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.seats[0].bonus, 0, "the bonus first")
	assert_eq(sim.state.props[0].holder, -1, "the ring left lying")
	assert_true(_of(events, SimEvent.Kind.PROP_GRABBED).is_empty())
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.props[0].holder, 0, "then the ring")


## Two seats pressing Grab at one bonus on one tick: the nearer takes it, the other
## nothing at all; of two as near, the lower seat.
func test_the_nearer_brawler_wins_a_tied_bonus_then_the_lower_seat() -> void:
	var sim := _with_a_bonus(2)
	SimFixtures.place(sim, 0, SPOT - Vector3(1.0, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, SPOT + Vector3(0.9, 0.0, 0.0), 180.0)
	var events := SimFixtures.step(sim, {0: _grab(0), 1: _grab(1)})
	assert_eq([sim.state.seats[0].bonus, sim.state.seats[1].bonus], [-1, 0], "the nearer one")
	assert_eq(_of(events, SimEvent.Kind.BONUS_TAKEN).size(), 1, "and only it")

	var even := _with_a_bonus(2)
	SimFixtures.place(even, 0, SPOT - Vector3(1.0, 0.0, 0.0), 0.0)
	SimFixtures.place(even, 1, SPOT + Vector3(1.0, 0.0, 0.0), 180.0)
	SimFixtures.step(even, {1: _grab(1), 0: _grab(0)})
	assert_eq([even.state.seats[0].bonus, even.state.seats[1].bonus], [0, -1], "the lower seat")


## Taking a bonus is never a way out of a hit, a swim or a shove.
func test_no_bonus_while_staggered_frozen_in_the_air_swimming_climbing_or_shoving() -> void:
	for what: String in [
		"staggered", "frozen", "in the air", "swimming", "climbing", "winding up", "recovering"
	]:
		var sim := _with_a_bonus()
		var player := sim.state.seats[0]
		match what:
			"staggered":
				player.stagger_ticks = 5
			"frozen":
				player.hitstop = 5
			"in the air":
				player.body = PlayerState.Body.AIRBORNE
			"swimming":
				player.body = PlayerState.Body.SWIMMING
			"climbing":
				player.body = PlayerState.Body.SWIMMING
				player.climb_left = 5
			"winding up":
				player.action = PlayerState.Action.WINDUP
			"recovering":
				player.action = PlayerState.Action.RECOVERY
		SimFixtures.step(sim, {0: _grab(0)})
		assert_eq(sim.state.seats[0].bonus, -1, what)
		assert_eq(sim.state.bonuses.size(), 1, "%s: still aboard" % what)


## A seat has one bonus at a time: one it takes replaces the one it had, whatever kinds
## the two are.
func test_a_bonus_taken_replaces_the_one_the_seat_had() -> void:
	var kinds: Array[BonusKind] = [SimFixtures.double_life(), SimFixtures.plain_kind()]
	var rules := SimFixtures.bonus_rules(600.0, 45.0, 0.0, 2, kinds)
	var sim := SimFixtures.bonus_sim(rules, 1, SimFixtures.below_decks(2))
	SimFixtures.bring_aboard(sim, 0, 1)
	SimFixtures.bring_aboard(sim, 1, 0)
	SimFixtures.place(sim, 0, BESIDE, 0.0)
	sim.state.seats[0].bonus = 0
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.seats[0].bonus, 1, "the other kind, its Double life gone")
	SimFixtures.place(sim, 0, SimFixtures.by_hold_spot(1), 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.seats[0].bonus, 0, "and a Double life again")
	assert_true(sim.state.bonuses.is_empty())


## Nothing of an out seat's plays on after it: its bonus goes with it.
func test_an_out_seat_loses_its_bonus() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 2)
	SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
	var swimmer := sim.state.seats[0]
	sim.config.bonus_rules.kinds.append(SimFixtures.plain_kind())
	sim.config.bonus_rules.odds.append(0.0)
	swimmer.bonus = 1
	swimmer.cold = 0.1
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_true(swimmer.is_out(), "the cold takes it")
	assert_eq(swimmer.bonus, -1, "and its bonus with it")
	assert_eq(sim.snapshot()["seats"][0]["bonus"], -1)


## A bonus comes aboard as its tick ends, every press of that tick done: a press on the tick
## it comes takes none — no snapshot has shown it yet — and the next press takes it, as the
## snapshot that tick leaves shows it (D13).
func test_a_bonus_comes_as_its_tick_ends() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(1.0))
	SimFixtures.place(sim, 0, BESIDE, 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	var events := SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(_of(events, SimEvent.Kind.BONUS_CAME).size(), 1, "it came on that tick")
	assert_true(_of(events, SimEvent.Kind.BONUS_TAKEN).is_empty(), "the press on it took none")
	assert_eq(sim.snapshot()["bonuses"].size(), 1, "the snapshot it leaves shows it")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.seats[0].bonus, 0, "and the next press takes it")


## The spot a bonus was taken from is open again: a later planned bonus may come there.
func test_a_taken_bonus_s_spot_opens_again() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(1.0, 2.0, 0.0, 2))
	SimFixtures.place(sim, 0, BESIDE, 0.0)
	SimFixtures.step(sim, {}, Ticks.from_seconds(1.5))
	assert_eq(sim.state.bonuses.size(), 1, "the first came")
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(sim.state.seats[0].bonus, 0, "and was taken")
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.from_seconds(2.0))
	assert_eq(_of(events, SimEvent.Kind.BONUS_CAME).size(), 1, "the next comes to its spot")
	assert_eq(sim.state.bonuses.size(), 1)


## The HUD's prompt asks GrabReach.would_press of the snapshot it draws, the one question
## the sim's press asks (D13): what it names — the bonus taken, the ring grabbed or the ring
## let go of — is what the next press does, wherever the seat stands and whatever it holds.
func test_the_reach_query_names_what_the_next_press_does() -> void:
	var ring := SimFixtures.lifebuoy(BESIDE - Vector3(0.75, 0.0, 0.0))
	var layout := SimFixtures.crated([ring], SimFixtures.below_decks(2))
	var rules := SimFixtures.rules()
	# [where, facing, holding the ring, what a press does]
	for case: Array in [
		[BESIDE, 0.0, false, "takes the bonus in front, the ring behind"],
		[BESIDE, 180.0, false, "grabs the ring in front, the bonus behind"],
		[BESIDE, 0.0, true, "takes the bonus with the ring in its hands"],
		[BESIDE, 180.0, true, "lets go of the ring, the bonus behind"],
		[SimFixtures.hold_spot(1) + Vector3(0.9, 0.0, 0.3), 180.0, false, "the other hold's"],
		[Vector3.ZERO, 0.0, false, "on deck: nothing"],
	]:
		var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 1, layout)
		SimFixtures.bring_aboard(sim, 0)
		SimFixtures.bring_aboard(sim, 1)
		SimFixtures.place(sim, 0, case[0], case[1])
		if case[2]:
			SimFixtures.hand(sim, 0, 0)
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		var aboard: Array = sim.snapshot()["bonuses"].duplicate()
		var reach := GrabReach.new(layout, rules, sim.config.bonus_rules)
		var said := reach.would_press(sim.snapshot(), 0, sim.surfaces)
		var events := SimFixtures.step(sim, {0: _grab(0)})
		var spot: int = aboard[said.aboard]["spot"] if said.aboard != -1 else -1
		assert_eq(
			[spot, said.let_go, said.prop],
			[
				_named(events, SimEvent.Kind.BONUS_TAKEN, "spot"),
				_named(events, SimEvent.Kind.PROP_LET_GO, "prop"),
				_named(events, SimEvent.Kind.PROP_GRABBED, "prop"),
			],
			case[3]
		)


## What [param events] say of their one event of [param kind]: its [param field]; -1 with
## none.
func _named(events: Array[SimEvent], kind: SimEvent.Kind, field: String) -> int:
	var found := _of(events, kind)
	return found[0].get(field) if not found.is_empty() else -1
