extends GutTest
## Bots and bonuses (#307, #315), each bot behind its delayed view (D10): a bot goes below
## decks for a bonus worth more to it than its own, down toward the water by design, while
## its tier's range and margin hold — the water as it stands now, never as the timeline has
## it next — and takes it with a Grab press; it drops one gone, or once the water comes
## within its margin; and in the sea it counts the spare meter its Double life gives it,
## unspent, as more time.

## Where on the steamer's main deck a bot sets out from: a walk of 13 m from her cabin
## corridor's bonus spot, down the stair aft of her deckhouse, every step of it 0.8 m or
## more above the sea while she floats as built.
const MAIN_DECK := Vector3(-12.0, 0.0, 3.5)
## Where the other two seats stand meanwhile, on her main deck well forward of the bot.
const ASIDE := Vector3(4.0, 0.0, 4.2)


func _tier(tier: StringName) -> BotProfile:
	var profile: BotProfile = BotProfile.for_tier(tier).duplicate()
	profile.mistake_rate = 0.0
	return profile


## A match of three on the steamer, played with Double life and none of the plan's coming,
## sunk as [param sinking] has her — floating as built when none is given — seats 1 and 2
## standing ASIDE: three in, the bot is not down to its last rivals, whom it hunts hard
## (hunt_at_seats).
func _steamer(sinking: SinkScenario = null) -> MatchSim:
	var rules := SimFixtures.bonus_rules(600.0)
	var calm := SimFixtures.calm() if sinking == null else sinking
	var sim := SimFixtures.bonus_sim(rules, 3, SimFixtures.steamer(), calm)
	SimFixtures.place(sim, 1, ASIDE)
	SimFixtures.place(sim, 2, ASIDE + Vector3(2.0, 0.0, 0.0))
	return sim


## below_decks' hold drawn out to 75 m long, from far aft of the flat deck to her fore end,
## its bonus spot at its fore end: room enough to stand any tier's range off it. A bot in it
## has nowhere to go but the hold, its floor 1 m over the sea while she floats as built.
func _long_hold() -> ShipLayout:
	var layout := SimFixtures.below_decks()
	layout.rooms[0].area = Rect2(-60.0, -3.0, 75.0, 6.0)
	layout.platforms[-1].area = layout.rooms[0].area
	layout.bonus_spots[0].point = Vector3(14.0, SimFixtures.HOLD_FLOOR, 0.0)
	return layout


## A match of three on [param layout] — _long_hold when none is given — played with
## [param rules] — Double life alone when none are given, none of the plan's coming — the sea
## [param sink] metres up her, a bonus of the rules' first kind at the hold's spot and the
## other seats out of sight and earshot on the deck over it.
func _in_the_hold(sink := 0.0, rules: BonusRules = null, layout: ShipLayout = null) -> MatchSim:
	var playing := SimFixtures.bonus_rules(600.0) if rules == null else rules
	var sea := SimFixtures.scenario([[0.0, sink, 0.0, 0.0]])
	var sim := SimFixtures.bonus_sim(playing, 3, _long_hold() if layout == null else layout, sea)
	SimFixtures.bring_aboard(sim, 0)
	SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 0.0))
	SimFixtures.place(sim, 2, Vector3(-12.0, 0.0, 2.0))
	return sim


## Bonus rules of Double life, kind 0, and Plain, kind 1 (SimFixtures.plain_kind) — a kind
## no tier values — none of the plan's coming.
func _two_kinds() -> BonusRules:
	var kinds: Array[BonusKind] = [SimFixtures.double_life(), SimFixtures.plain_kind()]
	return SimFixtures.bonus_rules(600.0, 45.0, 0.0, 2, kinds)


## Whether [param profile]'s bot, seat 0 of [param sim] placed at [param at], goes for a
## bonus at its first think.
func _goes(sim: MatchSim, profile: BotProfile, at: Vector3) -> bool:
	SimFixtures.place(sim, 0, at)
	var source := BotInputSource.new(0, profile, sim.config)
	source.observe(sim.snapshot(), sim.pose())
	source.next_frame(sim.state.tick)
	return source.brain.intent == BotBrain.Intent.TAKE_BONUS


