class_name BotBrain
extends RefCounted
## A bot is a player (D10): it reads a BotView and answers an InputFrame, nothing
## more. v0 makes for the zone its nearest seat stands in, or — once the water is
## within its edge margin, the floor it stands on is within its climb margin of the
## sea, or that seat's zone is flooded — for the highest zone it can reach, where it
## holds unless that seat comes up too. It follows the walk graph there, through
## doorways and up ramps, turning round blockers; once there it walks at that seat —
## past the grip angle, round to its uphill side first, and not out of its own zone
## or that seat's — and shoves when it is in reach and cone. It looks at that seat
## while it walks at it and the way it walks otherwise, turning no faster than its
## profile's turn rate. It keeps its edge margin from the waterline and from open
## edges: a drop, or a railing gap, unless the target stands between the bot and it.
## On its reads, rolled each think, it charges a bracing target instead of tapping,
## and — unless it is climbing — braces, standing still and looking at it, against a
## seat that could be winding up a shove that would land on it. It hears the sinking's
## telegraphs as a player does, in the current pose: told of a lurch, it walks away
## from the side the lurch will put down and, once the deck swings, braces if it can;
## it leaves a deck that is giving way, and never routes onto one.

## Directions probed around the bot for water and open edges.
const PROBES := 8

var seat: int

var _profile: BotProfile
var _rules: BrawlRules
var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rng: RandomNumberGenerator
var _target := -1
## The zone the bot is making for, or WalkGraph.NONE.
var _goal := WalkGraph.NONE
## The portals to it, as the last think found them; steered along until the next.
var _legs: Array[WalkGraph.Portal] = []
## Whether that is the high ground, rather than its target's zone.
var _seeking_high := false
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


## [param rng] is this seat's own stream, SeedStreams' (match seed, seat).
func _init(
	bot_seat: int,
	profile: BotProfile,
	rules: BrawlRules,
	surfaces: Surfaces,
	walk_graph: WalkGraph,
	rng: RandomNumberGenerator
) -> void:
	seat = bot_seat
	_profile = profile
	_rules = rules
	_surfaces = surfaces
	_walk_graph = walk_graph
	_rng = rng
	_charge_full_ticks = Ticks.from_seconds(rules.charge_full)


