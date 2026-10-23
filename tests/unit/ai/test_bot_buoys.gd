extends GutTest
## Bots and lifebuoys (#273): a bot goes for a ring it can reach once enough of her is
## under water, a hard one charges a seat for the ring in its hands and takes it as it
## falls, and a swimmer holding one plans for its slower cold — all through its delayed
## view (D10), as it sees everything else.

const SEED := 1701
## The flat deck's port railing span aft of its gap, and where along it a ring hangs.
const SPAN := 0
const STATION := Vector3(-6.0, 0.0, -4.0)


func _tier(tier: StringName) -> BotProfile:
	var profile: BotProfile = BotProfile.for_tier(tier).duplicate()
	profile.mistake_rate = 0.0
	return profile


## The flat deck down by the head with the sea over its middle — every deck it has, under
## — and its aft end, where the rings are, still dry.
func _going_under() -> SinkScenario:
	var trim := 5.0
	return SimFixtures.scenario([[0.0, 3.0 + 2.0 * sin(deg_to_rad(trim)), trim, 0.0]])


## A match of [param seats] on the flat deck carrying [param props], under [param sinking].
func _sim(seats: int, props: Array[ShipProp], sinking: SinkScenario) -> MatchSim:
	return MatchSim.create(SimFixtures.config(seats, sinking, SEED, SimFixtures.crated(props)))


## [param bot] plays seat 0 of [param sim]; every other seat stands where it is.
func _runner(sim: MatchSim, bot: BotInputSource) -> MatchRunner:
	var sources: Array[InputSource] = [bot]
	for _seat in range(1, sim.config.seats):
		sources.append(InputSource.new())
	return MatchRunner.new(sim, sources)


## Steps [param runner] up to [param seconds], until [param done] says so; whether it did.
func _until(runner: MatchRunner, seconds: float, done: Callable) -> bool:
	for _tick in Ticks.from_seconds(seconds):
		runner.step()
		if done.call():
			return true
	return false


func test_a_bot_takes_a_ring_off_its_span_as_her_decks_go_under() -> void:
	for case: Array in [
		[_going_under(), true, "her decks going under"], [SimFixtures.calm(), false, "dry"]
	]:
		var sim := _sim(2, [SimFixtures.lifebuoy(STATION, SPAN)], case[0])
		SimFixtures.place(sim, 0, Vector3(-11.0, 0.0, 1.0), 0.0)
		SimFixtures.place(sim, 1, Vector3(-13.0, 0.0, 3.0))
		var ring := sim.state.props[0]
		var runner := _runner(sim, BotInputSource.new(0, _tier(&"normal"), sim.config))
		var took := _until(runner, 8.0, func() -> bool: return ring.holder == 0)
		assert_eq(took, case[1], case[2])


func test_a_hard_bot_charges_a_ring_from_its_holder_and_takes_it() -> void:
	for tier: StringName in [&"hard", &"easy"]:
		var sim := _sim(2, [SimFixtures.lifebuoy(Vector3(-9.0, 0.0, 0.0))], _going_under())
		SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, 0.0), 0.0)
		SimFixtures.place(sim, 1, Vector3(-9.0, 0.0, 0.0), 180.0)
		SimFixtures.hand(sim, 1, 0)
		var ring := sim.state.props[0]
		var runner := _runner(sim, BotInputSource.new(0, _tier(tier), sim.config))
		var loosened: Array[SimEvent] = []
		var took := _until(
			runner,
			8.0,
			func() -> bool:
				for event: SimEvent in sim.state.events:
					if event.kind == SimEvent.Kind.KNOCKED_LOOSE and event.credit == 0:
						loosened.append(event)
				return ring.holder == 0
		)
		if tier == &"hard":
			assert_false(loosened.is_empty(), "hard: its charge knocks the ring loose")
			assert_true(took, "and it takes the ring")
		else:
			assert_true(loosened.is_empty(), "easy: it never charges for a ring")
			assert_eq(ring.holder, 1)


func test_a_swimmer_with_a_ring_swims_for_a_way_out_only_it_can_reach() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.crated(
		[SimFixtures.lifebuoy(Vector3.ZERO)], SimFixtures.low_deck(rules.climb_reach * 0.5)
	)
	var off := 4.0 + rules.cold_meter * rules.swim_speed * 1.6
	for holding: bool in [false, true]:
		var sim := MatchSim.create(SimFixtures.config(2, SimFixtures.calm(), SEED, layout))
		SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
		SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, off), 0.0)
		if holding:
			SimFixtures.hand(sim, 0, 0)
		var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		var move := Vector2(source.next_frame(sim.state.tick).move)
		if holding:
			assert_lt(move.y, 0.0, "with a ring: for the deck, %.1f m off" % off)
		else:
			assert_eq(move, Vector2.ZERO, "without: nowhere it could reach")


