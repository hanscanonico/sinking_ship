extends GutTest

const SEED := 1701


func _profile() -> BotProfile:
	return load(SimFixtures.NORMAL_BOT)


## A bots-only match on [param config]; the runner is the one loop (D13).
func _bots(config: MatchConfig) -> MatchRunner:
	return MatchRunner.new(MatchSim.create(config), BotInputSource.fill(config, _profile()))


func test_bot_only_emits_input_frames() -> void:
	var config := SimFixtures.config(3, null, SEED)
	var runner := _bots(config)
	runner.run(60)
	var source := BotInputSource.new(1, _profile(), config)
	source.observe(runner.snapshot, runner.sim.pose())
	var seen := runner.snapshot.duplicate(true)
	var before := runner.sim.snapshot()
	var frame := source.next_frame(runner.tick())
	assert_true(frame is InputFrame)
	assert_eq(frame.seat, 1)
	assert_eq(frame.tick, runner.tick())
	assert_true(frame.move.length_squared() <= InputFrame.AXIS_MAX * InputFrame.AXIS_MAX)
	assert_eq(frame.buttons & ~(InputFrame.SHOVE | InputFrame.BRACE), 0, "shove and brace only")
	assert_eq(runner.snapshot, seen, "the bot leaves what it saw alone")
	assert_eq(runner.sim.snapshot(), before, "and the match too")


func test_bot_is_deterministic_per_seed() -> void:
	var config := SimFixtures.config(4, load(SimFixtures.FLAT_SINKING), SEED)
	var first := _bots(config)
	var second := _bots(config)
	first.run(40 * Ticks.RATE)
	second.run(40 * Ticks.RATE)
	assert_eq(second.digest.hex(), first.digest.hex())
	for tick in range(first.input_log.first_tick, first.input_log.last_tick() + 1):
		for seat in config.seats:
			var a := first.input_log.frame(tick, seat)
			var b := second.input_log.frame(tick, seat)
			if [a.move, a.look_yaw, a.buttons] != [b.move, b.look_yaw, b.buttons]:
				fail_test("seat %d differs at tick %d" % [seat, tick])
				return

	# Each bot rolls only its own stream: another seed moves the headings.
	var reseeded := _bots(SimFixtures.config(4, load(SimFixtures.FLAT_SINKING), SEED + 1))
	reseeded.run(40 * Ticks.RATE)
	assert_ne(reseeded.digest.hex(), first.digest.hex())


## What seat [param seat]'s brain answers to one view of [param sim] as it stands.
func _first_move(sim: MatchSim, seat: int) -> Vector2:
	var source := BotInputSource.new(seat, _profile(), sim.config)
	source.observe(sim.snapshot(), sim.pose())
	return Vector2(source.next_frame(sim.state.tick).move)


func test_bot_gets_uphill_of_its_target_past_the_grip_angle() -> void:
	var grip := SimFixtures.rules().grip_angle_deg
	# Starboard down, so uphill is toward port (-z). The same bot, the same target
	# and the same heading roll each time; only the heel and the bot's side change.
	var moves: Array[Vector2] = []
	for case: Vector2 in [
		Vector2(grip - 4.0, 1.0), Vector2(grip + 4.0, 1.0), Vector2(grip + 4.0, -1.0)
	]:
		var sim := SimFixtures.sim(2, SimFixtures.tilted(0.0, case.x))
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, case.y))
		SimFixtures.place(sim, 1, Vector3(-6.0, 0.0, 0.0))
		moves.append(_first_move(sim, 0))
	var held := moves[0]
	var steep := moves[1]
	var already_uphill := moves[2]
	var aim_error := deg_to_rad(_profile().aim_error_deg + 1.0)
	assert_lt(absf(held.angle_to(Vector2(2.0, -1.0))), aim_error, "gripping: straight at it")
	assert_lt(steep.angle(), held.angle() - deg_to_rad(15.0), "steep: round its uphill side")
	assert_lt(absf(already_uphill.angle_to(Vector2(2.0, 1.0))), aim_error, "uphill: straight")


