extends SceneTree
## `make match`: one bots-only match, headless, as fast as it runs, printed as a
## transcript — one line per exit, then the verdict and the digest.
##
##   godot --headless --path . -s res://tools/run_match.gd -- --seed=1701 --seats=8
##
## tests/unit/core/test_determinism.gd builds its golden match through these
## statics, so the golden files are exactly what this prints.

const DEFAULT_MATCH := "res://data/match/default.tres"
const DEFAULT_SEED := 1701


## The default match; [param seats] overrides its seat count when positive.
static func default_config(seed_value: int, seats: int = 0) -> MatchConfig:
	return MatchConfig.from_rules(load(DEFAULT_MATCH), seed_value, seats)


## [param config] with every seat a bot of its tier.
static func bots_only(config: MatchConfig) -> MatchRunner:
	return MatchRunner.new(
		MatchSim.create(config), BotInputSource.fill(config, BotProfile.for_tier(config.bot_tier))
	)


## Steps [param runner] to the end of its match, or to [param max_ticks].
static func transcript(runner: MatchRunner, max_ticks: int) -> String:
	var told := MatchTranscript.new()
	while not runner.is_over() and runner.tick() < max_ticks:
		told.add(runner.step())
	told.finish(runner)
	return told.text()


func _initialize() -> void:
	var args := MatchArgs.parse(OS.get_cmdline_user_args())
	var config := default_config(
		args.seed_value if args.seed_value >= 0 else DEFAULT_SEED, args.seats
	)
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
	printraw(transcript(bots_only(config), Ticks.from_seconds(args.seconds)))
	quit()
