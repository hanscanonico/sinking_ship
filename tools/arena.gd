extends SceneTree
## `make arena SEEDS=200`: bots-only matches, headless, in lobbies of tiers, written up
## as docs/arena.md — a dated record that the next run supersedes whole (§10, SH7).
##
##   godot --headless --path . -s res://tools/arena.gd -- --seeds=200 [--lobbies=a,b]
##
## Every lobby plays the default match (data/match/default.tres) for seeds 1…SEEDS;
## what a match does is a function of its seed (D4), so every number here but the
## milliseconds comes out the same on a rerun on the same build. The milliseconds
## are the one loop's — MatchRunner.step(), sim and bots together — per tick, on the
## machine that ran it.

const RunMatch := preload("res://tools/run_match.gd")

const REPORT := "res://docs/arena.md"
## The match time a match still on is stopped at, unfinished, unless --stop says.
const STOP_SECONDS := 900.0
const DEFAULT_SEEDS := 200
## The lobby that times sixteen seats plays this many seeds at most: it measures
## headroom, nothing else.
const SIXTEEN_SEEDS := 10
## A bot counts as idle on a tick when it is in, on its feet or afloat, free to act,
## presses nothing and its feet move less than this, in metres.
const STILL := 0.005
## Idle with an opponent in sight within this many metres — eye to eye, as the bots
## and the HUD ask Surfaces.line_of_sight — is what the gate bounds: a body a deck
## below, through the slab, is no fight being missed.
const NEAR := 6.0
const IDLE_BOUND_SECONDS := 3.0
## The plan's targets (SH7's card).
const HARD_WINS_AT_LEAST := 0.75
const SLOT_SHARE_AT_MOST := 1.6
const DRY_AT_PLUNGE_AT_MOST := 0.10
const DRY_AT_PLUNGE_SEATS := 3
const MEDIAN_FROM := 150.0
const MEDIAN_TO := 200.0
## The share of matches still on when the sinking's first platform collapses — the
## steamer's bridge — that SH7d aims at: the sinking is the match, not its epilogue.
const COLLAPSE_REACHED_AT_LEAST := 0.70
## Climbing out or fleeing on a dry ship — no platform under water at its middle — with
## the bot's feet over a body's height above the sea is running from nothing: on
## average a bot does it for at most this long a match (the SH7c review's gate).
const DRY_FLIGHT_AT_MOST_SECONDS := 2.0
## The tick-cost gate the SH7 review set, superseding the plan's 2 ms p99 at eight
## seats: sim + bots p50 and p99 at eight seats, p99 at sixteen.
const P50_AT_MOST_MS := 2.0
const P99_AT_MOST_MS := 8.0
const P99_SIXTEEN_AT_MOST_MS := 16.0


## One lobby: who fills its seats, and how many of the seeds it plays.
class Lobby:
	var key: String
	var title: String
	## Per seat: its tier, and whether it sees (false: it hears everyone, everywhere).
	var tiers: Array[StringName] = []
	var sighted: Array[bool] = []
	var seeds: int

	func _init(
		lobby_key: String, lobby_title: String, seat_tiers: Array, seat_sighted: Array
	) -> void:
		key = lobby_key
		title = lobby_title
		tiers.assign(seat_tiers)
		sighted.assign(seat_sighted)


## What one lobby's matches came to.
class Tally:
	var lobby: Lobby
	var matches := 0
	var lengths := PackedFloat64Array()
	var draws := 0
	## Matches still on at STOP, stopped there unfinished: a tool's limit, never a rule.
	var unfinished := 0
	var dry_at_plunge := 0
	var plunges := 0
	## Matches still on when the first platform collapsed, and the seats in then and at
	## the plunge, summed over the matches that saw it.
	var collapses := 0
	var in_at_collapse := 0
	var in_at_plunge := 0
	## Wins per spawn slot, per tier, per sightedness ("sighted"/"omniscient").
	var slot_wins := {}
	var tier_wins := {}
	var sight_wins := {}
	var idle_longest := 0
	var idle_where := ""
	var idle_near_longest := 0
	var idle_near_where := ""
	var tick_us := PackedInt64Array()
	var wall_seconds := 0.0
	## Exits credited to a crate, and railing spans the match broke — a vault or a crate,
	## never the sinking's own failures (SH10).
	var crate_exits := 0
	var spans_broken := 0
	## Ticks bots spent climbing out or fleeing on a dry ship, high above the sea, and
	## the longest a bot did in one match.
	var dry_flight_ticks := 0
	var dry_flight_longest := 0
	var dry_flight_where := ""