func decide(view: BotView, tick: int) -> InputFrame:
	if view.is_empty():
		return InputFrame.new(seat, tick)
	var seen := view.snapshot()
	var me := _entry(seen, seat)
	if me.is_empty() or me["out"]:
		return InputFrame.new(seat, tick)
	var my_pos: Vector3 = me["pos"]
	var my_surface: int = me["surface"]
	if _look == -1:
		_look = InputFrame.quantize_yaw(me["facing"])
	var pose := view.pose()
	_surfaces.honour(pose)
	# The pose is current but the snapshot is reaction_ticks old: probe from where
	# its own seen velocity has carried it since.
	var reaction_s := _profile.reaction_ticks * Ticks.SECONDS_PER_TICK
	var my_vel: Vector3 = me["vel"]
	var now_pos := my_pos + Vector3(my_vel.x, 0.0, my_vel.z) * reaction_s
	if _think_in <= 0:
		_think(seen, me, now_pos, pose)
		_think_in = _profile.think_period
	_think_in -= 1
	var target := _entry(seen, _target)
	if not target.is_empty() and target["out"]:
		target = {}
	var wish := Vector2.ZERO
	var watch := Vector2.ZERO
	var my_zone := _zone_of(me)
	# The route is followed from where the bot's seen velocity has carried it, as it
	# probes: a doorway is narrower than what the reaction lag would overshoot.
	var now_zone := _walk_graph.zone_at(now_pos, my_surface)
	var waypoint := _waypoint(now_pos, my_surface, now_zone, pose)
	if not waypoint.is_empty():
		wish = Vector2(waypoint[0].x - now_pos.x, waypoint[0].z - now_pos.z).normalized()
		wish = _clear_heading(now_pos, wish, PackedInt32Array(), PackedInt32Array())
	elif not target.is_empty() and not (_seeking_high and _zone_of(target) != my_zone):
		var goal := _approach(my_pos, target["pos"], pose)
		wish = Vector2(goal.x - my_pos.x, goal.z - my_pos.z)
		wish = wish.normalized().rotated(_aim_offset)
		wish = _clear_heading(
			my_pos,
			wish,
			PackedInt32Array([my_surface, target["surface"]]),
			PackedInt32Array([my_zone, _zone_of(target)])
		)
		var target_pos: Vector3 = target["pos"]
		watch = Vector2(target_pos.x - my_pos.x, target_pos.z - my_pos.z).rotated(_aim_offset)
	var lurch := pose.lurch_warning if pose.lurch_warning != 0.0 else pose.lurch
	var riding := lurch != 0.0 and not _climbing
	if riding:
		wish = _clear_heading(
			now_pos, -ShipPose.low_side(lurch), PackedInt32Array(), PackedInt32Array()
		)
		watch = Vector2.ZERO
	var away := _away_from_danger(now_pos, my_surface, pose, target, _stair_ahead(my_surface, pose))
	var move := wish
	if away != Vector2.ZERO:
		var toward_danger := minf(wish.dot(away), 0.0)
		move = (away + wish - away * toward_danger).normalized()
		# Slow enough that a reaction late, then stopping, stays inside the margin.
		var stop_s := _rules.walk_speed / _rules.ground_friction
		var escape_speed := _profile.edge_margin_m / (reaction_s + stop_s)
		move = move.limit_length(escape_speed / _rules.walk_speed)
	var threat := _threat(seen, me)
	var buttons := _buttons(me, target, threat)
	if buttons == InputFrame.BRACE:
		# Rooted: stand still and look at the threat, whose shove the front arc takes.
		var threat_pos: Vector3 = threat["pos"]
		watch = Vector2(threat_pos.x - my_pos.x, threat_pos.z - my_pos.z)
		move = Vector2.ZERO
	if riding and pose.lurch != 0.0 and _charge_held == 0 and not me["exhausted"]:
		# The deck is swinging: rooted, a brace holds where it would slide.
		buttons = InputFrame.BRACE
		move = Vector2.ZERO
	_last_buttons = buttons
	_turn_toward(watch if watch != Vector2.ZERO else move)
	return InputFrame.new(seat, tick, InputFrame.quantize(move), buttons, _look)


## A charge under way is held until it is full, then let go; otherwise a shove
## when one would land — a charge if the target braces and the read says so, else
## a tap — and failing that a brace against [param threat], if the read says so and
## the bot is not climbing out of a flooding floor: rooted, it would drown there.
func _buttons(me: Dictionary, target: Dictionary, threat: Dictionary) -> int:
	if _charge_held > 0:
		if _charge_held >= _charge_full_ticks:
			_charge_held = 0
			return 0
		_charge_held += 1
		return InputFrame.SHOVE
	if _wants_shove(me, target):
		if target["bracing"] and _reads_charge:
			_charge_held = 1
			return InputFrame.SHOVE
		return 0 if _last_buttons & InputFrame.SHOVE else InputFrame.SHOVE
	if _reads_brace and not _climbing and not threat.is_empty() and not me["exhausted"]:
		return InputFrame.BRACE
	return 0


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
		if entry["seat"] == seat or entry["out"]:
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