## A bot sees a ring where its view, reaction_ticks old, has it: one taken off its span
## since is still there to it.
func test_a_bot_sees_a_ring_only_as_old_as_its_view() -> void:
	var profile := _tier(&"normal")
	var sim := _sim(2, [SimFixtures.lifebuoy(STATION, SPAN)], _going_under())
	SimFixtures.place(sim, 0, Vector3(-11.0, 0.0, 1.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(-6.0, 0.0, -3.4), -90.0)
	var source := BotInputSource.new(0, profile, sim.config)
	source.observe(sim.snapshot(), sim.pose())
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.GRAB)})
	assert_eq(sim.state.props[0].holder, 1, "taken")
	for _tick in profile.reaction_ticks - 1:
		source.observe(sim.snapshot(), sim.pose())
		SimFixtures.step(sim)
	source.observe(sim.snapshot(), sim.pose())
	var move := Vector2(source.next_frame(sim.state.tick).move).normalized()
	var toward := Vector2(STATION.x + 11.0, STATION.z - 1.0).normalized()
	assert_gt(move.dot(toward), 0.7, "it still walks for the ring it saw")


## A ring cannot run into a bot in this slice (#273): a bot that dodges cargo walks on
## through a sliding ring's path.
func test_a_bot_does_not_dodge_a_sliding_ring() -> void:
	var walks := []
	for ring_vel: Vector3 in [Vector3.ZERO, Vector3(-4.0, 0.0, 0.0)]:
		var sim := _sim(2, [SimFixtures.lifebuoy(Vector3(3.0, 0.0, 0.0))], SimFixtures.calm())
		SimFixtures.place(sim, 0, Vector3(0.0, 0.0, -0.3), 180.0)
		SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
		sim.state.props[0].vel = ring_vel
		var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		walks.append(Vector2(source.next_frame(sim.state.tick).move))
	assert_eq(walks[1], walks[0], "a ring sliding at it changes nothing")


## A hard bot charges a holder for the ring only once it would go for one: on a dry ship
## it leaves a holder its ring.
func test_a_hard_bot_does_not_charge_for_a_ring_on_a_dry_ship() -> void:
	var sim := _sim(2, [SimFixtures.lifebuoy(Vector3(-9.0, 0.0, 0.0))], SimFixtures.calm())
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(-9.0, 0.0, 0.0), 180.0)
	SimFixtures.hand(sim, 1, 0)
	var runner := _runner(sim, BotInputSource.new(0, _tier(&"hard"), sim.config))
	var loosened: Array[SimEvent] = []
	for _tick in Ticks.from_seconds(6.0):
		runner.step()
		for event: SimEvent in sim.state.events:
			if event.kind == SimEvent.Kind.KNOCKED_LOOSE:
				loosened.append(event)
	assert_true(loosened.is_empty(), "no charge for a ring it does not want yet")


## Going for a ring with a seat in its shove's reach, a bot presses Grab alone: a shove
## pressed with it would start its windup and leave the press to nothing.
func test_a_bot_reaching_a_ring_presses_grab_and_not_shove() -> void:
	var sim := _sim(2, [SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0))], _going_under())
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(-6.7, 0.0, 0.5))
	sim.state.props[0].pos = Vector3(-7.0, 0.0, 0.0)
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	source.observe(sim.snapshot(), sim.pose())
	var frame := source.next_frame(sim.state.tick)
	assert_true(frame.is_held(InputFrame.GRAB), "it presses Grab")
	assert_false(frame.is_held(InputFrame.SHOVE), "and not Shove with it")


## A bot never goes down toward the water for a ring: one a deck or more below where it
## stands, nearer the sea, it leaves where it hangs.
func test_a_bot_does_not_go_down_a_deck_for_a_ring() -> void:
	var layout := SimFixtures.steamer().duplicate()
	var by_the_head := SimFixtures.scenario([[0.0, 2.5, 4.0, 0.0], [10.0, 2.5, 8.0, 0.0]])
	var sim := MatchSim.create(SimFixtures.config(2, by_the_head, SEED, layout))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	SimFixtures.place(sim, 0, Vector3(-2.0, 2.5, 2.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	source.observe(sim.snapshot(), sim.pose())
	source.next_frame(sim.state.tick)
	assert_eq(source.brain._props.buoy, -1, "the main deck's rings are below the boat deck")