var _stop_ticks := Ticks.from_seconds(STOP_SECONDS)


func _initialize() -> void:
	var seeds := DEFAULT_SEEDS
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--seeds":
				seeds = value.to_int()
			"--lobbies":
				only = value.split(",", false)
			"--stop":
				_stop_ticks = Ticks.from_seconds(MatchArgs.clock_seconds(value))
	var started := Time.get_ticks_msec()
	var load_before := _load_average()
	var tallies: Array[Tally] = []
	for lobby: Lobby in _lobbies(seeds):
		if not only.is_empty() and not lobby.key in only:
			continue
		var tally := _play(lobby)
		if tally == null:
			quit(1)
			return
		tallies.append(tally)
	var minutes := (Time.get_ticks_msec() - started) / 60000.0
	var report := _report(tallies, seeds, minutes, [load_before, _load_average()])
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file == null:
		printerr("arena: cannot write %s" % REPORT)
		quit(1)
		return
	file.store_string(report)
	file.close()
	printraw(report)
	quit()


func _lobbies(seeds: int) -> Array[Lobby]:
	var normal := _repeat(&"normal", 8)
	var mixed: Array[StringName] = []
	var halves: Array[bool] = []
	for seat in 8:
		mixed.append(&"hard" if seat % 2 == 0 else &"easy")
		halves.append(seat % 2 == 0)
	var lobbies: Array[Lobby] = [
		Lobby.new("normal", "Eight normal bots — the default match", normal, _all(true, 8)),
		Lobby.new("hard-easy", "Four hard and four easy", mixed, _all(true, 8)),
		Lobby.new("sighted", "Four sighted and four omniscient, all normal", normal, halves),
		Lobby.new(
			"sixteen", "Sixteen normal bots — timing only", _repeat(&"normal", 16), _all(true, 16)
		),
	]
	for lobby: Lobby in lobbies:
		lobby.seeds = mini(seeds, SIXTEEN_SEEDS) if lobby.key == "sixteen" else seeds
	return lobbies


static func _repeat(tier: StringName, count: int) -> Array[StringName]:
	var tiers: Array[StringName] = []
	for _seat in count:
		tiers.append(tier)
	return tiers


static func _all(value: bool, count: int) -> Array[bool]:
	var values: Array[bool] = []
	for _seat in count:
		values.append(value)
	return values


## Plays [param lobby]'s seeds; null when its match cannot start.
func _play(lobby: Lobby) -> Tally:
	var tally := Tally.new()
	tally.lobby = lobby
	var started := Time.get_ticks_msec()
	for seed_value in range(1, lobby.seeds + 1):
		var config := RunMatch.default_config(seed_value, lobby.tiers.size())
		if lobby.tiers.size() > config.ship.spawns.size():
			config.ship = _with_spawns(config.ship, lobby.tiers.size(), config.rules)
		var problems := config.problems()
		var sources: Array[InputSource] = []
		var walk_graph := WalkGraph.new(config.ship, Surfaces.new(config.ship), config.rules)
		for seat in lobby.tiers.size():
			var profile := BotProfile.for_tier(lobby.tiers[seat])
			if profile == null:
				problems.append("arena: no bot tier %s" % lobby.tiers[seat])
				continue
			problems.append_array(profile.problems())
			if not lobby.sighted[seat]:
				profile = profile.duplicate()
				profile.hearing_m = INF
			sources.append(BotInputSource.new(seat, profile, config, walk_graph))
		if not problems.is_empty():
			printerr("\n".join(problems))
			return null
		_match(MatchRunner.new(MatchSim.create(config), sources), sources, tally, seed_value)
		printerr("arena: %s seed %d" % [lobby.key, seed_value])
	tally.wall_seconds = (Time.get_ticks_msec() - started) / 1000.0
	return tally


