class_name BotReckoning
extends RefCounted
## Where a bot stands now (D10): its view shows it as it was reaction_ticks ago, so it
## reckons on from there — by the velocity it was seen at, or, on its feet and free to
## walk, by the walks it has sent since, which it knows: what it pressed and has yet to see
## itself do. Asked of the footing and the Surfaces of the floors it stands on (stand_on);
## nothing here rolls the bot's stream.

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
## since its view's [param seen_tick], unless a wall or a railing stands across them:
## it knows what it pressed, so a turn since is no surprise to it. Otherwise where
## [param reckoned] by its seen velocity.
func by_walks(me: Dictionary, seen_tick: int, reckoned: Vector3) -> Vector3:
	if me["state"] != PlayerState.Body.GROUNDED or me["stagger"] != 0 or me["hitstop"] != 0:
		return reckoned
	var seen_pos: Vector3 = me["pos"]
	var walked := Vector2.ZERO
	for index in _sent_ticks.size():
		if _sent_ticks[index] >= seen_tick:
			walked += _sent_moves[index]
	var height := _rules.height_at(_surfaces, seen_pos)
	var pace := _rules.walk_speed if height >= _rules.body_height else _rules.crawl_speed
	walked *= pace * Ticks.SECONDS_PER_TICK
	var walked_to := seen_pos + Vector3(walked.x, 0.0, walked.y)
	if (
		_surfaces.blocked(seen_pos, walked_to, height, _rules.step_height)
		or _surfaces.railed(seen_pos, walked_to, me["surface"])
	):
		return reckoned
	if me["surface"] != Surfaces.NONE:
		walked_to.y = _footing.feet_at(seen_pos, walked_to)
	return walked_to