## The index of [param sim]'s bonus spot in the room called [param room].
func _spot_in(sim: MatchSim, room: StringName) -> int:
	var layout := sim.config.ship
	for index in layout.bonus_spots.size():
		if layout.rooms[layout.bonus_spots[index].room].name == room:
			return index
	return -1


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


## A bot on the steamer's main deck goes down the stair to her cabin corridor for the
## Double life lying there — a room it cannot see into: the feed has told every player
## — and takes it with a Grab press, used up at once.
func test_a_bot_goes_below_decks_for_a_bonus_and_takes_it() -> void:
	var sim := _steamer()
	SimFixtures.bring_aboard(sim, _spot_in(sim, &"cabin corridor"))
	SimFixtures.place(sim, 0, MAIN_DECK, 0.0)
	var bot := sim.state.seats[0]
	var runner := _runner(sim, BotInputSource.new(0, _tier(&"normal"), sim.config))
	var took := _until(runner, 20.0, func() -> bool: return bot.bonus != -1)
	assert_true(took, "it went down and took it: at %s" % bot.pos)
	assert_eq(bot.bonus, 0, "its bonus is Double life")
	assert_true(sim.state.bonuses.is_empty(), "gone from aboard")


## A bot sets out for a bonus while the floor it lies on and every step of its way there
## stand its margin above the water as the water stands then — the sea coming up her a
## second later, which nothing it sees tells it — and gives the bonus up once the water
## comes within that margin, its room still dry and the bonus still aboard.
func test_a_bot_gives_a_bonus_up_once_the_water_comes_within_its_margin() -> void:
	var profile := _tier(&"normal")
	var sim := _steamer()
	var spot := _spot_in(sim, &"cabin corridor")
	var floor := sim.pose().above_water(sim.config.ship.bonus_spots[spot].point)
	# From 1 s to 1.5 s the sea comes up her to put the corridor's floor, the lowest of the
	# way, a little within the bot's margin; then it stays.
	var rise := floor - (profile.bonus_margin_m - 0.05)
	var rows := [[0.0, 0.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0], [1.5, rise, 0.0, 0.0]]
	rows.append([600.0, rise, 0.0, 0.0])
	sim = _steamer(SimFixtures.scenario(rows))
	SimFixtures.bring_aboard(sim, spot)
	SimFixtures.place(sim, 0, MAIN_DECK, 0.0)
	var source := BotInputSource.new(0, profile, sim.config)
	var runner := _runner(sim, source)
	var going := func() -> bool: return source.brain.intent == BotBrain.Intent.TAKE_BONUS
	assert_true(_until(runner, 1.0, going), "it set out, the water clear of its margin")
	var took := _until(runner, 15.0, func() -> bool: return sim.state.seats[0].bonus != -1)
	assert_false(took, "it gave the bonus up once the water came within its margin")
	assert_false(going.call(), "and goes for it no more")
	assert_eq(sim.state.bonuses.size(), 1, "the bonus still aboard, its room dry")


## The lowest point of its way counts as the bonus's floor does: from her engine room on
## her lower deck, a bot leaves the Double life in her port side passage — 1.6 m higher,
## well clear of the sea — where once the sea is up her far enough to put the lower deck
## within its margin; with the lower deck clear of it, it goes.
func test_a_bot_heeds_the_lowest_point_of_its_way_to_a_bonus() -> void:
	var profile := _tier(&"normal")
	profile.bonus_range_m = 40.0
	var lower_deck := Vector3(-2.0, -2.6, -3.2)
	var probe := _steamer()
	var clear := probe.pose().above_water(lower_deck)
	for case: Array in [[clear - profile.bonus_margin_m + 0.05, false], [0.0, true]]:
		var sim := _steamer(SimFixtures.scenario([[0.0, case[0], 0.0, 0.0]]))
		var spot := _spot_in(sim, &"port side passage")
		SimFixtures.bring_aboard(sim, spot)
		SimFixtures.place(sim, 0, lower_deck, 0.0)
		var passage := sim.pose().above_water(sim.config.ship.bonus_spots[spot].point)
		assert_gt(passage, profile.bonus_margin_m + 1.0, "the passage's floor stands well clear")
		var source := BotInputSource.new(0, profile, sim.config)
		source.observe(sim.snapshot(), sim.pose())
		source.next_frame(sim.state.tick)
		var going := source.brain.intent == BotBrain.Intent.TAKE_BONUS
		assert_eq(going, case[1], "the sea %.2f m up her" % case[0])