## Steps one match to its end, timing every tick, and adds it to [param tally]; the
## bots' intents are read off [param sources].
func _match(
	runner: MatchRunner, sources: Array[InputSource], tally: Tally, seed_value: int
) -> void:
	var config := runner.sim.config
	var fled := PackedInt32Array()
	fled.resize(config.seats)
	var slots := PackedInt32Array()
	for player: PlayerState in runner.sim.state.seats:
		slots.append(config.ship.spawns.find(player.pos))
	var idle := PackedInt32Array()
	idle.resize(config.seats)
	var idle_near := PackedInt32Array()
	idle_near.resize(config.seats)
	var before: Array[Vector3] = []
	for player: PlayerState in runner.sim.state.seats:
		before.append(player.pos)
	var eyes := PackedFloat64Array()
	for tier: StringName in tally.lobby.tiers:
		eyes.append(BotProfile.for_tier(tier).eye_height_m)
	var winner := -1
	var ended := -1
	var collapsed := false
	while not runner.is_over() and runner.tick() < _stop_ticks:
		var start := Time.get_ticks_usec()
		var events := runner.step()
		tally.tick_us.append(Time.get_ticks_usec() - start)
		for event: SimEvent in events:
			if event.kind == SimEvent.Kind.PLUNGE_BEGAN:
				tally.plunges += 1
				tally.in_at_plunge += _in(runner.sim)
				if _dry(runner.sim) >= DRY_AT_PLUNGE_SEATS:
					tally.dry_at_plunge += 1
			elif event.kind == SimEvent.Kind.PLATFORM_COLLAPSED and not collapsed:
				collapsed = true
				tally.collapses += 1
				tally.in_at_collapse += _in(runner.sim)
			elif event.kind == SimEvent.Kind.MATCH_ENDED:
				winner = event.seat
				ended = event.tick
			elif event.kind == SimEvent.Kind.SEAT_OUT and event.prop != -1:
				tally.crate_exits += 1
			elif (
				event.kind == SimEvent.Kind.RAILING_BROKE and (event.seat != -1 or event.prop != -1)
			):
				tally.spans_broken += 1
		var dry_ship := _ship_dry(runner.sim)
		for player: PlayerState in runner.sim.state.seats:
			var seat := player.seat
			var moved := Vector2(player.pos.x - before[seat].x, player.pos.z - before[seat].z)
			before[seat] = player.pos
			if dry_ship and _flees(sources[seat], player, runner.sim):
				tally.dry_flight_ticks += 1
				fled[seat] += 1
			if player.is_out() or player.is_climbing() or player.is_frozen():
				idle[seat] = 0
				idle_near[seat] = 0
				continue
			var still := (
				moved.length() < STILL and player.last_buttons == 0 and not player.is_staggered()
			)
			idle[seat] = idle[seat] + 1 if still else 0
			idle_near[seat] = (
				idle_near[seat] + 1 if still and _opponent_near(runner.sim, player, eyes) else 0
			)
			var where := (
				"seed %d seat %d at (%.1f, %.1f, %.1f), %s"
				% [
					seed_value,
					seat,
					player.pos.x,
					player.pos.y,
					player.pos.z,
					MatchTranscript.clock(runner.tick())
				]
			)
			if idle[seat] > tally.idle_longest:
				tally.idle_longest = idle[seat]
				tally.idle_where = where
			if idle_near[seat] > tally.idle_near_longest:
				tally.idle_near_longest = idle_near[seat]
				tally.idle_near_where = where
	tally.matches += 1
	if not runner.is_over():
		tally.unfinished += 1
		return
	tally.lengths.append(ended / float(Ticks.RATE))
	for seat in config.seats:
		if fled[seat] > tally.dry_flight_longest:
			tally.dry_flight_longest = fled[seat]
			tally.dry_flight_where = "seed %d seat %d" % [seed_value, seat]
	if winner == -1:
		tally.draws += 1
		return
	_count(tally.slot_wins, slots[winner])
	_count(tally.tier_wins, tally.lobby.tiers[winner])
	_count(tally.sight_wins, "sighted" if tally.lobby.sighted[winner] else "omniscient")


