extends SceneTree
## `make net-bench`: what the client costs (R7). One match of the default data,
## headless, served by a MatchHost and played through a MatchClient over a loopback
## lying as --net-sim says — seat 0's bot sampled on the client, as a player's input
## would be, every other seat the host's bot — timed beat by beat:
##
##   godot --headless --path . -s res://tools/net_bench.gd -- --seed=1701 \
##       --net-sim=latency:120,jitter:20,loss:5
##
## It prints the ticks re-run per beat, the client's and the host's time per beat —
## the client's also by how it met the newest snapshot — and the packet sizes. The
## first two seconds, while the client's lead settles, are left out. Timings are the
## machine's: read them beside its load.

const RunMatch := preload("res://tools/run_match.gd")
const SETTLE_BEATS := 2 * Ticks.RATE


func _initialize() -> void:
	var args := MatchArgs.parse(OS.get_cmdline_user_args())
	var config := RunMatch.default_config(
		args.seed_value if args.seed_value >= 0 else RunMatch.DEFAULT_SEED, args.seats
	)
	var profile := BotProfile.for_tier(config.bot_tier)
	var bots := BotInputSource.fill(config, profile)
	var player := bots[0]
	bots[0] = null
	var rules := NetRules.load_default()
	var played := LoopbackMatch.new(config, rules, args.net_sim, 0, player, bots)
	var re_run := PackedInt64Array()
	var client_us := PackedInt64Array()
	var host_us := PackedInt64Array()
	var by_path := {"nothing new": PackedInt64Array(), "trusted": PackedInt64Array()}
	by_path["rewound, re-ran none"] = PackedInt64Array()
	by_path["rewound and re-ran"] = PackedInt64Array()
	var beats := 0
	while not played.client.is_over() and beats < Ticks.from_seconds(args.seconds):
		played.clock.advance(Ticks.SECONDS_PER_TICK)
		var started := Time.get_ticks_usec()
		played.client.sample()
		var sampled := Time.get_ticks_usec()
		played.host.step()
		var hosted := Time.get_ticks_usec()
		played.client.step()
		var spent := (sampled - started) + (Time.get_ticks_usec() - hosted)
		beats += 1
		if beats <= SETTLE_BEATS:
			continue
		re_run.append(played.client.resim_ticks)
		client_us.append(spent)
		host_us.append(hosted - sampled)
		by_path[_path(played.client)].append(spent)
	var lines := PackedStringArray()
	lines.append("net-bench seed %d · %s · %d beats" % [config.match_seed, _wire(args), beats])
	lines.append(_stats("ticks re-run per beat", re_run, 1.0, ""))
	lines.append(_stats("client.step per beat", client_us, 0.001, " ms"))
	for path: String in by_path:
		lines.append(_stats("  %s" % path, by_path[path], 0.001, " ms"))
	lines.append(_stats("host.step per beat", host_us, 0.001, " ms"))
	var codec := WireCodec.new(config.data_hash())
	var snapshot := played.host.runner.snapshot
	var frames: Array[InputFrame] = []
	for tick in rules.input_redundancy:
		frames.append(InputFrame.new(0, tick))
	(
		lines
		. append(
			(
				"packets: snapshot %d B (%d seats, %d crates, %d railings, no events) · input %d B"
				% [
					codec.encode_snapshot(snapshot, 0, 0, 0).size(),
					snapshot["seats"].size(),
					snapshot["props"].size(),
					snapshot["railing_hp"].size(),
					codec.encode_inputs(frames).size(),
				]
			)
		)
	)
	printraw("\n".join(lines) + "\n")
	quit()


static func _path(client: MatchClient) -> String:
	match client.reconciled:
		MatchClient.Reconciled.TRUSTED:
			return "trusted"
		MatchClient.Reconciled.REWOUND:
			return "rewound and re-ran" if client.resim_ticks > 0 else "rewound, re-ran none"
	return "nothing new"


static func _wire(args: MatchArgs) -> String:
	var lie := args.net_sim
	if lie.latency == 0.0 and lie.jitter == 0.0 and lie.loss == 0.0:
		return "an instant wire"
	return (
		"latency %.0f ms, jitter %.0f ms, loss %.0f%%"
		% [lie.latency * 1000.0, lie.jitter * 1000.0, lie.loss * 100.0]
	)


## [param label]: how many, and the mean, median, 95th percentile and most of
## [param values], scaled by [param scale] and suffixed [param unit].
static func _stats(label: String, values: PackedInt64Array, scale: float, unit: String) -> String:
	if values.is_empty():
		return "%s: none" % label
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for value: int in sorted:
		total += value
	var count := sorted.size()
	return (
		"%s: %d · mean %.2f%s · p50 %.2f%s · p95 %.2f%s · max %.2f%s"
		% [
			label,
			count,
			total * scale / count,
			unit,
			sorted[int(count * 0.5)] * scale,
			unit,
			sorted[mini(count - 1, int(count * 0.95))] * scale,
			unit,
			sorted[-1] * scale,
			unit,
		]
	)
