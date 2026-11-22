extends SceneTree
## One bots-only match, every tick scanned for things that cannot be right.
##   godot --headless --path . -s ABSOLUTE/PATH/sim_scan.gd -- --seed=1 --ship=tug --seats=6
##     [--fast] [--goal=survival] [--x-max=TICKS] [--x-trace=FROM:TO[:SEAT]]
##     [--x-ptrace=FROM:TO:PROP] [--x-plant=KIND:TICK:SEAT] [--x-stop=TICK]

const B := PlayerState.Body

var rules: BrawlRules
var sim: MatchSim
var runner: MatchRunner
var ship_name := ""
var seed_value := 0
var mode := "normal"
var counts: Dictionary = {}
var last_logged: Dictionary = {}
var suppressed: Dictionary = {}
var bounds: Rect2
var min_floor := INF
var max_h := 0.0
var max_v := 0.0

var trace_from := -1
var trace_to := -1
var trace_seat := -1
var ptrace_from := -1
var ptrace_to := -1
var ptrace_prop := -1
var plant_kind := ""
var plant_tick := -1
var plant_seat := 0
var plant_pin := Vector3.ZERO
var stop_tick := -1
var want_dump: Dictionary = {}
var dumps: Dictionary = {}
const DUMPED := ["teleport", "through_wall", "in_wall", "grounded_no_floor", "grounded_off_height", "left_cells", "below_ship", "body_flip", "climb_flip", "swim_no_cold", "grounded_deep", "out_cause", "airborne_long", "in_prop", "speed", "climb_jump", "far_outside"]


func clock(tick: int) -> String:
	var s := tick / 30.0
	return "%d:%05.2f" % [int(s) / 60, fmod(s, 60.0)]


func flag(det: String, tick: int, id: String, msg: String, cooldown := 30) -> void:
	counts[det] = counts.get(det, 0) + 1
	var key := det + "#" + id
	if last_logged.has(key) and tick - last_logged[key] < cooldown:
		suppressed[key] = suppressed.get(key, 0) + 1
		return
	last_logged[key] = tick
	if id.begins_with("seat") and det in DUMPED and dumps.get(det, 0) < 3:
		dumps[det] = dumps.get(det, 0) + 1
		want_dump[int(id.substr(4))] = det
	print("A|%s|%s|%d|%s|%d|%s|%s|%s" % [det, ship_name, seed_value, mode, tick, clock(tick), id, msg])


func v3(v: Vector3) -> String:
	return "(%.3f,%.3f,%.3f)" % [v.x, v.y, v.z]


func bad(v: Vector3) -> bool:
	return not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z))


func _initialize() -> void:
	var raw := OS.get_cmdline_user_args()
	var passed := PackedStringArray()
	var max_ticks := 0
	for arg: String in raw:
		if arg.begins_with("--x-max="):
			max_ticks = int(arg.get_slice("=", 1))
		elif arg.begins_with("--x-stop="):
			stop_tick = int(arg.get_slice("=", 1))
		elif arg.begins_with("--x-trace="):
			var parts := arg.get_slice("=", 1).split(":")
			trace_from = int(parts[0])
			trace_to = int(parts[1])
			if parts.size() > 2:
				trace_seat = int(parts[2])
		elif arg.begins_with("--x-ptrace="):
			var parts := arg.get_slice("=", 1).split(":")
			ptrace_from = int(parts[0])
			ptrace_to = int(parts[1])
			ptrace_prop = int(parts[2])
		elif arg.begins_with("--x-plant="):
			var parts := arg.get_slice("=", 1).split(":")
			plant_kind = parts[0]
			plant_tick = int(parts[1])
			plant_seat = int(parts[2])
		else:
			passed.append(arg)
			if arg == "--fast":
				mode = "fast" if mode == "normal" else mode + "+fast"
			if arg.begins_with("--goal=survival"):
				mode = "survival" if mode == "normal" else mode + "+survival"
	var rm = load("res://tools/run_match.gd")
	var args := MatchArgs.parse(passed)
	var config: MatchConfig = rm.chosen_config(args)
	if config == null:
		quit(1)
		return
	var cache := BakeCache.when(true)
	var cached := cache != null and cache.take(config)
	config.schedule().timeline()
	if cache != null and not cached:
		cache.store(config)
	runner = rm.bots_only(config)
	sim = runner.sim
	rules = config.rules
	ship_name = str(Fleet.name_of(config.ship))
	seed_value = config.match_seed
	bounds = SpatialIndex.bounds_of(config.ship)
	for platform: ShipPlatform in config.ship.platforms:
		min_floor = minf(min_floor, platform.height)
	var end_tick := sim.schedule.end_tick()
	if max_ticks == 0:
		max_ticks = maxi(27000, end_tick + 3600)
	print(
		(
			"H|%s|%d|seats=%d|%s|end_tick=%d|bounds=%s|min_floor=%.2f|props=%d|max=%d"
			% [ship_name, seed_value, config.seats, mode, end_tick, bounds, min_floor, config.ship.props.size(), max_ticks]
		)
	)
	_scan(config, max_ticks)
	quit()