static func _count(counts: Dictionary, key: Variant) -> void:
	counts[key] = counts.get(key, 0) + 1


## How many seats are in, in the sea or out of it.
static func _in(sim: MatchSim) -> int:
	var count := 0
	for player: PlayerState in sim.state.seats:
		count += 0 if player.is_out() else 1
	return count


## How many seats are in and out of the sea.
static func _dry(sim: MatchSim) -> int:
	var dry := 0
	for player: PlayerState in sim.state.seats:
		if not player.is_out() and player.body != PlayerState.Body.SWIMMING:
			dry += 1
	return dry


## Whether no platform of the ship stands under water at its middle.
static func _ship_dry(sim: MatchSim) -> bool:
	var pose := sim.pose()
	for platform in sim.surfaces.platform_count():
		if sim.surfaces.flooded(platform, pose):
			return false
	return true


## Whether the bot behind [param source], in, is climbing out or fleeing with
## [param player]'s feet more than a body's height above the sea.
static func _flees(source: InputSource, player: PlayerState, sim: MatchSim) -> bool:
	var intent := (source as BotInputSource).brain.intent
	return (
		not player.is_out()
		and (intent == BotBrain.Intent.CLIMB_OUT or intent == BotBrain.Intent.FLEE)
		and sim.pose().world_height(player.pos) > sim.config.rules.body_height
	)


## Whether another seat in stands within NEAR of [param player] and in its sight: no
## wall, deck or hull between their eyes, [param eyes] high by seat.
static func _opponent_near(sim: MatchSim, player: PlayerState, eyes: PackedFloat64Array) -> bool:
	var pose := sim.pose()
	var eye := player.pos + Vector3.UP * eyes[player.seat]
	for other: PlayerState in sim.state.seats:
		if (
			other != player
			and not other.is_out()
			and other.pos.distance_to(player.pos) < NEAR
			and sim.surfaces.line_of_sight(eye, other.pos + Vector3.UP * eyes[other.seat], pose)
		):
			return true
	return false


## [param layout] with spawns added beside its own until there are [param seats]:
## for the sixteen-seat lobby, which the steamer has no spawns for.
static func _with_spawns(layout: ShipLayout, seats: int, rules: BrawlRules) -> ShipLayout:
	var wider: ShipLayout = layout.duplicate()
	var surfaces := Surfaces.new(layout)
	var spawns := layout.spawns.duplicate()
	var reach := rules.body_radius * 2.5
	for spawn: Vector3 in layout.spawns:
		for offset: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			if spawns.size() >= seats:
				break
			var beside := spawn + offset * reach
			var clear := (
				surfaces.under(beside, rules.step_height) != Surfaces.NONE
				and (
					surfaces
					. obstacle_contacts(
						beside, rules.body_radius, rules.body_height, rules.step_height
					)
					. is_empty()
				)
			)
			for other: Vector3 in spawns:
				clear = clear and other.distance_to(beside) >= reach
			if clear:
				spawns.append(beside)
				break
	wider.spawns.assign(spawns)
	return wider


## The machine's load averages over 1, 5 and 15 minutes, as the system reports them,
## or "unknown" where it does not.
static func _load_average() -> String:
	var output: Array = []
	if OS.execute("sysctl", ["-n", "vm.loadavg"], output) != 0 or output.is_empty():
		return "unknown"
	return str(output[0]).strip_edges().trim_prefix("{").trim_suffix("}").strip_edges()


