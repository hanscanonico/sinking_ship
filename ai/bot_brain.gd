class_name BotBrain
extends RefCounted
## A bot is a player (D10): it reads a BotView and answers an InputFrame, nothing
## more, rolling only its own stream. It plays §7's intents. Every think_period ticks
## one arbiter picks what it does: the first of the urgent intents whose reason holds,
## else the best scored of the rest, the one it has kept unless another beats it by
## its profile's hysteresis. Every tick in between it steers toward that intent's goal
## and turns its look toward what matters, no faster than its turn rate. Urgent first:
##
## - SWIM_OUT, in the sea: for the nearest way out it can reach — round through open
##   water when the hull or a wall stands across the straight swim — and up it.
## - FLEE, its open deck giving way: for the highest zone it can reach, down the stair
##   off it if need be.
## - CLIMB_OUT, the lowest corner of its floor within climb_margin_m of the sea and
##   higher ground within reach: for the highest zone it can reach, until it stands
##   there.
## - RIDE, a lurch telegraphed or under way: within ride_margin_m of the side it puts
##   down, away from it; else, once the deck swings, a brace where it stands while its
##   stamina lasts. Farther off, until the swing, it carries on with its target.
## - RECOVER, water or an open edge within edge_margin_m on a deck tilted past the grip
##   angle toward it: uphill, away from it.
## - BRACE, a seat facing it that could be winding up a shove that would land, on the
##   read brace_read gives, and for as long as that seat could: rooted, looking at it —
##   never with an edge at its back.
## - GUARD, a seat in the sea within guard_range_m: to the waterline, to shove it back
##   as it climbs.
##
## Then scored: SEEK_HIGH — water within edge_margin_m and higher ground to reach, or
## nobody to go at — for the highest zone it can reach, where it goes at whoever
## comes up too; LINE_UP, its target within a shove's carry of the water or an
## unrailed drop, weighed by lineup_weight — round to the far side of it, then the
## shove that puts it over; HUNT — through the walk graph to its target's zone, then at
## it, past the grip angle round to its uphill side first.
##
## Its target is a seat it perceives and can reach, scored by nearness and, by
## king_of_hill_bias, by how high it stands. Whatever the intent, every tick, a tier
## that dodges_cargo steps out of the path of a crate sliding at it (SH10), and then it
## keeps edge_margin_m from water and open edges — unless its target stands lined up
## between it and one — and shoves whoever a shove from where it looks would land on,
## charging a bracing one on its read; it presses only once its view shows its last
## press, so what it sees of itself is never from before it. A bot that has stood still
## for two thinks while walking, with nobody at hand to be holding it back, steps
## aside. Its stream also rolls, mistake_rate times a second, a lapse: mistake_seconds
## walking a heading of its choosing, heedless of the edges.

enum Intent { SEEK_HIGH, LINE_UP, HUNT, GUARD, BRACE, RECOVER, RIDE, CLIMB_OUT, FLEE, SWIM_OUT }

## Directions probed around the bot for water and open edges.
const PROBES := 8
## How far apart the open-water points a swimmer tries for a way round are, in metres.
const SWIM_LEG := 1.5


## What one tick's intent asks for: a walk, a look, buttons, whether the edges may be
## ignored and whether no shove may be thrown.
class Steer:
	var move := Vector2.ZERO
	var watch := Vector2.ZERO
	var buttons := 0
	var heedless := false
	var hold_fire := false


var seat: int
## What the bot does, as its last think chose it.
var intent := Intent.SEEK_HIGH
## The seat it goes at, or -1 for none.
var target := -1

var _profile: BotProfile
var _rules: BrawlRules
## The layout's cargo: each crate's grip, against the deck's slope.
var _cargo: Array[ShipProp] = []
var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rng: RandomNumberGenerator
## The zone its intent makes for, or WalkGraph.NONE.
var _goal := WalkGraph.NONE
## The portals to it, as the last think found them; steered along until the next.
var _legs: Array[WalkGraph.Portal] = []
## Whether it is climbing because its floor was about to flood: it climbs on until it
## stands in the zone it was making for.
var _climbing := false
var _aim_offset := 0.0
var _think_in := 0
var _last_buttons := 0
## The look this brain last sent, or -1 before its first: it turns from there no
## faster than its profile's turn rate (D10).
var _look := -1
## Whether this think's reads came up: brace against a windup, charge a brace.
var _reads_brace := false
var _reads_charge := false
## Ticks this charge has been held for; 0 when not charging.
var _charge_held := 0
var _charge_full_ticks: int
## The tick of its last shove press, -1 for none.
var _pressed_at := -1
## How far a shove carries an unbraced body on a level deck, from the rules: how near a
## drop a target must stand to be worth lining up.
var _carry: float
## The way from its target to the drop nearest it, and how far, as the last think
## found them; zero for none.
var _drop_way := Vector2.ZERO
var _drop_distance := INF
## A lapse under way: ticks of it left, and the heading it walks.
var _lapse := 0
var _lapse_heading := Vector2.ZERO
## Where it stood at the last think, whether it meant to walk since, and how many
## thinks running it has meant to and not moved.
var _stood_at := Vector3.INF
var _walking := false
var _stuck := 0
## Whether, at the last think, water or an open edge stood within the edge margin
## plus the walk to the next think: until then, nothing nearer needs looking for.
var _edges_near := true
## In the sea, the way out it is swimming for and the open water it swims through on
## the way, as the last think found them; null and INF for none.
var _way_out: Surfaces.Climb
var _swim_via := Vector3.INF


