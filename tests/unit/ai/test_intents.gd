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
	# along the edge — a shove from there would only push it along the deck.
	var sim := MatchSim.create(SimFixtures.config(2, null, SEED, _open_deck()))
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 3.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.0))
	var source := BotInputSource.new(0, _tier(&"hard"), sim.config)
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
