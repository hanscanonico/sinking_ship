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
##   water when the hull or a wall stands across the straight swim, out of a flooded
##   room by its doorways and stairs — and up it.
## - FLEE, its open deck giving way: for its refuge, down the stair off it if need be.
## - CLIMB_OUT, its floor — its room's lowest corner, or the open deck where it stands —
##   within climb_margin_m of the sea, or, once refuge_from of the ship is under water,
##   its way to its refuge dipping below its feet to within refuge_margin_m of it; and
##   its refuge elsewhere: for its refuge, until it stands there — or, while less than
##   refuge_from is under, on a floor a body's height above the sea. Its refuge is the
##   highest zone it can reach; once refuge_from is under, the highest were the deck
##   tilted further the way it leans, by as much as BotProfile.refuge_tilt says — the end
##   the ship rises by, where the last dry deck will be — kept through a lurch, and else
##   unless another would stand refuge_keep_m higher; so it goes there while the way is
##   dry.
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
## Then scored — the hunt and the line-up for more, the more of the ship's decks are
## under water, by late_hunt_gain: SEEK_HIGH — water within edge_margin_m and higher
## ground to reach, or nobody to go at — for the highest zone it can reach, where it
## goes at whoever comes up too; LINE_UP, its target within a shove's carry of the
## water or an unrailed drop and no nearer than its spar margin, weighed by
## lineup_weight — round to the far side of it, then the shove that puts it over; HUNT
## — through the walk graph to its target's zone, then at it, past the grip angle round
## to its uphill side first.
##
## Its target is a seat it perceives and can reach, scored by nearness and, by
## king_of_hill_bias, by how high it stands — less so on a crowded perch — and by how
## far over a shove would put it and whether another is at it already. With its target
## on its perch — its refuge or the highest ground — it aims ahead of it by perch_lead
## of where its seen velocity carries it: the last perch is fought for. Whatever the
## intent, every tick, a tier that dodges_cargo steps out of a sliding crate's path
## (SH10); then it keeps edge_margin_m from water and open edges, a broken railing's
## among them — less late in the sinking, none toward its target lined up between it
## and one — and shoves whoever a shove from where it looks would land on, charging a
## bracing one on its read. While the ship is level it spars: it charges nobody, and
## shoves nobody it would send at the water, an open drop or a railing within its spar
## margin. It presses only once its view shows its last press, so what it sees of
## itself is never from before it. A bot that has stood still for two thinks while
## walking, with nobody at hand moving to be holding it back, steps aside — or, on an
## open deck making for a stair, goes round through the rooms beside it.
## Its stream also rolls, mistake_rate times a second, a lapse: mistake_seconds walking
## a heading of its choosing, neither bracing nor holding its shove for a line-up —
## still off the water, and off open drops too (and out of a crate's path) unless it is
## one of the share of its profile's lapses that are heedless.

enum Intent { SEEK_HIGH, LINE_UP, HUNT, GUARD, BRACE, RECOVER, RIDE, CLIMB_OUT, FLEE, SWIM_OUT }