func _scan(config: MatchConfig, max_ticks: int) -> void:
	var n := config.seats
	var state := sim.state
	var prev_pos: Array[Vector3] = []
	var prev_body := PackedInt32Array()
	var prev_piece := PackedInt32Array()
	var prev_up := PackedInt32Array()
	var prev_cold := PackedFloat64Array()
	var prev_climb := PackedInt32Array()
	var prev_cell := PackedInt32Array()
	var air_run := PackedInt32Array()
	var cold_run := PackedInt32Array()
	var deep_run := PackedInt32Array()
	var nofloor_run := PackedInt32Array()
	var wall_run := PackedInt32Array()
	var ring: Array = []
	var post := PackedInt32Array()
	var flips: Array = []
	var cflips: Array = []
	var travel := PackedFloat64Array()
	var travel_marks: Array = []
	var anchor: Array[Vector3] = []
	var anchor_tick := PackedInt32Array()
	var anchor_idle := PackedInt32Array()
	for seat in n:
		var p := state.seats[seat]
		prev_pos.append(p.pos)
		prev_body.append(p.body)
		prev_piece.append(p.piece)
		prev_up.append(state.up[p.piece])
		prev_cold.append(p.cold)
		prev_climb.append(p.climb_left)
		prev_cell.append(-9)
		air_run.append(0)
		cold_run.append(0)
		deep_run.append(0)
		nofloor_run.append(0)
		wall_run.append(0)
		ring.append([])
		post.append(0)
		flips.append([])
		cflips.append([])
		travel.append(0.0)
		travel_marks.append([])
		anchor.append(p.pos)
		anchor_tick.append(0)
		anchor_idle.append(0)
	var prop_prev_pos: Array[Vector3] = []
	var prop_prev_body := PackedInt32Array()
	for crate: PropState in state.props:
		prop_prev_pos.append(crate.pos)
		prop_prev_body.append(crate.body)
	var spam: Dictionary = {}
	var duel_shoves := 0
	var duel_flagged := false
	var flip_plant_n := 0

	while not runner.is_over() and runner.tick() < max_ticks:
		if stop_tick >= 0 and runner.tick() >= stop_tick:
			break
		var t := runner.tick()
		var events: Array[SimEvent] = runner.step().duplicate()
		state = sim.state
		var pose := sim.schedule.pose_at(t)

		# ---- plants: a state no sim would make, for a detector to find ----
		if plant_kind != "" and t >= plant_tick:
			var pl := state.seats[plant_seat]
			if t == plant_tick:
				print("P|plant %s at tick %d seat %d pos %s body %d" % [plant_kind, t, plant_seat, v3(pl.pos), pl.body])
				match plant_kind:
					"teleport":
						pl.pos.x += 3.0
					"nan":
						pl.vel.x = NAN
					"wall":
						var blk := config.ship.blockers[0]
						for cand: ShipBlocker in config.ship.blockers:
							if cand.shape == ShipBlocker.Shape.BOX and cand.top - cand.bottom > 1.5:
								blk = cand
								break
						var c := blk.area.get_center()
						pl.pos = Vector3(c.x, blk.bottom, c.y)
						pl.vel = Vector3.ZERO
						print("P|blocker area %s bottom %.2f top %.2f" % [blk.area, blk.bottom, blk.top])
					"nofloor":
						pl.pos.y += 3.0
						plant_pin = pl.pos
					"below":
						pl.pos.y = min_floor - 10.0
					"outside":
						pl.pos.x += 200.0
					"cold":
						pl.cold = 99.0
					"sky":
						pl.pos.y += 1000.0
						pl.body = B.AIRBORNE
						pl.surface = Surfaces.NONE
					"swimcold":
						pl.pos.x = bounds.end.x + 8.0
					"prop":
						state.props[0].pos.x += 10.0
					"propwall":
						var blk2 := config.ship.blockers[0]
						for cand: ShipBlocker in config.ship.blockers:
							if cand.shape == ShipBlocker.Shape.BOX and cand.top - cand.bottom > 1.5:
								blk2 = cand
								break
						var c2 := blk2.area.get_center()
						plant_pin = Vector3(c2.x, blk2.bottom, c2.y)
					"pin":
						plant_pin = pl.pos
			match plant_kind:
				"nofloor":
					if t < plant_tick + 20:
						pl.pos = plant_pin
						pl.body = B.GROUNDED
				"swimcold":
					if pl.body == B.SWIMMING:
						pl.cold = 3.0
				"propwall":
					if t < plant_tick + 40:
						state.props[0].pos = plant_pin
						state.props[0].vel = Vector3.ZERO
						state.props[0].body = PropState.Body.GROUNDED
				"pin":
					if t < plant_tick + 2000 and not pl.is_out():
						pl.pos = plant_pin
						pl.vel = Vector3.ZERO
				"flip":
					if t < plant_tick + 12 and not pl.is_out():
						flip_plant_n += 1
						pl.body = B.AIRBORNE if flip_plant_n % 2 == 1 else B.GROUNDED
				"spam":
					if t < plant_tick + 8:
						events.append(SimEvent.fell(t, plant_seat))
				"props3":
					if state.props.size() >= 3:
						for i in 3:
							state.props[i].pos = state.props[0].pos
							state.props[i].body = PropState.Body.GROUNDED

		var whole := pose.standing.size() == 1 and pose.standing[0] == 0
		var framed_cache: Dictionary = {}

		# ---- events ----
		var outs: Dictionary = {}
		for e: SimEvent in events:
			if trace_from >= 0 and t >= trace_from and t <= trace_to:
				print("E|%d|%s|seat=%d|prop=%d|target=%d|surface=%d|cause=%d|credit=%d" % [t, SimEvent.Kind.keys()[e.kind], e.seat, e.prop, e.target, e.surface, e.cause, e.credit])
			if e.kind == SimEvent.Kind.SEAT_OUT:
				outs[e.seat] = e
			if e.kind == SimEvent.Kind.SHOVE_LANDED and state.remaining() == 2:
				duel_shoves += 1
				if duel_shoves > 100 and not duel_flagged:
					duel_flagged = true
					flag("duel", t, "match", "last two seats: more than 100 shoves landed with no knock-out")
			if e.kind == SimEvent.Kind.SEAT_OUT:
				duel_shoves = 0
				duel_flagged = false
			if e.seat < 0 and e.prop < 0:
				continue
			if e.kind == SimEvent.Kind.MATCH_ENDED:
				continue
			var skey := "%s:s%d:p%d:t%d" % [SimEvent.Kind.keys()[e.kind], e.seat, e.prop, e.target]
			if not spam.has(skey):
				spam[skey] = []
			var recent: Array = spam[skey]
			recent.append(t)
			while recent[0] < t - 29:
				recent.pop_front()
			if recent.size() > 5:
				flag("event_spam", t, skey, "%d times in the last second" % recent.size(), 90)

		# ---- seats ----
		for seat in n:
			var p := state.seats[seat]
			var id := "seat%d" % seat
			if p.is_out():
				if outs.has(seat) and prev_body[seat] != B.OUT:
					var e: SimEvent = outs[seat]
					print("O|%s|%d|%d|%s|seat%d|cause=%d place=%d prev_body=%d prev_cold=%.2f pos=%s piece=%d up=%d left=%d" % [ship_name, seed_value, t, clock(t), seat, e.cause, e.place, prev_body[seat], prev_cold[seat], v3(p.pos), p.piece, state.up[p.piece], state.remaining()])
					if e.cause == PlayerState.Cause.COLD and prev_body[seat] != B.SWIMMING and prev_cold[seat] > 0.2:
						flag("out_cause", t, id, "out by the cold from body %d with %.2f s of cold left at %s" % [prev_body[seat], prev_cold[seat], v3(p.pos)])
					if e.cause == PlayerState.Cause.WITH_HER and t != sim.schedule.piece_gone_tick(p.piece):
						flag("out_cause", t, id, "out with her on a tick her piece is not gone")
				prev_body[seat] = B.OUT
				continue
			var up: int = state.up[p.piece]
			var same_frame: bool = p.piece == prev_piece[seat] and up == prev_up[seat]
			var faces := sim.pieces.faces(p.piece)
			var surf := faces.surfaces(up)
			var fpose: ShipPose
			var fkey := p.piece * 8 + up
			if framed_cache.has(fkey):
				fpose = framed_cache[fkey]
			else:
				fpose = pose.of_piece(p.piece)
				if up != Faces.Up.DECK:
					fpose = faces.framed(fpose, up)
				framed_cache[fkey] = fpose
			var to_frame := Faces.to_frame(up)
			var fpos: Vector3 = p.pos if up == Faces.Up.DECK else to_frame * p.pos
			var fvel: Vector3 = p.vel if up == Faces.Up.DECK else to_frame * p.vel
			var fprev: Vector3 = prev_pos[seat] if up == Faces.Up.DECK else to_frame * prev_pos[seat]
			var climbing := p.climb_left > 0
			var was_climbing: bool = prev_climb[seat] > 0

			# 7: numbers
			if bad(p.pos) or bad(p.vel) or bad(p.held_vel) or not is_finite(p.cold) or not is_finite(p.stamina) or not is_finite(p.facing):
				flag("nan", t, id, "pos %s vel %s cold %s stamina %s" % [p.pos, p.vel, p.cold, p.stamina])
				prev_pos[seat] = p.pos
				continue
			if p.cold < -1e-6 or p.cold > rules.cold_meter + 1e-6 or p.stamina < -1e-6 or p.stamina > rules.stamina_max + 1e-6:
				flag("meter_range", t, id, "cold %.3f stamina %.3f" % [p.cold, p.stamina])

			# 1: teleports and speeds
			var moved := p.pos.distance_to(prev_pos[seat])
			if same_frame:
				travel[seat] += moved
				if moved > 1.5 and not (was_climbing and not climbing):
					flag("teleport", t, id, "moved %.2f m in a tick: %s -> %s body %d->%d surface %d climb %d->%d" % [moved, v3(prev_pos[seat]), v3(p.pos), prev_body[seat], p.body, p.surface, prev_climb[seat], p.climb_left])
				elif moved > 3.0:
					flag("climb_jump", t, id, "a climb's end moved it %.2f m: %s -> %s" % [moved, v3(prev_pos[seat]), v3(p.pos)])
			var hs := Vector2(fvel.x, fvel.z).length()
			max_h = maxf(max_h, hs)
			max_v = maxf(max_v, absf(fvel.y))
			if hs > 30.0 or absf(fvel.y) > 40.0:
				flag("speed", t, id, "speed %.2f across, %.2f up at %s body %d" % [hs, fvel.y, v3(p.pos), p.body])

			var under := surf.under(fpos, rules.step_height)
			var tall := rules.body_height if p.body == B.GROUNDED else rules.height_at(surf, fpos)

			if not climbing:
				# 2: walls
				var step := rules.step_height
				var crawl := rules.crawl_height
				if p.body != B.GROUNDED:
					crawl = INF
				if p.body == B.AIRBORNE:
					step = Movement.AIR_STEP
				elif p.body == B.SWIMMING:
					var mover: Movement = sim._movements[p.piece]
					step = mover._swim_step(Vector3(fpos.x, fprev.y, fpos.z), fpose.water_height(fpos))
				var deepest := 0.0
				var deepest_prop := -1
				var deepest_wall := 0.0
				for contact: Surfaces.Contact in surf.obstacle_contacts(fpos, rules.body_radius, tall, step, Surfaces.NONE, crawl):
					if contact.prop != -1:
						if contact.depth > deepest:
							deepest = contact.depth
							deepest_prop = contact.prop
					else:
						deepest_wall = maxf(deepest_wall, contact.depth)
				if deepest_wall > 0.15 and same_frame:
					# Movement meets them at the height the feet stood at before the move.
					var before := 0.0
					for contact: Surfaces.Contact in surf.obstacle_contacts(Vector3(fpos.x, fprev.y, fpos.z), rules.body_radius, tall, step, Surfaces.NONE, crawl):
						if contact.prop == -1:
							before = maxf(before, contact.depth)
					deepest_wall = minf(deepest_wall, before)
				if deepest_wall > 0.15:
					wall_run[seat] += 1
					if wall_run[seat] >= 3:
						flag("in_wall", t, id, "%.2f m into a wall or edge for %d ticks at %s body %d surface %d up %d vel %s" % [deepest_wall, wall_run[seat], v3(fpos), p.body, p.surface, up, v3(fvel)])
				else:
					wall_run[seat] = 0
				if deepest > 0.3:
					flag("in_prop", t, id, "%.2f m into prop %d at %s body %d" % [deepest, deepest_prop, v3(fpos), p.body])
				if same_frame and not was_climbing and moved > 0.0005 and moved < 20.0:
					if surf.blocked(fprev, fpos, tall, rules.step_height):
						flag("through_wall", t, id, "crossed a blocker: %s -> %s body %d->%d" % [v3(fprev), v3(fpos), prev_body[seat], p.body])

				# 3: footing
				if p.body == B.GROUNDED:
					if p.surface == Surfaces.NONE or under == Surfaces.NONE:
						nofloor_run[seat] += 1
						if nofloor_run[seat] >= 2:
							flag("grounded_no_floor", t, id, "grounded on surface %d with %d under it at %s up %d" % [p.surface, under, v3(fpos), up])
					else:
						nofloor_run[seat] = 0
						var gap := fpos.y - surf.height_at(p.surface, fpos)
						if absf(gap) > rules.step_height + 0.1:
							flag("grounded_off_height", t, id, "%.2f m off its surface %d at %s" % [gap, p.surface, v3(fpos)])
				else:
					nofloor_run[seat] = 0
			if p.body == B.AIRBORNE and not climbing:
				air_run[seat] += 1
				if air_run[seat] > 120:
					flag("airborne_long", t, id, "airborne %d ticks at %s vel %s" % [air_run[seat], v3(fpos), v3(fvel)], 120)
			else:
				air_run[seat] = 0
			if up == Faces.Up.DECK:
				if fpos.y < min_floor - 4.0:
					flag("below_ship", t, id, "%.2f m under her lowest floor at %s body %d" % [min_floor - fpos.y, v3(fpos), p.body], 150)
				if not bounds.grow(30.0).has_point(Vector2(fpos.x, fpos.z)):
					flag("far_outside", t, id, "outside the hull's box at %s body %d" % [v3(fpos), p.body], 300)
				# 4: in no cell and on no surface, inside her, below the main deck
				var cell := fpose.cell_at(fpos + Vector3.UP * 0.85)
				var feet_cell := fpose.cell_at(fpos + Vector3.UP * 0.05)
				if cell == CellMap.NONE and feet_cell == CellMap.NONE and under == Surfaces.NONE and fpos.y < -0.5 and not climbing and bounds.grow(-1.0).has_point(Vector2(fpos.x, fpos.z)) and same_frame:
					if prev_cell[seat] >= 0:
						flag("left_cells", t, id, "left cell %d for none at %s body %d vel %s" % [prev_cell[seat], v3(fpos), p.body, v3(fvel)])
				prev_cell[seat] = cell if cell != CellMap.NONE else feet_cell

			# 5: flips
			if p.body != prev_body[seat]:
				var fl: Array = flips[seat]
				fl.append(t)
				while fl[0] < t - 29:
					fl.pop_front()
				if fl.size() > 6:
					flag("body_flip", t, id, "%d body changes in a second, last %d->%d at %s" % [fl.size(), prev_body[seat], p.body, v3(fpos)], 60)
			if climbing != was_climbing:
				var cf: Array = cflips[seat]
				cf.append(t)
				while cf[0] < t - 29:
					cf.pop_front()
				if cf.size() > 6:
					flag("climb_flip", t, id, "%d climb changes in a second at %s" % [cf.size(), v3(fpos)], 60)

			# 6: the cold
			if p.body == B.SWIMMING and prev_body[seat] == B.SWIMMING and not climbing and not was_climbing and p.hitstop == 0 and p.cold >= prev_cold[seat] and p.cold < rules.cold_meter:
				cold_run[seat] += 1
				if cold_run[seat] >= 10:
					flag("swim_no_cold", t, id, "swimming %d ticks with its cold at %.2f not draining, at %s" % [cold_run[seat], p.cold, v3(fpos)], 90)
			else:
				cold_run[seat] = 0
			if p.body == B.GROUNDED and p.surface != Surfaces.NONE and p.hitstop == 0 and surf.wet(fpos, fpose):
				var depth := fpose.water_height(fpos) - surf.height_at(p.surface, fpos)
				if depth >= rules.wade_depth + 0.05:
					deep_run[seat] += 1
					if deep_run[seat] >= 10:
						flag("grounded_deep", t, id, "on its feet %d ticks in %.2f m of water at %s cold %.2f" % [deep_run[seat], depth, v3(fpos), p.cold], 90)
				else:
					deep_run[seat] = 0
			else:
				deep_run[seat] = 0

			# stuck: under 2 m of travel in 60 s
			if t >= config.countdown_ticks and t % 300 == 0:
				var marks: Array = travel_marks[seat]
				marks.append(travel[seat])
				if marks.size() > 6:
					var before: float = marks[marks.size() - 7]
					if travel[seat] - before < 2.0:
						flag("stuck", t, id, "%.2f m of travel in 60 s at %s body %d surface %d above_water %.2f" % [travel[seat] - before, v3(fpos), p.body, p.surface, fpose.above_water(fpos)], 1800)

			# wall walk: input says move, the body stays within 0.3 m for 10 s
			var frame := runner.input_log.frame(t, seat)
			var wants := frame != null and frame.move != Vector2i.ZERO and not frame.is_held(InputFrame.BRACE)
			if not wants:
				anchor_idle[seat] += 1
			if p.pos.distance_to(anchor[seat]) > 0.3 or anchor_idle[seat] > 30 or not same_frame or t < config.countdown_ticks:
				anchor[seat] = p.pos
				anchor_tick[seat] = t
				anchor_idle[seat] = 0
			elif t - anchor_tick[seat] >= 300:
				var near_d := INF
				var near_s := -1
				for other: PlayerState in state.seats:
					if other.seat != seat and not other.is_out() and other.piece == p.piece and other.pos.distance_to(p.pos) < near_d:
						near_d = other.pos.distance_to(p.pos)
						near_s = other.seat
				var holds := ""
				for contact: Surfaces.Contact in surf.obstacle_contacts(fpos, rules.body_radius + 0.05, tall, rules.step_height, Surfaces.NONE, rules.crawl_height):
					holds += " n(%.2f,%.2f)%s" % [contact.normal.x, contact.normal.y, "prop%d" % contact.prop if contact.prop != -1 else ""]
				if p.body == B.GROUNDED:
					for contact: Surfaces.Contact in surf.rail_contacts(fpos, rules.body_radius + 0.05, p.surface, rules.step_height, rules.railing_height):
						holds += " rail%d" % contact.railing
				flag("wall_walk", t, id, "within 0.3 m of %s for 10 s while its input says move (%d idle ticks) body %d surface %d move %s nearest seat%d %.2f m held by:%s above_water %.2f" % [v3(anchor[seat]), anchor_idle[seat], p.body, p.surface, frame.move if frame != null else Vector2i.ZERO, near_s, near_d, holds, fpose.above_water(fpos)], 300)
				anchor_tick[seat] = t
				anchor_idle[seat] = 0

			var line := "%d|s%d|body=%d|surf=%d|under=%d|pos=%s|vel=%s|cold=%.2f|climb=%d|stag=%d|hs=%d|act=%d|mv=%s|btn=%d|piece=%d|up=%d|wh=%.2f|wet=%s" % [t, seat, p.body, p.surface, under, v3(p.pos), v3(p.vel), p.cold, p.climb_left, p.stagger_ticks, p.hitstop, p.action, frame.move if frame != null else Vector2i.ZERO, frame.buttons if frame != null else -1, p.piece, up, fpose.water_height(fpos), surf.wet(fpos, fpose)]
			for e: SimEvent in events:
				if e.seat == seat or e.target == seat:
					line += "|" + SimEvent.Kind.keys()[e.kind] + ("(s%d>t%d)" % [e.seat, e.target] if e.target >= 0 else "")
			var rg: Array = ring[seat]
			rg.append(line)
			if rg.size() > 14:
				rg.pop_front()
			if want_dump.has(seat):
				print("C|--- %s %s %d seat%d: the ticks before %s" % [ship_name, mode, seed_value, seat, want_dump[seat]])
				for kept: String in rg:
					print("C|" + kept)
				want_dump.erase(seat)
				post[seat] = 8
			elif post[seat] > 0:
				post[seat] -= 1
				print("C|" + line)
			if trace_from >= 0 and t >= trace_from and t <= trace_to and (trace_seat < 0 or trace_seat == seat):
				print("T|" + line)

			prev_pos[seat] = p.pos
			prev_body[seat] = p.body
			prev_piece[seat] = p.piece
			prev_up[seat] = up
			prev_cold[seat] = p.cold
			prev_climb[seat] = p.climb_left

		# ---- props ----
		var deck_whole: bool = whole and state.up[0] == Faces.Up.DECK
		var pile: Dictionary = {}
		for i in state.props.size():
			var crate := state.props[i]
			var pid := "prop%d" % i
			if ptrace_from >= 0 and t >= ptrace_from and t <= ptrace_to and ptrace_prop == i:
				print("TP|%d|p%d|body=%d|surf=%d|pos=%s|vel=%s|holder=%d" % [t, i, crate.body, crate.surface, v3(crate.pos), v3(crate.vel), crate.holder])
			if crate.is_loose():
				if bad(crate.pos) or bad(crate.vel):
					flag("prop_nan", t, pid, "pos %s vel %s" % [crate.pos, crate.vel])
				elif deck_whole:
					var was: int = prop_prev_body[i]
					var was_loose := was == PropState.Body.GROUNDED or was == PropState.Body.AIRBORNE or was == PropState.Body.FLOATING
					var pm := crate.pos.distance_to(prop_prev_pos[i])
					if was_loose and pm > 3.0:
						flag("prop_teleport", t, pid, "%s moved %.2f m in a tick: %s -> %s body %d->%d" % [config.ship.props[i].kind, pm, v3(prop_prev_pos[i]), v3(crate.pos), was, crate.body])
					if crate.vel.length() > 30.0:
						flag("prop_speed", t, pid, "speed %.1f at %s" % [crate.vel.length(), v3(crate.pos)])
					if not bounds.grow(20.0).has_point(Vector2(crate.pos.x, crate.pos.z)) or crate.pos.y < min_floor - 8.0:
						flag("prop_far", t, pid, "%s loose far outside her at %s body %d" % [config.ship.props[i].kind, v3(crate.pos), crate.body], 600)
					if crate.body == PropState.Body.GROUNDED and crate.vel == Vector3.ZERO and (t + i) % 15 == 0:
						var lp := config.ship.props[i]
						var worst := 0.0
						for contact: Surfaces.Contact in sim.surfaces.obstacle_contacts(crate.pos, lp.radius, lp.height, rules.step_height, i):
							if contact.prop == -1:
								worst = maxf(worst, contact.depth)
						if worst > 0.15:
							flag("prop_in_wall", t, pid, "%s at rest %.2f m into a wall at %s surface %d" % [lp.kind, worst, v3(crate.pos), crate.surface], 900)
					if t % 30 == 0 and crate.body != PropState.Body.AIRBORNE:
						var pk := "%d,%d,%d" % [roundi(crate.pos.x * 200.0), roundi(crate.pos.y * 200.0), roundi(crate.pos.z * 200.0)]
						if not pile.has(pk):
							pile[pk] = []
						pile[pk].append(i)
			prop_prev_pos[i] = crate.pos
			prop_prev_body[i] = crate.body
		for pk: String in pile:
			if pile[pk].size() >= 3:
				flag("prop_pile", t, "pile" + pk, "props %s at one point %s" % [pile[pk], v3(state.props[pile[pk][0]].pos)], 900)

	# ---- the end ----
	var t_end := runner.tick()
	var ending := "ended"
	if not runner.is_over():
		ending = "stopped" if stop_tick >= 0 else "NO_END"
		if stop_tick < 0:
			flag("no_end", t_end, "match", "not over after %d ticks with %d seats in" % [t_end, sim.state.remaining()])
	elif sim.state.winner() == -1 and config.goal == MatchRules.Goal.LAST_STANDING:
		flag("tie", t_end, "match", "ended with no winner")
	var parts := PackedStringArray()
	for det: String in counts:
		parts.append("%s=%d" % [det, counts[det]])
	print("S|%s|%d|seats=%d|%s|ticks=%d|%s|winner=%d|left=%d|maxh=%.1f|maxv=%.1f|%s" % [ship_name, seed_value, config.seats, mode, t_end, ending, sim.state.winner(), sim.state.remaining(), max_h, max_v, ",".join(parts)])
