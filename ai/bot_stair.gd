class_name BotStair
extends RefCounted
## A bot on the stair its route runs along (D10): onto, up or down one no wider than its
## profile's narrow_stair_m it walks the stair's middle, along it, and keeps off its open
## sides by that alone — on a ladder a body's width wide the edge margin's probes find a
## drop on every side and turn it any way at all, off the side among them (#447). Asked of
## the Surfaces and the walk graph of the floors it stands on; nothing here rolls the
## bot's stream.

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
