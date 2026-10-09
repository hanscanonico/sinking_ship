extends SceneTree
## `make bench [SEATS=64] [SHIP=] [SECONDS=60] [SEED=1]`: what one MatchSim.step costs
## with many bodies on a huge hull (SH18, R7). Every seat is a wanderer on its own seeded
## dice — it walks a way for a second or two, turns, shoves and jumps now and then; no
## bots, whose planning on a hull this size is SH20's — on the Titanic-scale fixture
## (tests/fixtures/titanic_scale.gd), or on SHIP of the Fleet in her open-sea sinking.
## The match is played once through MatchRunner and its input log replayed through bare
## MatchSims, ROUNDS times with the spatial index and as many without it — IndexRules'
## cells and bands INF, one cell each, every query a scan — taking turns:
##
##   godot --headless --path . -s res://tools/bench_sim.gd -- --seats=64
##
## It prints the milliseconds per step, p50 and p99, each way, the load average beside
## them, and each way's digest: the index changes how fast, never what (D4), so the two
## must match. Timings are the machine's: compare runs of one session, never across.

const ROUNDS := 2
const FIXTURE := &"fixture"


## A seat played by dice: a heading held for 20 to 60 ticks, then another; one heading in
## four starts with a shove pressed — let go at once, or held into a charge — and one in
## six with a jump.
class Wanderer:
	extends InputSource

	var _seat: int
	var _dice: RandomNumberGenerator
	var _until := 0
	var _let_go := 0
	var _frame := InputFrame.new()

	func _init(seat: int, match_seed: int) -> void:
		_seat = seat
		_dice = SeedStreams.derive(match_seed, "bench %d" % seat)

	func next_frame(tick: int) -> InputFrame:
		if tick >= _until:
			_until = tick + _dice.randi_range(20, 60)
			var heading := _dice.randf() * TAU
			var buttons := 0
			if _dice.randi_range(0, 3) == 0:
				buttons |= InputFrame.SHOVE
			if _dice.randi_range(0, 5) == 0:
				buttons |= InputFrame.JUMP
			_let_go = tick + (1 if _dice.randi_range(0, 1) == 0 else 25)
			_frame = InputFrame.new(
				_seat,
				tick,
				InputFrame.quantize(Vector2.from_angle(heading)),
				buttons,
				InputFrame.quantize_yaw(heading)
			)
		elif tick == _let_go:
			_frame = InputFrame.new(_seat, tick, _frame.move, 0, _frame.look_yaw)
		return _frame


func _initialize() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var config := _config(args)
	var problems := config.problems()
	if not problems.is_empty():
		printerr("\n".join(problems))
		quit(1)
		return
	var sources: Array[InputSource] = []
	for seat in config.seats:
		sources.append(Wanderer.new(seat, config.match_seed))
	var runner := MatchRunner.new(MatchSim.create(config), sources)
	runner.run(Ticks.from_seconds(args["seconds"]))
	var played := runner.input_log
	var index := IndexRules.load_default()
	var cells := [index.surface_cell, index.body_cell, index.surface_band, index.scan_over]
	var step_us: Array[PackedInt64Array] = [PackedInt64Array(), PackedInt64Array()]
	var digests := PackedStringArray(["", ""])
	for turn in ROUNDS * 2:
		var indexed := turn % 2 == 0
		index.surface_cell = cells[0] if indexed else INF
		index.body_cell = cells[1] if indexed else INF
		index.surface_band = cells[2] if indexed else INF
		index.scan_over = cells[3] if indexed else INF
		var sim := MatchSim.create(config)
		var digest := SnapshotDigest.new()
		digest.add(sim.snapshot())
		for tick in range(played.first_tick, played.last_tick() + 1):
			var frames: Array[InputFrame] = []
			for seat in played.seats:
				frames.append(played.frame(tick, seat))
			var started := Time.get_ticks_usec()
			sim.step(frames)
			step_us[turn % 2].append(Time.get_ticks_usec() - started)
			digest.add(sim.snapshot(), sim.is_over())
		digests[turn % 2] = digest.hex()
	index.surface_cell = cells[0]
	index.body_cell = cells[1]
	index.surface_band = cells[2]
	index.scan_over = cells[3]
	var layout := config.ship
	var lines := PackedStringArray()
	(
		lines
		. append(
			(
				"bench %s · seed %d · %d seats · %d surfaces · %d ticks · %d rounds each way"
				% [
					args["ship"],
					config.match_seed,
					config.seats,
					layout.platforms.size() + layout.ramps.size() + layout.blockers.size(),
					played.last_tick() + 1 - played.first_tick,
					ROUNDS,
				]
			)
		)
	)
	var on := "step, index on  (cells %s m, %s m, bands %s m, scan over %s cells)" % cells
	lines.append(_stats(on, step_us[0]))
	lines.append(_stats("step, index off (one cell)", step_us[1]))
	lines.append("load: %s" % _uptime())
	var same := digests[0] == digests[1] and digests[0] == runner.digest.hex()
	var told := "match the match played" if same else "DIFFER"
	lines.append("digests %s · on %s · off %s" % [told, digests[0], digests[1]])
	printraw("\n".join(lines) + "\n")
	quit(0 if same else 1)


## --seats, --ship, --seconds and --seed, as `make match` takes them.
static func _parse(arguments: PackedStringArray) -> Dictionary:
	var args := {"seats": 64, "ship": FIXTURE, "seconds": 60.0, "seed": 1}
	for argument: String in arguments:
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2 and args.has(pair[0]) and not pair[1].is_empty():
			var given: Variant = args[pair[0]]
			args[pair[0]] = (
				StringName(pair[1])
				if given is StringName
				else pair[1].to_float() if given is float else pair[1].to_int()
			)
	return args


## The bench's match: on the fixture, standing level, or on a ship of the Fleet as
## her matches are struck; no countdown.
static func _config(args: Dictionary) -> MatchConfig:
	var rules: BrawlRules = load("res://data/rules/brawl.tres")
	if args["ship"] == FIXTURE:
		return MatchConfig.new(
			args["seed"], args["seats"], rules, TitanicScale.layout(), TitanicScale.scenario()
		)
	var ship := Fleet.layout(args["ship"])
	return MatchConfig.new(args["seed"], args["seats"], rules, ship, Fleet.scenario(args["ship"]))


## [param values], microseconds, as milliseconds: how many, the mean, p50, p99 and the
## longest.
static func _stats(label: String, values: PackedInt64Array) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for value: int in sorted:
		total += value
	var count := sorted.size()
	return (
		"%s: %d · mean %.2f ms · p50 %.2f ms · p99 %.2f ms · max %.2f ms"
		% [
			label,
			count,
			total / 1e3 / count,
			sorted[int(count * 0.5)] / 1e3,
			sorted[mini(count - 1, int(count * 0.99))] / 1e3,
			sorted[-1] / 1e3,
		]
	)


## The machine's load, as `uptime` says it: the timings are only worth as much.
static func _uptime() -> String:
	var said := []
	OS.execute("uptime", [], said)
	return str(said[0]).strip_edges() if not said.is_empty() else "?"
