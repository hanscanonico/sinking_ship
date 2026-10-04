class_name BotFooting
extends RefCounted
## What a walk from where a bot stands would meet, for one bot's edge margin: the
## water, an open edge, the trench between two decks, a wall or a stair's solid side;
## and what the deck round a seat would do with a shove.
## Every answer is asked of Surfaces (D6, D13) under the pose handed in; nothing here
## remembers a tick.

## Directions probed round the bot.
const PROBES := 8

## How far from water and open edges the bot keeps, in metres: its profile's
## edge_margin_m, or less once few dry decks are left to share.
var margin: float

var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rules: BrawlRules
## How far ahead a heading is looked along: the profile's edge margin, whatever the
## late game makes of the margin.
var _look_ahead: float


func _init(
	surfaces: Surfaces, walk_graph: WalkGraph, rules: BrawlRules, edge_margin: float
) -> void:
	_surfaces = surfaces
	_walk_graph = walk_graph
	_rules = rules
	margin = edge_margin
	_look_ahead = edge_margin


## Away from [param dangers]: a unit vector when they lie to one side, shorter the
## more they balance out — a stair with a drop either side pushes only off the nearer.
static func away(dangers: PackedVector2Array) -> Vector2:
	var push := Vector2.ZERO
	for danger: Vector2 in dangers:
		push -= danger
	return push.limit_length(1.0)


## The directions of the probes at the margin round [param my_pos] that are wet or
## past an open edge, as danger_toward finds them.
func dangers(
	my_pos: Vector3,
	my_surface: int,
	pose: ShipPose,
	mark: Dictionary,
	stair_ahead: Vector2,
	heed_drops: bool = true
) -> PackedVector2Array:
	var found := PackedVector2Array()
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		if danger_toward(my_pos, my_surface, pose, mark, stair_ahead, direction, heed_drops):
			found.append(direction)
	return found


## Whether the probe at the margin from [param my_pos] along [param direction] is wet
## or past an open edge: walking there would drop off it, even onto a surface within
## a step of its feet beyond — a trench is an edge. One past a railing of
## [param my_surface] is safe; one through a gap is not, unless [param mark] is lined
## up for a shove through it — nor one into the sea, when [param mark] is climbing out
## of it there. On a stair whose way on is [param stair_ahead], an open edge ahead of
## it is the stair's far end and its sides, and is no danger. Unless
## [param heed_drops], only a wet one is.
func danger_toward(
	my_pos: Vector3,
	my_surface: int,
	pose: ShipPose,
	mark: Dictionary,
	stair_ahead: Vector2,
	direction: Vector2,
	heed_drops: bool
) -> bool:
	var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * margin
	if _surfaces.wet(probe, pose):
		var guarding: bool = not mark.is_empty() and mark["climb"] > 0
		return not (guarding and _lined_up(my_pos, probe, mark))
	return (
		heed_drops
		and direction.dot(stair_ahead) <= 0.0
		and _surfaces.drops(my_pos, probe, _rules.step_height)
		and not _surfaces.railed(my_pos, probe, my_surface)
		and not _lined_up(my_pos, probe, mark)
	)


## Whether any probe at [param reach] round [param my_pos] is wet or past an edge,
## railed or not: the look further out that says whether the margin's probes are
## worth making until the next think. A railing counts — a step along it may bring a
## gap in it into the margin.
func danger_within(my_pos: Vector3, pose: ShipPose, reach: float) -> bool:
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		var probe := my_pos + Vector3(direction.x, 0.0, direction.y) * reach
		if _surfaces.wet(probe, pose):
			return true
		if (
			_surfaces.under(probe, _rules.step_height) == Surfaces.NONE
			and _surfaces.drops(my_pos, probe, _rules.step_height)
		):
			return true
	return false


## Whether any probe at the margin round [param my_pos] is wet.
func water_near(my_pos: Vector3, pose: ShipPose) -> bool:
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		if _surfaces.wet(my_pos + Vector3(direction.x, 0.0, direction.y) * margin, pose):
			return true
	return false