## [param rng] is this seat's own stream, SeedStreams' (match seed, seat).
func _init(
	bot_seat: int,
	profile: BotProfile,
	rules: BrawlRules,
	cargo: Array[ShipProp],
	surfaces: Surfaces,
	walk_graph: WalkGraph,
	rng: RandomNumberGenerator
) -> void:
	seat = bot_seat
	_profile = profile
	_rules = rules
	_cargo = cargo
	_surfaces = surfaces
	_walk_graph = walk_graph
	_rng = rng
	_charge_full_ticks = Ticks.from_seconds(rules.charge_full)
	var knock := rules.knockback
	var slowed := rules.stagger_friction * rules.stagger
	if slowed >= knock:
		_carry = knock * knock / (2.0 * rules.stagger_friction)
	else:
		_carry = (
			(knock + knock - slowed) * 0.5 * rules.stagger
			+ pow(knock - slowed, 2.0) / (2.0 * rules.ground_friction)
		)


func decide(view: BotView, tick: int) -> InputFrame:
	if view.is_empty():
		return InputFrame.new(seat, tick)
	var seen := view.snapshot()
	var me := _entry(seen, seat)
	if me.is_empty() or me["out"]:
		return InputFrame.new(seat, tick)
	var first := _look == -1
	if first:
		_look = InputFrame.quantize_yaw(me["facing"])
	var pose := view.pose()
	# As a player sees them: the railings the match has broken, and its crates.
	_surfaces.honour(pose, MatchState.broken_in(seen["railing_hp"]), PropState.from_snapshot(seen))
	# The pose is current but the snapshot is reaction_ticks old: it reckons from where
	# its own seen velocity has carried it since.
	var reaction_s := _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
	var my_vel: Vector3 = me["vel"]
	var now_pos: Vector3 = me["pos"] + Vector3(my_vel.x, 0.0, my_vel.z) * reaction_s
	if me["state"] == PlayerState.Body.SWIMMING:
		intent = Intent.SWIM_OUT
		return _swim_out(me, now_pos, pose, tick)
	var mark := _entry(seen, target)
	if intent == Intent.SWIM_OUT:
		# Out of the sea: a fresh look round on deck.
		_think_in = 0
	elif mark.has(BotView.REMEMBERED) and _flat(now_pos, mark["pos"]) < _rules.body_radius * 4.0:
		# Where it last saw its target, and nobody there: time to think again.
		_think_in = 0
	if _think_in <= 0:
		_think(seen, me, now_pos, pose)
		# After the first, each seat thinks on its own beat: never every bot at once.
		_think_in = _profile.think_period - (seat % _profile.think_period if first else 0)
		mark = _entry(seen, target)
	_think_in -= 1
	var steer := _steer(seen, me, mark, now_pos, pose)
	if _lapse > 0:
		_lapse -= 1
		steer.move = _lapse_heading
		steer.watch = Vector2.ZERO
		steer.heedless = true
	if _stuck >= 2 and steer.move != Vector2.ZERO:
		steer.move = steer.move.rotated(PI * 0.5 if _stuck % 4 < 2 else -PI * 0.5)
	if not steer.heedless:
		_out_of_cargo(steer, seen, now_pos, pose)
		_keep_off_edges(steer, me, mark, now_pos, pose)
	var buttons := steer.buttons
	if _charge_held > 0:
		buttons = _hold_charge(seen, me)
	elif not steer.hold_fire:
		var shove := _shove(seen, me, mark, tick)
		if shove != 0:
			buttons = shove
	_walking = steer.move != Vector2.ZERO
	_last_buttons = buttons
	_turn_toward(steer.watch if steer.watch != Vector2.ZERO else steer.move)
	return InputFrame.new(seat, tick, InputFrame.quantize(steer.move), buttons, _look)


## In the sea: nothing to press while a climb is under way; else for the way out the
## last think found, through the open water on the way to it first, looking where it
## swims. It presses on into the edge that stops it, which is what starts the climb.
func _swim_out(me: Dictionary, now_pos: Vector3, pose: ShipPose, tick: int) -> InputFrame:
	if _think_in <= 0:
		_find_way_out(me, now_pos, pose)
		# With nowhere to climb out, the next look round can wait a second.
		_think_in = _profile.think_period if _way_out != null else Ticks.RATE
	_think_in -= 1
	_last_buttons = 0
	_charge_held = 0
	if me["climb"] > 0 or _way_out == null:
		return InputFrame.new(seat, tick, Vector2i.ZERO, 0, _look)
	var toward := _way_out.stand if _swim_via == Vector3.INF else _swim_via
	var wish := Vector2(toward.x - now_pos.x, toward.z - now_pos.z).normalized()
	_turn_toward(wish)
	return InputFrame.new(seat, tick, InputFrame.quantize(wish), 0, _look)


## The nearest way out within the swim its cold has left, straight across the water;
## failing that, the nearest by way of a point of open water a leg or a few off that
## nothing hides from it — round the hull or a wall; failing that too, the nearest of
## those within a whole cold meter's swim, so it keeps swimming while there is one.
func _find_way_out(me: Dictionary, now_pos: Vector3, pose: ShipPose) -> void:
	var reach: float = me["cold"] * _rules.swim_speed
	_swim_via = Vector3.INF
	_way_out = _surfaces.nearest_climb(now_pos, pose, _rules, reach)
	if _way_out != null:
		return
	var eye := Vector3.UP * _profile.eye_height_m
	for within: float in [reach, _rules.cold_meter * _rules.swim_speed]:
		var best := INF
		for ring in range(1, 4):
			for index in PROBES:
				var direction := Vector2.from_angle(TAU * index / PROBES)
				var via := now_pos + Vector3(direction.x, 0.0, direction.y) * SWIM_LEG * ring
				if not _surfaces.line_of_sight(now_pos + eye, via + eye, pose):
					continue
				var leg := now_pos.distance_to(via)
				var climb := _surfaces.nearest_climb(via, pose, _rules, within - leg)
				if climb == null or leg + via.distance_to(climb.stand) >= best:
					continue
				best = leg + via.distance_to(climb.stand)
				_way_out = climb
				_swim_via = via
		if _way_out != null:
			return