## Picks the nearest seat still in (ties to the lower seat), this choice's heading
## error from the bot's own stream, and the zone to make for: the highest zone it can
## reach once the water is within edge_margin of [param now_pos], while it climbs —
## from when the lowest corner of its own floor comes within climb_margin of the sea
## until it arrives — while its own zone is giving way, or when the target's zone is
## flooded or giving way; else the target's.
func _think(seen: Dictionary, me: Dictionary, now_pos: Vector3, pose: ShipPose) -> void:
	var my_pos: Vector3 = me["pos"]
	_target = -1
	var best := INF
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == seat or entry["out"]:
			continue
		var distance := my_pos.distance_squared_to(entry["pos"])
		if distance < best:
			best = distance
			_target = entry["seat"]
	var error := _profile.aim_error_deg
	_aim_offset = deg_to_rad(_rng.randf_range(-error, error))
	_reads_brace = _rng.randf() < _profile.brace_read
	_reads_charge = _rng.randf() < _profile.charge_read
	var target_zone := _zone_of(_entry(seen, _target)) if _target != -1 else WalkGraph.NONE
	var my_zone := _zone_of(me)
	if _climbing and my_zone == _goal and not _surfaces.is_ramp(me["surface"]):
		_climbing = false
	_climbing = (
		_climbing
		or (
			my_zone != WalkGraph.NONE
			and _walk_graph.lowest_world_height(my_zone, pose) < _profile.climb_margin_m
		)
	)
	_seeking_high = (
		_water_near(now_pos, pose)
		or _climbing
		or my_zone != WalkGraph.NONE and _walk_graph.doomed(my_zone, pose)
		or (
			target_zone != WalkGraph.NONE
			and (_walk_graph.flooded(target_zone, pose) or _walk_graph.doomed(target_zone, pose))
		)
	)
	if _seeking_high:
		_goal = _walk_graph.highest_reachable(my_pos, me["surface"], pose)
	else:
		_goal = target_zone
	_legs = _walk_graph.route(my_pos, me["surface"], _goal, pose)


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
## out). A probe past a railing of [param my_surface] is safe; one through a gap is
## not, unless [param target] is lined up for a shove through it. On a stair whose
## way on is [param stair_ahead], an open edge ahead of it is the stair's far end and
## its sides, and is no danger.
func _away_from_danger(
	my_pos: Vector3, my_surface: int, pose: ShipPose, target: Dictionary, stair_ahead: Vector2
) -> Vector2:
	var push := Vector2.ZERO
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * _profile.edge_margin_m
		if _surfaces.wet(probe, pose):
			push -= direction
		elif (
			direction.dot(stair_ahead) <= 0.0
			and _surfaces.drops(my_pos, probe, _rules.step_height)
			and not _surfaces.railed(my_pos, probe, my_surface)
			and not _lined_up(my_pos, probe, target)
		):
			push -= direction
	return push.normalized()


## Whether [param target] stands between the bot and [param probe] — nearer the
## probe than the bot, inside the shove cone toward it.
func _lined_up(my_pos: Vector3, probe: Vector3, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var target_pos: Vector3 = target["pos"]
	var toward_probe := Vector2(probe.x - my_pos.x, probe.z - my_pos.z)
	var toward_target := Vector2(target_pos.x - my_pos.x, target_pos.z - my_pos.z)
	return (
		target_pos.distance_to(probe) < _profile.edge_margin_m
		and absf(toward_probe.angle_to(toward_target)) <= deg_to_rad(_rules.shove_cone_deg)
	)


func _wants_shove(me: Dictionary, target: Dictionary) -> bool:
	if target.is_empty() or target["out"]:
		return false
	if me["action"] != PlayerState.Action.IDLE or me["stagger"] > 0:
		return false
	var candidate := ShoveResolver.Candidate.new(
		target["seat"], target["pos"], _rules.body_radius, _rules.body_height
	)
	return ShoveResolver.lands(
		me["pos"],
		_rules.body_radius,
		Vector2.from_angle(me["facing"]),
		candidate,
		_rules.shove_reach,
		_rules.shove_cone_deg,
		_surfaces,
		_rules.step_height
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


static func _entry(seen: Dictionary, wanted: int) -> Dictionary:
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == wanted:
			return entry
	return {}
