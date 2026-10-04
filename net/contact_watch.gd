class_name ContactWatch
extends RefCounted
## Whether anything but a seat's own frames can have moved it over a span of ticks
## (R7): no other body and no crate comes within touching distance of where the seat
## is predicted to be. Touching is a shove's reach between the two edges; how far the
## other can have come is the fastest the rules move anything across the deck —
## walking, vaulting, a charged knockback, a crate's — or its own speed when more,
## with the most the deck pulls anything downhill over the span on top: gravity across
## the ship plane, as the schedule tilts it (D7). Distances are across the ship plane,
## whatever the heights: a body on a deck overhead counts as near.

var _rules: BrawlRules
var _schedule: SinkSchedule
var _crate_radii := PackedFloat64Array()
var _fastest: float
## The deck's pull downhill by tick, for the ticks asked about in the last second.
var _pulls := {}


## A watch over [param config]'s match, tilted as [param schedule] says.
func _init(config: MatchConfig, schedule: SinkSchedule) -> void:
	_rules = config.rules
	_schedule = schedule
	for prop: ShipProp in config.ship.props:
		_crate_radii.append(prop.radius)
	_fastest = maxf(
		maxf(_rules.walk_speed, _rules.vault_speed),
		maxf(_rules.charged_knockback, maxf(_rules.knockback, _rules.crate_knockback))
	)


## Whether, from [param snapshot]'s tick on, nothing in it but [param seat] can come
## within touching distance of [param path] — where the seat is, one point a tick from
## that tick — nor, for [param lookahead] ticks more, of the path's end.
func clear(snapshot: Dictionary, seat: int, path: PackedVector3Array, lookahead: int) -> bool:
	var ticks := path.size() - 1 + lookahead
	var gained := _pull(snapshot["tick"], ticks) * ticks * Ticks.SECONDS_PER_TICK
	var body := _rules.body_radius + _rules.shove_reach
	for entry: Dictionary in snapshot["seats"]:
		if entry["seat"] != seat and not entry["out"]:
			if not _apart(entry, body + _rules.body_radius, path, lookahead, gained):
				return false
	for entry: Dictionary in snapshot["props"]:
		if entry["state"] != PropState.Body.LOST:
			var touch: float = body + _crate_radii[entry["prop"]]
			if not _apart(entry, touch, path, lookahead, gained):
				return false
	return true


## The most the deck pulls anything downhill, across the ship plane, over the
## [param ticks] ticks from [param first] on.
func _pull(first: int, ticks: int) -> float:
	for tick: int in _pulls.keys():
		if tick < first - Ticks.RATE:
			_pulls.erase(tick)
	var most := 0.0
	for tick in range(first, first + ticks + 1):
		if not _pulls.has(tick):
			var down := _schedule.pose_at(tick).ship_gravity(_rules.gravity)
			_pulls[tick] = Vector2(down.x, down.z).length()
		most = maxf(most, _pulls[tick])
	return most


## Whether [param entry] — a seat's or a crate's — stays more than [param touch] from
## every point of [param path], however fast it may go, with [param gained] more
## speed downhill at most.
func _apart(
	entry: Dictionary, touch: float, path: PackedVector3Array, lookahead: int, gained: float
) -> bool:
	var pos: Vector3 = entry["pos"]
	var vel: Vector3 = entry["vel"]
	var speed := maxf(_fastest, Vector2(vel.x, vel.z).length()) + gained
	for index in path.size():
		var travel := speed * (index + lookahead) * Ticks.SECONDS_PER_TICK
		var apart := Vector2(pos.x - path[index].x, pos.z - path[index].z).length()
		if apart <= touch + travel:
			return false
	return true
