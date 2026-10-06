extends GutTest
## BotBrain v1's intents (§7): lining a shove up toward the water, bracing a charge,
## recovering uphill, keeping a choice against dithering, and going at whoever stands
## highest — each stepped through the sim, the bot behind its delayed view (D10).

const SEED := 1701


func _tier(tier: StringName) -> BotProfile:
	return BotProfile.for_tier(tier)


## The flat deck with its railings taken away: every side is an open drop to the sea.
func _open_deck() -> ShipLayout:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	layout.railings = []
	return layout


## [param bot] plays seat 0 of [param sim]; every other seat stands where it is.
func _runner(sim: MatchSim, bot: BotInputSource) -> MatchRunner:
	var sources: Array[InputSource] = [bot]
	for _seat in range(1, sim.config.seats):
		sources.append(InputSource.new())
	return MatchRunner.new(sim, sources)


func test_lineup_puts_the_target_between_bot_and_water() -> void:
	# The target stands a metre from the starboard edge; the hard bot comes up beside it,
	# along the edge — a shove from there would only push it along the deck. It spars no
	# more, as once the ship founders.
	var sim := MatchSim.create(SimFixtures.config(2, null, SEED, _open_deck()))
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 3.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.0))
	var profile: BotProfile = _tier(&"hard").duplicate()
	profile.spar_margin_m = 0.0
	var source := BotInputSource.new(0, profile, sim.config)
	var runner := _runner(sim, source)
	var lined_up := false
	var landed := Vector2.ZERO
	var in_the_sea := false
	for _tick in 6 * Ticks.RATE:
		var bot_at := sim.state.seats[0].pos
		var target_at := sim.state.seats[1].pos
		for event: SimEvent in runner.step():
			if event.kind == SimEvent.Kind.SHOVE_LANDED and landed == Vector2.ZERO:
				landed = Vector2(target_at.x - bot_at.x, target_at.z - bot_at.z)
			if event.kind == SimEvent.Kind.ENTERED_WATER and event.seat == 1:
				in_the_sea = true
		lined_up = lined_up or source.brain.intent == BotBrain.Intent.LINE_UP
		if in_the_sea:
			break
	assert_true(lined_up, "it set out to line the shove up")
	assert_ne(landed, Vector2.ZERO, "and threw it")
	var cone := deg_to_rad(SimFixtures.rules().shove_cone_deg)
	assert_lt(absf(landed.angle_to(Vector2(0.0, 1.0))), cone, "from inboard, toward the water")
	assert_true(in_the_sea, "the target went over the side")


func test_hard_bot_braces_a_charged_shove() -> void:
	var rules := SimFixtures.rules()
	# Seat 0 charges a shove at the hard bot, seat 1, square in front of it, and lets it
	# go before it is full: a brace takes a charge that is not.
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.5, 0.0, 0.0), 180.0)
	var charging := SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE, 0.0)
	SimFixtures.step(sim, {0: charging})
	var source := BotInputSource.new(1, _tier(&"hard"), sim.config)
	var release := Ticks.from_seconds(rules.charge_threshold) + 4
	var bot := sim.state.seats[1]
	var hit := false
	var shoved_into_it := false
	var answered := false
	var braced_when_hit := false
	for tick in 2 * Ticks.RATE:
		source.observe(sim.snapshot(), sim.pose())
		var frame := source.next_frame(sim.state.tick)
		if frame.is_held(InputFrame.SHOVE):
			shoved_into_it = shoved_into_it or not hit
			answered = answered or hit
		var held := charging if tick < release else SimFixtures.frame(0, Vector2.ZERO, 0, 0.0)
		for event: SimEvent in sim.step([held, frame]):
			if event.kind == SimEvent.Kind.SHOVE_LANDED and event.seat == 0 and not hit:
				hit = true
				braced_when_hit = bot.bracing
				assert_false(bot.is_staggered(), "the brace held")
	assert_true(hit, "the charge was thrown")
	assert_false(shoved_into_it, "it never shoved into the windup")
	assert_true(braced_when_hit, "it was braced when the charge landed")
	assert_true(answered, "and shoved back once it was spent")
	assert_false(bot.is_out())