func _report(tallies: Array[Tally], seeds: int, minutes: float, loads: Array) -> String:
	var lines := PackedStringArray()
	lines.append("# Arena — %s" % Time.get_date_string_from_system())
	lines.append("")
	lines.append(
		(
			"Written by `make arena SEEDS=%d` (tools/arena.gd) on %s, %s, in %.1f minutes."
			% [seeds, OS.get_model_name(), OS.get_processor_name(), minutes]
		)
	)
	if seeds < DEFAULT_SEEDS:
		lines.append(
			(
				(
					"Fewer seeds than the plan's %d: SEEDS is the knob, and %d seeds a lobby "
					+ "would take about %.0f minutes at this run's pace."
				)
				% [DEFAULT_SEEDS, DEFAULT_SEEDS, minutes * DEFAULT_SEEDS / seeds]
			)
		)
	lines.append(
		(
			(
				"Load average (1, 5, 15 min) at the start: %s; at the end: %s. The "
				+ "milliseconds are what this machine gave at that load: with a load above its "
				+ "%d cores they are measured under load, not a reading of the budget."
			)
			% [loads[0], loads[1], OS.get_processor_count()]
		)
	)
	lines.append(
		(
			"The build has the hazards (SH10: cargo, railing damage) and the network seam "
			+ "(SH11: the MatchRunner a MatchHost serves); a lobby steps that MatchRunner "
			+ "itself, so the milliseconds are sim and bots, with no snapshots sent."
		)
	)
	lines.append(
		(
			"A dated record: the next run supersedes this file whole. Each lobby plays the "
			+ "default match (data/match/default.tres) on seeds 1…N; match time is the "
			+ "transcript's clock, countdown included. A bot is idle on a tick when it is "
			+ "in, free to act, presses nothing and its feet move less than 5 mm; an "
			+ "opponent is in sight when no wall, deck or hull stands between their eyes "
			+ "(Surfaces.line_of_sight, the bots' and the HUD's question); dry means "
			+ "in and not in the sea. Everything but the milliseconds is the same on a "
			+ "rerun on the same build (D4)."
		)
	)
	lines.append("")
	lines.append(
		(
			"The tick-cost targets are the SH7 review's and supersede the plan's \"sim + bots "
			+ 'p99 ≤ 2 ms at eight seats": that budget priced the sim, O(n²) in n ≤ 16 bodies; '
			+ "bots that look through line of sight, route a walk graph and probe the edges "
			+ "spend a few milliseconds on the ticks they think, which a 2 ms p99 leaves no "
			+ "room for. 8 ms is a quarter of a 30 Hz tick, the rest left to drawing."
		)
	)
	lines.append("")
	lines.append_array(_targets(tallies))
	for tally: Tally in tallies:
		lines.append_array(_lobby_lines(tally))
	return "\n".join(lines) + "\n"


