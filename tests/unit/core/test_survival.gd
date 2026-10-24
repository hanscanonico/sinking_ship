extends GutTest
## Survival (#60): a second goal beside the battle royale. Everyone tries to stay in as
## long as possible while she sinks, so a lone seat left plays on until her sinking is
## over — end_tick() — or until it goes out; the places are still the order seats go out
## in.

const DEFAULT_MATCH := "res://data/match/default.tres"
const SURVIVAL_MATCH := "res://data/match/survival.tres"
## The default match's data hash on main before goals came (#65's ShipLayout), taken
## again when her data moved (#74's stokehold, then a spawn stepped off its gallery wall,
## then #148's crawl_height and crawl_speed and the rooms' crawl_space mark, then Q20's
## paced clock, narrower hits and 1 h 30 bound, then #148's spaces in the steamer's old
## voids, their scuttles and the pieces' fitted mark, then the floating crates'
## crate_draft, crate_float_drag and crate_adrift_depth, then crate_float_drag's lighter
## drag and crate_float_pull for their drift, then wade_speed_deep, then dunk_depth, then
## body_restitution and body_impact_speed, then #273's grab_reach and grab_cone_deg, her
## lifebuoys and the kinds of her props, then #308's bonus spots): the goals must not move
## the battle royale's.
const BATTLE_ROYALE_HASH := "9d545e1824592e63f9c1a0eba47c760e542f85f0d62e1f3198997b12fd2c422b"


func test_the_data_carries_the_goal_onto_the_match() -> void:
	var royale := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
	var survival := MatchConfig.from_rules(load(SURVIVAL_MATCH), 1701)
	assert_eq(royale.goal, MatchRules.Goal.LAST_STANDING, "the default stays the battle royale")
	assert_eq(survival.goal, MatchRules.Goal.SURVIVAL)


func test_the_battle_royale_hash_is_unchanged() -> void:
	assert_eq(MatchConfig.from_rules(load(DEFAULT_MATCH), 1701).data_hash(), BATTLE_ROYALE_HASH)


func test_a_replay_refuses_a_log_recorded_under_the_other_goal() -> void:
	var royale := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
	var survival := MatchConfig.from_rules(load(SURVIVAL_MATCH), 1701)
	assert_ne(royale.data_hash(), survival.data_hash(), "the goal is part of the data")
	assert_false(InputLog.new(royale).matches(survival))
	assert_false(InputLog.new(survival).matches(royale))
	assert_true(InputLog.new(survival).matches(survival))


func test_the_same_seed_plays_the_same_until_the_battle_royale_ends() -> void:
	var royale := _duel(MatchRules.Goal.LAST_STANDING)
	var survival := _duel(MatchRules.Goal.SURVIVAL)
	while not royale.is_over():
		SimFixtures.step(royale)
		SimFixtures.step(survival)
		if royale.is_over():
			# On its last tick, alike but for the place the battle royale gives its winner.
			var won: Array = royale.snapshot()["seats"]
			won[1]["place"] = 0
			assert_eq(survival.snapshot()["seats"], won, "on its last tick")
		elif survival.snapshot() != royale.snapshot():
			fail_test("the goals part at tick %d" % royale.state.tick)
			return
	var ended := royale.state.tick - 1
	assert_eq(royale.state.seats[0].out_tick, ended, "the battle royale ends as seat 0 goes out")
	assert_eq(royale.state.winner(), 1)
	assert_false(survival.is_over(), "survival plays on with one seat left")
	assert_eq(survival.state.seats[0].place, 2)


func test_a_lone_seat_plays_on_until_her_sinking_is_over() -> void:
	var sim := _duel(MatchRules.Goal.SURVIVAL)
	var end := sim.schedule.end_tick()
	var events: Array[SimEvent] = []
	while not sim.is_over() and sim.state.tick <= end + 1:
		events.append_array(SimFixtures.step(sim))
	assert_true(sim.is_over())
	var ended := _ended(events)
	assert_eq(ended.size(), 1, "the match ends once")
	if ended.size() == 1:
		assert_eq(ended[0].tick, end, "on the tick her sinking is over")
		assert_eq(ended[0].seat, 1, "won by the seat still in")
	assert_eq(sim.state.winner(), 1)
	assert_eq(sim.state.seats[1].place, 1, "the last one in places first")
	assert_eq(sim.state.seats[0].place, 2)


func test_a_lone_seat_going_out_sooner_ends_it_then() -> void:
	var sim := _duel(MatchRules.Goal.SURVIVAL)
	SimFixtures.swim(sim, 1, Vector3(0.0, 0.0, -10.0))
	sim.state.seats[0].cold = 1.0
	var events: Array[SimEvent] = []
	while not sim.is_over() and sim.state.tick <= sim.schedule.end_tick():
		events.append_array(SimFixtures.step(sim))
	var ended := _ended(events)
	assert_eq(ended.size(), 1)
	assert_lt(sim.state.seats[1].out_tick, sim.schedule.end_tick(), "the cold takes it first")
	if ended.size() == 1:
		assert_eq(ended[0].tick, sim.state.seats[1].out_tick, "as the last seat goes out")
		assert_eq(ended[0].seat, -1, "with nobody left in")
	assert_eq(sim.state.seats[1].place, 1, "the last one out places first")
	assert_eq(sim.state.seats[0].place, 2)


func test_seats_out_on_the_same_tick_share_places_and_end_it() -> void:
	var sim := _duel(MatchRules.Goal.SURVIVAL)
	SimFixtures.swim(sim, 1, Vector3(0.0, 0.0, -10.0))
	var events: Array[SimEvent] = []
	while not sim.is_over() and sim.state.tick <= sim.schedule.end_tick():
		events.append_array(SimFixtures.step(sim))
	assert_true(sim.is_over())
	assert_eq(sim.state.seats[0].out_tick, sim.state.seats[1].out_tick, "together, by the cold")
	assert_eq(sim.state.seats[0].place, 1)
	assert_eq(sim.state.seats[1].place, 1, "a shared place")
	assert_eq(_ended(events).size(), 1)


func test_a_survival_match_continues_exactly_from_its_snapshot() -> void:
	var sim := _duel(MatchRules.Goal.SURVIVAL)
	var snapshots: Array[Dictionary] = [sim.snapshot()]
	while not sim.is_over():
		SimFixtures.step(sim)
		snapshots.append(sim.snapshot())
	var out := sim.state.seats[0].out_tick
	for start: int in [0, out - 3, out, out + 7, snapshots.size() - 4]:
		var resumed := MatchSim.from_snapshot(snapshots[start], sim.config)
		for tick in range(start + 1, snapshots.size()):
			var frames: Array[InputFrame] = []
			frames.resize(2)
			resumed.step(frames)
			if resumed.snapshot() != snapshots[tick]:
				fail_test("from tick %d diverged at tick %d" % [start, tick])
				return
		assert_true(resumed.is_over(), "from tick %d it ends as the match did" % start)


## Two seats on the flat deck, her sinking over at 6 s: seat 0 swims, out by the cold
## in 4 s; seat 1 stands on deck.
func _duel(goal: MatchRules.Goal) -> MatchSim:
	var config := SimFixtures.config(
		2, SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [6.0, 0.0, 0.0, 0.0]])
	)
	config.goal = goal
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 10.0))
	return sim


static func _ended(events: Array[SimEvent]) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.MATCH_ENDED:
			found.append(event)
	return found