func test_bot_recovers_uphill_near_an_edge() -> void:
	# Starboard down past the grip angle, the ship lifted clear of the sea, the bot alone
	# a metre from the open starboard edge: idle, it would slide off.
	var steep := SimFixtures.rules().grip_angle_deg + 6.0
	var tilted := SimFixtures.config(1, SimFixtures.tilted(0.0, steep), SEED, _open_deck())
	var idle := MatchSim.create(tilted)
	SimFixtures.place(idle, 0, Vector3(0.0, 0.0, 3.0))
	SimFixtures.step(idle, {}, 2 * Ticks.RATE)
	assert_ne(idle.state.seats[0].body, PlayerState.Body.GROUNDED, "left alone, it slides off")

	var sim := MatchSim.create(tilted)
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 3.0))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	runner.step()
	assert_eq(source.brain.intent, BotBrain.Intent.RECOVER)
	runner.run(2 * Ticks.RATE)
	var bot := sim.state.seats[0]
	assert_eq(bot.body, PlayerState.Body.GROUNDED, "it stayed on the deck")
	assert_lt(bot.pos.z, 3.0 - 1.0, "having walked uphill, away from the edge")


func test_hysteresis_prevents_dithering() -> void:
	# Two seats four metres either side of the bot swap which is nearer by a few
	# centimetres every few ticks: the bot keeps the one it chose; without hysteresis
	# it turns from one to the other again and again.
	var changes := {}
	for hysteresis: float in [_tier(&"normal").hysteresis, 0.0]:
		var profile: BotProfile = _tier(&"normal").duplicate()
		profile.hysteresis = hysteresis
		profile.mistake_rate = 0.0
		var sim := SimFixtures.sim(3)
		SimFixtures.place(sim, 0, Vector3.ZERO)
		var source := BotInputSource.new(0, profile, sim.config)
		var chosen := PackedInt32Array()
		var intents := PackedInt32Array()
		for tick in 3 * Ticks.RATE:
			var snapshot := sim.snapshot().duplicate(true)
			snapshot["tick"] = tick
			var nearer := 0.1 if tick / 4 % 2 == 0 else -0.1
			snapshot["seats"][1]["pos"] = Vector3(-4.0 + nearer, 0.0, 0.0)
			snapshot["seats"][2]["pos"] = Vector3(4.0 + nearer, 0.0, 0.0)
			source.observe(snapshot, sim.pose())
			source.next_frame(tick)
			if chosen.is_empty() or chosen[-1] != source.brain.target:
				chosen.append(source.brain.target)
			if intents.is_empty() or intents[-1] != source.brain.intent:
				intents.append(source.brain.intent)
		changes[hysteresis] = chosen.size() - 1
		if hysteresis > 0.0:
			assert_eq(chosen.size(), 1, "with hysteresis: one target, kept")
			assert_eq(intents.size(), 1, "and one intent")
	assert_gt(changes[0.0], 5, "without it, it dithers")


func test_intent_hysteresis_holds_between_close_scores() -> void:
	# The bot's target, by the open starboard edge, stands a body's width from it at one
	# think and two at the next: lining the shove up scores just above going straight at
	# it, then just below — by less than the hysteresis either way. The bot keeps the
	# intent it chose; without hysteresis it swaps at every think. It spars no more, so a
	# drop that near is one to line up.
	var edge := _open_deck().platforms[0].area.end.y
	var stride := SimFixtures.rules().body_radius * 2.0
	var changes := {}
	for hysteresis: float in [_tier(&"normal").hysteresis, 0.0]:
		var profile: BotProfile = _tier(&"normal").duplicate()
		profile.hysteresis = hysteresis
		profile.mistake_rate = 0.0
		profile.brace_read = 0.0
		profile.lineup_weight = 0.3
		profile.spar_margin_m = 0.0
		var sim := MatchSim.create(SimFixtures.config(2, null, SEED, _open_deck()))
		SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, edge - 1.0))
		SimFixtures.place(sim, 1, Vector3(0.0, 0.0, edge - 1.0))
		var source := BotInputSource.new(0, profile, sim.config)
		var intents := PackedInt32Array()
		for tick in 3 * Ticks.RATE:
			var snapshot := sim.snapshot().duplicate(true)
			snapshot["tick"] = tick
			var off := stride * 0.6 if tick / profile.think_period % 2 == 0 else stride * 1.6
			snapshot["seats"][1]["pos"] = Vector3(0.0, 0.0, edge - off)
			source.observe(snapshot, sim.pose())
			source.next_frame(tick)
			if intents.is_empty() or intents[-1] != source.brain.intent:
				intents.append(source.brain.intent)
		changes[hysteresis] = intents.size() - 1
		var scored := [BotBrain.Intent.LINE_UP, BotBrain.Intent.HUNT]
		assert_true(intents[0] in scored, "hysteresis %s: a scored intent" % hysteresis)
	assert_eq(changes[_tier(&"normal").hysteresis], 0, "with hysteresis: one intent, kept")
	assert_gt(changes[0.0], 5, "without it, it swaps back and forth")