func test_bot_keeps_off_a_railing_gap_unless_lined_up() -> void:
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var gap := SimFixtures.rail_gap(edge)
	# Inside edge_margin of the starboard edge, and alone, so nothing to walk at.
	var near := edge - _profile().edge_margin_m * 0.8
	var railed := SimFixtures.sim(1)
	SimFixtures.place(railed, 0, Vector3(-8.0, 0.0, near))
	assert_eq(_first_move(railed, 0), Vector2.ZERO, "a railing between it and the sea: safe")

	var open := SimFixtures.sim(1)
	SimFixtures.place(open, 0, Vector3(gap.x, 0.0, near))
	assert_lt(_first_move(open, 0).y, 0.0, "level with the gap: backs off from it")

	# Its target stands between it and the gap: the shove is lined up, so it goes in.
	var lined_up := SimFixtures.sim(2)
	SimFixtures.place(lined_up, 0, Vector3(gap.x, 0.0, near))
	var reach := SimFixtures.rules().body_radius * 2.0
	SimFixtures.place(lined_up, 1, Vector3(gap.x, 0.0, near + reach))
	assert_gt(_first_move(lined_up, 0).y, 0.0, "lined up: walks at the target, toward the gap")


func test_bot_finds_its_way_up_to_its_target() -> void:
	# On the steamer, abaft the deckhouse, its only target standing still on the
	# bridge: round the deckhouse, up to the boat deck, up to the bridge.
	var layout := SimFixtures.steamer()
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var config := SimFixtures.config(2, null, SEED, layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, Vector3(-10.5, 0.0, 2.5))
	SimFixtures.place(sim, 1, Vector3(-2.5, layout.platforms[bridge].height, 0.0))
	var sources: Array[InputSource] = [BotInputSource.new(0, _profile(), config), InputSource.new()]
	var runner := MatchRunner.new(sim, sources)
	var reached := false
	for _tick in 30 * Ticks.RATE:
		runner.step()
		if sim.state.seats[0].surface == bridge:
			reached = true
			break
	assert_true(reached, "the bot climbed to the bridge")


func test_lone_bot_stays_dry_while_it_can() -> void:
	var config := SimFixtures.config(1, load(SimFixtures.FLAT_SINKING), SEED)
	var runner := _bots(config)
	SimFixtures.place(runner.sim, 0, Vector3.ZERO)
	runner.run(300 * Ticks.RATE)
	var bot := runner.sim.state.seats[0]
	assert_true(bot.is_out(), "the sea takes everyone in the end")

	# The last moment any spot edge_margin inside the deck was still dry — over the
	# whole sinking, not just while the bot was in.
	var area := config.ship.platforms[0].area.grow(-_profile().edge_margin_m)
	var surfaces := runner.sim.surfaces
	var last_dry := -1
	for tick in 300 * Ticks.RATE:
		var pose := runner.sim.schedule.pose_at(tick)
		for corner: Vector2 in [area.position, area.end, Vector2(area.position.x, area.end.y)]:
			if not surfaces.wet(Vector3(corner.x, 0.0, corner.y), pose):
				last_dry = tick
	assert_eq(bot.out_cause, PlayerState.Cause.WATER)
	assert_true(bot.surface != Surfaces.NONE, "it went under standing on the deck")
	assert_gt(bot.out_tick, last_dry - Ticks.RATE, "it held out until the deck ran out")


## Every look [param seat]'s brain sends over [param ticks] ticks, shown the same
## view of [param sim] each time, with [param profile]'s knobs.
func _looks(sim: MatchSim, seat: int, profile: BotProfile, ticks: int) -> Array[int]:
	var source := BotInputSource.new(seat, profile, sim.config)
	var looks: Array[int] = []
	for tick in ticks:
		source.observe(sim.snapshot(), sim.pose())
		looks.append(source.next_frame(tick).look_yaw)
	return looks