func _targets(tallies: Array[Tally]) -> PackedStringArray:
	var lines := PackedStringArray(["## Targets", "", "| Target | Measured | |", "|---|---|---|"])
	var by_key := {}
	for tally: Tally in tallies:
		by_key[tally.lobby.key] = tally
	if by_key.has("hard-easy"):
		var tally: Tally = by_key["hard-easy"]
		var share := _share(tally.tier_wins.get(&"hard", 0), tally.matches)
		lines.append(
			_row(
				"Hard wins ≥ 75% of four-hard-four-easy lobbies",
				"%.1f%%" % (share * 100.0),
				share >= HARD_WINS_AT_LEAST
			)
		)
	if by_key.has("normal"):
		var tally: Tally = by_key["normal"]
		var fair := 1.0 / tally.lobby.tiers.size()
		var worst := 0.0
		for slot: int in tally.slot_wins:
			worst = maxf(worst, _share(tally.slot_wins[slot], tally.matches) / fair)
		lines.append(
			_row(
				"No spawn slot wins more than 1.6× its fair share",
				"%.2f×" % worst,
				worst <= SLOT_SHARE_AT_MOST
			)
		)
		var dry := _share(tally.dry_at_plunge, tally.matches)
		lines.append(
			_row(
				"≤ 10% of matches reach the plunge with three or more dry",
				"%.1f%%" % (dry * 100.0),
				dry <= DRY_AT_PLUNGE_AT_MOST
			)
		)
		var median := _median(tally.lengths)
		lines.append(
			_row(
				"Median length 2:30–3:20",
				_clock(median),
				median >= MEDIAN_FROM and median <= MEDIAN_TO
			)
		)
		var collapse := _share(tally.collapses, tally.matches)
		lines.append(
			_row(
				"≥ 70% of matches still on at the bridge collapse (SH7d's aim)",
				"%.1f%%" % (collapse * 100.0),
				collapse >= COLLAPSE_REACHED_AT_LEAST
			)
		)
		var p50 := _percentile_ms(tally.tick_us, 0.5)
		var p99 := _percentile_ms(tally.tick_us, 0.99)
		lines.append(
			_row(
				"Sim + bots p50 ≤ 2 ms and p99 ≤ 8 ms per tick at eight seats",
				"p50 %.2f ms, p99 %.2f ms" % [p50, p99],
				p50 <= P50_AT_MOST_MS and p99 <= P99_AT_MOST_MS
			)
		)
	if by_key.has("sixteen"):
		var p99 := _percentile_ms(by_key["sixteen"].tick_us, 0.99)
		lines.append(
			_row(
				"Sim + bots p99 ≤ 16 ms per tick at sixteen seats",
				"%.2f ms" % p99,
				p99 <= P99_SIXTEEN_AT_MOST_MS
			)
		)
	var idle := 0
	var where := ""
	for tally: Tally in tallies:
		if tally.idle_near_longest > idle:
			idle = tally.idle_near_longest
			where = "%s: %s" % [tally.lobby.key, tally.idle_near_where]
	var seconds := idle / float(Ticks.RATE)
	lines.append(
		_row(
			"No bot idle more than 3 s with an opponent in sight within 6 m",
			"%.1f s (%s)" % [seconds, where],
			seconds <= IDLE_BOUND_SECONDS
		)
	)
	for tally: Tally in tallies:
		var flight := _dry_flight(tally)
		lines.append(
			_row(
				(
					(
						"%s: ≤ 2 s a bot a match climbing out or fleeing on a dry ship, "
						+ "feet over a body's height above the sea"
					)
					% tally.lobby.key
				),
				(
					"%.2f s (longest %.1f s, %s)"
					% [flight, tally.dry_flight_longest / float(Ticks.RATE), tally.dry_flight_where]
				),
				flight <= DRY_FLIGHT_AT_MOST_SECONDS
			)
		)
	if by_key.has("sighted"):
		var tally: Tally = by_key["sighted"]
		var gap := (
			_share(tally.sight_wins.get("omniscient", 0), tally.matches)
			- _share(tally.sight_wins.get("sighted", 0), tally.matches)
		)
		lines.append(
			(
				"| Win-share gap, omniscient minus sighted (R16, reported) | %+.1f points | — |"
				% (gap * 100.0)
			)
		)
	lines.append("")
	return lines


static func _row(target: String, measured: String, met: bool) -> String:
	return "| %s | %s | %s |" % [target, measured, "met" if met else "**missed**"]