func test_a_bot_prefers_the_target_with_the_water_behind_it() -> void:
	# On the open deck, all at one height: seat 2 a little nearer, in the middle of the
	# deck; seat 1 a little farther, close by the starboard edge, the sea behind it.
	# Nearness alone picks seat 2; a hard bot weighs what a shove would do, and picks 1.
	var edge := _open_deck().platforms[0].area.end.y
	var targets := {}
	for weight: float in [0.0, _tier(&"hard").exposure_weight]:
		var profile: BotProfile = _tier(&"hard").duplicate()
		profile.exposure_weight = weight
		var sim := MatchSim.create(SimFixtures.config(3, null, SEED, _open_deck()))
		SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.0))
		SimFixtures.place(sim, 1, Vector3(0.0, 0.0, edge - 0.6))
		SimFixtures.place(sim, 2, Vector3(-(edge - 1.0), 0.0, 0.0))
		var source := BotInputSource.new(0, profile, sim.config)
		source.observe(sim.snapshot(), sim.pose())
		source.next_frame(sim.state.tick)
		targets[weight] = source.brain.target
	assert_eq(targets[0.0], 2, "by nearness: the one in the middle")
	assert_eq(targets[_tier(&"hard").exposure_weight], 1, "weighing the shove: the one by the edge")


func test_a_bot_does_not_commit_with_a_threat_at_its_back() -> void:
	# The hard bot looks at seat 1 in reach; seat 2 stands right behind it, facing it.
	# Minding its back, it holds the shove; with nobody behind it, it throws it.
	var rules := SimFixtures.rules()
	var gap := rules.body_radius * 2.0 + 0.3
	var shoved := {}
	for behind: float in [gap, 20.0]:
		var profile: BotProfile = _tier(&"hard").duplicate()
		profile.brace_read = 0.0
		var sim := SimFixtures.sim(3)
		SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
		SimFixtures.place(sim, 1, Vector3(gap, 0.0, 0.0), 0.0)
		SimFixtures.place(sim, 2, Vector3(-behind, 0.0, 0.0), 0.0)
		var source := BotInputSource.new(0, profile, sim.config)
		var pressed := false
		for tick in Ticks.RATE:
			source.observe(sim.snapshot(), sim.pose())
			pressed = pressed or source.next_frame(sim.state.tick + tick).is_held(InputFrame.SHOVE)
		shoved[behind] = pressed
	assert_false(shoved[gap], "a threat at its back: it holds its shove")
	assert_true(shoved[20.0], "nobody behind it: it shoves")


func test_late_in_the_sinking_a_bot_presses_closer_to_the_water() -> void:
	# The flat deck down by the head, the sea over its middle — every deck it has, under
	# — and the bot's target standing a metre aft of the waterline. With its late
	# margin the normal bot goes in closer to the water after it than without.
	var trim := 5.0
	var sinking := SimFixtures.scenario([[0.0, 3.0 + 2.0 * sin(deg_to_rad(trim)), trim, 0.0]])
	var nearest := {}
	for share: float in [0.0, _tier(&"normal").late_margin_share]:
		var profile: BotProfile = _tier(&"normal").duplicate()
		profile.mistake_rate = 0.0
		profile.late_margin_share = share
		var sim := SimFixtures.sim(2, sinking)
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
		SimFixtures.place(sim, 1, Vector3(-3.2, 0.0, 1.0))
		var runner := _runner(sim, BotInputSource.new(0, profile, sim.config))
		nearest[share] = INF
		for _tick in 5 * Ticks.RATE:
			runner.step()
			# How far up the deck from the sea its feet are, in metres.
			var above := sim.pose().world_height(sim.state.seats[0].pos) / sin(deg_to_rad(trim))
			nearest[share] = minf(nearest[share], above)
	var late: float = nearest[_tier(&"normal").late_margin_share]
	assert_lt(late, nearest[0.0] - 0.2, "late, it goes in closer to the water")
	assert_gt(late, 0.0, "but not into it")


