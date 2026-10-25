extends GutTest
## The bonus plan (#307, #310): bonuses come aboard on a plan drawn once at the start from a
## stream of their own — the first at its time, each next an interval on, give or take its
## jitter, until her sinking's end — each at the open bonus spot its pick lands on, never
## more than the bonus rules' most aboard at once, and on the fast clock quickened with her
## sinking. Here every hold is dry, so a spot is open whenever no bonus lies there; what the
## sea decides (#311) is test_bonus_sea's.

const RunMatch := preload("res://tools/run_match.gd")
## The tug's seats: she bakes her drawn hit quickest of the fleet.
const TUG_SEATS := 6


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


func test_the_first_bonus_comes_aboard_at_its_time() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(2.0))
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(2.0))
	assert_true(sim.state.bonuses.is_empty(), "none before its time")
	assert_true(_of(events, SimEvent.Kind.BONUS_CAME).is_empty())
	events = SimFixtures.step(sim)
	assert_eq(sim.state.bonuses.size(), 1, "one aboard at its time")
	if sim.state.bonuses.size() == 1:
		var bonus := sim.state.bonuses[0]
		assert_eq(
			[bonus.planned, bonus.kind, bonus.spot],
			[0, 0, 0],
			"the plan's first, a Double life, at the hold's spot"
		)
	var came := _of(events, SimEvent.Kind.BONUS_CAME)
	assert_eq(came.size(), 1, "and says so")
	if came.size() == 1:
		assert_eq([came[0].tick, came[0].bonus, came[0].spot], [Ticks.from_seconds(2.0), 0, 0])


## The ticks bonuses come aboard on over [param seconds] of a match of [param rules] on
## [param holds] holds, nobody taking any, seeded [param seed_value].
func _came(rules: BonusRules, holds: int, seconds: float, seed_value := 1) -> PackedInt32Array:
	var config := SimFixtures.config(
		1, SimFixtures.calm_until(600.0), seed_value, SimFixtures.below_decks(holds)
	)
	config.bonus_rules = rules
	var sim := MatchSim.create(config)
	var ticks := PackedInt32Array()
	for event: SimEvent in SimFixtures.step(sim, {}, Ticks.from_seconds(seconds)):
		if event.kind == SimEvent.Kind.BONUS_CAME:
			ticks.append(event.tick)
	return ticks


func test_each_next_comes_an_interval_on_give_or_take_its_jitter() -> void:
	var even := _came(SimFixtures.bonus_rules(1.0, 10.0, 0.0, 9), 9, 45.0)
	assert_eq(
		even,
		PackedInt32Array([30, 330, 630, 930, 1230]),
		"without jitter: the first at its time, then every interval"
	)
	var jittered := _came(SimFixtures.bonus_rules(1.0, 10.0, 3.0, 9), 9, 60.0)
	assert_gt(jittered.size(), 4, "as many, near enough")
	assert_eq(jittered[0], 30, "the first at its time all the same")
	var gaps := {}
	for index in range(1, jittered.size()):
		var gap := jittered[index] - jittered[index - 1]
		assert_between(gap, Ticks.from_seconds(7.0) - 1, Ticks.from_seconds(13.0) + 1, "%d" % index)
		gaps[gap] = true
	assert_gt(gaps.size(), 1, "the jitter moves them apart unevenly")
	assert_eq(_came(SimFixtures.bonus_rules(1.0, 10.0, 3.0, 9), 9, 60.0), jittered, "seeded")
	assert_ne(_came(SimFixtures.bonus_rules(1.0, 10.0, 3.0, 9), 9, 60.0, 2), jittered, "by seed")


## At most the rules' most are aboard at once: a planned bonus that comes while as many
## lie aboard never comes, and the plan goes on from the next.
func test_a_bonus_planned_with_the_most_aboard_never_comes() -> void:
	var sim := SimFixtures.bonus_sim(
		SimFixtures.bonus_rules(1.0, 2.0, 0.0, 2), 1, SimFixtures.below_decks(3)
	)
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(5.5))
	assert_eq(_of(events, SimEvent.Kind.BONUS_CAME).size(), 2, "two of the three planned so far")
	assert_eq(sim.state.bonuses.size(), 2)
	sim.state.bonuses.remove_at(0)
	events = SimFixtures.step(sim, {}, Ticks.from_seconds(2.0))
	var came := _of(events, SimEvent.Kind.BONUS_CAME)
	assert_eq(came.size(), 1, "with room again, the next planned comes")
	if came.size() == 1:
		assert_eq(came[0].tick, Ticks.from_seconds(7.0), "on its own time, not the skipped one's")


## A planned bonus with no spot open — each has a bonus lying at it — never comes.
func test_a_bonus_planned_with_no_spot_open_never_comes() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(1.0, 2.0, 0.0, 5))
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(5.5))
	assert_eq(_of(events, SimEvent.Kind.BONUS_CAME).size(), 1, "the one hold's spot taken")
	assert_eq(sim.state.bonuses.size(), 1)