## What one tick's intent asks for: a walk, a look, buttons, whether open drops may be
## ignored — the water never is — and whether no shove may be thrown.
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
## Its way out of a sliding crate's path (SH10).
var _dodge: CargoDodge
var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _footing: BotFooting
## Whom it goes at, and the drop behind its target.
var _targeting: BotTargeting
var _rng: RandomNumberGenerator
## The zone its intent makes for, or WalkGraph.NONE.
var _goal := WalkGraph.NONE
## The portals to it, as the last think found them; steered along until the next.
var _legs: Array[WalkGraph.Portal] = []
## Whether it is climbing because its floor was about to flood: it climbs on until it
## stands in the zone it was making for.
var _climbing := false
## The refuge the ship's lean gave it at the last think, or WalkGraph.NONE.
var _refuge := WalkGraph.NONE
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
var _windup_ticks: int
## The tick of its last shove press, -1 for none.
var _pressed_at := -1
## A lapse under way: ticks of it left, the heading it walks, and whether it is
## heedless of open drops.
var _lapse := 0
var _lapse_heading := Vector2.ZERO
var _lapse_heedless := false
## Where it stood at the last think, whether it meant to walk since, and how many
## thinks running it has meant to and not moved.
var _stood_at := Vector3.INF
var _walking := false
var _stuck := 0
## The tick it set off walking on, this time.
var _walked_from := 0
## Where it saw every seat at the last think, by seat.
var _others_at := {}
## Where it last made headway walking — a body's radius from the last such place —
## and the tick its view showed it there: jiggling against a wall is no headway.
var _headway_at := Vector3.INF
var _stalled_since := 0
## Whether, at the last think, water or an open edge stood within the edge margin
## plus the walk to the next think: until then, nothing nearer needs looking for.
var _edges_near := true
## In the sea, where it swims for.
var _swim: BotSwim
## The walks it has sent and the ticks it sent them on, for as long as its view lags:
## what it pressed and has yet to see itself do. A tick of -1 is none.
var _sent_moves := PackedVector2Array()
var _sent_ticks := PackedInt32Array()
## Where it keeps off the edges from this tick: reckoned by its walks, and past the
## grip angle by its seen velocity too — the same place on a deck that grips.
var _edge_from := Vector3.ZERO
var _edge_also := Vector3.ZERO
## What the hunt and line-up scores are multiplied by, as the last think found the
## sinking: 1 with every deck dry, more the more are under.
var _pressing := 1.0
## How far ahead of its target it aims, as the last think found it: the share of where
## the target's seen velocity carries it over the bot's reaction time.
var _lead := 0.0
## How far from the water, an open drop or a railing it keeps whoever it shoves, as the
## last think found the sinking (BotProfile.spar_margin).
var _spar := 0.0


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
	_dodge = CargoDodge.new(profile, rules, cargo)
	_surfaces = surfaces
	_walk_graph = walk_graph
	_footing = BotFooting.new(surfaces, walk_graph, rules, profile.edge_margin_m)
	_targeting = BotTargeting.new(bot_seat, profile, rules, _footing, walk_graph)
	_swim = BotSwim.new(walk_graph, rules, profile.eye_height_m)
	_rng = rng
	_charge_full_ticks = Ticks.from_seconds(rules.charge_full)
	_windup_ticks = Ticks.from_seconds(rules.shove_windup)
	_sent_moves.resize(maxi(profile.reaction_ticks, 1))
	_sent_ticks.resize(_sent_moves.size())
	_sent_ticks.fill(-1)


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
	# As a player sees them, for the footing's probes too: broken railings, crates.
	_surfaces.honour(pose, MatchState.broken_in(seen["railing_hp"]), PropState.from_snapshot(seen))
	# The route is followed from where its seen velocity carries it; the edges are kept
	# from where its own walks have, which a turn toward one since cannot hide — and,
	# past the grip angle, where it slides wherever it walks, from both.
	var now_pos := _reckon(me)
	_edge_from = _by_walks(me, seen["tick"], now_pos)
	_edge_also = now_pos if pose.slope_deg() > _rules.grip_angle_deg else _edge_from
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
		steer.buttons = 0
		steer.hold_fire = false
		steer.heedless = _lapse_heedless
	if _stuck >= 2 and steer.move != Vector2.ZERO:
		steer.move = steer.move.rotated(PI * 0.5 if _stuck % 4 < 2 else -PI * 0.5)
	# Out of a crate's way, then off the edges: edge-keeping has the last word.
	if not steer.heedless:
		_out_of_cargo(steer, seen, now_pos, pose)
	_keep_off_edges(steer, me, mark, _edge_from, pose)
	var buttons := steer.buttons
	if _charge_held > 0:
		buttons = _hold_charge(seen, me)
	elif not steer.hold_fire:
		var shove := _shove(seen, me, mark, tick, pose)
		if shove != 0:
			buttons = shove
	if steer.move != Vector2.ZERO and not _walking:
		_walked_from = tick
	_walking = steer.move != Vector2.ZERO
	_last_buttons = buttons
	_turn_toward(steer.watch if steer.watch != Vector2.ZERO else steer.move)
	var frame := InputFrame.new(seat, tick, InputFrame.quantize(steer.move), buttons, _look)
	_sent_moves[tick % _sent_moves.size()] = frame.move_vector()
	_sent_ticks[tick % _sent_ticks.size()] = tick
	return frame