## The floor of every room on its way counts too, by its lowest corner, as the bot's climb
## reads a floor: listed 4° to port, her engine room — on the way from her deckhouse hall
## down to her cabin corridor — has its port side within the bot's margin of the water while
## its doorways and the corridor stand clear of it, and the bot stays; upright, it goes.
func test_a_bot_heeds_the_floor_of_every_room_on_its_way() -> void:
	var profile := _tier(&"normal")
	profile.bonus_margin_m = 0.75
	var hall := Vector3(-2.5, 0.0, 2.2)
	for case: Array in [[-4.0, false], [0.0, true]]:
		var sim := _steamer(SimFixtures.scenario([[0.0, -0.1, 0.0, case[0]]]))
		var spot := _spot_in(sim, &"cabin corridor")
		SimFixtures.bring_aboard(sim, spot)
		SimFixtures.place(sim, 0, hall, 0.0)
		var corridor := sim.pose().above_water(sim.config.ship.bonus_spots[spot].point)
		assert_gt(corridor, profile.bonus_margin_m, "the corridor stands clear")
		var source := BotInputSource.new(0, profile, sim.config)
		source.observe(sim.snapshot(), sim.pose())
		source.next_frame(sim.state.tick)
		var going := source.brain.intent == BotBrain.Intent.TAKE_BONUS
		assert_eq(going, case[1], "listed %.0f°" % case[0])


## A bot sees a bonus only as old as its view, reaction_ticks: one taken since is still
## aboard to it, and it goes on for it; once its view shows it gone, it lets it go.
func test_a_bot_sees_a_bonus_only_as_old_as_its_view() -> void:
	var profile := _tier(&"normal")
	var sim := _in_the_hold(-1.0)
	SimFixtures.place(sim, 0, Vector3(9.0, SimFixtures.HOLD_FLOOR, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(13.1, SimFixtures.HOLD_FLOOR, 0.0), 0.0)
	var source := BotInputSource.new(0, profile, sim.config)
	source.observe(sim.snapshot(), sim.pose())
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.GRAB)})
	assert_eq(sim.state.seats[1].bonus, 0, "seat 1 took it")
	for _tick in profile.reaction_ticks - 1:
		source.observe(sim.snapshot(), sim.pose())
		SimFixtures.step(sim)
	source.observe(sim.snapshot(), sim.pose())
	var move := Vector2(source.next_frame(sim.state.tick).move)
	assert_eq(source.brain.intent, BotBrain.Intent.TAKE_BONUS, "still aboard to it")
	assert_gt(move.x, 0.0, "it walks on for the bonus it saw")
	for _tick in profile.think_period:
		SimFixtures.step(sim)
		source.observe(sim.snapshot(), sim.pose())
		source.next_frame(sim.state.tick)
	assert_ne(source.brain.intent, BotBrain.Intent.TAKE_BONUS, "gone, once its view shows it")


## A Grab press that reaches no bonus lets go of what the hands hold (GrabReach), so a bot
## with a lifebuoy in its hands presses for a bonus only once its view, as well as where it
## reckons it stands now, has the bonus in reach; with its hands empty, on its reckoning
## alone. Here its view shows it 1.35 m from the bonus, out of reach, walking at it fast
## enough to be in reach by now.
func test_a_bot_holding_a_ring_presses_for_a_bonus_only_once_its_view_has_it_in_reach() -> void:
	var ring := SimFixtures.lifebuoy(Vector3(0.0, SimFixtures.HOLD_FLOOR, 0.0))
	for holding: bool in [false, true]:
		var sim := _in_the_hold(-1.0, null, SimFixtures.crated([ring], _long_hold()))
		SimFixtures.place(sim, 0, Vector3(12.65, SimFixtures.HOLD_FLOOR, 0.0), 0.0)
		sim.state.seats[0].vel = Vector3(2.0, 0.0, 0.0)
		if holding:
			SimFixtures.hand(sim, 0, 0)
		var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		var frame := source.next_frame(sim.state.tick)
		assert_eq(source.brain.intent, BotBrain.Intent.TAKE_BONUS)
		assert_eq(frame.is_held(InputFrame.GRAB), not holding, "a ring in its hands: %s" % holding)