## A bonus comes only to a spot no bonus lies at, the one its pick lands on among those:
## seed by seed they land on every open spot, never on the one taken.
func test_a_bonus_comes_to_the_open_spot_its_pick_lands_on() -> void:
	var landed := {}
	for seed_value in range(1, 25):
		var config := SimFixtures.config(
			1, SimFixtures.calm_until(600.0), seed_value, SimFixtures.below_decks(3)
		)
		config.bonus_rules = SimFixtures.bonus_rules()
		var sim := MatchSim.create(config)
		SimFixtures.bring_aboard(sim, 1)
		SimFixtures.step(sim, {}, Ticks.from_seconds(1.5))
		assert_eq(sim.state.bonuses.size(), 2, "seed %d: it came" % seed_value)
		if sim.state.bonuses.size() == 2:
			landed[sim.state.bonuses[1].spot] = true
	assert_false(landed.has(1), "never where one lies")
	assert_true(landed.has(0) and landed.has(2), "each open one, by the seed")


## No bonus comes to a match without bonuses, nor to a ship with no bonus spots.
func test_no_bonus_comes_without_bonuses_or_spots() -> void:
	var off := SimFixtures.config(1, SimFixtures.calm_until(600.0), 1, SimFixtures.below_decks())
	var sim := MatchSim.create(off)
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(3.0))
	assert_true(_of(events, SimEvent.Kind.BONUS_CAME).is_empty(), "bonuses off")
	var spotless := SimFixtures.bonus_sim(SimFixtures.bonus_rules(), 1, SimFixtures.deck())
	events = SimFixtures.step(spotless, {}, Ticks.from_seconds(3.0))
	assert_true(_of(events, SimEvent.Kind.BONUS_CAME).is_empty(), "the flat deck has no spots")


## Her sinking on the fast clock quickens the plan with her: a fast match gets as many
## bonuses per sinking as a paced one, each at half the time on a clock twice as fast.
func test_the_fast_clock_quickens_the_plan() -> void:
	var rules := SimFixtures.bonus_rules(4.0, 10.0, 3.0, 9)
	var paced := SimFixtures.config(1, SimFixtures.calm_until(600.0), 1, SimFixtures.below_decks(9))
	paced.bonus_rules = rules
	var fast := SimFixtures.config(
		1, MatchConfig.quickened(SimFixtures.calm_until(600.0), 2.0), 1, SimFixtures.below_decks(9)
	)
	fast.bonus_rules = rules
	var came := {}
	for config: MatchConfig in [paced, fast]:
		var ticks := PackedInt32Array()
		for event: SimEvent in SimFixtures.step(
			MatchSim.create(config), {}, Ticks.from_seconds(40.0)
		):
			if event.kind == SimEvent.Kind.BONUS_CAME:
				ticks.append(event.tick)
		came[config] = ticks
	var slow: PackedInt32Array = came[paced]
	var quick: PackedInt32Array = came[fast]
	assert_eq(quick[0], Ticks.from_seconds(2.0), "the first at half its time")
	for index in mini(slow.size(), quick.size()):
		assert_almost_eq(quick[index], slow[index] / 2.0, 1.0, "bonus %d at half its time" % index)
	assert_gt(quick.size(), slow.size(), "more of them by the same match time")


## The plan draws from a stream of its own (SeedStreams' "bonus"), so bonuses on leave her
## sinking, the match stream and every bot's draws as they are with bonuses off: on the
## tug, her drawn hit the same, and a bots-only match on her — a plan drawn, but no spot to
## bring a bonus to — the same tick by tick.
func test_the_plan_moves_no_other_draw() -> void:
	var hits := PackedStringArray()
	var runners: Array[MatchRunner] = []
	for on: bool in [false, true]:
		var config := RunMatch.default_config(4, TUG_SEATS, &"tug")
		var spotless: ShipLayout = config.ship.duplicate()
		spotless.bonus_spots = []
		config.ship = spotless
		config.bonus_rules = SimFixtures.bonus_rules(0.0, 1.0, 0.5, 9) if on else null
		var told := MatchTranscript.new()
		told.hit(config.schedule())
		hits.append(told.text())
		runners.append(RunMatch.bots_only(config))
	assert_eq(hits[1], hits[0], "her sinking: the same hit, drawn alike")
	assert_eq(runners[1].snapshot, runners[0].snapshot, "the spawns: the match stream alike")
	for _tick in 20 * Ticks.RATE:
		runners[0].step()
		runners[1].step()
		if runners[1].snapshot != runners[0].snapshot:
			fail_test("the bots part at tick %d" % runners[0].tick())
			return
	assert_eq(runners[1].digest.hex(), runners[0].digest.hex(), "every bot's draws alike")


## The plan runs until her sinking is over: none comes after it.
func test_no_bonus_is_planned_past_her_sinking_s_end() -> void:
	var config := SimFixtures.config(1, SimFixtures.calm_until(10.0), 1, SimFixtures.below_decks(9))
	config.bonus_rules = SimFixtures.bonus_rules(1.0, 2.0, 0.0, 9)
	var sim := MatchSim.create(config)
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(30.0))
	var came := _of(events, SimEvent.Kind.BONUS_CAME)
	assert_eq(came.size(), 5, "at 1, 3, 5, 7 and 9 s")
	if not came.is_empty():
		assert_lte(came[-1].tick, sim.schedule.end_tick())
