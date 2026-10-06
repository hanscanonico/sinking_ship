extends GutTest

const SEED := 1701


func _profile() -> BotProfile:
	return load(SimFixtures.NORMAL_BOT)


## The normal profile without its lapses: for what a bot does when it does not slip.
func _steady() -> BotProfile:
	var profile: BotProfile = _profile().duplicate()
	profile.mistake_rate = 0.0
	return profile


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
	var runner := MatchRunner.new(MatchSim.create(config), BotInputSource.fill(config, _steady()))
	SimFixtures.place(runner.sim, 0, Vector3.ZERO)
	var events := runner.run(300 * Ticks.RATE)
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
	assert_eq(bot.out_cause, PlayerState.Cause.COLD)
	var kinds := events.map(func(event: SimEvent) -> SimEvent.Kind: return event.kind)
	assert_false(kinds.has(SimEvent.Kind.FELL), "the sea came up over the deck under it")
	assert_gt(bot.out_tick, last_dry - Ticks.RATE, "it held out until the deck ran out")


func test_a_lone_bot_stays_out_of_the_sea_from_every_spawn() -> void:
	# Alone on the steamer as it starts to sink, the shipped normal bot — lapses and
	# all — from each spawn: nobody to go at, so it makes for the high ground, round
	# the boat deck's stairs and past the gaps in the railings. Within the first minute
	# no floor it can reach floods but the hold's, which it climbs out of in time.
	var layout := SimFixtures.steamer()
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SCRIPT)
	for spawn: Vector3 in layout.spawns:
		var runner := _bots(SimFixtures.config(1, sinking, SEED, layout))
		SimFixtures.place(runner.sim, 0, spawn)
		var entered := -1
		for event: SimEvent in runner.run(60 * Ticks.RATE):
			if event.kind == SimEvent.Kind.ENTERED_WATER and entered == -1:
				entered = event.tick
		assert_eq(entered, -1, "from %s: in the sea at tick %d" % [spawn, entered])


func test_a_normal_bot_s_lapse_never_walks_it_into_the_sea() -> void:
	# The normal bot lapsing half the time — a second's random walk every other second
	# or so — on the flat deck as it sinks: its lapses keep off the water and the
	# deck's open ends, so it holds out as long as a steady one, until the deck runs out.
	var profile: BotProfile = _profile().duplicate()
	profile.mistake_rate = 0.5
	var config := SimFixtures.config(1, load(SimFixtures.FLAT_SINKING), SEED)
	var runner := MatchRunner.new(MatchSim.create(config), BotInputSource.fill(config, profile))
	SimFixtures.place(runner.sim, 0, Vector3.ZERO)
	var events := runner.run(300 * Ticks.RATE)
	var bot := runner.sim.state.seats[0]
	var area := config.ship.platforms[0].area.grow(-_profile().edge_margin_m)
	var last_dry := -1
	for tick in 300 * Ticks.RATE:
		var pose := runner.sim.schedule.pose_at(tick)
		for corner: Vector2 in [area.position, area.end, Vector2(area.position.x, area.end.y)]:
			if not runner.sim.surfaces.wet(Vector3(corner.x, 0.0, corner.y), pose):
				last_dry = tick
	var kinds := events.map(func(event: SimEvent) -> SimEvent.Kind: return event.kind)
	assert_false(kinds.has(SimEvent.Kind.FELL), "no lapse walked it off the deck")
	assert_eq(bot.out_cause, PlayerState.Cause.COLD)
	assert_gt(bot.out_tick, last_dry - Ticks.RATE, "it held out until the deck ran out")


