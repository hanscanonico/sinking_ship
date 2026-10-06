class_name BotSwim
extends RefCounted
## Where a bot in the sea swims (SH5): for the nearest way out it can reach — round
## through open water when the hull or a wall stands across the straight swim — or,
## where none is in reach, for the nearest air pocket it has seen that is (BotPockets,
## SH29); and in a flooded room with no way out in sight, out by the doorways and stairs
## the walk graph has from it to dry ground: the sea takes the stair's foot first, never
## its head. With its head in a pocket it climbs onto a dry face there if there is one,
## else waits, the cold coming slower (Q22), until its meter is down to what the swim on
## costs — and its own lag — then goes (§5b.3); a swim on longer than its meter it does
## not start. Every answer is asked of Surfaces, the
## pose and the walk graph under the pose handed in; nothing here rolls the bot's stream.

## Directions probed around the swimmer for open water.
const PROBES := 8
## How far apart the open-water points a swimmer tries for a way round are, in metres.
const SWIM_LEG := 1.5

## The way out the last look found, and the point it swims through on the way — the
## open water round a wall, the next portal out of a flooded room, or a pocket; null and
## INF for none.
var way_out: Surfaces.Climb
var via := Vector3.INF
## Whether the last look found it in a pocket, waiting there.
var waiting := false

var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rules: BrawlRules
var _eye_height: float
var _pockets: BotPockets
## The cold meter a wait in a pocket keeps in hand past the swim's own cost: what drains
## there between its looks and while its view of itself lags.
var _lag: float
## The walk graph's portals to dry ground the last look found, for the swim's length;
## and the cell of the pocket it has set out from, or -1: once it goes, it goes.
var _legs: Array[WalkGraph.Portal] = []
var _leaving := -1


func _init(walk_graph: WalkGraph, rules: BrawlRules, profile: BotProfile) -> void:
	_walk_graph = walk_graph
	_surfaces = walk_graph.surfaces()
	_rules = rules
	_eye_height = profile.eye_height_m
	_pockets = BotPockets.new(_surfaces, rules, profile.eye_height_m)
	_lag = (profile.reaction_ticks + Ticks.RATE) * Ticks.SECONDS_PER_TICK * rules.pocket_cold_rate


## Where a swimmer swims next, as the last look found it: through [member via] first;
## INF when it found nowhere to make for, or waits.
func goal() -> Vector3:
	if waiting:
		return Vector3.INF
	if via != Vector3.INF:
		return via
	return way_out.stand if way_out != null else Vector3.INF


## Looks for the way out of the sea of a swimmer at [param now_pos] with [param cold]
## seconds of its cold meter left: the nearest way out within the swim that leaves,
## straight across the water; failing that, the nearest by way of a point of open water
## a leg or a few off that nothing hides from it; failing that, the nearest pocket it
## knows within that swim; failing that, the nearest way out within a whole cold
## meter's swim, so it keeps swimming while there is one; and in a flooded room with
## none of those, the next portal of the walk graph's way to dry ground. With its head
## in a pocket it takes a dry face there at once, and anything else only once its meter
## is down to what that swim costs.
func find(cold: float, now_pos: Vector3, pose: ShipPose) -> void:
	var reach := cold * _rules.swim_speed
	var head := now_pos + Vector3.UP * _rules.head_height()
	waiting = false
	_pockets.look(now_pos, pose)
	_find_out(reach, now_pos, pose)
	if not pose.in_pocket(head) or pose.cell_at(head) == _leaving:
		return
	_leaving = -1
	if way_out != null and via == Vector3.INF:
		return
	var cost := _length(now_pos, pose) / _rules.swim_speed
	waiting = cold > cost + _lag or cost > cold
	if not waiting:
		_leaving = pose.cell_at(head)


## The way out as find() has it, within a swim of [param reach].
func _find_out(reach: float, now_pos: Vector3, pose: ShipPose) -> void:
	via = Vector3.INF
	_legs = []
	way_out = _surfaces.nearest_climb(now_pos, pose, _rules, reach)
	if way_out != null:
		return
	if _round(reach, now_pos, pose):
		return
	via = _pockets.nearest(now_pos, reach, pose)
	if via != Vector3.INF:
		return
	if _round(_rules.cold_meter * _rules.swim_speed, now_pos, pose):
		return
	# What it swims over: the floor or the stair under the sea where it is.
	var sea := Vector3(now_pos.x, pose.water_height(now_pos), now_pos.z)
	var bottom := _surfaces.landing(sea)
	_legs = _walk_graph.way_ashore(now_pos, bottom, pose)
	if not _legs.is_empty():
		via = _walk_graph.toward(_legs[0], now_pos, bottom)


## Whether a way out within a swim of [param within] lies by way of a point of open
## water a leg or a few off [param now_pos] that nothing hides from it: the nearest such
## found, into way_out and via.
func _round(within: float, now_pos: Vector3, pose: ShipPose) -> bool:
	var eye := Vector3.UP * _eye_height
	var best := INF
	for ring in range(1, 4):
		for index in PROBES:
			var direction := Vector2.from_angle(TAU * index / PROBES)
			var point := now_pos + Vector3(direction.x, 0.0, direction.y) * SWIM_LEG * ring
			if not _surfaces.line_of_sight(now_pos + eye, point + eye, pose):
				continue
			var leg := now_pos.distance_to(point)
			var climb := _surfaces.nearest_climb(point, pose, _rules, within - leg)
			if climb == null or leg + point.distance_to(climb.stand) >= best:
				continue
			best = leg + point.distance_to(climb.stand)
			way_out = climb
			via = point
	return way_out != null


## How far across the water the swim the last look found runs from [param now_pos]
## under [param pose]: through via to the way out or the pocket it makes for — or, by the
## walk graph's portals, on from via straight to the first of their ends whose floor
## stands in a climb's reach of the water, floating over whatever a walk goes round.
func _length(now_pos: Vector3, pose: ShipPose) -> float:
	var from := now_pos
	var length := 0.0
	if via != Vector3.INF:
		length += _across(from, via)
		from = via
	if way_out != null:
		return length + _across(from, way_out.stand)
	for leg: WalkGraph.Portal in _legs:
		for point: Vector3 in [leg.entry, leg.exit]:
			if point.y > pose.water_height(point) - _rules.climb_reach:
				return length + _across(from, point)
	return length


## How far apart [param a] and [param b] are across the ship's plane.
static func _across(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
