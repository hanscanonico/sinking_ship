class_name BotStair
extends RefCounted
## A bot on the stair its route runs along (D10): onto, up or down one no wider than its
## profile's narrow_stair_m it walks the stair's middle, along it, and keeps off its open
## sides by that alone — on a ladder a body's width wide the edge margin's probes find a
## drop on every side and turn it any way at all, off the side among them (#447). Asked of
## the Surfaces and the walk graph of the floors it stands on; nothing here rolls the
## bot's stream.

## How long a walk short of a stair's end a bot turning onto it follows its route from
## where its own walks have stepped it (nears): a second's, room enough to turn and the
## lag of its view several times over.
const TURNING_S := 1.0

var _surfaces: Surfaces
var _walk_graph: WalkGraph
var _rules: BrawlRules
var _narrow: float


func _init(walk_graph: WalkGraph, rules: BrawlRules, profile: BotProfile) -> void:
	_walk_graph = walk_graph
	_surfaces = walk_graph.surfaces()
	_rules = rules
	_narrow = profile.narrow_stair_m


## The walk onto and along [param leg]'s stair from [param at], a unit vector, when the leg
## runs along a stair no wider than narrow_stair_m; else zero. Seen on the stair,
## [param seen_surface], or reckoned on it, along it, closing on its middle over the next
## two bodies' widths of it. Beside its near end, a body's width onto it, straight: a
## stair's side is a step up there, and a narrow stair's foot may be crowded — a capstan
## before the docking bridge's — so that a body steps onto it only from beside it.
func heading(leg: WalkGraph.Portal, seen_surface: int, at: Vector3) -> Vector2:
	if leg.ramp == WalkGraph.NONE or leg.half_width * 2.0 > _narrow:
		return Vector2.ZERO
	var radius := _rules.body_radius
	var offset := Vector2(at.x - leg.entry.x, at.z - leg.entry.z)
	var ahead := offset.dot(leg.along)
	var stair := _surfaces.ramp_surface(leg.ramp)
	if seen_surface == stair or _surfaces.under(at, _rules.step_height) == stair:
		var aside := offset - leg.along * ahead
		return (leg.along * radius * 4.0 - aside).normalized()
	var onto := leg.along * radius - offset
	if ahead >= -radius and onto.length() <= leg.half_width + radius * 2.0:
		return onto.normalized()
	return Vector2.ZERO


## Whether [param at] stands within TURNING_S's walk of the near end of [param leg]'s
## stair, where a bot turns onto it: there its view, a lag behind, still shows the walk
## it turned from, and it follows the route from where its own walks have stepped it
## (BotReckoning.by_steps) — past its railing's end, short of the berth that stops it.
func nears(leg: WalkGraph.Portal, at: Vector3) -> bool:
	if leg.ramp == WalkGraph.NONE:
		return false
	var off := Vector2(at.x - leg.entry.x, at.z - leg.entry.z).length()
	return off <= _rules.walk_speed * TURNING_S


## Whether [param at] stands at the head of [param leg]'s stair — or its foot, the way the
## leg runs — within its width and no more than a body's width short of its end: where the
## walk graph reads the zone the leg leaves from (WalkGraph._end_zone). The floor there
## may be laid in another room, or between rooms, but a body there is at the stair, and
## turns onto it.
func at_head(leg: WalkGraph.Portal, at: Vector3) -> bool:
	if leg.ramp == WalkGraph.NONE:
		return false
	var offset := Vector2(at.x - leg.entry.x, at.z - leg.entry.z)
	var ahead := offset.dot(leg.along)
	var lead := _rules.body_radius * 2.0
	return ahead <= 0.0 and ahead >= -lead and absf(offset.cross(leg.along)) <= leg.half_width


## The way along the stair the bot stands on — seen there, [param my_surface], and still
## there at [param my_pos] — when [param legs] run down it off a deck giving way under
## [param pose], else zero: fleeing, the stair's far end is the way off, not an edge to
## back away from.
func ahead(
	legs: Array[WalkGraph.Portal], my_surface: int, my_pos: Vector3, pose: ShipPose
) -> Vector2:
	if (
		legs.is_empty()
		or legs[0].ramp == WalkGraph.NONE
		or my_surface != _surfaces.ramp_surface(legs[0].ramp)
		or _surfaces.under(my_pos, _rules.step_height) != my_surface
		or not _walk_graph.doomed(legs[0].from_zone, pose)
	):
		return Vector2.ZERO
	return legs[0].along