func test_two_bots_in_the_pocket_by_the_boat_ramp_find_the_way_out() -> void:
	# The bow going down, the sea a few metres forward: two bots in the pocket between
	# the deckhouse's forward wall, the side of the starboard stair up to the boat deck
	# and the hatch. The way up to the poop lies straight across the stair's side; the
	# way out is round — through the deckhouse, or the long way about the hatch.
	var layout := SimFixtures.steamer()
	var sinking := SimFixtures.scenario([[0.0, 2.6, 7.0, -3.0], [30.0, 3.35, 10.0, -5.0]])
	var sim := MatchSim.create(SimFixtures.config(2, sinking, SEED, layout))
	var pocket := Vector3(3.4, 0.0, 1.5)
	SimFixtures.place(sim, 0, pocket, 180.0)
	SimFixtures.place(sim, 1, Vector3(3.5, 0.0, 0.6))
	var config := sim.config
	var sources: Array[InputSource] = [
		BotInputSource.new(0, _steady(), config), BotInputSource.new(1, _steady(), config)
	]
	var runner := MatchRunner.new(sim, sources)
	var kinds: Array[SimEvent.Kind] = []
	var out := false
	while not out and runner.tick() < 15 * Ticks.RATE:
		for event: SimEvent in runner.step():
			kinds.append(event.kind)
		out = true
		for seat in 2:
			out = out and _flat(sim.state.seats[seat].pos, pocket) > 4.0
	assert_true(out, "both got out of the pocket")
	# Up on the poop deck they may fight it out; on the way there, nobody went in.
	assert_false(kinds.has(SimEvent.Kind.ENTERED_WATER), "and neither went into the sea")


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
## brace_read and charge_read. It spars no more, as once the ship founders: a charge is
## a charge.
func _reading(brace: float, charge: float) -> BotProfile:
	var profile: BotProfile = _steady().duplicate()
	profile.brace_read = brace
	profile.charge_read = charge
	profile.spar_margin_m = 0.0
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
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SCRIPT)
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


func test_bot_leaves_the_bridge_on_the_collapse_warning() -> void:
	var layout := SimFixtures.steamer()
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(5.0, &"bridge")]
	)
	var runner := _bots(SimFixtures.config(1, scenario, SEED, layout))
	SimFixtures.place(runner.sim, 0, Vector3(-2.5, 4.7, 0.0))
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var bot := runner.sim.state.seats[0]
	runner.run(Ticks.from_seconds(2.0))
	assert_eq(bot.surface, bridge, "it holds the high ground until the warning")
	runner.run(Ticks.from_seconds(3.0))
	assert_ne(bot.surface, bridge, "off the bridge before it goes")
	assert_true(bot.pos.y < 4.0, "down off the bridge's ramp too")
	runner.run(Ticks.from_seconds(5.0))
	assert_false(bot.is_out())


func test_bot_avoids_the_low_rail_on_a_lurch_warning() -> void:
	# Port goes down: a bot by the port rail walks to starboard while the lurch is
	# telegraphed, and braces through the swing — never jumps.
	var scenario := SimFixtures.with_events(
		SimFixtures.tilted(2.0, 0.0), [SimFixtures.lurch(2.0, -20.0)]
	)
	var config := SimFixtures.config(1, scenario, SEED)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, -2.5))
	var source := BotInputSource.new(0, _profile(), config)
	var start_z := sim.state.seats[0].pos.z
	var braced := 0
	var jumped := false
	while sim.state.tick < Ticks.from_seconds(5.0):
		source.observe(sim.snapshot(), sim.pose())
		var frame := source.next_frame(sim.state.tick)
		sim.step([frame])
		if sim.pose().lurch != 0.0 and frame.is_held(InputFrame.BRACE):
			braced += 1
		jumped = jumped or frame.is_held(InputFrame.JUMP)
		if sim.state.tick == Ticks.from_seconds(2.0):
			assert_gt(sim.state.seats[0].pos.z, start_z + 0.5, "away from the port rail")
	assert_gt(braced, Ticks.RATE, "braced through the swing")
	assert_false(jumped, "and never jumped")
	assert_false(sim.state.seats[0].is_out())


## A seat that presses one way from a tick on, and stands still before it.
class Pressing:
	extends InputSource

	var seat: int
	var from_tick: int
	var move: Vector2

	func _init(pressing_seat: int, pressing_from: int, toward: Vector2) -> void:
		seat = pressing_seat
		from_tick = pressing_from
		move = toward

	func next_frame(tick: int) -> InputFrame:
		var pressed := move if tick >= from_tick else Vector2.ZERO
		return InputFrame.new(seat, tick, InputFrame.quantize(pressed))