func test_bot_looks_toward_its_target() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-4.0, 0.0, 1.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(-7.0, 0.0, -2.0))
	var looks := _looks(sim, 0, _profile(), Ticks.RATE)
	var toward := Vector2(-3.0, -3.0).angle()
	var off := angle_difference(InputFrame.yaw_angle(looks[-1]), toward)
	assert_lt(absf(off), deg_to_rad(_profile().aim_error_deg + 0.1), "it looks at its target")
	assert_ne(looks[0], looks[-1], "having turned to do it")


func test_bot_turn_rate_is_capped_by_its_profile() -> void:
	# Its target is right behind it: half a turn to make.
	for turn_rate_deg: float in [_profile().turn_rate_deg, 90.0]:
		var profile: BotProfile = _profile().duplicate()
		profile.turn_rate_deg = turn_rate_deg
		var sim := SimFixtures.sim(2)
		SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
		SimFixtures.place(sim, 1, Vector3(-3.0, 0.0, 0.0))
		var looks := _looks(sim, 0, profile, 3 * Ticks.RATE)
		var most := turn_rate_deg / 360.0 * InputFrame.YAW_STEPS / Ticks.RATE
		var fastest := 0
		var previous := sim.state.seats[0].last_look
		for look: int in looks:
			var turn := posmod(look - previous, InputFrame.YAW_STEPS)
			fastest = maxi(fastest, mini(turn, InputFrame.YAW_STEPS - turn))
			previous = look
		assert_almost_eq(float(fastest), most, 0.5, "%s°/s: never faster" % turn_rate_deg)
		var behind := angle_difference(InputFrame.yaw_angle(looks[-1]), PI)
		assert_lt(absf(behind), deg_to_rad(profile.aim_error_deg + 0.1), "and it gets there")


## The normal profile with its reads forced: [param brace] and [param charge] are
## brace_read and charge_read.
func _reading(brace: float, charge: float) -> BotProfile:
	var profile: BotProfile = _profile().duplicate()
	profile.brace_read = brace
	profile.charge_read = charge
	return profile


func test_bot_braces_against_a_facing_windup() -> void:
	var rules := SimFixtures.rules()
	# Seat 0 winds up a shove that would land on the bot, seat 1, which faces away —
	# its own shove could not land, so a brace is its answer.
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	assert_eq(sim.state.seats[0].action, PlayerState.Action.WINDUP)
	var winding := sim.snapshot()
	# The same windup turned away from the bot, and the same one thrown and spent.
	var turned := winding.duplicate(true)
	turned["seats"][0]["facing"] = PI
	var spent := winding.duplicate(true)
	spent["seats"][0]["action"] = PlayerState.Action.RECOVERY
	var seen := {"reads it": winding, "no read": winding, "turned away": turned, "spent": spent}
	var answers := {}
	for case: String in seen:
		var source := BotInputSource.new(
			1, _reading(0.0 if case == "no read" else 1.0, 0.0), sim.config
		)
		source.observe(seen[case], sim.pose())
		answers[case] = source.next_frame(sim.state.tick)
	# Read again and again, it stands still and turns, at its turn rate, to look at
	# the shover: the brace covers where it looks.
	var reader := BotInputSource.new(1, _reading(1.0, 0.0), sim.config)
	var looks: Array[int] = []
	for tick in Ticks.RATE:
		reader.observe(winding, sim.pose())
		var frame := reader.next_frame(sim.state.tick + tick)
		assert_eq([frame.buttons, frame.move], [InputFrame.BRACE, Vector2i.ZERO], "braced, still")
		looks.append(frame.look_yaw)
	assert_eq(answers["reads it"].buttons, InputFrame.BRACE, "it braces")
	assert_ne(looks[0], looks[-1], "turning")
	assert_eq(looks[-1], InputFrame.quantize_yaw(PI), "to look at the shover")
	assert_eq(answers["no read"].buttons, 0, "without the read, no brace")
	assert_eq(answers["turned away"].buttons, 0, "a windup that would miss, no brace")
	assert_eq(answers["spent"].buttons, 0, "a shove already thrown, no brace")