## Rolls this think's heading error, reads and lapse from the bot's own stream — the
## same draws, in the same order, every think — then picks its target, its intent and
## the route to the intent's goal.
func _think(seen: Dictionary, me: Dictionary, now_pos: Vector3, pose: ShipPose) -> void:
	var my_pos: Vector3 = me["pos"]
	var my_surface: int = me["surface"]
	var error := _profile.aim_error_deg
	_aim_offset = deg_to_rad(_rng.randf_range(-error, error))
	_reads_brace = _rng.randf() < _profile.brace_read
	_reads_charge = _rng.randf() < _profile.charge_read
	var lapses := (
		_rng.randf() < _profile.mistake_rate * _profile.think_period * Ticks.SECONDS_PER_TICK
	)
	var lapse_heading := Vector2.from_angle(_rng.randf() * TAU)
	if lapses and _lapse == 0:
		_lapse = Ticks.from_seconds(_profile.mistake_seconds)
		_lapse_heading = lapse_heading
	var moved := _stood_at == Vector3.INF or _flat(my_pos, _stood_at) >= _rules.body_radius * 0.1
	var held: bool = (
		me["action"] != PlayerState.Action.IDLE
		or me["stagger"] > 0
		or me["hitstop"] > 0
		or _body_near(seen, my_pos)
	)
	_stuck = _stuck + 1 if _walking and not moved and not held else 0
	_stood_at = my_pos
	var found := _walk_graph.search(my_pos, my_surface, pose)
	_choose_target(seen, me, found, pose)
	var mark := _entry(seen, target)
	var my_zone := _zone_of(me)
	var highest := _walk_graph.highest_in(found, pose)
	if _climbing and my_zone == _goal and not _surfaces.is_ramp(my_surface):
		_climbing = false
	_climbing = (
		_climbing
		or (
			my_zone != WalkGraph.NONE
			and highest != my_zone
			and _walk_graph.lowest_world_height(my_zone, pose) < _profile.climb_margin_m
		)
	)
	var walk := _rules.walk_speed * _profile.think_period * Ticks.SECONDS_PER_TICK
	_edges_near = _danger_within(now_pos, my_surface, pose, _profile.edge_margin_m + walk)
	_drop_way = Vector2.ZERO
	_drop_distance = INF
	if (
		_profile.lineup_weight > _profile.hunt_weight
		and not mark.is_empty()
		and not mark.has(BotView.REMEMBERED)
		and _flat(my_pos, mark["pos"]) < _carry * 2.0
	):
		_find_drop(mark, pose)
	var swimmer := _swimmer_near(seen, my_pos)
	intent = _arbitrate(seen, me, mark, now_pos, pose, swimmer, highest)
	if intent == Intent.GUARD:
		target = swimmer
	match intent:
		Intent.SEEK_HIGH, Intent.CLIMB_OUT, Intent.FLEE:
			_goal = highest
		Intent.GUARD:
			_goal = WalkGraph.NONE
		_:
			_goal = _zone_of(_entry(seen, target))
	_legs = _walk_graph.route_in(found, _goal)


## The arbiter: the first urgent intent whose reason holds, else the best of SEEK_HIGH,
## LINE_UP and HUNT by score — the one the bot has, unless another beats it by its
## profile's hysteresis. Standing in [param highest] already, there is no higher
## ground to seek: it goes at whoever it can.
func _arbitrate(
	seen: Dictionary,
	me: Dictionary,
	mark: Dictionary,
	now_pos: Vector3,
	pose: ShipPose,
	swimmer: int,
	highest: int
) -> Intent:
	var urgent := _urgent(seen, me, mark, now_pos, pose, swimmer)
	if urgent != -1:
		return urgent as Intent
	var scores := PackedFloat64Array()
	scores.resize(Intent.size())
	if mark.is_empty():
		scores[Intent.SEEK_HIGH] = _profile.wander_weight
	elif _zone_of(me) != highest and _water_near(now_pos, pose):
		scores[Intent.SEEK_HIGH] = 1.0
	if _drop_way != Vector2.ZERO:
		scores[Intent.LINE_UP] = _profile.lineup_weight * (1.0 - 0.5 * _drop_distance / _carry)
	if not mark.is_empty():
		scores[Intent.HUNT] = _profile.hunt_weight
	var kept := intent
	if kept != Intent.SEEK_HIGH and kept != Intent.LINE_UP and kept != Intent.HUNT:
		kept = Intent.SEEK_HIGH
	var best := kept
	for candidate: Intent in [Intent.SEEK_HIGH, Intent.LINE_UP, Intent.HUNT]:
		if scores[candidate] > scores[best]:
			best = candidate
	if scores[kept] > 0.0 and scores[best] <= scores[kept] + _profile.hysteresis:
		return kept
	return best


