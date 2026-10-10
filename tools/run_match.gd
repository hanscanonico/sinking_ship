extends SceneTree
## `make match`: one bots-only match, headless, as fast as it runs, served by the
## local host the game plays through (SH11), printed as a transcript — its iceberg hit
## and how the must-sink rule came to it, one line per exit and per thing the physics
## does, then the verdict and the digest, and where the sinking stood at the end and
## how its bake ends. STOP= (--stop) stops a match still on then, unfinished; the bake's
## time and the timeline's size go to stderr, as the time is the machine's, not the
## match's.
##
##   godot --headless --path . -s res://tools/run_match.gd -- --seed=1701 --seats=8
##
## tests/unit/core/test_determinism.gd builds its golden match through these
## statics, so the golden files are exactly what this prints.

const DEFAULT_MATCH := "res://data/match/default.tres"
const DEFAULT_SEED := 1701


## The default match; [param seats] overrides its seat count when positive, and
## [param ship_name] its ship when given (MatchConfig.from_rules).
static func default_config(seed_value: int, seats: int = 0, ship_name := &"") -> MatchConfig:
	return MatchConfig.from_rules(load(DEFAULT_MATCH), seed_value, seats, ship_name)


## [param config] with every seat a bot of its tier.
static func bots_only(config: MatchConfig) -> MatchRunner:
	return MatchRunner.new(
		MatchSim.create(config), BotInputSource.fill(config, BotProfile.for_tier(config.bot_tier))
	)


## [param config]'s bots-only match on a MatchHost, with nobody connected.
static func served(config: MatchConfig) -> MatchHost:
	return MatchHost.new(bots_only(config), Transport.new(), NetRules.load_default())


## Steps [param host] to the end of its match, or to [param max_ticks].
static func transcript(host: MatchHost, max_ticks: int) -> String:
	var told := MatchTranscript.new()
	told.hit(host.runner.sim.schedule)
	while not host.is_over() and host.tick() < max_ticks:
		told.add(host.step())
	told.finish(host.runner)
	return told.text()


func _initialize() -> void:
	var args := MatchArgs.parse(OS.get_cmdline_user_args())
	if not args.problems().is_empty():
		printerr("\n".join(args.problems()))
		quit(1)
		return
	var config := default_config(
		args.seed_value if args.seed_value >= 0 else DEFAULT_SEED, args.seats, args.ship()
	)
	var match_rules: MatchRules = load(DEFAULT_MATCH)
	config.scenario = args.struck(config.scenario, match_rules.fast_clock if args.fast else 0.0)
	var problems := config.problems()
	var profile := BotProfile.for_tier(config.bot_tier)
	if profile == null:
		problems.append("bot: no profile for the tier %s" % config.bot_tier)
	else:
		problems.append_array(profile.problems())
	if not problems.is_empty():
		printerr("\n".join(problems))
		quit(1)
		return
	var started := Time.get_ticks_usec()
	var timeline := config.schedule().timeline()
	var took := (Time.get_ticks_usec() - started) / 1e6
	if timeline != null:
		printerr(
			(
				"bake %.2f s · %d steps · %d of %d states kept · %.1f kB"
				% [took, timeline.steps, timeline.count(), timeline.states, timeline.size() / 1e3]
			)
		)
	printraw(transcript(served(config), Ticks.from_seconds(args.seconds)))
	quit()
