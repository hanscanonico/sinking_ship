class_name BotBrain
extends RefCounted
## A bot is a player (D10): it reads a BotView and answers an InputFrame, nothing
## more. v0 makes for the surface its nearest seat stands on, or — once the water is
## within its edge margin or that seat's platform is flooded — for the highest
## platform it can reach, where it holds unless that seat comes up too. It follows
## the walk graph there, turning round blockers; once there it walks at that seat —
## past the grip angle, round to its uphill side first, and not onto any other
## surface — and shoves when it is in reach and cone. It keeps its edge margin from
## the waterline and from open edges: a drop, or a railing gap, unless the target
## stands between the bot and it.

## Directions probed around the bot for water and open edges.
const PROBES := 8

var seat: int

var _profile: BotProfile
var _rules: BrawlRules
var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rng: RandomNumberGenerator
var _target := -1
## The surface the bot is making for, or Surfaces.NONE.
var _goal := Surfaces.NONE
## Whether that is the high ground, rather than its target's surface.
var _seeking_high := false
var _aim_offset := 0.0
var _think_in := 0
var _last_buttons := 0


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


func decide(view: BotView, tick: int) -> InputFrame:
	if view.is_empty():
		return InputFrame.new(seat, tick)
	var seen := view.snapshot()
	var me := _entry(seen, seat)
	if me.is_empty() or me["out"]:
		return InputFrame.new(seat, tick)
	var my_pos: Vector3 = me["pos"]
	var my_surface: int = me["surface"]
	var pose := view.pose()
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
	var waypoint := _walk_graph.steer(my_pos, my_surface, _goal, pose)
	if not waypoint.is_empty():
		wish = Vector2(waypoint[0].x - my_pos.x, waypoint[0].z - my_pos.z).normalized()
		wish = _clear_heading(my_pos, wish, PackedInt32Array())
	elif not target.is_empty() and not (_seeking_high and target["surface"] != my_surface):
		var goal := _approach(my_pos, target["pos"], pose)
		wish = Vector2(goal.x - my_pos.x, goal.z - my_pos.z)
		wish = wish.normalized().rotated(_aim_offset)
		wish = _clear_heading(my_pos, wish, PackedInt32Array([my_surface, target["surface"]]))
	var away := _away_from_danger(now_pos, my_surface, pose, target)
	var move := wish
	if away != Vector2.ZERO:
		var toward_danger := minf(wish.dot(away), 0.0)
		move = (away + wish - away * toward_danger).normalized()
		# Slow enough that a reaction late, then stopping, stays inside the margin.
		var stop_s := _rules.walk_speed / _rules.ground_friction
		var escape_speed := _profile.edge_margin_m / (reaction_s + stop_s)
		move = move.limit_length(escape_speed / _rules.walk_speed)
	var buttons := 0
	if _wants_shove(me, target) and not _last_buttons & InputFrame.SHOVE:
		buttons = InputFrame.SHOVE
	_last_buttons = buttons
	return InputFrame.new(seat, tick, InputFrame.quantize(move), buttons)


## Picks the nearest seat still in (ties to the lower seat), this choice's heading
## error from the bot's own stream, and the surface to make for: the highest
## platform it can reach once the water is within edge_margin of [param now_pos] or
## the target's platform is flooded, else the target's.
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
	var target_surface: int = _entry(seen, _target)["surface"] if _target != -1 else Surfaces.NONE
	_seeking_high = (
		_water_near(now_pos, pose)
		or target_surface != Surfaces.NONE and _surfaces.flooded(target_surface, pose)
	)
	if _seeking_high:
		_goal = _walk_graph.highest_reachable(my_pos, me["surface"], pose)
	else:
		_goal = target_surface


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
## [param keep_to] lists surfaces, steps onto any surface but those; unturned when
## every way does.
func _clear_heading(my_pos: Vector3, wish: Vector2, keep_to: PackedInt32Array) -> Vector2:
	if wish == Vector2.ZERO:
		return wish
	for turn: int in [0, 1, -1, 2, -2]:
		var heading := wish.rotated(TAU * turn / PROBES)
		var ahead := my_pos + Vector3(heading.x, 0.0, heading.y) * _profile.edge_margin_m
		if _surfaces.blocked(my_pos, ahead, _rules.body_height, _rules.step_height):
			continue
		var onto := _surfaces.under(ahead, _rules.step_height)
		if not keep_to.is_empty() and onto != Surfaces.NONE and not onto in keep_to:
			continue
		return heading
	return wish


## A unit vector away from every probe at edge_margin that is wet or past an open
## edge — walking there would drop off it — or zero when none is (or they cancel
## out). A probe past a railing of [param my_surface] is safe; one through a gap is
## not, unless [param target] is lined up for a shove through it.
func _away_from_danger(
	my_pos: Vector3, my_surface: int, pose: ShipPose, target: Dictionary
) -> Vector2:
	var push := Vector2.ZERO
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * _profile.edge_margin_m
		if _surfaces.wet(probe, pose):
			push -= direction
		elif (
			_surfaces.drops(my_pos, probe, _rules.step_height)
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


static func _entry(seen: Dictionary, wanted: int) -> Dictionary:
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == wanted:
			return entry
	return {}