## The first of the urgent intents whose reason holds, in order of claim, or -1.
func _urgent(
	seen: Dictionary,
	me: Dictionary,
	mark: Dictionary,
	now_pos: Vector3,
	pose: ShipPose,
	swimmer: int
) -> int:
	var my_zone := _zone_of(me)
	# A brace, once read, is kept while the threat it answers is: it is not re-rolled.
	var bracing := _reads_brace or intent == Intent.BRACE
	var urgent := -1
	if my_zone != WalkGraph.NONE and _walk_graph.doomed(my_zone, pose):
		urgent = Intent.FLEE
	elif _climbing:
		urgent = Intent.CLIMB_OUT
	elif _rides(me, now_pos, pose):
		urgent = Intent.RIDE
	elif _slipping(me, mark, now_pos, pose):
		urgent = Intent.RECOVER
	elif bracing and not me["exhausted"] and not _threat(seen, me).is_empty():
		urgent = Intent.BRACE
	elif swimmer != -1:
		urgent = Intent.GUARD
	return urgent


## The seat to go at: of those it perceives on their feet, in a zone it can reach,
## scored by how near — against the nearest — and by king_of_hill_bias how high they
## stand, against the lowest and the highest. Its current target stays unless another
## beats it by the hysteresis; ties go to the lower seat.
func _choose_target(
	seen: Dictionary, me: Dictionary, found: WalkGraph.Search, pose: ShipPose
) -> void:
	var my_pos: Vector3 = me["pos"]
	var candidates: Array[Dictionary] = []
	var nearest := INF
	var lowest := INF
	var highest := -INF
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == seat or entry["out"] or entry["state"] == PlayerState.Body.SWIMMING:
			continue
		var zone := _zone_of(entry)
		if zone != WalkGraph.NONE and (found.cost.is_empty() or found.cost[zone] == INF):
			continue
		candidates.append(entry)
		var height := pose.world_height(entry["pos"])
		nearest = minf(nearest, my_pos.distance_to(entry["pos"]))
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	var bias := _profile.king_of_hill_bias
	var best := -1
	var best_score := -INF
	var kept_score := -INF
	for entry: Dictionary in candidates:
		var near := nearest / maxf(my_pos.distance_to(entry["pos"]), _rules.body_radius)
		var high := 1.0
		if highest - lowest > _rules.step_height:
			high = (pose.world_height(entry["pos"]) - lowest) / (highest - lowest)
		var score := (1.0 - bias) * near + bias * high
		if score > best_score:
			best = entry["seat"]
			best_score = score
		if entry["seat"] == target:
			kept_score = score
	if best != -1 and kept_score + _profile.hysteresis >= best_score:
		return
	target = best