## A bot drops its intent once the bonus it went for is gone, even with nothing else to
## score — a tier of the test's own that neither wanders, hunts nor lines up: it seeks high
## ground instead.
func test_a_bot_drops_a_bonus_gone_though_nothing_else_scores() -> void:
	var profile := _tier(&"normal")
	profile.wander_weight = 0.0
	profile.hunt_weight = 0.0
	profile.lineup_weight = 0.0
	var sim := _in_the_hold(-1.0)
	SimFixtures.place(sim, 0, Vector3(9.0, SimFixtures.HOLD_FLOOR, 0.0), 0.0)
	var source := BotInputSource.new(0, profile, sim.config)
	var runner := _runner(sim, source)
	runner.step()
	assert_eq(source.brain.intent, BotBrain.Intent.TAKE_BONUS, "it goes for the bonus")
	sim.state.bonuses.clear()
	runner.run(profile.reaction_ticks + profile.think_period + 1)
	assert_eq(source.brain.intent, BotBrain.Intent.SEEK_HIGH, "gone, it is dropped")


## Each tier goes for a bonus only while the floor it lies on stands the tier's own margin
## over the water: a little more, it goes; a little less, it does not.
func test_each_tier_goes_only_while_its_margin_holds() -> void:
	var near := Vector3(11.0, SimFixtures.HOLD_FLOOR, 0.0)
	for tier: String in BotProfile.tiers():
		var profile := _tier(StringName(tier))
		for case: Array in [[0.05, true], [-0.05, false]]:
			var floor: float = profile.bonus_margin_m + case[0]
			var sim := _in_the_hold(SimFixtures.deck().freeboard + SimFixtures.HOLD_FLOOR - floor)
			var above := sim.pose().above_water(sim.config.ship.bonus_spots[0].point)
			assert_almost_eq(above, floor, 1e-3, "%s: the hold's floor %.2f m up" % [tier, floor])
			assert_eq(_goes(sim, profile, near), case[1], "%s, its floor %.2f m up" % [tier, floor])


## Each tier goes for a bonus only within its own range: a walk of nine tenths of it, it
## goes; half a metre past it, it does not. The hold lifted a metre clear of every margin.
func test_each_tier_goes_only_within_its_range() -> void:
	for tier: String in BotProfile.tiers():
		var profile := _tier(StringName(tier))
		var range_m := profile.bonus_range_m
		for case: Array in [[range_m * 0.9, true], [range_m + 0.5, false]]:
			var at := Vector3(14.0 - case[0], SimFixtures.HOLD_FLOOR, 0.0)
			var goes := _goes(_in_the_hold(-1.0), profile, at)
			assert_eq(goes, case[1], "%s, %.1f m off" % [tier, case[0]])


## A bot weighs a bonus's kind against its own bonus: it goes for one worth more to it than
## the one it has, or than none, and leaves one worth no more. Its tier here values Plain at
## half what it values Double life; the shipped tier, leaving Plain out, never goes for one.
func test_a_bot_weighs_a_bonus_against_its_own() -> void:
	var rules := _two_kinds()
	var profile := _tier(&"normal")
	profile.bonus_worth = {rules.kinds[0]: 1.0, rules.kinds[1]: 0.5}
	var near := Vector3(11.0, SimFixtures.HOLD_FLOOR, 0.0)
	# Its own bonus, the kind aboard — 0 Double life, 1 Plain, -1 none — and whether it goes.
	for case: Array in [[-1, 1, true], [1, 0, true], [0, 1, false], [0, 0, false]]:
		var sim := _in_the_hold(-1.0, rules)
		sim.state.bonuses[0].kind = case[1]
		sim.state.seats[0].bonus = case[0]
		var goes := _goes(sim, profile, near)
		assert_eq(goes, case[2], "its own %d, aboard %d" % case.slice(0, 2))
	var plain := _in_the_hold(-1.0, rules)
	plain.state.bonuses[0].kind = 1
	assert_false(_goes(plain, _tier(&"normal"), near), "a kind its tier leaves out, never")


