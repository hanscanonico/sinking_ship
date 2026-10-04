class_name CargoDodge
extends RefCounted
## The way out of the path of a crate a bot sees sliding at it (SH10), for one bot's
## profile: square to the path of the nearest one coming at it — ahead of it, no
## farther than it slides in the bot's reaction and stopping time plus the edge margin,
## and passing within a body's radius and the edge margin of the bot — toward the side
## of the path the bot stands on. Crates are seen as old as the rest of the view and
## carried on by their speed as the bot carries itself and, on a deck the pose tilts
## past a crate's grip, by the pull downhill: one seen still as the deck swings is
## coming too. It knows nothing of edges: the brain keeps them after it. Nothing here
## remembers a tick, and nothing here rolls the bot's stream.

var _profile: BotProfile
var _rules: BrawlRules
## The layout's cargo: each crate's grip, against the deck's slope.
var _cargo: Array[ShipProp]


func _init(profile: BotProfile, rules: BrawlRules, cargo: Array[ShipProp]) -> void:
	_profile = profile
	_rules = rules
	_cargo = cargo


## The unit walk out of the path of the nearest crate in [param seen] coming at a bot
## reckoned at [param now_pos], under [param pose]; zero for none, and always for a
## tier that does not dodge cargo.
func way_out(seen: Dictionary, now_pos: Vector3, pose: ShipPose) -> Vector2:
	if not _profile.dodges_cargo:
		return Vector2.ZERO
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
	return dodge