func _steer(
	seen: Dictionary, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> Steer:
	var steer := Steer.new()
	match intent:
		Intent.SEEK_HIGH, Intent.CLIMB_OUT, Intent.FLEE:
			_make_for_goal(steer, me, mark, now_pos, pose)
		Intent.LINE_UP:
			_line_up(steer, me, mark, now_pos, pose)
		Intent.GUARD:
			_walk_at(steer, me, mark, pose)
		Intent.BRACE:
			_brace(steer, seen, me, mark, now_pos, pose)
		Intent.RECOVER:
			_recover(steer, me, mark, now_pos, pose)
		Intent.RIDE:
			_ride(steer, me, mark, now_pos, pose)
		_:
			_hunt(steer, me, mark, now_pos, pose)
	return steer


## Along the route to its goal; there, at a target that has come up into its zone, or
## holding, looking at its target.
func _make_for_goal(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	if _follow_route(steer, me, now_pos, pose):
		return
	if not mark.is_empty() and _zone_of(mark) == _zone_of(me):
		_walk_at(steer, me, mark, pose)
	elif not mark.is_empty():
		var mark_pos: Vector3 = mark["pos"]
		steer.watch = Vector2(mark_pos.x - now_pos.x, mark_pos.z - now_pos.z)


## Along the route to its target's zone; there, at it.
func _hunt(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	if not _follow_route(steer, me, now_pos, pose):
		_walk_at(steer, me, mark, pose)


## Round its target, a shove's reach off it, toward the far side from the drop — at
## most a sixth of a turn round it at a time, so the circle keeps clear of the target
## and of the drop — holding its shove until the target stands between it and the
## drop; then at it.
func _line_up(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	if mark.is_empty() or _drop_way == Vector2.ZERO or _follow_route(steer, me, now_pos, pose):
		_hunt(steer, me, mark, now_pos, pose)
		return
	var my_pos: Vector3 = me["pos"]
	var mark_pos: Vector3 = mark["pos"]
	var from := Vector2(my_pos.x, my_pos.z)
	var at := Vector2(mark_pos.x, mark_pos.z)
	if absf((at - from).angle_to(_drop_way)) <= deg_to_rad(_rules.shove_cone_deg):
		_walk_at(steer, me, mark, pose)
		return
	var bearing := (from - at).angle()
	var turn := clampf(angle_difference(bearing, (-_drop_way).angle()), -TAU / 6.0, TAU / 6.0)
	var standoff := _rules.body_radius * 2.0 + _rules.shove_reach
	var point := at + Vector2.from_angle(bearing + turn) * standoff
	steer.move = _clear_heading(
		my_pos,
		(point - from).normalized(),
		PackedInt32Array([me["surface"], mark["surface"]]),
		PackedInt32Array([_zone_of(me), _zone_of(mark)])
	)
	steer.watch = at - from
	steer.hold_fire = true


## Rooted, looking at the seat that could be winding up at it — and holding its own
## shove while that one is seen winding up — or, with no such seat now, hunting.
func _brace(
	steer: Steer,
	seen: Dictionary,
	me: Dictionary,
	mark: Dictionary,
	now_pos: Vector3,
	pose: ShipPose
) -> void:
	var threat := _threat(seen, me)
	if threat.is_empty() or me["exhausted"]:
		_hunt(steer, me, mark, now_pos, pose)
		return
	var my_pos: Vector3 = me["pos"]
	var threat_pos: Vector3 = threat["pos"]
	steer.watch = Vector2(threat_pos.x - my_pos.x, threat_pos.z - my_pos.z)
	steer.buttons = InputFrame.BRACE
	var action: PlayerState.Action = threat["action"]
	steer.hold_fire = action == PlayerState.Action.WINDUP or action == PlayerState.Action.CHARGE


## Uphill, and away from the water or the edge the slope would carry it to.
func _recover(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	var gravity := pose.ship_gravity(_rules.gravity)
	var uphill := -Vector2(gravity.x, gravity.z).normalized()
	var away := _away_from_danger(now_pos, me["surface"], pose, mark, Vector2.ZERO)
	steer.move = _clear_heading(
		now_pos, (uphill + away).normalized(), PackedInt32Array(), PackedInt32Array()
	)
	if not mark.is_empty():
		var mark_pos: Vector3 = mark["pos"]
		steer.watch = Vector2(mark_pos.x - now_pos.x, mark_pos.z - now_pos.z)


## Told of a lurch: away from the side it will put down while that side is within
## ride_margin_m; else, with the deck swinging, a brace where it stands; else hunting.
func _ride(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	var lurch := pose.lurch_warning if pose.lurch_warning != 0.0 else pose.lurch
	if lurch != 0.0 and _near_low_side(me, now_pos, pose, lurch):
		steer.move = _clear_heading(
			now_pos, -ShipPose.low_side(lurch), PackedInt32Array(), PackedInt32Array()
		)
		return
	if pose.lurch != 0.0 and not me["exhausted"]:
		steer.buttons = InputFrame.BRACE
		steer.hold_fire = true
		if not mark.is_empty():
			var mark_pos: Vector3 = mark["pos"]
			steer.watch = Vector2(mark_pos.x - now_pos.x, mark_pos.z - now_pos.z)
		return
	_hunt(steer, me, mark, now_pos, pose)


## Toward the next point on the route, round what stands in the way; false when there
## is no portal left to go through.
func _follow_route(steer: Steer, me: Dictionary, now_pos: Vector3, pose: ShipPose) -> bool:
	# The route is followed from where the bot's seen velocity has carried it: a
	# doorway is narrower than what the reaction lag would overshoot.
	var my_surface: int = me["surface"]
	var now_zone := _walk_graph.zone_at(now_pos, my_surface)
	var waypoint := _waypoint(now_pos, my_surface, now_zone, pose)
	if waypoint.is_empty():
		return false
	var wish := Vector2(waypoint[0].x - now_pos.x, waypoint[0].z - now_pos.z).normalized()
	steer.move = _clear_heading(now_pos, wish, PackedInt32Array(), PackedInt32Array())
	return true


## At [param mark], off by this think's heading error, looking at it, keeping to its
## own surface and zone and the mark's.
func _walk_at(steer: Steer, me: Dictionary, mark: Dictionary, pose: ShipPose) -> void:
	if mark.is_empty():
		return
	var my_pos: Vector3 = me["pos"]
	var mark_pos: Vector3 = mark["pos"]
	var goal := _approach(my_pos, mark_pos, pose)
	var wish := Vector2(goal.x - my_pos.x, goal.z - my_pos.z).normalized().rotated(_aim_offset)
	steer.move = _clear_heading(
		my_pos,
		wish,
		PackedInt32Array([me["surface"], mark["surface"]]),
		PackedInt32Array([_zone_of(me), _zone_of(mark)])
	)
	steer.watch = Vector2(mark_pos.x - my_pos.x, mark_pos.z - my_pos.z).rotated(_aim_offset)


## Turns [param steer]'s walk away from water and open edges within edge_margin_m —
## slow enough that a reaction late, then stopping, stays inside the margin — and lets
## go of a brace there: rooted, the bot could not step back from it.
func _keep_off_edges(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	if not _edges_near:
		return
	var my_surface: int = me["surface"]
	var away := _away_from_danger(now_pos, my_surface, pose, mark, _stair_ahead(my_surface, pose))
	if away == Vector2.ZERO:
		return
	if steer.buttons == InputFrame.BRACE:
		steer.buttons = 0
		steer.hold_fire = false
	var toward_danger := minf(steer.move.dot(away), 0.0)
	var move := (away + steer.move - away * toward_danger).normalized()
	var reaction_s := _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
	var stop_s := _rules.walk_speed / _rules.ground_friction
	var escape_speed := _profile.edge_margin_m / (reaction_s + stop_s)
	steer.move = move.limit_length(escape_speed / _rules.walk_speed)


## A shove at whoever one would land on, its target first — weighed as things stood in
## its view, from where it looks now: a charge at a bracing one on the read, else a
## tap. Nothing while its view predates its last press, nor while it sees itself busy.
func _shove(seen: Dictionary, me: Dictionary, mark: Dictionary, tick: int) -> int:
	if _last_buttons & InputFrame.SHOVE or seen["tick"] <= _pressed_at:
		return 0
	if me["action"] != PlayerState.Action.IDLE or me["stagger"] > 0:
		return 0
	var my_pos: Vector3 = me["pos"]
	var victim := {}
	if _lands(my_pos, mark):
		victim = mark
	else:
		for entry: Dictionary in seen["seats"]:
			if entry["seat"] != seat and _lands(my_pos, entry):
				victim = entry
				break
	if victim.is_empty():
		return 0
	_pressed_at = tick
	if victim["bracing"] and _reads_charge:
		_charge_held = 1
	return InputFrame.SHOVE


## A charge under way: held until it is full, then let go — or let go at once once
## its view, caught up with the press, shows the press went unheeded.
func _hold_charge(seen: Dictionary, me: Dictionary) -> int:
	var unheeded: bool = seen["tick"] > _pressed_at and me["action"] == PlayerState.Action.IDLE
	if _charge_held >= _charge_full_ticks or unheeded:
		_charge_held = 0
		return 0
	_charge_held += 1
	return InputFrame.SHOVE


## Whether a shove from [param from], where the bot looks, lands on the seat
## [param entry] describes as it was seen.
func _lands(from: Vector3, entry: Dictionary) -> bool:
	if entry.is_empty() or entry["out"] or entry.has(BotView.REMEMBERED):
		return false
	var candidate := ShoveResolver.Candidate.new(
		entry["seat"], entry["pos"], _rules.body_radius, _rules.body_height
	)
	return ShoveResolver.lands(
		from,
		_rules.body_radius,
		Vector2.from_angle(InputFrame.yaw_angle(_look)),
		candidate,
		_rules.shove_reach,
		_rules.shove_cone_deg,
		_surfaces,
		_rules.step_height
	)


## Whether another seat stands within a body's width of touching [param my_pos]: a
## walk it holds back is a crowd, not a wall.
func _body_near(seen: Dictionary, my_pos: Vector3) -> bool:
	for entry: Dictionary in seen["seats"]:
		if (
			entry["seat"] != seat
			and not entry["out"]
			and my_pos.distance_to(entry["pos"]) < _rules.body_radius * 4.0
		):
			return true
	return false


## The nearest seat seen in the sea within guard_range_m of [param my_pos], or -1:
## one there may climb out at the bot's feet.
func _swimmer_near(seen: Dictionary, my_pos: Vector3) -> int:
	var nearest := -1
	var best := _profile.guard_range_m
	for entry: Dictionary in seen["seats"]:
		if (
			entry["seat"] == seat
			or entry["state"] != PlayerState.Body.SWIMMING
			or entry.has(BotView.REMEMBERED)
		):
			continue
		var distance := my_pos.distance_to(entry["pos"])
		if distance < best:
			best = distance
			nearest = entry["seat"]
	return nearest


## The nearest seat whose shove would land on the bot as things stand and that
## could be winding one up: seen in a windup or a charge, or idle and able to
## start one. The view is reaction_ticks old, so this is a read, never a reaction
## to a quick windup — that has landed before the bot could see it. Empty when
## there is none.
func _threat(seen: Dictionary, me: Dictionary) -> Dictionary:
	var nearest := {}
	var best := INF
	var my_pos: Vector3 = me["pos"]
	var mine := ShoveResolver.Candidate.new(seat, my_pos, _rules.body_radius, _rules.body_height)
	for entry: Dictionary in seen["seats"]:
		if (
			entry["seat"] == seat
			or entry["state"] != PlayerState.Body.GROUNDED
			or entry.has(BotView.REMEMBERED)
		):
			continue
		var action: PlayerState.Action = entry["action"]
		if action == PlayerState.Action.ACTIVE or action == PlayerState.Action.RECOVERY:
			continue
		if entry["stagger"] > 0:
			continue
		if not ShoveResolver.lands(
			entry["pos"],
			_rules.body_radius,
			Vector2.from_angle(entry["facing"]),
			mine,
			_rules.shove_reach,
			_rules.shove_cone_deg,
			_surfaces,
			_rules.step_height
		):
			continue
		var distance := my_pos.distance_squared_to(entry["pos"])
		if distance < best:
			best = distance
			nearest = entry
	return nearest


## Whether a lurch gives the bot a reason to ride it: the side it puts down within
## ride_margin_m, or the deck swinging and stamina to brace with.
func _rides(me: Dictionary, now_pos: Vector3, pose: ShipPose) -> bool:
	var lurch := pose.lurch_warning if pose.lurch_warning != 0.0 else pose.lurch
	if lurch == 0.0:
		return false
	return _near_low_side(me, now_pos, pose, lurch) or pose.lurch != 0.0 and not me["exhausted"]


## Whether walking ride_margin_m — and a body's radius — toward the side
## [param lurch] puts down meets the water or a drop, railed or not.
func _near_low_side(me: Dictionary, now_pos: Vector3, pose: ShipPose, lurch: float) -> bool:
	var reach := _profile.ride_margin_m + _rules.body_radius
	return _edge_toward(now_pos, me["surface"], ShipPose.low_side(lurch), reach, pose, true) < INF


## Whether the deck, tilted past the grip angle, would carry the bot toward water or
## an open edge within its edge margin.
func _slipping(me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose) -> bool:
	if not _edges_near or pose.slope_deg() <= _rules.grip_angle_deg:
		return false
	var away := _away_from_danger(now_pos, me["surface"], pose, mark, Vector2.ZERO)
	var gravity := pose.ship_gravity(_rules.gravity)
	return away != Vector2.ZERO and away.dot(Vector2(gravity.x, gravity.z)) < 0.0


## The way from [param mark] to the water or unrailed drop within a shove's carry of
## it — every probe that meets one, the nearer the more — and how far the nearest is,
## into _drop_way and _drop_distance; zero and INF for none.
func _find_drop(mark: Dictionary, pose: ShipPose) -> void:
	var way := Vector2.ZERO
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var distance := _edge_toward(mark["pos"], mark["surface"], direction, _carry, pose, false)
		if distance < INF:
			way += direction * (1.0 - distance / _carry)
			_drop_distance = minf(_drop_distance, distance)
	_drop_way = way.normalized()


## How far a walk from [param from] on [param surface] along [param direction] goes
## before it meets the water or a drop within [param reach] — a body's width at a
## time — or INF when it meets neither, or a wall stands before it, or, unless
## [param through_railings], a railing of [param surface] does.
func _edge_toward(
	from: Vector3,
	surface: int,
	direction: Vector2,
	reach: float,
	pose: ShipPose,
	through_railings: bool
) -> float:
	var stride := _rules.body_radius * 2.0
	var feet := from.y
	for index in range(1, ceili(reach / stride) + 1):
		var along := minf(index * stride, reach)
		var at := from + Vector3(direction.x, 0.0, direction.y) * along
		at.y = feet
		var under := (
			Surfaces.NONE if _surfaces.wet(at, pose) else _surfaces.under(at, _rules.step_height)
		)
		if under != Surfaces.NONE:
			feet = _surfaces.height_at(under, at)
			continue
		if (
			_surfaces.blocked(from, at, _rules.body_height, _rules.step_height)
			or not through_railings and _surfaces.railed(from, at, surface)
		):
			return INF
		return along
	return INF


## The next point on the way to the goal: past the portals already gone through, or
## by a fresh route when the bot has strayed off the one it had; none when there is
## no portal left to go through.
func _waypoint(
	my_pos: Vector3, my_surface: int, my_zone: int, pose: ShipPose
) -> PackedVector3Array:
	while not _legs.is_empty():
		var leg := _legs[0]
		var on_its_ramp := (
			leg.ramp != WalkGraph.NONE and my_surface == _surfaces.ramp_surface(leg.ramp)
		)
		if on_its_ramp or my_zone == leg.from_zone:
			break
		if my_zone == leg.to_zone:
			_legs.pop_front()
			continue
		_legs = _walk_graph.route(my_pos, my_surface, _goal, pose)
		break
	if _legs.is_empty():
		return PackedVector3Array()
	return PackedVector3Array([_walk_graph.toward(_legs[0], my_pos, my_surface)])


## Where to walk to reach [param target_pos]: straight at it, except past the
## grip angle, where the bot first gets uphill of it so that its shove goes
## downhill.
func _approach(my_pos: Vector3, target_pos: Vector3, pose: ShipPose) -> Vector3:
	if pose.slope_deg() <= _rules.grip_angle_deg:
		return target_pos
	var gravity := pose.ship_gravity(_rules.gravity)
	var uphill := -Vector3(gravity.x, 0.0, gravity.z).normalized()
	if (my_pos - target_pos).dot(uphill) >= 0.0:
		return target_pos
	return target_pos + uphill * (_rules.body_radius * 2.0 + _rules.shove_reach)


## Whether any probe at edge_margin round [param my_pos] is wet.
func _water_near(my_pos: Vector3, pose: ShipPose) -> bool:
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * _profile.edge_margin_m
		if _surfaces.wet(probe, pose):
			return true
	return false


## [param wish] turned as little as it can, a probe direction at a time either way,
## so that the next edge_margin of the walk neither runs into a blocker nor, when
## [param keep_to] lists surfaces, steps onto any surface but those or a platform of
## the zones [param keep_zones]; unturned when every way does.
func _clear_heading(
	my_pos: Vector3, wish: Vector2, keep_to: PackedInt32Array, keep_zones: PackedInt32Array
) -> Vector2:
	if wish == Vector2.ZERO:
		return wish
	for turn: int in [0, 1, -1, 2, -2]:
		var heading := wish.rotated(TAU * turn / PROBES)
		var ahead := my_pos + Vector3(heading.x, 0.0, heading.y) * _profile.edge_margin_m
		if _surfaces.blocked(my_pos, ahead, _rules.body_height, _rules.step_height):
			continue
		var onto := _surfaces.under(ahead, _rules.step_height)
		if (
			not keep_to.is_empty()
			and onto != Surfaces.NONE
			and not onto in keep_to
			and (_surfaces.is_ramp(onto) or not _walk_graph.zone_at(ahead, onto) in keep_zones)
		):
			continue
		return heading
	return wish


## The way along the ramp the bot stands on when its route runs down it off a deck
## giving way, else zero: fleeing, the stair's far end is the way off, not an edge to
## back away from.
func _stair_ahead(my_surface: int, pose: ShipPose) -> Vector2:
	if (
		_legs.is_empty()
		or _legs[0].ramp == WalkGraph.NONE
		or my_surface != _surfaces.ramp_surface(_legs[0].ramp)
		or not _walk_graph.doomed(_legs[0].from_zone, pose)
	):
		return Vector2.ZERO
	return _legs[0].along


## A unit vector away from every probe at edge_margin that is wet or past an open
## edge — walking there would drop off it — or zero when none is (or they cancel
## out). A probe that stands on a surface within a step of the bot's feet is no edge;
## one past a railing of [param my_surface] is safe; one through a gap is not, unless
## [param mark] is lined up for a shove through it — nor one into the sea, when
## [param mark] is climbing out of it there. On a stair whose way on is
## [param stair_ahead], an open edge ahead of it is the stair's far end and its sides,
## and is no danger.
func _away_from_danger(
	my_pos: Vector3, my_surface: int, pose: ShipPose, mark: Dictionary, stair_ahead: Vector2
) -> Vector2:
	var push := Vector2.ZERO
	var guarding: bool = not mark.is_empty() and mark["climb"] > 0
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * _profile.edge_margin_m
		if _surfaces.wet(probe, pose):
			if not (guarding and _lined_up(my_pos, probe, mark)):
				push -= direction
		elif (
			_surfaces.under(probe, _rules.step_height) == Surfaces.NONE
			and direction.dot(stair_ahead) <= 0.0
			and _surfaces.drops(my_pos, probe, _rules.step_height)
			and not _surfaces.railed(my_pos, probe, my_surface)
			and not _lined_up(my_pos, probe, mark)
		):
			push -= direction
	return push.normalized()


## Whether any probe at [param reach] round [param my_pos] is wet or past an open edge
## of [param my_surface]: the look further out that says whether the edge margin's
## probes are worth making until the next think.
func _danger_within(my_pos: Vector3, my_surface: int, pose: ShipPose, reach: float) -> bool:
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * reach
		if _surfaces.wet(probe, pose):
			return true
		if (
			_surfaces.under(probe, _rules.step_height) == Surfaces.NONE
			and _surfaces.drops(my_pos, probe, _rules.step_height)
			and not _surfaces.railed(my_pos, probe, my_surface)
		):
			return true
	return false


## Turns [param steer]'s walk square to the path of the nearest crate seen coming at
## the bot — ahead of it, no farther than it slides in the bot's reaction and stopping
## time plus the edge margin, and passing within a body's radius and the edge margin of
## the bot — toward the side of the path the bot stands on, and lets go of a brace:
## rooted, it would be knocked down. Crates are seen as old as the rest of the view and
## carried on by their speed as the bot carries itself (decide's now_pos) and, on a
## deck [param pose] tilts past a crate's grip, by the pull downhill: one seen still as
## the deck swings is coming too. Nothing for a tier that does not dodge cargo.
func _out_of_cargo(steer: Steer, seen: Dictionary, now_pos: Vector3, pose: ShipPose) -> void:
	if not _profile.dodges_cargo:
		return
	var reaction_s := _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
	var lead_s := reaction_s + _rules.walk_speed / _rules.ground_friction
	var clearance := _rules.body_radius + _profile.edge_margin_m
	var gravity := pose.ship_gravity(_rules.gravity)
	var pull := Vector2(gravity.x, gravity.z) * reaction_s
	var slope := pose.slope_deg()
	var dodge := Vector2.ZERO
	var nearest := INF
	for entry: Dictionary in seen["props"]:
		if entry["state"] == PropState.Body.LOST:
			continue
		var vel: Vector3 = entry["vel"]
		var path := Vector2(vel.x, vel.z)
		if (
			entry["state"] == PropState.Body.GROUNDED
			and slope > _cargo[entry["prop"]].grip_angle_deg
		):
			path += pull
		var pos: Vector3 = entry["pos"]
		if path == Vector2.ZERO or absf(pos.y - now_pos.y) >= _rules.body_height:
			continue
		var now := pos + Vector3(path.x, 0.0, path.y) * reaction_s
		var offset := Vector2(now_pos.x - now.x, now_pos.z - now.z)
		var way := path.normalized()
		var ahead := offset.dot(way)
		var aside := offset - way * ahead
		if ahead <= 0.0 or ahead > path.length() * lead_s + _profile.edge_margin_m:
			continue
		if aside.length() >= clearance or ahead >= nearest:
			continue
		nearest = ahead
		dodge = aside.normalized() if aside != Vector2.ZERO else way.orthogonal()
	if dodge == Vector2.ZERO:
		return
	if steer.buttons == InputFrame.BRACE:
		steer.buttons = 0
		steer.hold_fire = false
	steer.move = dodge


## Whether [param mark] stands between the bot and [param probe] — nearer the probe
## than the bot, inside the shove cone toward it.
func _lined_up(my_pos: Vector3, probe: Vector3, mark: Dictionary) -> bool:
	if mark.is_empty() or mark.has(BotView.REMEMBERED):
		return false
	var mark_pos: Vector3 = mark["pos"]
	var toward_probe := Vector2(probe.x - my_pos.x, probe.z - my_pos.z)
	var toward_mark := Vector2(mark_pos.x - my_pos.x, mark_pos.z - my_pos.z)
	return (
		mark_pos.distance_to(probe) < _profile.edge_margin_m
		and absf(toward_probe.angle_to(toward_mark)) <= deg_to_rad(_rules.shove_cone_deg)
	)


## Turns the look toward [param heading] by at most the profile's turn rate in one
## tick; no heading keeps it.
func _turn_toward(heading: Vector2) -> void:
	if heading == Vector2.ZERO:
		return
	var most := roundi(
		_profile.turn_rate_deg / 360.0 * InputFrame.YAW_STEPS * Ticks.SECONDS_PER_TICK
	)
	var turn := posmod(InputFrame.quantize_yaw(heading.angle()) - _look, InputFrame.YAW_STEPS)
	if turn * 2 > InputFrame.YAW_STEPS:
		turn -= InputFrame.YAW_STEPS
	_look = posmod(_look + clampi(turn, -most, most), InputFrame.YAW_STEPS)


## The walk graph's zone for the seat [param entry] describes; WalkGraph.NONE for
## none.
func _zone_of(entry: Dictionary) -> int:
	if entry.is_empty():
		return WalkGraph.NONE
	return _walk_graph.zone_at(entry["pos"], entry["surface"])


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _entry(seen: Dictionary, wanted: int) -> Dictionary:
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == wanted:
			return entry
	return {}