func test_swimming_bot_heads_for_a_climbable_edge() -> void:
	# Three metres out from the flat deck's side, the deck 0.4 m out of the sea.
	var config := SimFixtures.config(2, null, SEED, SimFixtures.low_deck(0.4))
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 7.0))
	assert_lt(_first_move(sim, 0).y, 0.0, "it swims for the side")
	var sources: Array[InputSource] = [BotInputSource.new(0, _profile(), config), InputSource.new()]
	var events := MatchRunner.new(sim, sources).run(Ticks.from_seconds(config.rules.cold_meter))
	var bot := sim.state.seats[0]
	assert_eq(bot.body, PlayerState.Body.GROUNDED, "and climbs out before the cold takes it")
	assert_eq(bot.surface, 0)
	var kinds := events.map(func(event: SimEvent) -> SimEvent.Kind: return event.kind)
	assert_true(kinds.has(SimEvent.Kind.CLIMBED_OUT))


func test_swimming_bot_climbs_a_boarding_ladder() -> void:
	# Over the steamer's side at the start, the main deck 3.4 m up: only the ladder
	# reaches it.
	var layout := SimFixtures.steamer()
	var config := SimFixtures.config(2, load(SimFixtures.STEAMER_SINKING), SEED, layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 1, Vector3(-17.0, 1.2, 0.0))
	SimFixtures.swim(sim, 0, Vector3(5.0, 0.0, 8.0))
	var sources: Array[InputSource] = [BotInputSource.new(0, _profile(), config), InputSource.new()]
	var events := MatchRunner.new(sim, sources).run(
		Ticks.from_seconds(config.rules.cold_meter + 3.0)
	)
	var bot := sim.state.seats[0]
	assert_false(bot.is_out(), "the cold did not take it")
	assert_eq(bot.body, PlayerState.Body.GROUNDED)
	var climbed := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.CLIMBED_OUT
	)
	assert_eq(climbed.size(), 1, "it climbed out once")
	if not climbed.is_empty():
		assert_eq(SimFixtures.name_of(layout, climbed[0].surface), &"main deck", "up the ladder")


func test_deck_bot_shoves_a_climber_back() -> void:
	# Seat 0 swims beside the flat deck, 0.4 m out of the sea, and after a second
	# presses in to climb out; the bot stands on the deck within its guard range. It
	# spars no more, as once the ship founders: a sparring bot lets a climber up.
	var config := SimFixtures.config(2, null, SEED, SimFixtures.low_deck(0.4))
	var sim := MatchSim.create(config)
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 4.6))
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 2.4), 90.0)
	var profile: BotProfile = _profile().duplicate()
	profile.spar_margin_m = 0.0
	var sources: Array[InputSource] = [
		Pressing.new(0, Ticks.RATE, Vector2(0.0, -1.0)), BotInputSource.new(1, profile, config)
	]
	var runner := MatchRunner.new(sim, sources)
	var knocked: Array[SimEvent] = []
	var climbed := false
	for _tick in 3 * Ticks.RATE:
		for event: SimEvent in runner.step():
			if event.kind == SimEvent.Kind.KNOCKED_BACK_IN:
				knocked.append(event)
			climbed = climbed or event.kind == SimEvent.Kind.CLIMBED_OUT and knocked.is_empty()
		if not knocked.is_empty():
			break
	assert_false(climbed, "the climber never got up")
	assert_eq(knocked.size(), 1, "the bot shoved it back in")
	assert_eq([knocked[0].seat, knocked[0].credit], [0, 1])


## Seat 0 a bot of [param profile], every other seat [param others] or standing still.
func _with_bot(sim: MatchSim, profile: BotProfile, others: Array[InputSource] = []) -> Array:
	var source := BotInputSource.new(0, profile, sim.config)
	var sources: Array[InputSource] = [source]
	for seat in range(1, sim.config.seats):
		sources.append(others[seat - 1] if seat - 1 < others.size() else InputSource.new())
	return [source, MatchRunner.new(sim, sources)]


