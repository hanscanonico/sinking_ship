class_name ContactWatch
extends RefCounted
## Whether anything but a seat's own frames can have moved it over a span of ticks
## (R7): no other body and no crate comes within touching distance of where the seat
## is predicted to be. Touching is a shove's reach between the two edges; how far the
## other can have come is the fastest the rules move anything across the deck
## (BrawlRules.fastest_speed: walking, vaulting, a charged knockback, a crate's) or its own
## speed when more, with the most the deck pulls anything downhill over the span on top:
## gravity across the ship plane, as the schedule tilts it (D7) — the steepest of her
## pieces' once she breaks — and the fastest her water can carry anything near the seat
## over the span on top of that (_carried): the server's water moves a body (Currents,
## Falls) that a prediction from its last snapshot cannot. Distances are across the ship
## plane, whatever the heights: a body on a deck overhead counts as near, and one on
## another piece of her is seen from the seat's (Pieces.seen_from).

var _config: MatchConfig
var _rules: BrawlRules
var _schedule: SinkSchedule
var _crate_radii := PackedFloat64Array()
var _fastest: float
## The deck's pull downhill by tick, for the ticks asked about in the last second.
var _pulls := {}
## Per piece of her, made the first time asked: its currents and its falls, null for none.
var _currents: Array[Currents] = []
var _falls: Array[Falls] = []


## A watch over [param config]'s match, tilted as [param schedule] says.
func _init(config: MatchConfig, schedule: SinkSchedule) -> void:
	_config = config
	_rules = config.rules
	_schedule = schedule
	for prop: ShipProp in config.ship.props:
		_crate_radii.append(prop.radius)
	_fastest = _rules.fastest_speed()


## Whether, from [param snapshot]'s tick on, nothing in it but [param seat] can come
## within touching distance of [param path] — where the seat is, one point a tick from
## that tick — nor, for [param lookahead] ticks more, of the path's end.
func clear(snapshot: Dictionary, seat: int, path: PackedVector3Array, lookahead: int) -> bool:
	var ticks := path.size() - 1 + lookahead
	var gained := _pull(snapshot["tick"], ticks) * ticks * Ticks.SECONDS_PER_TICK
	var body := _rules.body_radius + _rules.shove_reach
	var piece: int = snapshot["seats"][seat]["piece"]
	var widest := _rules.body_radius
	for radius in _crate_radii:
		widest = maxf(widest, radius)
	var within := body + widest + (_fastest + gained) * ticks * Ticks.SECONDS_PER_TICK
	gained += _carried(snapshot["tick"], ticks, piece, path, within)
	var pose := _schedule.pose_at(snapshot["tick"])
	var seen := Pieces.seen_from(snapshot, piece, pose)
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] != seat and not entry["out"]:
			if not _apart(entry, body + _rules.body_radius, path, lookahead, gained):
				return false
	for entry: Dictionary in snapshot["props"]:
		if entry["state"] != PropState.Body.LOST:
			var touch: float = body + _crate_radii[entry["prop"]]
			if not _apart(entry, touch, path, lookahead, gained):
				return false
	return true


## The most the deck of any piece of her pulls anything downhill, across its ship plane,
## over the [param ticks] ticks from [param first] on.
func _pull(first: int, ticks: int) -> float:
	for tick: int in _pulls.keys():
		if tick < first - Ticks.RATE:
			_pulls.erase(tick)
	var most := 0.0
	for tick in range(first, first + ticks + 1):
		if not _pulls.has(tick):
			var pose := _schedule.pose_at(tick)
			var pull := 0.0
			for piece in _schedule.piece_count():
				var down := pose.of_piece(piece).ship_gravity(_rules.gravity)
				pull = maxf(pull, Vector2(down.x, down.z).length())
			_pulls[tick] = pull
		most = maxf(most, _pulls[tick])
	return most


## The fastest the water of her can carry a body anywhere it may come from to touch
## [param path] — on piece [param piece], seen from it — over the [param ticks] ticks from
## [param first] on, a body reaching [param within] of it unhelped: per tick and piece the
## fastest current near it (Currents.fastest_in), a pour's throw at current_wade_share of
## its landing speed and blast_speed for every blast under way there, all of them added,
## as a swimmer feels them (Movement). A body the water carries comes from farther, so the area
## grows by what it carries until that finds no faster water.
func _carried(first: int, ticks: int, piece: int, path: PackedVector3Array, within: float) -> float:
	var span := ticks * Ticks.SECONDS_PER_TICK
	var lasts := maxi(Ticks.from_seconds(_rules.blast_time), 1)
	var poses: Array[ShipPose] = []
	var areas: Array[Rect2] = []
	var on := PackedInt32Array()
	var ticked := PackedInt32Array()
	for tick in range(first, first + ticks + 1):
		var pose := _schedule.pose_at(tick)
		var seat_to := pose.of_piece(piece).transform
		for other in _schedule.piece_count() if not pose.pieces.is_empty() else 1:
			if _currents.size() <= other:
				_make(other)
			if _currents[other] == null:
				continue
			var mine := pose.of_piece(other)
			var into := mine.transform.affine_inverse() * seat_to
			var area := Rect2()
			for index in path.size():
				var point := into * path[index]
				var at := Rect2(point.x, point.z, 0.0, 0.0)
				area = at if index == 0 else area.merge(at)
			poses.append(mine)
			areas.append(area)
			on.append(other)
			ticked.append(tick)
	var carried := 0.0
	var grew := true
	while grew:
		var most := 0.0
		for index in poses.size():
			var area := areas[index].grow(within + carried * span)
			var other := on[index]
			var water := _currents[other].fastest_in(poses[index], area)
			var speed := water.x + water.y * _rules.current_wade_share
			var falls := _falls[other]
			for blast in falls.blasts():
				var since := ticked[index] - falls.blast_at(blast).x
				if since < 0 or since >= lasts:
					continue
				var way := falls.way_out_of(blast)
				if way == null:
					continue
				var low := way.centre - way.size * 0.5
				var mouth := Rect2(low.x, low.z, way.size.x, way.size.z).grow(_rules.blast_reach)
				if mouth.intersects(area, true):
					speed += _rules.blast_speed
			most = maxf(most, speed)
		grew = most > carried
		carried = maxf(carried, most)
	return carried


## Makes piece [param piece]'s currents and falls, and those of every piece before it.
func _make(piece: int) -> void:
	for other in range(_currents.size(), piece + 1):
		var currents := Currents.of_piece(_config, _schedule, other)
		_currents.append(currents)
		_falls.append(Falls.of_piece(_config, _schedule, other, currents))


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