func test_king_of_hill_targets_the_highest_seat() -> void:
	# On the main deck abreast the boat deck: seat 1 two metres off on the main deck,
	# seat 2 up on the boat deck, farther — both within earshot.
	var layout := SimFixtures.steamer()
	var targets := {}
	for tier: StringName in [&"easy", &"normal", &"hard"]:
		var sim := SimFixtures.sim(3, null, layout)
		SimFixtures.place(sim, 0, Vector3(5.0, 0.0, 3.5))
		SimFixtures.place(sim, 1, Vector3(7.0, 0.0, 3.5))
		SimFixtures.place(sim, 2, Vector3(1.0, 2.5, 2.5))
		var source := BotInputSource.new(0, _tier(tier), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		source.next_frame(sim.state.tick)
		targets[tier] = source.brain.target
	assert_eq(targets[&"hard"], 2, "hard goes at whoever stands highest")
	assert_eq(targets[&"normal"], 2, "so does normal")
	assert_eq(targets[&"easy"], 1, "easy goes at whoever stands nearest")


## Down by the head and seen going further, with the foot of the boat deck's stairs a
## hand above the sea: the bridge still stands highest, a seat waits up there, but a bot
## on the boat deck that has watched the water come up forward goes down while the way
## aft is dry and makes for the poop deck, the end she rises by — it is not left on an
## island the sea closes round. The two seats stand for a full match: neither is down
## to hunting the last seats left.
func test_a_bot_leaves_an_island_to_be_for_the_last_refuge() -> void:
	var layout := SimFixtures.steamer()
	var by_the_head := SimFixtures.scenario([[0.0, 2.5, 4.0, 0.0], [10.0, 2.5, 8.0, 0.0]])
	var sim := SimFixtures.sim(2, by_the_head, layout)
	SimFixtures.place(sim, 0, Vector3(-2.0, 2.5, 2.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	var graph := WalkGraph.new(layout, Surfaces.new(layout), SimFixtures.rules())
	var poop_deck := graph.deck_of(SimFixtures.platform_named(layout, &"poop deck"))
	var bridge := graph.deck_of(SimFixtures.platform_named(layout, &"bridge"))
	var pose := sim.pose()
	var found := graph.search(sim.state.seats[0].pos, sim.state.seats[0].surface, pose)
	assert_eq(graph.highest_in(found, pose), bridge, "the bridge stands highest now")
	var profile: BotProfile = _tier(&"normal").duplicate()
	profile.hunt_at_seats = 0
	var source := BotInputSource.new(0, profile, sim.config)
	var runner := _runner(sim, source)
	var reached := false
	for _tick in 30 * Ticks.RATE:
		runner.step()
		var bot := sim.state.seats[0]
		if bot.body == PlayerState.Body.SWIMMING or bot.is_out():
			break
		if graph.zone_at(bot.pos, bot.surface) == poop_deck:
			reached = true
			break
	var bot := sim.state.seats[0]
	assert_true(reached, "it made the poop deck dry: at %s" % bot.pos)


## Settled half a metre, the cabins' floor a hand above the sea: a bot in a starboard
## cabin climbs out, its target on the bridge — out to the corridor, up the aft stair,
## round its head and forward past the hatch, up the boat deck's stairs. It never turns
## back down a stair it has come up, nor stalls at the foot of the next.
func test_a_bot_climbing_out_from_below_decks_never_turns_back_on_a_stair() -> void:
	var layout := SimFixtures.steamer()
	var settled := SimFixtures.scenario([[0.0, 0.5, 0.0, 0.0]])
	var sim := SimFixtures.sim(2, settled, layout)
	SimFixtures.place(sim, 0, Vector3(-7.0, -2.6, 2.8))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	var graph := WalkGraph.new(layout, Surfaces.new(layout), SimFixtures.rules())
	var bridge := graph.deck_of(SimFixtures.platform_named(layout, &"bridge"))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var passed: Array[int] = []
	var climbed := false
	for _tick in 40 * Ticks.RATE:
		runner.step()
		climbed = climbed or source.brain.intent == BotBrain.Intent.CLIMB_OUT
		var bot := sim.state.seats[0]
		var zone := graph.zone_at(bot.pos, bot.surface)
		if zone != WalkGraph.NONE and (passed.is_empty() or passed.back() != zone):
			passed.append(zone)
		if zone == bridge and not sim.surfaces.is_ramp(bot.surface):
			break
	assert_true(climbed, "it climbed out")
	assert_eq(passed.back(), bridge, "it reached the bridge: at %s" % sim.state.seats[0].pos)
	var again := passed.filter(func(zone: int) -> bool: return passed.count(zone) > 1)
	assert_eq(again, [], "it never went back into a zone it had left: %s" % [passed])


## Settled half a metre, the ship not yet foundering: a bot that climbs out of the
## cabins stops climbing once up on the main deck, three metres out of the sea's reach,
## and goes after its target there instead of on up to the bridge.
func test_a_bot_out_of_the_seas_reach_stops_climbing() -> void:
	var layout := SimFixtures.steamer()
	var settled := SimFixtures.scenario([[0.0, 0.5, 0.0, 0.0]])
	var sim := SimFixtures.sim(2, settled, layout)
	SimFixtures.place(sim, 0, Vector3(-7.0, -2.6, 2.8))
	SimFixtures.place(sim, 1, Vector3(-13.4, 0.0, 3.0))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var climbed := false
	var nearest := INF
	var highest := -INF
	for _tick in 20 * Ticks.RATE:
		runner.step()
		climbed = climbed or source.brain.intent == BotBrain.Intent.CLIMB_OUT
		nearest = minf(nearest, sim.state.seats[0].pos.distance_to(sim.state.seats[1].pos))
		highest = maxf(highest, sim.state.seats[0].pos.y)
	assert_true(climbed, "it climbed out")
	assert_lt(nearest, 2.0, "it came at its target on the main deck")
	assert_lt(highest, 2.0, "it never went on up to the boat deck")


## On a dry, level ship the cabins' floor stands under a metre above the sea, and so
## does the way out of them: that is no way going under. A bot down there with its
## target on the main deck goes up after it, never climbing out for the bridge.
func test_a_bot_below_decks_on_a_dry_ship_does_not_climb_out() -> void:
	var layout := SimFixtures.steamer()
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(-7.0, -2.6, 2.8))
	SimFixtures.place(sim, 1, Vector3(1.5, 0.0, -1.5))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var climbed := 0
	for _tick in 10 * Ticks.RATE:
		runner.step()
		climbed += 1 if source.brain.intent == BotBrain.Intent.CLIMB_OUT else 0
	assert_eq(climbed, 0, "ticks it spent climbing out")
	assert_eq(source.brain.target, 1, "it went after its target")


## In the alley between the hatch and the port stair up to the boat deck, its target on
## the bridge: a bot walks along the stair's side to its foot and up — beside a stair
## is not under it.
func test_a_bot_beside_a_stair_walks_along_it_to_its_foot() -> void:
	var layout := SimFixtures.steamer()
	var graph := WalkGraph.new(layout, Surfaces.new(layout), SimFixtures.rules())
	var boat_deck := graph.deck_of(SimFixtures.platform_named(layout, &"boat deck"))
	for start: Vector3 in [Vector3(4.0, 0.0, -1.45), Vector3(5.5, 0.0, -1.45)]:
		var sim := SimFixtures.sim(2, null, layout)
		SimFixtures.place(sim, 0, start)
		SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
		var runner := _runner(sim, BotInputSource.new(0, _tier(&"normal"), sim.config))
		var up := false
		for _tick in 10 * Ticks.RATE:
			runner.step()
			var bot := sim.state.seats[0]
			if graph.zone_at(bot.pos, bot.surface) == boat_deck:
				up = true
				break
		assert_true(up, "from %s it got up: at %s" % [start, sim.state.seats[0].pos])


## Settled half a metre, the cabins' floor a hand above the sea: a bot in a starboard
## cabin, its target still in a port one and a third seat on the bridge. It climbs out
## once, and up on the main deck — out of the sea's reach, so it climbs no further — it
## does not go back down after its target into rooms the sea is about to take.
func test_a_bot_that_climbed_out_does_not_go_back_down_after_its_target() -> void:
	var layout := SimFixtures.steamer()
	var settled := SimFixtures.scenario([[0.0, 0.5, 0.0, 0.0]])
	var sim := SimFixtures.sim(3, settled, layout)
	SimFixtures.place(sim, 0, Vector3(-7.0, -2.6, 2.8))
	SimFixtures.place(sim, 1, Vector3(-7.0, -2.6, -2.8))
	SimFixtures.place(sim, 2, Vector3(-2.5, 4.7, 0.0))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var climbs := 0
	var climbing := false
	var up := false
	var back_down := false
	for _tick in 30 * Ticks.RATE:
		runner.step()
		var now := source.brain.intent == BotBrain.Intent.CLIMB_OUT
		climbs += 1 if now and not climbing else 0
		climbing = now
		var bot := sim.state.seats[0]
		up = up or bot.pos.y >= 0.0
		back_down = back_down or up and bot.pos.y < -2.0
	assert_true(up, "it climbed out: at %s" % sim.state.seats[0].pos)
	assert_eq(climbs, 1, "times it set off climbing out")
	assert_false(back_down, "it never went back down below decks")


## On a dry, level ship the cabins stand out of the sea's reach: a bot on the main deck
## that hears its target in the cabin under it goes down after it and fights it there.
func test_on_a_dry_ship_a_bot_goes_below_decks_after_its_target() -> void:
	var layout := SimFixtures.steamer()
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(-7.0, 0.0, 3.5))
	SimFixtures.place(sim, 1, Vector3(-7.0, -2.6, 2.8))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var nearest := INF
	for _tick in 20 * Ticks.RATE:
		runner.step()
		nearest = minf(nearest, sim.state.seats[0].pos.distance_to(sim.state.seats[1].pos))
	assert_eq(source.brain.target, 1, "it went after its target")
	assert_lt(nearest, 1.5, "and came at it below decks")


## Settled half a metre, a bot climbing out of a cabin is knocked off its feet before
## it is out: in the air it stands in no zone, which is not where it was making for —
## it climbs on, without ever letting go, until it is out of the sea's reach.
func test_a_bot_knocked_off_its_feet_climbing_out_climbs_on() -> void:
	var layout := SimFixtures.steamer()
	var settled := SimFixtures.scenario([[0.0, 0.5, 0.0, 0.0]])
	var sim := SimFixtures.sim(2, settled, layout)
	SimFixtures.place(sim, 0, Vector3(-7.0, -2.6, 2.8))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	var source := BotInputSource.new(0, _tier(&"normal"), sim.config)
	var runner := _runner(sim, source)
	var bot := sim.state.seats[0]
	while source.brain.intent != BotBrain.Intent.CLIMB_OUT and sim.state.tick < Ticks.RATE:
		runner.step()
	assert_eq(source.brain.intent, BotBrain.Intent.CLIMB_OUT, "it set off climbing out")
	bot.body = PlayerState.Body.AIRBORNE
	bot.surface = Surfaces.NONE
	bot.vel.y = 6.0
	var let_go := 0
	var out_of_reach := SimFixtures.rules().body_height
	while sim.pose().world_height(bot.pos) <= out_of_reach and sim.state.tick < 5 * Ticks.RATE:
		runner.step()
		let_go += 0 if source.brain.intent == BotBrain.Intent.CLIMB_OUT else 1
	assert_gt(sim.pose().world_height(bot.pos), out_of_reach, "it got out: at %s" % bot.pos)
	assert_eq(let_go, 0, "ticks it was not climbing out on the way")


## On a level ship, early on, a bot spars: its target a metre from the railing, it
## holds the shove that would send it at the rail and over, and throws the one that
## sends it along the deck — and with no spar margin it throws both.
func test_on_a_level_ship_a_bot_spars() -> void:
	for from_deg: float in [90.0, 0.0]:
		var label := "from inboard" if from_deg == 90.0 else "along the deck"
		assert_eq(_spar_shoves(2.5, from_deg, 3, 0.0), from_deg == 0.0, "sparring: " + label)
		assert_true(_spar_shoves(0.0, from_deg, 3, 0.0), "no spar margin: " + label)


## A level ship that stays level does not hold the bots sparring: spar_for_s after the
## match went live, with nothing flooded, the shove at the railing is thrown.
func test_a_bot_spars_no_more_once_the_match_has_gone_on() -> void:
	var spar_for := _tier(&"normal").spar_for_s
	assert_false(_spar_shoves(2.5, 90.0, 3, spar_for * 0.5), "halfway: still sparring")
	assert_true(_spar_shoves(2.5, 90.0, 3, spar_for), "from spar_for_s: the shove at the rail")


## Down to the last two seats on a dry, level ship, the opening's spar margin counts for
## nothing: the shove toward the water is thrown.
func test_the_last_two_seats_fight_to_the_death() -> void:
	assert_true(_spar_shoves(2.5, 90.0, 2, 0.0), "two left: the shove at the railing")


## Whether the normal bot, a gap behind its target a metre from the railing — coming
## from [param from_deg], 90 from inboard — throws a shove within a second, with a spar
## margin of [param spar], [param seats] seats in the match — any third well off down
## the deck — and [param live_s] seconds of it gone.
func _spar_shoves(spar: float, from_deg: float, seats: int, live_s: float) -> bool:
	var rules := SimFixtures.rules()
	var gap := rules.body_radius * 2.0 + 0.3
	var target_at := Vector3(-6.0, 0.0, 3.0)
	var profile: BotProfile = _tier(&"normal").duplicate()
	profile.brace_read = 0.0
	profile.mistake_rate = 0.0
	profile.spar_margin_m = spar
	profile.spar_until = 0.5
	var sim := SimFixtures.sim(seats)
	var way := Vector2.from_angle(deg_to_rad(from_deg)) * gap
	SimFixtures.place(sim, 0, target_at - Vector3(way.x, 0.0, way.y), from_deg)
	SimFixtures.place(sim, 1, target_at)
	if seats > 2:
		SimFixtures.place(sim, 2, Vector3(10.0, 0.0, -3.0))
	var source := BotInputSource.new(0, profile, sim.config)
	var pressed := _go_live_for(source, sim, live_s)
	for tick in Ticks.RATE:
		source.observe(sim.snapshot(), sim.pose())
		pressed = pressed or source.next_frame(sim.state.tick + tick).is_held(InputFrame.SHOVE)
	return pressed


## [param source]'s bot sees [param sim] go live, then [param live_s] seconds on —
## the clock moved, nobody moved: whether it shoved as it went live.
func _go_live_for(source: BotInputSource, sim: MatchSim, live_s: float) -> bool:
	source.observe(sim.snapshot(), sim.pose())
	var pressed := source.next_frame(sim.state.tick).is_held(InputFrame.SHOVE)
	sim.state.tick += Ticks.from_seconds(live_s)
	return pressed


## Sparring, a bot answers a brace with a tap, never a charge — a charge sends a body
## over a railing from metres off; with no spar margin it charges it on its read, and
## so it does down to the last two seats.
func test_a_sparring_bot_does_not_charge_a_brace() -> void:
	assert_eq(_longest_press(2.5, 3), 1, "sparring: a tap")
	assert_gt(_longest_press(0.0, 3), 1, "no spar margin: a charge, held")
	assert_gt(_longest_press(2.5, 2), 1, "two left: a charge, held")


## The most ticks running the hard bot holds its shove against a bracing seat facing it,
## over a second, with a spar margin of [param spar] and [param seats] seats in the
## match — any third well off down the deck.
func _longest_press(spar: float, seats: int) -> int:
	var rules := SimFixtures.rules()
	var gap := rules.body_radius * 2.0 + 0.3
	var profile: BotProfile = _tier(&"hard").duplicate()
	profile.brace_read = 0.0
	profile.charge_read = 1.0
	profile.spar_margin_m = spar
	profile.spar_until = 0.5
	var sim := SimFixtures.sim(seats)
	SimFixtures.place(sim, 0, Vector3(-gap, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3.ZERO, 180.0)
	if seats > 2:
		SimFixtures.place(sim, 2, Vector3(10.0, 0.0, -3.0))
	sim.state.seats[1].bracing = true
	var source := BotInputSource.new(0, profile, sim.config)
	var run := 0
	var held := 0
	for tick in Ticks.RATE:
		source.observe(sim.snapshot(), sim.pose())
		var pressed := source.next_frame(sim.state.tick + tick).is_held(InputFrame.SHOVE)
		run = run + 1 if pressed else 0
		held = maxi(held, run)
	return held