## Where the bot stands now, from where its view shows it: carried on by the velocity
## it was seen at. Its feet have risen or sunk with the walk, up a stair or onto the
## next deck.
func _reckon(me: Dictionary) -> Vector3:
	var seen_pos: Vector3 = me["pos"]
	var my_vel: Vector3 = me["vel"]
	var reaction_s := _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
	var now_pos := seen_pos + Vector3(my_vel.x, 0.0, my_vel.z) * reaction_s
	if me["surface"] != Surfaces.NONE:
		now_pos.y = _footing.feet_at(seen_pos, now_pos)
	return now_pos


## Where the bot stands now — on its feet and free to walk — by the walks it has sent
## since its view's [param seen_tick], unless a wall or a railing stands across them:
## it knows what it pressed, so a turn since is no surprise to it. Otherwise where
## [param reckoned] by its seen velocity.
func _by_walks(me: Dictionary, seen_tick: int, reckoned: Vector3) -> Vector3:
	if me["state"] != PlayerState.Body.GROUNDED or me["stagger"] != 0 or me["hitstop"] != 0:
		return reckoned
	var seen_pos: Vector3 = me["pos"]
	var walked := Vector2.ZERO
	for index in _sent_ticks.size():
		if _sent_ticks[index] >= seen_tick:
			walked += _sent_moves[index]
	walked *= _rules.walk_speed * Ticks.SECONDS_PER_TICK
	var walked_to := seen_pos + Vector3(walked.x, 0.0, walked.y)
	if (
		_surfaces.blocked(seen_pos, walked_to, _rules.body_height, _rules.step_height)
		or _surfaces.railed(seen_pos, walked_to, me["surface"])
	):
		return reckoned
	if me["surface"] != Surfaces.NONE:
		walked_to.y = _footing.feet_at(seen_pos, walked_to)
	return walked_to


