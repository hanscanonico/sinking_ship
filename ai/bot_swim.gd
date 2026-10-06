class_name BotSwim
extends RefCounted
## Where a bot in the sea swims (SH5): for the nearest way out it can reach — round
## through open water when the hull or a wall stands across the straight swim — and,
## in a flooded room with no way out in sight, out by the doorways and stairs the walk
## graph has from it to dry ground: the sea takes the stair's foot first, never its
## head. Every answer is asked of Surfaces and the walk graph under the pose handed in;
## nothing here rolls the bot's stream.

## Directions probed around the swimmer for open water.
const PROBES := 8
## How far apart the open-water points a swimmer tries for a way round are, in metres.
const SWIM_LEG := 1.5

## The way out the last look found, and the point it swims through on the way — the
## open water round a wall, or the next portal out of a flooded room; null and INF for
## none.
var way_out: Surfaces.Climb
var via := Vector3.INF

var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rules: BrawlRules
var _eye_height: float


func _init(walk_graph: WalkGraph, rules: BrawlRules, eye_height: float) -> void:
	_walk_graph = walk_graph
	_surfaces = walk_graph.surfaces()
	_rules = rules
	_eye_height = eye_height


## Where a swimmer swims next, as the last look found it: through [member via] first;
## INF when it found nowhere to make for.
func goal() -> Vector3:
	if via != Vector3.INF:
		return via
	return way_out.stand if way_out != null else Vector3.INF


## Looks for the way out of the sea of a swimmer at [param now_pos] with [param cold]
## seconds of its cold meter left: the nearest within the swim that leaves, straight
## across the water; failing that, the nearest by way of a point of open water a leg or
## a few off that nothing hides from it; failing that too, the nearest of those within
## a whole cold meter's swim, so it keeps swimming while there is one; and in a flooded
## room with none of those, the next portal of the walk graph's way to dry ground.
func find(cold: float, now_pos: Vector3, pose: ShipPose) -> void:
	var reach := cold * _rules.swim_speed
	via = Vector3.INF
	way_out = _surfaces.nearest_climb(now_pos, pose, _rules, reach)
	if way_out != null:
		return
	var eye := Vector3.UP * _eye_height
	for within: float in [reach, _rules.cold_meter * _rules.swim_speed]:
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
		if way_out != null:
			return
	# What it swims over: the floor or the stair under the sea where it is.
	var sea := Vector3(now_pos.x, pose.water_height(now_pos), now_pos.z)
	var bottom := _surfaces.landing(sea)
	var legs := _walk_graph.way_ashore(now_pos, bottom, pose)
	if not legs.is_empty():
		via = _walk_graph.toward(legs[0], now_pos, bottom)