## How far a walk from [param from] on [param surface] along [param direction] goes
## before it meets the water or a drop within [param reach] — a body's width at a
## time — or INF when it meets neither, or a wall stands before it, or, unless
## [param through_railings], a railing of [param surface] does.
func edge_toward(
	from: Vector3,
	surface: int,
	direction: Vector2,
	reach: float,
	pose: ShipPose,
	through_railings: bool
) -> float:
	var stride := _rules.body_radius * 2.0
	var feet := from.y
	for index in range(1, ceili(reach / stride) + 1):
		var along := minf(index * stride, reach)
		var at := from + Vector3(direction.x, 0.0, direction.y) * along
		at.y = feet
		var under := (
			Surfaces.NONE if _surfaces.wet(at, pose) else _surfaces.under(at, _rules.step_height)
		)
		if under != Surfaces.NONE:
			feet = _surfaces.height_at(under, at)
			continue
		if (
			_surfaces.blocked(from, at, _rules.body_height, _rules.step_height)
			or not through_railings and _surfaces.railed(from, at, surface)
		):
			return INF
		return along
	return INF


## How high the feet of a walk from [param from] straight to [param to]'s x/z come,
## a step at a time: up a stair, its top is a deck to walk onto, not a wall. Where
## the walk leaves every surface, the height they had there.
func feet_at(from: Vector3, to: Vector3) -> float:
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var samples := maxi(1, ceili(start.distance_to(end) / _rules.step_height))
	var feet := from.y
	for index in range(1, samples + 1):
		var at := start.lerp(end, float(index) / samples)
		var point := Vector3(at.x, feet, at.y)
		var surface := _surfaces.under(point, _rules.step_height)
		if surface == Surfaces.NONE:
			break
		feet = _surfaces.height_at(surface, point)
	return feet


## Whether feet at [param point] would stand inside something that holds a body back
## — a stair's solid side, a deck's edge too high to step onto — as the sim asks it.
func walled(point: Vector3) -> bool:
	return not (
		_surfaces
		. obstacle_contacts(point, _rules.body_radius * 0.1, _rules.body_height, _rules.step_height)
		. is_empty()
	)


## [param wish] turned as little as it can, a probe direction at a time either way,
## so that the walk's next edge margin neither runs into a blocker or a stair's side
## nor, when [param keep_to] lists surfaces, steps onto any surface but those or a
## platform of the zones [param keep_zones]; unturned when every way does.
func clear_heading(
	my_pos: Vector3, wish: Vector2, keep_to: PackedInt32Array, keep_zones: PackedInt32Array
) -> Vector2:
	if wish == Vector2.ZERO:
		return wish
	for turn: int in [0, 1, -1, 2, -2]:
		var heading := wish.rotated(TAU * turn / PROBES)
		var ahead := my_pos + Vector3(heading.x, 0.0, heading.y) * _look_ahead
		ahead.y = feet_at(my_pos, ahead)
		if _surfaces.blocked(my_pos, ahead, _rules.body_height, _rules.step_height):
			continue
		if walled(my_pos.lerp(ahead, 0.5)) or walled(ahead):
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


## How far over a shove carrying [param carry] metres would put the seat
## [param entry] describes: 1 with the water or an open drop right behind it, down to
## 0 at the carry or past a railing; half that braced.
func exposure(entry: Dictionary, carry: float, pose: ShipPose) -> float:
	var behind := INF
	for index in PROBES:
		var direction := Vector2.from_angle(TAU * index / PROBES)
		behind = minf(
			behind, edge_toward(entry["pos"], entry["surface"], direction, carry, pose, false)
		)
	if behind == INF:
		return 0.0
	return (1.0 - behind / carry) * (0.5 if entry["bracing"] else 1.0)


## The share of the ship's platforms under water at their middle under [param pose].
func flooded_share(pose: ShipPose) -> float:
	var flooded := 0
	for platform in _surfaces.platform_count():
		flooded += 1 if _surfaces.flooded(platform, pose) else 0
	return flooded / float(_surfaces.platform_count())


## Whether [param mark] stands between the bot and [param probe] — nearer the probe
## than the bot, inside the shove cone toward it.
func _lined_up(my_pos: Vector3, probe: Vector3, mark: Dictionary) -> bool:
	if mark.is_empty() or mark.has(BotView.REMEMBERED):
		return false
	var mark_pos: Vector3 = mark["pos"]
	var toward_probe := Vector2(probe.x - my_pos.x, probe.z - my_pos.z)
	var toward_mark := Vector2(mark_pos.x - my_pos.x, mark_pos.z - my_pos.z)
	return (
		mark_pos.distance_to(probe) < margin
		and absf(toward_probe.angle_to(toward_mark)) <= deg_to_rad(_rules.shove_cone_deg)
	)