func test_a_bot_climbing_out_does_not_brace() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	# Seat 0 winds up a shove that would land on the bot, seat 1, in the forward hold.
	# With the hold's floor well above the sea the bot braces; with it within the
	# climb margin it keeps climbing — rooted, it would drown there.
	var bot_at := Vector3(9.0, -2.6, -2.0)
	var shover_at := bot_at - Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0)
	var floor_above_sea := {"dry": 1.8, "climbing": _profile().climb_margin_m * 0.5}
	var braced := {}
	for case: String in floor_above_sea:
		var sink: float = layout.freeboard + bot_at.y - floor_above_sea[case]
		var sinking := SimFixtures.scenario([[0.0, sink, 0.0, 0.0]])
		var sim := SimFixtures.sim(2, sinking, layout)
		SimFixtures.place(sim, 0, shover_at, 0.0)
		SimFixtures.place(sim, 1, bot_at, 0.0)
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
		assert_eq(sim.state.seats[0].action, PlayerState.Action.WINDUP, case)
		var source := BotInputSource.new(1, _reading(1.0, 0.0), sim.config)
		source.observe(sim.snapshot(), sim.pose())
		braced[case] = source.next_frame(sim.state.tick).is_held(InputFrame.BRACE)
	assert_true(braced["dry"], "it braces on a dry floor")
	assert_false(braced["climbing"], "climbing out, it does not stop to brace")


func test_bot_charges_a_bracing_target() -> void:
	var rules := SimFixtures.rules()
	# The bot, seat 0, faces seat 1 in reach; seat 1 braces facing it.
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 180.0)
	var brace := SimFixtures.frame(1, Vector2.ZERO, InputFrame.BRACE, 180.0)
	SimFixtures.step(sim, {1: brace})
	assert_true(sim.state.seats[1].bracing)
	var source := BotInputSource.new(0, _reading(0.0, 1.0), sim.config)
	var held := 0
	var target := sim.state.seats[1]
	while not target.is_staggered() and held <= 2 * Ticks.RATE:
		source.observe(sim.snapshot(), sim.pose())
		var frame := source.next_frame(sim.state.tick)
		if frame.is_held(InputFrame.SHOVE):
			held += 1
		sim.step([frame, brace])
	assert_eq(held, Ticks.from_seconds(rules.charge_full), "held for a full charge")
	assert_true(target.is_staggered(), "the charge broke the brace")
	assert_almost_eq(SimFixtures.sent(target).length(), rules.charged_knockback, 0.0001)


func test_lone_bot_climbs_out_before_its_floor_floods() -> void:
	# Alone on the steamer as it sinks, from the forward hold — the first room to flood
	# — and from a cabin aft: the bot is out of the lower deck before the sea reaches
	# the room it started in.
	var layout := SimFixtures.steamer()
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	for start: Vector3 in [Vector3(8.0, -2.6, -2.0), Vector3(-7.0, -2.6, 2.8)]:
		var room := layout.room_at(start, 0.01)
		assert_ne(room, -1, "%s is in a room" % start)
		var config := SimFixtures.config(1, sinking, SEED, layout)
		var runner := _bots(config)
		SimFixtures.place(runner.sim, 0, start)
		# The first tick any corner of that room's floor is under.
		var area := layout.rooms[room].area
		var corners: Array[Vector2] = [
			area.position,
			area.end,
			Vector2(area.position.x, area.end.y),
			Vector2(area.end.x, area.position.y)
		]
		var floods := -1
		for tick in 150 * Ticks.RATE:
			var pose := runner.sim.schedule.pose_at(tick)
			for corner: Vector2 in corners:
				if (
					floods == -1
					and runner.sim.surfaces.wet(Vector3(corner.x, -2.6, corner.y), pose)
				):
					floods = tick
		assert_gt(floods, 0, "%s floods" % layout.rooms[room].name)
		runner.run(floods)
		var bot := runner.sim.state.seats[0]
		assert_false(bot.is_out(), "%s: still in when its floor floods" % layout.rooms[room].name)
		assert_gte(bot.pos.y, 0.0, "%s: up out of the lower deck by then" % layout.rooms[room].name)
