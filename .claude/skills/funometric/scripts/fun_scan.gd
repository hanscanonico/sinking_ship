extends SceneTree
## The funometric's measuring half: one match stepped headless, and every seat's
## experience of it measured tick by tick — how soon it met somebody, how much of its
## life it spent near an opponent, its longest stretch with nothing happening to it,
## its close calls, whether a player or the sea put it out, how long it then watched —
## and the match's pacing in windows. No verdicts here: fun_report.py judges.
##
##   godot --headless --path . -s ABSOLUTE/PATH/fun_scan.gd -- --seed=1 --ship=tug --seats=6 [--fast] [--goal=survival]
##   godot --headless --path . -s ABSOLUTE/PATH/fun_scan.gd -- --replay=ABSOLUTE/PATH/one.replay
##
## The first runs a bots-only match (bots are players reading a delayed view, D10, so
## their matches are a fair proxy for pacing). The second re-runs a recorded match from
## its input log (D4): seats 0…humans-1 were played by a person (or an agent through
## make play) and are marked human.
##
## Output, one record a line, fields split on `|`:
##   H|ship|seed|seats|mode|source|humans|live_from_s
##   P|seat|human|place|cause|credit|alive_s|first_contact_s|near_pct|median_gap_m|
##     shoves_given|shoves_taken|kos|water_in|climbed_out|back_in|bonuses|grabs|falls|
##     swim_s|idle_pct|longest_lull_s|lull_from_s|close_calls|spectate_s|beats_per_min
##   T|from_s|alive|encounters|shoves|water|spectacle|outs        (one per WINDOW_S)
##   E|t_s|kind|seat|target|note                                 (beats, for the journal's timeline)
##   M|ticks|live_s|winner|first_out_s|out_gaps|duel_s|duel_shoves|spectacle|last_cause|ending

const K := SimEvent.Kind
const B := PlayerState.Body
const TICKS := 30.0
## An opponent this close (metres, on the same hull piece, across the deck) is "near":
## a shove is a step or two away.
const NEAR := 6.0
## Closer than this is a contact: the first one is when a seat first met somebody.
const CONTACT := 3.0
## Slower than this across the deck, grounded and with nobody near, is standing about.
const IDLE_SPEED := 0.5
## A climb out of the sea the seat then outlives by this long is a close call.
const SURVIVED_AFTER := 10.0
const WINDOW_S := 15.0
## What the ship does that every seat aboard sees or feels.
const SPECTACLE := [
	K.HOLED,
	K.SHIP_LURCHED,
	K.PLATFORM_COLLAPSED,
	K.RAILING_BROKE,
	K.PLUNGE_BEGAN,
	K.FUNNEL_FALLING,
	K.LIGHTS_OUT,
	K.POWER_LOST,
	K.HULL_PARTED,
	K.GROUNDED,
	K.OPENING_GAVE_WAY,
	K.SHIP_GONE,
]
## What happens to a seat itself: these are its beats.
const PERSONAL := [
	K.SHOVE_LANDED,
	K.BOWLED,
	K.FELL,
	K.ENTERED_WATER,
	K.CLIMBED_OUT,
	K.KNOCKED_BACK_IN,
	K.KNOCKED_DOWN,
	K.BONUS_TAKEN,
	K.PROP_GRABBED,
	K.DOUBLE_LIFE_SPENT,
	K.KNOCKED_LOOSE,
	K.SEAT_OUT,
]

var runner: MatchRunner
var sim: MatchSim
var ship_name := ""
var seed_value := 0
var mode := "normal"
var source := "bots"
var humans := 0


func _initialize() -> void:
	var passed := PackedStringArray()
	var replay_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--replay="):
			replay_path = arg.get_slice("=", 1)
		else:
			passed.append(arg)
			if arg == "--fast":
				mode = "fast" if mode == "normal" else mode + "+fast"
			if arg.begins_with("--goal=survival"):
				mode = "survival" if mode == "normal" else mode + "+survival"
	var config: MatchConfig
	var max_ticks := 0
	if replay_path != "":
		var file := ReplayFile.from_bytes(FileAccess.get_file_as_bytes(replay_path))
		if file == null or not file.playable():
			printerr("not a playable replay on this build: " + replay_path)
			quit(1)
			return
		config = file.config()
		source = "replay"
		humans = config.humans
		runner = MatchRunner.new(MatchSim.create(config), file.replay_sources())
		max_ticks = file.log.last_tick() + 1
		mode = "survival" if config.goal == MatchRules.Goal.SURVIVAL else "normal"
	else:
		var rm = load("res://tools/run_match.gd")
		config = rm.chosen_config(MatchArgs.parse(passed))
		if config == null:
			quit(1)
			return
		var cache := BakeCache.when(true)
		var cached := cache != null and cache.take(config)
		config.schedule().timeline()
		if cache != null and not cached:
			cache.store(config)
		runner = rm.bots_only(config)
		max_ticks = maxi(27000, runner.sim.schedule.end_tick() + 3600)
	sim = runner.sim
	ship_name = str(Fleet.name_of(config.ship))
	seed_value = config.match_seed
	_scan(config, max_ticks)
	quit()