## A bot weighs a bonus's worth against the walk to it: of a Plain at its feet and a
## Double life it values more, it goes for the Double life a short walk off, and for the
## Plain once the Double life lies near the end of its range.
func test_a_bot_weighs_a_bonus_against_the_walk_to_it() -> void:
	var rules := _two_kinds()
	var profile := _tier(&"normal")
	profile.bonus_worth = {rules.kinds[0]: 1.0, rules.kinds[1]: 0.6}
	profile.bonus_range_m = 25.0
	# How far fore of the bot the Double life lies, and which way it walks: fore, or aft for
	# the Plain a metre aft of it.
	for case: Array in [[5.0, 1.0], [24.0, -1.0]]:
		var layout := _long_hold()
		var bot_at := Vector3(14.0 - case[0], SimFixtures.HOLD_FLOOR, 0.0)
		var aft := ShipBonusSpot.new()
		aft.point = bot_at - Vector3(1.0, 0.0, 0.0)
		aft.room = 0
		layout.bonus_spots.append(aft)
		var sim := _in_the_hold(-1.0, rules, layout)
		SimFixtures.bring_aboard(sim, 1, 1)
		SimFixtures.place(sim, 0, bot_at)
		var source := BotInputSource.new(0, profile, sim.config)
		source.observe(sim.snapshot(), sim.pose())
		var move := Vector2(source.next_frame(sim.state.tick).move)
		assert_eq(source.brain.intent, BotBrain.Intent.TAKE_BONUS, "%.0f m" % case[0])
		assert_eq(signf(move.x), case[1], "the Double life %.0f m off" % case[0])


## A swimmer with Double life swims for a way out it could not reach on its one meter: its
## spare is a whole meter more of cold (MatchVerdict.cold_left), which its swim counts on;
## without one, nothing it could reach in time.
func test_a_swimmer_with_a_spare_meter_swims_for_a_way_out_only_it_can_reach() -> void:
	var rules := SimFixtures.rules()
	var off := 4.0 + rules.cold_meter * rules.swim_speed * 1.6
	var layout := SimFixtures.low_deck(rules.climb_reach * 0.5)
	for spare: bool in [false, true]:
		var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 2, layout)
		SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
		SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, off), 0.0)
		if spare:
			sim.state.seats[0].bonus = 0
		var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		var move := Vector2(source.next_frame(sim.state.tick).move)
		if spare:
			assert_lt(move.y, 0.0, "with a spare meter: for the deck, %.1f m off" % off)
		else:
			assert_eq(move, Vector2.ZERO, "without: nowhere it could reach")


## A swimmer with Strong arms swims for a way out only its own reach gets to (#316): a deck
## edge a hair under that reach out of the sea — past the brawl rules' — which its swim reads
## off its seat's rules; without them, nothing it could climb onto.
func test_a_swimmer_with_strong_arms_swims_for_a_way_out_only_it_can_reach() -> void:
	var layout := SimFixtures.low_deck(SimFixtures.strong_arms().climb_reach - 0.05)
	assert_gt(layout.freeboard, SimFixtures.rules().climb_reach, "past the brawl rules' reach")
	for strong: bool in [false, true]:
		var sim := SimFixtures.kind_sim(SimFixtures.strong_arms(), strong, 2, layout)
		SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
		SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0), 0.0)
		var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		var move := Vector2(source.next_frame(sim.state.tick).move)
		if strong:
			assert_lt(move.y, 0.0, "with Strong arms: for the deck")
		else:
			assert_eq(move, Vector2.ZERO, "without: nowhere it could climb onto")