func test_lurch_far_from_the_low_side_keeps_place_and_target() -> void:
	# Port goes down; the bot, five metres from the port side, is after a seat far aft.
	# It carries on after it through the warning — no walk for the high side — and
	# braces where it stands through the swing.
	var scenario := SimFixtures.with_events(
		SimFixtures.tilted(2.0, 0.0), [SimFixtures.lurch(2.0, -20.0)]
	)
	var sim := MatchSim.create(SimFixtures.config(2, scenario, SEED))
	SimFixtures.place(sim, 0, Vector3(4.0, 0.0, 1.0), 180.0)
	SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 1.0))
	var made := _with_bot(sim, _steady())
	var source: BotInputSource = made[0]
	var runner: MatchRunner = made[1]
	var bot := sim.state.seats[0]
	var warned_at := Ticks.from_seconds(1.0)
	var swing_at := Ticks.from_seconds(2.0)
	runner.run(warned_at)
	var x_warned := bot.pos.x
	var braced := 0
	while sim.state.tick < Ticks.from_seconds(5.0):
		runner.step()
		assert_eq(source.brain.target, 1, "its target, kept at %d" % sim.state.tick)
		assert_almost_eq(bot.pos.z, 1.0, 0.5, "not off to the high side at %d" % sim.state.tick)
		if sim.state.tick == swing_at:
			assert_lt(bot.pos.x, x_warned - 1.0, "it went on after its target in the warning")
		if sim.pose().lurch != 0.0 and bot.bracing:
			braced += 1
	assert_gt(braced, Ticks.RATE, "braced where it stood through the swing")
	assert_false(bot.is_out())


func test_bracing_bot_lets_go_to_step_back_from_the_edge() -> void:
	var rules := SimFixtures.rules()
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	layout.railings = []
	# Seat 1 winds up at the bot, seat 0, from beside it; the bot stands half a metre
	# from an open edge. Rooted in a brace it would stay there: it steps back instead.
	var sim := MatchSim.create(SimFixtures.config(2, null, SEED, layout))
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 3.5), 180.0)
	SimFixtures.place(sim, 1, Vector3(-(rules.body_radius * 2.0 + 0.3), 0.0, 3.5), 0.0)
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)})
	var source := BotInputSource.new(0, _reading(1.0, 0.0), sim.config)
	source.observe(sim.snapshot(), sim.pose())
	var frame := source.next_frame(sim.state.tick)
	assert_eq(source.brain.intent, BotBrain.Intent.BRACE, "it read the windup")
	assert_false(frame.is_held(InputFrame.BRACE), "but braces not at the edge")
	assert_lt(frame.move_vector().y, 0.0, "it steps back from it")


## A seat that braces every tick, looking astern (toward -x).
class Bracing:
	extends InputSource

	var seat: int

	func _init(bracing_seat: int) -> void:
		seat = bracing_seat

	func next_frame(tick: int) -> InputFrame:
		return InputFrame.new(seat, tick, Vector2i.ZERO, InputFrame.BRACE, InputFrame.YAW_STEPS / 2)


func test_bot_never_presses_a_shove_into_its_own_recovery() -> void:
	# A braced seat in reach takes a tap without flying off, so the bot could shove it
	# again at once — but its view of itself is reaction_ticks old. Tapping, or charging,
	# no press it makes comes while it is still busy with its last: each one is heeded.
	var rules := SimFixtures.rules()
	for charge_read: float in [0.0, 1.0]:
		var sim := SimFixtures.sim(2)
		SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
		SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 180.0)
		var others: Array[InputSource] = [Bracing.new(1)]
		var made := _with_bot(sim, _reading(0.0, charge_read), others)
		var runner: MatchRunner = made[1]
		var bot := sim.state.seats[0]
		var presses := 0
		var unheeded := 0
		var charged := false
		for _tick in 4 * Ticks.RATE:
			var busy := bot.action != PlayerState.Action.IDLE or bot.is_staggered()
			var before := bot.last_buttons
			runner.step()
			if bot.last_buttons & InputFrame.SHOVE and not before & InputFrame.SHOVE:
				presses += 1
				unheeded += 1 if busy else 0
			charged = charged or bot.action == PlayerState.Action.CHARGE
		assert_gt(presses, 2, "charge read %s: it kept shoving" % charge_read)
		assert_eq(unheeded, 0, "charge read %s: and every press was heeded" % charge_read)
		assert_eq(charged, charge_read > 0.0, "charge read %s: charging on the read" % charge_read)