func _lobby_lines(tally: Tally) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("## %s" % tally.lobby.title)
	lines.append("")
	lines.append(
		(
			"- Matches: %d (seeds 1…%d), %.0f s of wall time."
			% [tally.matches, tally.lobby.seeds, tally.wall_seconds]
		)
	)
	lines.append(
		(
			"- Length: median %s, mean %s; draws %d; still on at %s and stopped: %d."
			% [
				_clock(_median(tally.lengths)),
				_clock(_mean(tally.lengths)),
				tally.draws,
				_clock(_stop_ticks / float(Ticks.RATE)),
				tally.unfinished
			]
		)
	)
	lines.append(
		(
			"- Reached the plunge with three or more dry: %d of %d (%.1f%%)."
			% [
				tally.dry_at_plunge,
				tally.matches,
				_share(tally.dry_at_plunge, tally.matches) * 100.0
			]
		)
	)
	lines.append(
		(
			(
				"- Still on at the first collapse (the bridge): %d of %d (%.1f%%), %.1f seats in "
				+ "on average; at the plunge: %d of %d (%.1f%%), %.1f seats in."
			)
			% [
				tally.collapses,
				tally.matches,
				_share(tally.collapses, tally.matches) * 100.0,
				_share(tally.in_at_collapse, tally.collapses),
				tally.plunges,
				tally.matches,
				_share(tally.plunges, tally.matches) * 100.0,
				_share(tally.in_at_plunge, tally.plunges)
			]
		)
	)
	var slots := PackedStringArray()
	for slot in tally.lobby.tiers.size():
		slots.append(
			"%d: %.1f%%" % [slot, _share(tally.slot_wins.get(slot, 0), tally.matches) * 100.0]
		)
	lines.append(
		(
			"- Wins by spawn slot (fair share %.1f%%): %s."
			% [100.0 / tally.lobby.tiers.size(), ", ".join(slots)]
		)
	)
	var tiers := PackedStringArray()
	for tier: StringName in tally.tier_wins:
		tiers.append("%s %.1f%%" % [tier, _share(tally.tier_wins[tier], tally.matches) * 100.0])
	lines.append("- Wins by tier: %s." % ", ".join(tiers))
	if tally.lobby.sighted.has(false):
		var sight := PackedStringArray()
		for side: String in tally.sight_wins:
			sight.append(
				"%s %.1f%%" % [side, _share(tally.sight_wins[side], tally.matches) * 100.0]
			)
		lines.append("- Wins by sight: %s." % ", ".join(sight))
	lines.append(
		(
			"- Cargo: %d exits credited to a crate; %d railing sections broken, %.1f a match."
			% [tally.crate_exits, tally.spans_broken, _share(tally.spans_broken, tally.matches)]
		)
	)
	lines.append(
		(
			(
				"- Climbing out or fleeing on a dry ship, feet over a body's height above the "
				+ "sea: %.2f s a bot a match; longest %.1f s (%s)."
			)
			% [
				_dry_flight(tally),
				tally.dry_flight_longest / float(Ticks.RATE),
				tally.dry_flight_where
			]
		)
	)
	lines.append(
		(
			"- Longest idle streak: %.1f s (%s)."
			% [tally.idle_longest / float(Ticks.RATE), tally.idle_where]
		)
	)
	lines.append(
		(
			"- Longest idle streak with an opponent in sight within 6 m: %.1f s (%s)."
			% [tally.idle_near_longest / float(Ticks.RATE), tally.idle_near_where]
		)
	)
	(
		lines
		. append(
			(
				"- Sim + bots per tick, %d seats: p50 %.2f ms, p99 %.2f ms, mean %.2f ms, worst %.1f ms."
				% [
					tally.lobby.tiers.size(),
					_percentile_ms(tally.tick_us, 0.5),
					_percentile_ms(tally.tick_us, 0.99),
					_mean_ms(tally.tick_us),
					_percentile_ms(tally.tick_us, 1.0)
				]
			)
		)
	)
	lines.append("")
	return lines


## Seconds a bot of [param tally]'s lobby spent climbing out or fleeing on a dry ship,
## high above the sea, a match, on average.
static func _dry_flight(tally: Tally) -> float:
	var bot_matches := tally.matches * tally.lobby.tiers.size()
	return tally.dry_flight_ticks / float(Ticks.RATE) / bot_matches if bot_matches > 0 else 0.0


static func _share(count: int, total: int) -> float:
	return count / float(total) if total > 0 else 0.0


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) * 0.5


static func _mean(values: PackedFloat64Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / values.size() if not values.is_empty() else 0.0


static func _percentile_ms(samples: PackedInt64Array, share: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[mini(int(share * sorted.size()), sorted.size() - 1)] / 1000.0


static func _mean_ms(samples: PackedInt64Array) -> float:
	var total := 0
	for sample: int in samples:
		total += sample
	return total / 1000.0 / samples.size() if not samples.is_empty() else 0.0


static func _clock(seconds: float) -> String:
	return MatchTranscript.clock(roundi(seconds * Ticks.RATE)).substr(0, 5)