## In the sea: nothing to press while a climb is under way; else for the way out the
## last think found (BotSwim), through the open water or the portal on the way to it
## first, looking where it swims. It presses on into the edge that stops it, which is
## what starts the climb.
func _swim_out(me: Dictionary, now_pos: Vector3, pose: ShipPose, tick: int) -> InputFrame:
	if _think_in <= 0:
		_swim.find(me["cold"], now_pos, pose)
		# With nowhere to make for, the next look round can wait a second.
		_think_in = _profile.think_period if _swim.goal() != Vector3.INF else Ticks.RATE
	_think_in -= 1
	_last_buttons = 0
	_charge_held = 0
	var toward := _swim.goal()
	if me["climb"] > 0 or toward == Vector3.INF:
		return InputFrame.new(seat, tick, Vector2i.ZERO, 0, _look)
	var wish := Vector2(toward.x - now_pos.x, toward.z - now_pos.z).normalized()
	_turn_toward(wish)
	return InputFrame.new(seat, tick, InputFrame.quantize(wish), 0, _look)


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
	var lapse_chance := _profile.mistake_rate * _profile.think_period * Ticks.SECONDS_PER_TICK
	var lapse_roll := _rng.randf()
	var lapse_heading := Vector2.from_angle(_rng.randf() * TAU)
	if lapse_roll < lapse_chance and _lapse == 0:
		_lapse = Ticks.from_seconds(_profile.mistake_seconds)
		_lapse_heading = lapse_heading
		# The same roll, under the heedless share of the chance: no draw of its own.
		_lapse_heedless = lapse_roll < lapse_chance * _profile.heedless_lapses
	var moved := _stood_at == Vector3.INF or _flat(my_pos, _stood_at) >= _rules.body_radius * 0.1
	var held: bool = (
		me["action"] != PlayerState.Action.IDLE
		or me["stagger"] > 0
		or me["hitstop"] > 0
		or _jostled(seen, my_pos)
	)
	# Not before its view could show it walking: until then, standing is no news.
	var seen_walking: bool = _walking and seen["tick"] > _walked_from
	_stuck = _stuck + 1 if seen_walking and not moved and not held else 0
	_stood_at = my_pos
	if not seen_walking or _flat(my_pos, _headway_at) >= _rules.body_radius:
		_headway_at = my_pos
		_stalled_since = seen["tick"]
	_others_at.clear()
	for entry: Dictionary in seen["seats"]:
		_others_at[entry["seat"]] = entry["pos"]
	var found := _walk_graph.search(my_pos, my_surface, pose)
	var under := _footing.flooded_share(pose)
	var highest := _walk_graph.highest_in(found, pose)
	# As the ship founders, the highest ground now is not where the last dry deck will be.
	var refuge := highest
	if under >= _profile.refuge_from:
		var tilt := _profile.refuge_tilt(pose.slope_deg())
		_refuge = _walk_graph.highest_in(found, pose, tilt, _refuge, _profile.refuge_keep_m)
		refuge = _refuge
	target = _targeting.choose(seen, me, found, pose, highest, target)
	var mark := _entry(seen, target)
	var my_zone := _zone_of(me)
	var feet := pose.above_water(my_pos)
	var floor_height := _walk_graph.floor_height(my_zone, my_pos, pose)
	# It climbs until it stands where it was making for — off its feet, it stands
	# nowhere — or, the ship not yet foundering, on a floor a body's height out of the
	# sea's reach.
	var clear := under < _profile.refuge_from and floor_height > _rules.body_height
	var there := my_zone != WalkGraph.NONE and my_zone == _goal
	if _climbing and (clear or there and not _surfaces.is_ramp(my_surface)):
		_climbing = false
	_climbing = (
		_climbing
		or (
			my_zone != WalkGraph.NONE
			and refuge != my_zone
			and (
				floor_height < _profile.climb_margin_m
				or (
					under >= _profile.refuge_from
					and _going_under(_walk_graph.route_in(found, refuge), pose, feet)
				)
			)
		)
	)
	# On the perch with its target, it presses: it aims where the target goes.
	_lead = 0.0
	if (
		not mark.is_empty()
		and my_zone != WalkGraph.NONE
		and (my_zone == refuge or my_zone == highest)
		and _zone_of(mark) == my_zone
	):
		_lead = _profile.perch_lead
	# Late in the sinking, with few dry decks left, it presses: closer to the edges, and
	# keener to go at someone than to keep its ground.
	_footing.margin = _profile.edge_margin_m * (1.0 - _profile.late_margin_share * under)
	_pressing = 1.0 + _profile.late_hunt_gain * under
	_spar = _profile.spar_margin(under)
	var walk := _rules.walk_speed * _profile.think_period * Ticks.SECONDS_PER_TICK
	var reach := _profile.edge_margin_m + walk
	_edges_near = (
		_footing.danger_within(_edge_from, pose, reach)
		or _edge_also != _edge_from and _footing.danger_within(_edge_also, pose, reach)
	)
	var lines_up := (
		_profile.lineup_weight > _profile.hunt_weight
		and not mark.is_empty()
		and not mark.has(BotView.REMEMBERED)
		and _flat(my_pos, mark["pos"]) < _targeting.carry * 2.0
	)
	_targeting.find_drop(mark if lines_up else {}, pose)
	var swimmer := _swimmer_near(seen, my_pos)
	intent = _arbitrate(seen, me, mark, now_pos, pose, swimmer, highest)
	if intent == Intent.GUARD:
		target = swimmer
	var kept_goal := _goal
	match intent:
		Intent.SEEK_HIGH:
			_goal = highest
		Intent.CLIMB_OUT, Intent.FLEE:
			_goal = refuge
		Intent.GUARD:
			_goal = WalkGraph.NONE
		_:
			_goal = _zone_of(_entry(seen, target))
	# The route it has, while its goal stands and every portal on it is open: two ways
	# of near one length do not swap it from one to the other at every think.
	var legs := _walk_graph.route_in(found, _goal)
	if _goal != kept_goal or legs.is_empty() or not _open(_legs, pose):
		_legs = legs
	if (
		seen["tick"] - _stalled_since >= Ticks.from_seconds(_profile.detour_after_s)
		and not _legs.is_empty()
		and _legs[0].ramp != WalkGraph.NONE
	):
		# No headway for a while on the way to a stair across its deck: round through
		# the rooms beside it.
		var way := _walk_graph.toward(_legs[0], now_pos, my_surface)
		var round_by := _walk_graph.detour(now_pos, my_surface, way, pose)
		if not round_by.is_empty():
			round_by.append_array(_legs)
			_legs = round_by
			_stalled_since = seen["tick"]


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
	elif _zone_of(me) != highest and _footing.water_near(now_pos, pose):
		scores[Intent.SEEK_HIGH] = 1.0
	if _targeting.drop_way != Vector2.ZERO and _targeting.drop_distance >= _spar:
		scores[Intent.LINE_UP] = (
			_profile.lineup_weight
			* (1.0 - 0.5 * _targeting.drop_distance / _targeting.carry)
			* _pressing
		)
	if not mark.is_empty():
		scores[Intent.HUNT] = _profile.hunt_weight * _pressing
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
	var drop_way := _targeting.drop_way
	if mark.is_empty() or drop_way == Vector2.ZERO or _follow_route(steer, me, now_pos, pose):
		_hunt(steer, me, mark, now_pos, pose)
		return
	var my_pos: Vector3 = me["pos"]
	var mark_pos: Vector3 = mark["pos"]
	var from := Vector2(my_pos.x, my_pos.z)
	var at := Vector2(mark_pos.x, mark_pos.z)
	if absf((at - from).angle_to(drop_way)) <= deg_to_rad(_rules.shove_cone_deg):
		_walk_at(steer, me, mark, pose)
		return
	var bearing := (from - at).angle()
	var turn := clampf(angle_difference(bearing, (-drop_way).angle()), -TAU / 6.0, TAU / 6.0)
	var standoff := _rules.body_radius * 2.0 + _rules.shove_reach
	var point := at + Vector2.from_angle(bearing + turn) * standoff
	steer.move = _footing.clear_heading(
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
	var away := BotFooting.away(_footing.dangers(now_pos, me["surface"], pose, mark, Vector2.ZERO))
	steer.move = _footing.clear_heading(
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
		steer.move = _footing.clear_heading(
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
	# doorway is narrower than what the reaction lag would overshoot. Off the foot of a
	# stair there, it is off the stair, whatever the view still says.
	var my_surface: int = me["surface"]
	var under := _surfaces.under(now_pos, _rules.step_height)
	if under != Surfaces.NONE:
		my_surface = under
	var now_zone := _walk_graph.zone_at(now_pos, my_surface)
	var waypoint := _waypoint(now_pos, my_surface, now_zone, pose)
	if waypoint.is_empty():
		return false
	var wish := Vector2(waypoint[0].x - now_pos.x, waypoint[0].z - now_pos.z).normalized()
	# Down a stair the route does not take is into another zone, whose route is back up
	# it: on one — as it sees itself or reckons — with the way on back across it, off it
	# first by its end in the leg's zone.
	var leg := _legs[0]
	var stair: int = me["surface"] if _surfaces.is_ramp(me["surface"]) else my_surface
	var on_its_own := leg.ramp != WalkGraph.NONE and stair == _surfaces.ramp_surface(leg.ramp)
	if _surfaces.is_ramp(stair) and not on_its_own:
		var off := _walk_graph.way_off(stair, leg.from_zone)
		if off != null and wish.dot(off.along) < 0.0:
			var past := _walk_graph.toward(off, now_pos, stair)
			wish = Vector2(past.x - now_pos.x, past.z - now_pos.z).normalized()
	steer.move = _footing.clear_heading(now_pos, wish, PackedInt32Array(), PackedInt32Array())
	return true


## At [param mark], off by this think's heading error, looking at it, keeping to its
## own surface and zone and the mark's.
func _walk_at(steer: Steer, me: Dictionary, mark: Dictionary, pose: ShipPose) -> void:
	if mark.is_empty():
		return
	var my_pos: Vector3 = me["pos"]
	var mark_pos: Vector3 = mark["pos"]
	if not mark.has(BotView.REMEMBERED):
		var mark_vel: Vector3 = mark["vel"]
		var ahead := _lead * _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
		mark_pos += Vector3(mark_vel.x, 0.0, mark_vel.z) * ahead
	var goal := _approach(my_pos, mark_pos, pose)
	var wish := Vector2(goal.x - my_pos.x, goal.z - my_pos.z).normalized().rotated(_aim_offset)
	steer.move = _footing.clear_heading(
		my_pos,
		wish,
		PackedInt32Array([me["surface"], mark["surface"]]),
		PackedInt32Array([_zone_of(me), _zone_of(mark)])
	)
	steer.watch = Vector2(mark_pos.x - my_pos.x, mark_pos.z - my_pos.z).rotated(_aim_offset)


## Turns [param steer]'s walk away from water and open edges within edge_margin_m,
## slow enough that a reaction late, then stopping, stays inside the margin, and lets
## go of a brace there: rooted, the bot could not step back from it. A walk whose own
## way is clear keeps it and is only edged sideways, away from them — between the
## open sides of a stair's head, say; a walk headed for one keeps nothing of itself
## toward any of them, so two either side of a stair do not cancel out. A heedless
## walk keeps off the water alone.
func _keep_off_edges(
	steer: Steer, me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose
) -> void:
	if not _edges_near:
		return
	var my_surface: int = me["surface"]
	var stair_ahead := _stair_ahead(my_surface, now_pos, pose)
	var heed_drops := not steer.heedless
	var dangers := _footing.dangers(now_pos, my_surface, pose, mark, stair_ahead, heed_drops)
	if _edge_also != now_pos:
		for danger: Vector2 in _footing.dangers(
			_edge_also, my_surface, pose, mark, stair_ahead, heed_drops
		):
			if not dangers.has(danger):
				dangers.append(danger)
	var move := steer.move
	var headed := false
	if move != Vector2.ZERO:
		var heading := move.normalized()
		headed = _footing.danger_toward(
			now_pos, my_surface, pose, mark, stair_ahead, heading, heed_drops
		)
		if not headed and _edge_also != now_pos:
			headed = _footing.danger_toward(
				_edge_also, my_surface, pose, mark, stair_ahead, heading, heed_drops
			)
		var ahead := now_pos + Vector3(heading.x, 0.0, heading.y) * _footing.margin
		if not headed and _surfaces.railed(now_pos, ahead, my_surface):
			# Into a railing the walk slides along it: its probe vouches for nothing past it.
			for danger: Vector2 in dangers:
				headed = headed or move.dot(danger) > 0.0
	if dangers.is_empty() and not headed:
		return
	if steer.buttons == InputFrame.BRACE:
		steer.buttons = 0
		steer.hold_fire = false
	var away := BotFooting.away(dangers)
	if headed:
		dangers.append(move.normalized())
		for danger: Vector2 in dangers:
			move -= danger * maxf(move.dot(danger), 0.0)
		away = BotFooting.away(dangers)
	elif move != Vector2.ZERO:
		away -= move.normalized() * away.dot(move.normalized())
	move = (away + move).normalized()
	var cleared := _footing.clear_heading(now_pos, move, PackedInt32Array(), PackedInt32Array())
	if not _footing.danger_toward(
		now_pos, my_surface, pose, mark, stair_ahead, cleared, heed_drops
	):
		# Backing off the water must not walk it into a wall: round it, if not toward more.
		move = cleared
	var reaction_s := _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
	var stop_s := _rules.walk_speed / _rules.ground_friction
	var escape_speed := _footing.margin / (reaction_s + stop_s)
	steer.move = move.limit_length(escape_speed / _rules.walk_speed)


## A shove at whoever one would land on, its target first — weighed as things stood in
## its view, from where it looks now: a charge at a bracing one on the read, else a
## tap. Nothing while its view predates its last press, nor while it sees itself busy,
## nor, sparring, while it would send anyone at an edge (_spared), nor, when it minds
## its back, while another seat could land one on it.
func _shove(seen: Dictionary, me: Dictionary, mark: Dictionary, tick: int, pose: ShipPose) -> int:
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
	if _spar > 0.0 and _spared(seen, my_pos, pose):
		return 0
	if _profile.minds_its_back:
		var threat := _threat(seen, me)
		if not threat.is_empty() and threat["seat"] != victim["seat"]:
			# Another could be winding up behind it: a shove thrown now leaves it open.
			return 0
	_pressed_at = tick
	# Sparring, it never charges: a charge sends a body over a railing from metres off.
	if victim["bracing"] and _reads_charge and _spar == 0.0:
		_charge_held = 1
	return InputFrame.SHOVE


## Whether a shove from [param my_pos], where the bot looks, would land on a seat in
## [param seen] with the water, an open drop or a railing it could go over within the
## spar margin the way the shove sends it — straight away from the bot — from where it
## was seen, or from where its seen velocity carries it by the time the shove lands.
func _spared(seen: Dictionary, my_pos: Vector3, pose: ShipPose) -> bool:
	var lag := (_profile.reaction_ticks + _windup_ticks) * Ticks.SECONDS_PER_TICK
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == seat or not _lands(my_pos, entry):
			continue
		var seen_at: Vector3 = entry["pos"]
		var vel: Vector3 = entry["vel"]
		for at: Vector3 in [seen_at, seen_at + Vector3(vel.x, 0.0, vel.z) * lag]:
			var way := Vector2(at.x - my_pos.x, at.z - my_pos.z).normalized()
			if _footing.edge_toward(at, entry["surface"], way, _spar, pose, true) < INF:
				return true
	return false


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


## Whether another seat within a body's width of touching [param my_pos] has moved
## since the last think: a walk it holds back is a crowd, not a wall. One standing as
## still as the bot is jammed with it, and stepping aside is the way out for both.
func _jostled(seen: Dictionary, my_pos: Vector3) -> bool:
	for entry: Dictionary in seen["seats"]:
		if (
			entry["seat"] != seat
			and not entry["out"]
			and my_pos.distance_to(entry["pos"]) < _rules.body_radius * 4.0
			and (
				not _others_at.has(entry["seat"])
				or _flat(entry["pos"], _others_at[entry["seat"]]) >= _rules.body_radius * 0.1
			)
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
	return (
		_footing.edge_toward(now_pos, me["surface"], ShipPose.low_side(lurch), reach, pose, true)
		< INF
	)


## Whether the deck, tilted past the grip angle, would carry the bot toward water or
## an open edge within its edge margin.
func _slipping(me: Dictionary, mark: Dictionary, now_pos: Vector3, pose: ShipPose) -> bool:
	if not _edges_near or pose.slope_deg() <= _rules.grip_angle_deg:
		return false
	var away := BotFooting.away(_footing.dangers(now_pos, me["surface"], pose, mark, Vector2.ZERO))
	var gravity := pose.ship_gravity(_rules.gravity)
	return away != Vector2.ZERO and away.dot(Vector2(gravity.x, gravity.z)) < 0.0


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


## Whether a portal on [param legs] has an end lower than [param below] — how high
## above its water under [param pose] the bot's feet stand — and within
## refuge_margin_m of its own water: the way dips toward the water and will be under
## before the bot is through. A way along its own floor is that floor's to answer for.
func _going_under(legs: Array[WalkGraph.Portal], pose: ShipPose, below: float) -> bool:
	for leg: WalkGraph.Portal in legs:
		for end: Vector3 in [leg.entry, leg.exit]:
			var height := pose.above_water(end)
			if height < below and height < _profile.refuge_margin_m:
				return true
	return false


## Whether [param legs] is a way still to take under [param pose]: not empty, and no
## portal on it with an end under water or into a zone flooded or giving way.
func _open(legs: Array[WalkGraph.Portal], pose: ShipPose) -> bool:
	if legs.is_empty():
		return false
	for leg: WalkGraph.Portal in legs:
		if (
			_surfaces.wet(leg.entry, pose)
			or _surfaces.wet(leg.exit, pose)
			or _walk_graph.flooded(leg.to_zone, pose)
			or _walk_graph.doomed(leg.to_zone, pose)
		):
			return false
	return true


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


## The way along the ramp the bot stands on — seen there, and still there at
## [param my_pos] — when its route runs down it off a deck giving way, else zero:
## fleeing, the stair's far end is the way off, not an edge to back away from.
func _stair_ahead(my_surface: int, my_pos: Vector3, pose: ShipPose) -> Vector2:
	if (
		_legs.is_empty()
		or _legs[0].ramp == WalkGraph.NONE
		or my_surface != _surfaces.ramp_surface(_legs[0].ramp)
		or _surfaces.under(my_pos, _rules.step_height) != my_surface
		or not _walk_graph.doomed(_legs[0].from_zone, pose)
	):
		return Vector2.ZERO
	return _legs[0].along


## Turns [param steer]'s walk out of the path of a crate seen sliding at the bot, and
## lets go of a brace: rooted, it would be knocked down. Edges are kept after it.
func _out_of_cargo(steer: Steer, seen: Dictionary, now_pos: Vector3, pose: ShipPose) -> void:
	var dodge := _dodge.way_out(seen, now_pos, pose)
	if dodge == Vector2.ZERO:
		return
	if steer.buttons == InputFrame.BRACE:
		steer.buttons = 0
		steer.hold_fire = false
	steer.move = dodge


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
