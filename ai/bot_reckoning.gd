class_name BotReckoning
extends RefCounted
## Where a bot stands now (D10): its view shows it as it was reaction_ticks ago, so it
## reckons on from there — by the velocity it was seen at, or, on its feet and free to
## walk, by the walks it has sent since, which it knows: what it pressed and has yet to see
## itself do, stepped at full pace or as its feet take them. Asked of the footing and the
## Surfaces of the floors it stands on (stand_on); nothing here rolls the bot's stream.

var _rules: BrawlRules
var _reaction_ticks: int
var _footing: BotFooting
var _surfaces: Surfaces
## The walks it has sent and the ticks it sent them on, for as long as its view lags:
## what it pressed and has yet to see itself do. A tick of -1 is none.
var _sent_moves := PackedVector2Array()
var _sent_ticks := PackedInt32Array()


func _init(profile: BotProfile, rules: BrawlRules) -> void:
	_rules = rules
	_reaction_ticks = profile.reaction_ticks
	_sent_moves.resize(maxi(profile.reaction_ticks, 1))
	_sent_ticks.resize(_sent_moves.size())
	_sent_ticks.fill(-1)


## It stands on floors [param footing] reads, and their [param surfaces], from now.
func stand_on(footing: BotFooting, surfaces: Surfaces) -> void:
	_footing = footing
	_surfaces = surfaces


## Keeps the walk [param frame] sends, on its tick: one it has yet to see itself make.
func sent(frame: InputFrame) -> void:
	_sent_moves[frame.tick % _sent_moves.size()] = frame.move_vector()
	_sent_ticks[frame.tick % _sent_ticks.size()] = frame.tick


## Where the bot stands now, from where its view shows it, [param me]: carried on by the
## velocity it was seen at. Its feet have risen or sunk with the walk, up a stair or onto
## the next deck.
func reckon(me: Dictionary) -> Vector3:
	var seen_pos: Vector3 = me["pos"]
	var my_vel: Vector3 = me["vel"]
	var reaction_s := _reaction_ticks * Ticks.SECONDS_PER_TICK
	var now_pos := seen_pos + Vector3(my_vel.x, 0.0, my_vel.z) * reaction_s
	if me["surface"] != Surfaces.NONE:
		now_pos.y = _footing.feet_at(seen_pos, now_pos)
	return now_pos


## Where the bot stands now — on its feet and free to walk — by the walks it has sent
## since its view's [param seen_tick], each taken at full pace on the tick it was sent: it
## knows what it pressed, so a turn since is no surprise to it. Its body is held by every
## railing it meets on the way, as by_steps holds it (#589); position only. Otherwise, or
## where a wall stands across the walk, where [param reckoned] by its seen velocity.
func by_walks(me: Dictionary, seen_tick: int, reckoned: Vector3) -> Vector3:
	return _stepped(me, seen_tick, reckoned, false)


## As by_walks, but stepped as its feet take the walks, tick by tick: from the velocity it
## was seen at, toward each walk by ground_accel, or slowing by ground_friction with none
## pressed — a turn or a stop since is no surprise to it, nor the ticks its feet take to
## make it — its body held by every railing it meets on the way as the sim holds one on its
## feet (Surfaces.rail_contacts), walking there from where the tick before left it — on the
## side it came from, whatever floor it stepped from (#592): pushed back out, losing the
## speed into it, it slides along the railing, round its end only once its body is past it
## (#557). Otherwise, or where a wall stands across the walk, where [param reckoned] by its
## seen velocity.
func by_steps(me: Dictionary, seen_tick: int, reckoned: Vector3) -> Vector3:
	return _stepped(me, seen_tick, reckoned, true)


## Where the walks sent since [param seen_tick] take [param me], tick by tick, its body held
## by every railing it meets: by its feet's velocity, eased toward each walk when
## [param eased] (by_steps), else at each walk's full pace (by_walks).
func _stepped(me: Dictionary, seen_tick: int, reckoned: Vector3, eased: bool) -> Vector3:
	if not _walking(me):
		return reckoned
	var seen_pos: Vector3 = me["pos"]
	var seen_vel: Vector3 = me["vel"]
	var height := _rules.height_at(_surfaces, seen_pos)
	var pace := _pace(height)
	var dt := Ticks.SECONDS_PER_TICK
	var vel := Vector2(seen_vel.x, seen_vel.z)
	var at := seen_pos
	var surface: int = me["surface"]
	for tick in range(seen_tick, seen_tick + _sent_ticks.size()):
		var index := tick % _sent_ticks.size()
		if _sent_ticks[index] != tick:
			break
		var wish := _sent_moves[index] * pace
		if eased:
			var rate := _rules.ground_accel if wish != Vector2.ZERO else _rules.ground_friction
			vel = vel.move_toward(wish, rate * dt)
		else:
			vel = wish
		var came := Vector2(at.x, at.z)
		at += Vector3(vel.x, 0.0, vel.y) * dt
		var radius := _rules.body_radius
		var railing := _rules.railing_height
		for held: Surfaces.Contact in _surfaces.rail_contacts(
			at, radius, surface, _rules.step_height, railing, came
		):
			at += Vector3(held.normal.x, 0.0, held.normal.y) * held.depth
			vel += held.normal * maxf(-vel.dot(held.normal), 0.0)
		var under := _surfaces.under(at, _rules.step_height)
		if under != Surfaces.NONE:
			surface = under
			at.y = _surfaces.height_at(under, at)
	if _surfaces.blocked(seen_pos, at, height, _rules.step_height):
		return reckoned
	return at


## Whether [param me] stands on its feet, free to walk: neither in the air, the sea nor a
## stagger or a hitstop.
func _walking(me: Dictionary) -> bool:
	return me["state"] == PlayerState.Body.GROUNDED and me["stagger"] == 0 and me["hitstop"] == 0


## How fast a body walks where its headroom is [param height]: crawling under a low one.
func _pace(height: float) -> float:
	return _rules.walk_speed if height >= _rules.body_height else _rules.crawl_speed