func test_swimmer_swims_round_to_a_way_out_it_cannot_reach_straight() -> void:
	# The sea 1.5 m under the main deck, the forward hold flooded: under the deck's
	# overhang beside the hold, the hold's side stands across every straight swim to a
	# way out. Round the overhang's edge, the starboard boarding ladder is one.
	var layout := SimFixtures.steamer()
	var rules := SimFixtures.rules()
	var sinking := SimFixtures.scenario([[0.0, layout.freeboard - 1.5, 0.0, 0.0]])
	var config := SimFixtures.config(2, sinking, SEED, layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 1, Vector3(-17.0, 1.2, 0.0))
	SimFixtures.swim(sim, 0, Vector3(6.0, 0.0, 4.4))
	var swimmer := sim.state.seats[0]
	var reach := swimmer.cold * rules.swim_speed
	assert_null(
		sim.surfaces.nearest_climb(swimmer.pos, sim.pose(), rules, reach), "no way straight out"
	)
	var runner: MatchRunner = _with_bot(sim, _profile())[1]
	var events := runner.run(Ticks.from_seconds(rules.cold_meter + 2.0))
	var climbed := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.CLIMBED_OUT
	)
	assert_false(swimmer.is_out(), "the cold did not take it")
	assert_eq(climbed.size(), 1, "it climbed out")


func test_bot_is_not_pinned_in_the_bay_between_the_boat_deck_ramps() -> void:
	# In the bay forward of the deckhouse, between the hatch and the starboard ramp up
	# to the boat deck, its target up on the boat deck: it finds the ramp's foot.
	var layout := SimFixtures.steamer()
	var sim := SimFixtures.sim(2, null, layout)
	SimFixtures.place(sim, 0, Vector3(5.0, 0.0, 1.5), 180.0)
	SimFixtures.place(sim, 1, Vector3(1.0, 2.5, 2.5))
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	var runner: MatchRunner = _with_bot(sim, _steady())[1]
	var reached := false
	for _tick in 10 * Ticks.RATE:
		runner.step()
		if sim.state.seats[0].surface == boat_deck:
			reached = true
			break
	assert_true(reached, "up on the boat deck")


func test_bot_leaving_the_bridge_does_not_dither_at_the_ramp_foot() -> void:
	# Off the bridge on its collapse warning, down its ramp to the boat deck: from the
	# ramp's foot the bot keeps going one way, never back and forth.
	var layout := SimFixtures.steamer()
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(5.0, &"bridge")]
	)
	var sim := MatchSim.create(SimFixtures.config(2, scenario, SEED, layout))
	SimFixtures.place(sim, 0, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.place(sim, 1, Vector3(-17.5, 1.2, -2.5))
	var runner: MatchRunner = _with_bot(sim, _steady())[1]
	var bot := sim.state.seats[0]
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	while bot.surface != boat_deck and sim.state.tick < Ticks.from_seconds(6.0):
		runner.step()
	assert_eq(bot.surface, boat_deck, "down on the boat deck")
	var reversals := 0
	var last := Vector2.ZERO
	var from := bot.pos
	for _tick in 2 * Ticks.RATE:
		runner.step()
		var frame := runner.input_log.frame(sim.state.tick - 1, 0)
		var move := frame.move_vector()
		if move != Vector2.ZERO and last != Vector2.ZERO and move.dot(last) < 0.0:
			reversals += 1
		if move != Vector2.ZERO:
			last = move
	assert_lte(reversals, 1, "no dithering")
	assert_gt(bot.pos.distance_to(from), 2.0, "it got clear of the ramp's foot")