func _s(ticks: int) -> String:
	return "%.1f" % (ticks / TICKS)


func _scan(config: MatchConfig, max_ticks: int) -> void:
	var n := config.seats
	var state := sim.state
	var live_from := -1
	var alive := PackedInt32Array()
	var first_contact := PackedInt32Array()
	var near_ticks := PackedInt32Array()
	var idle_ticks := PackedInt32Array()
	var swim_ticks := PackedInt32Array()
	var gaps: Array = []
	var was_near: Array[bool] = []
	var last_beat := PackedInt32Array()
	var lull := PackedInt32Array()
	var lull_from := PackedInt32Array()
	var beats := PackedInt32Array()
	var counts: Array[Dictionary] = []
	var climbed_at := PackedInt32Array()
	var credit_of := PackedInt32Array()
	var kos := PackedInt32Array()
	var close := PackedInt32Array()
	var prev_pos: Array[Vector3] = []
	for seat in n:
		alive.append(0)
		first_contact.append(-1)
		near_ticks.append(0)
		idle_ticks.append(0)
		swim_ticks.append(0)
		gaps.append([])
		was_near.append(false)
		last_beat.append(-1)
		lull.append(0)
		lull_from.append(0)
		beats.append(0)
		counts.append({})
		climbed_at.append(-1)
		credit_of.append(-1)
		kos.append(0)
		close.append(0)
		prev_pos.append(state.seats[seat].pos)
	var windows: Array = []
	var out_ticks: Array[int] = []
	var duel_from := -1
	var duel_shoves := 0
	var spectacle := 0
	var last_cause := "none"
	var ending := "unfinished"
	var winner := -1

	while not runner.is_over() and runner.tick() < max_ticks:
		var t := runner.tick()
		var events: Array[SimEvent] = runner.step().duplicate()
		state = sim.state
		if live_from < 0:
			if state.phase != MatchState.Phase.LIVE:
				continue
			live_from = t
			for seat in n:
				last_beat[seat] = t
		var w := int((t - live_from) / (WINDOW_S * TICKS))
		while windows.size() <= w:
			windows.append({"alive": 0, "encounters": 0, "shoves": 0, "water": 0, "spectacle": 0, "outs": 0})
		var win: Dictionary = windows[w]
		win.alive = maxi(win.alive, state.remaining())

		for e: SimEvent in events:
			if e.kind in SPECTACLE:
				spectacle += 1
				win.spectacle += 1
				print("E|%s|%s|-1|-1|" % [_s(e.tick - live_from), K.keys()[e.kind]])
				continue
			if not e.kind in PERSONAL or e.seat < 0 or e.seat >= n:
				if e.kind == K.MATCH_ENDED:
					winner = e.seat
					ending = "winner" if e.seat >= 0 else "draw"
				continue
			var name: String = K.keys()[e.kind]
			print("E|%s|%s|%d|%d|%s" % [_s(e.tick - live_from), name, e.seat, e.target, str(e.credit) if e.kind == K.SEAT_OUT else ""])
			_beat(e.seat, t, last_beat, lull, lull_from, beats)
			counts[e.seat][name] = counts[e.seat].get(name, 0) + 1
			match e.kind:
				K.SHOVE_LANDED:
					win.shoves += 1
					if e.target >= 0 and e.target < n:
						_beat(e.target, t, last_beat, lull, lull_from, beats)
						counts[e.target]["TAKEN"] = counts[e.target].get("TAKEN", 0) + 1
					if state.remaining() == 2:
						duel_shoves += 1
				K.ENTERED_WATER:
					win.water += 1
				K.CLIMBED_OUT:
					climbed_at[e.seat] = t
				K.DOUBLE_LIFE_SPENT:
					close[e.seat] += 1
				K.SEAT_OUT:
					win.outs += 1
					out_ticks.append(t)
					credit_of[e.seat] = e.credit
					if e.credit >= 0 and e.credit < n:
						kos[e.credit] += 1
					last_cause = (
						"shoved" if e.credit >= 0 else ("cold" if e.cause == PlayerState.Cause.COLD else "with_her")
					)
					if state.remaining() == 2 and duel_from < 0:
						duel_from = t

		for seat in n:
			var p := state.seats[seat]
			if p.is_out():
				continue
			alive[seat] += 1
			if climbed_at[seat] >= 0 and t - climbed_at[seat] >= int(SURVIVED_AFTER * TICKS):
				close[seat] += 1
				climbed_at[seat] = -1
			if p.body == B.SWIMMING:
				swim_ticks[seat] += 1
				# Back in the sea before the climb was outlived: no close call yet.
				if p.climb_left == 0:
					climbed_at[seat] = -1
			var nearest := INF
			for other: PlayerState in state.seats:
				if other.seat == seat or other.is_out() or other.piece != p.piece:
					continue
				nearest = minf(nearest, Vector2(other.pos.x - p.pos.x, other.pos.z - p.pos.z).length())
			var near := nearest <= NEAR
			if near:
				near_ticks[seat] += 1
				if not was_near[seat]:
					win.encounters += 1
					_beat(seat, t, last_beat, lull, lull_from, beats)
			was_near[seat] = near
			if nearest <= CONTACT and first_contact[seat] < 0:
				first_contact[seat] = t
			if (t - live_from) % int(TICKS) == 0 and nearest < INF:
				gaps[seat].append(nearest)
			var step := Vector2(p.pos.x - prev_pos[seat].x, p.pos.z - prev_pos[seat].z).length() * TICKS
			if p.body == B.GROUNDED and step < IDLE_SPEED and not near:
				idle_ticks[seat] += 1
			prev_pos[seat] = p.pos
			# A stretch still running counts as it stands.
			if t - last_beat[seat] > lull[seat]:
				lull[seat] = t - last_beat[seat]
				lull_from[seat] = last_beat[seat]

	var t_end := runner.tick()
	if live_from < 0:
		live_from = 0
	var live_ticks := t_end - live_from
	print(
		(
			"H|%s|%d|%d|%s|%s|%d|%s"
			% [ship_name, seed_value, n, mode, source, humans, _s(live_from)]
		)
	)
	for seat in n:
		var p := state.seats[seat]
		var c: Dictionary = counts[seat]
		var g: Array = gaps[seat]
		g.sort()
		var median := "-" if g.is_empty() else "%.1f" % g[g.size() / 2]
		var a := maxi(alive[seat], 1)
		var cause := "in"
		var credit := -1
		if p.is_out():
			credit = credit_of[seat]
			cause = (
				"shoved" if credit >= 0 else ("cold" if p.out_cause == PlayerState.Cause.COLD else "with_her")
			)
		var spectate := live_ticks - alive[seat] if p.is_out() else 0
		print(
			(
				"P|%d|%d|%d|%s|%d|%s|%s|%.0f|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%.0f|%s|%s|%d|%s|%.1f"
				% [
					seat,
					1 if seat < humans else 0,
					p.place,
					cause,
					credit,
					_s(alive[seat]),
					"-" if first_contact[seat] < 0 else _s(first_contact[seat] - live_from),
					100.0 * near_ticks[seat] / a,
					median,
					c.get("SHOVE_LANDED", 0),
					c.get("TAKEN", 0),
					kos[seat],
					c.get("ENTERED_WATER", 0),
					c.get("CLIMBED_OUT", 0),
					c.get("KNOCKED_BACK_IN", 0),
					c.get("BONUS_TAKEN", 0),
					c.get("PROP_GRABBED", 0),
					c.get("FELL", 0),
					_s(swim_ticks[seat]),
					100.0 * idle_ticks[seat] / a,
					_s(lull[seat]),
					_s(lull_from[seat] - live_from),
					close[seat],
					_s(spectate),
					beats[seat] * 60.0 * TICKS / a,
				]
			)
		)
	for i in windows.size():
		var win: Dictionary = windows[i]
		print("T|%.0f|%d|%d|%d|%d|%d|%d" % [i * WINDOW_S, win.alive, win.encounters, win.shoves, win.water, win.spectacle, win.outs])
	out_ticks.sort()
	var out_gaps := PackedStringArray()
	for i in range(1, out_ticks.size()):
		out_gaps.append(_s(out_ticks[i] - out_ticks[i - 1]))
	if runner.is_over() and ending == "unfinished":
		ending = "winner" if state.winner() >= 0 else "draw"
		winner = state.winner()
	print(
		(
			"M|%d|%s|%d|%s|%s|%s|%d|%d|%s|%s"
			% [
				t_end,
				_s(live_ticks),
				winner,
				"-" if out_ticks.is_empty() else _s(out_ticks[0] - live_from),
				",".join(out_gaps),
				"-" if duel_from < 0 else _s(t_end - duel_from),
				duel_shoves,
				spectacle,
				last_cause,
				ending,
			]
		)
	)


## A beat for [param seat] on [param t]: the stretch since its last one ends.
func _beat(seat: int, t: int, last_beat: PackedInt32Array, lull: PackedInt32Array, lull_from: PackedInt32Array, beats: PackedInt32Array) -> void:
	if last_beat[seat] >= 0 and t - last_beat[seat] > lull[seat]:
		lull[seat] = t - last_beat[seat]
		lull_from[seat] = last_beat[seat]
	last_beat[seat] = t
	beats[seat] += 1
