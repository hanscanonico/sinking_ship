extends SceneTree
## `make sim-bench`: what one MatchSim.step costs with no bots — what a predicting
## client pays for every tick it re-runs (R7). One bots-only match of the default
## data is played through the local host, as `make match` plays it, and its input
## log replayed through a bare MatchSim ROUNDS times:
##
##   godot --headless --path . -s res://tools/sim_bench.gd -- --seed=1701 --seats=8
##
## It prints the time per step past the countdown, per snapshot() and per restore()
## of every snapshot of the replay into a used sim, then the load average beside it,
## and the replay's exact fingerprint — a hash of every snapshot's bytes, which a
## change that should not move the match must leave as it was. Timings are the
## machine's: compare two builds run by turns in one session, never across sessions.

const RunMatch := preload("res://tools/run_match.gd")
const NetBench := preload("res://tools/net_bench.gd")
const ROUNDS := 5


func _initialize() -> void:
	var args := MatchArgs.parse(OS.get_cmdline_user_args())
	var config := RunMatch.default_config(
		args.seed_value if args.seed_value >= 0 else RunMatch.DEFAULT_SEED, args.seats
	)
	var host := RunMatch.served(config)
	while not host.is_over() and host.tick() < Ticks.from_seconds(args.seconds):
		host.step()
	var played := host.runner.input_log
	var step_us := PackedInt64Array()
	var snapshot_us := PackedInt64Array()
	var restore_us := PackedInt64Array()
	var fingerprint := ""
	var digest := SnapshotDigest.new()
	for replay in ROUNDS:
		var sim := MatchSim.create(config)
		var snapshots: Array[Dictionary] = []
		if replay == 0:
			digest.add(sim.snapshot())
		for tick in range(played.first_tick, played.last_tick() + 1):
			var frames: Array[InputFrame] = []
			for seat in played.seats:
				frames.append(played.frame(tick, seat))
			var started := Time.get_ticks_usec()
			sim.step(frames)
			var stepped := Time.get_ticks_usec()
			var snapshot := sim.snapshot()
			var taken := Time.get_ticks_usec()
			snapshots.append(snapshot)
			if tick >= config.countdown_ticks:
				step_us.append(stepped - started)
				snapshot_us.append(taken - stepped)
			if replay == 0:
				fingerprint = (fingerprint + str(hash(var_to_bytes(snapshot)))).sha256_text()
				digest.add(snapshot, sim.is_over())
		for snapshot: Dictionary in snapshots:
			var started := Time.get_ticks_usec()
			sim.restore(snapshot)
			restore_us.append(Time.get_ticks_usec() - started)
	var header := "sim-bench seed %d · %d seats · %d crates · %d ticks · %d rounds"
	var crates := config.ship.props.size()
	var ticks := played.last_tick() + 1 - played.first_tick
	var replayed := "matches" if digest.hex() == host.runner.digest.hex() else "DIFFERS FROM"
	var lines := PackedStringArray()
	lines.append(header % [config.match_seed, config.seats, crates, ticks, ROUNDS])
	lines.append(NetBench._stats("MatchSim.step", step_us, 1.0, " µs"))
	lines.append(NetBench._stats("MatchSim.snapshot", snapshot_us, 1.0, " µs"))
	lines.append(NetBench._stats("MatchSim.restore", restore_us, 1.0, " µs"))
	lines.append("load: %s" % _uptime())
	lines.append("replay %s the host's digest · fingerprint %s" % [replayed, fingerprint.left(16)])
	printraw("\n".join(lines) + "\n")
	quit()


## The machine's load, as `uptime` says it: the timings are only worth as much.
static func _uptime() -> String:
	var said := []
	OS.execute("uptime", [], said)
	return str(said[0]).strip_edges() if not said.is_empty() else "?"
