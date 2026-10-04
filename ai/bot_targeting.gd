class_name BotTargeting
extends RefCounted
## Whom a bot goes at, of the seats it perceives (D10), and which way the drop nearest
## its target lies. A think looks round each seat within two shoves' carry once, for
## the water and open drops along each probe direction: target choice weighs how far
## over a shove would put it, and the line-up reads its target's drop from that same
## look. Nothing here rolls the bot's stream.

## How far a shove carries an unbraced body on a level deck, from the rules: how near a
## drop a target must stand to be worth lining up.
var carry: float
## The way from the target to the water or unrailed drop within a shove's carry of it,
## and how far the nearest is, as the last think found them; zero and INF for none.
var drop_way := Vector2.ZERO
var drop_distance := INF

var _seat: int
var _profile: BotProfile
var _rules: BrawlRules
var _footing: BotFooting
var _walk_graph: WalkGraph
## This think's looks round seats, by seat: where it stood, and how far the water or an
## open drop is along each probe direction.
var _looked_from := {}
var _looked := {}


func _init(
	seat: int, profile: BotProfile, rules: BrawlRules, footing: BotFooting, walk_graph: WalkGraph
) -> void:
	_seat = seat
	_profile = profile
	_rules = rules
	_footing = footing
	_walk_graph = walk_graph
	var knock := rules.knockback
	var slowed := rules.stagger_friction * rules.stagger
	if slowed >= knock:
		carry = knock * knock / (2.0 * rules.stagger_friction)
	else:
		carry = (
			(knock + knock - slowed) * 0.5 * rules.stagger
			+ pow(knock - slowed, 2.0) / (2.0 * rules.ground_friction)
		)


## The seat to go at, [param kept] the one it goes at now: of those it perceives on
## their feet, in a zone it can reach — but a room whose floor stands within
## climb_margin_m of the sea — scored by how near — against the nearest — and
## by king_of_hill_bias how high they stand, against the lowest and the highest; that
## bias tapered by crowd_taper while crowd_seats or more stand in [param perch], the highest
## zone it can reach. By exposure_weight, one within two shoves' carry scores by how far
## over a shove would put it; by crowd_aversion, one nearer another seat than the bot
## scores less. [param kept] stays unless another beats it by the hysteresis; ties go
## to the lower seat. -1 for none.
func choose(
	seen: Dictionary, me: Dictionary, found: WalkGraph.Search, pose: ShipPose, perch: int, kept: int
) -> int:
	_looked_from.clear()
	_looked.clear()
	var my_pos: Vector3 = me["pos"]
	var candidates: Array[Dictionary] = []
	var nearest := INF
	var lowest := INF
	var highest := -INF
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == _seat or entry["out"] or entry["state"] == PlayerState.Body.SWIMMING:
			continue
		var zone := _zone_of(entry)
		if zone != WalkGraph.NONE and (found.cost.is_empty() or found.cost[zone] == INF):
			continue
		# Not down into a room the sea is about to take: the bot would climb out of it.
		if (
			_walk_graph.is_room(zone)
			and _walk_graph.floor_height(zone, entry["pos"], pose) < _profile.climb_margin_m
		):
			continue
		candidates.append(entry)
		var height := pose.world_height(entry["pos"])
		nearest = minf(nearest, my_pos.distance_to(entry["pos"]))
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	var bias := _profile.king_of_hill_bias
	var on_perch := 0
	for entry: Dictionary in candidates:
		on_perch += 1 if perch != WalkGraph.NONE and _zone_of(entry) == perch else 0
	if on_perch >= _profile.crowd_seats:
		bias *= 1.0 - _profile.crowd_taper
	var span := PackedFloat64Array([nearest, lowest, highest, bias])
	var scores := _scores(seen, my_pos, candidates, span, pose, kept)
	var best := -1
	var best_score := -INF
	var kept_score := -INF
	for index in candidates.size():
		if scores[index] > best_score:
			best = candidates[index]["seat"]
			best_score = scores[index]
		if candidates[index]["seat"] == kept:
			kept_score = scores[index]
	if best != -1 and kept_score + _profile.hysteresis >= best_score:
		return kept
	return best


## Each of [param candidates]' scores as choose() has them — [param span] holds the
## nearest distance, the lowest and highest height and the king-of-hill bias — but
## -INF for one that could not beat the best fully exposed: every score but for
## exposure comes first, and the most exposure could add to it, so such a seat is
## never looked round. [param kept]'s is always whole.
func _scores(
	seen: Dictionary,
	my_pos: Vector3,
	candidates: Array[Dictionary],
	span: PackedFloat64Array,
	pose: ShipPose,
	kept: int
) -> PackedFloat64Array:
	var nearest := span[0]
	var lowest := span[1]
	var highest := span[2]
	var bias := span[3]
	var bases := PackedFloat64Array()
	var scores := PackedFloat64Array()
	var fought := PackedByteArray()
	var looks: Array[int] = []
	for entry: Dictionary in candidates:
		var distance := my_pos.distance_to(entry["pos"])
		var near := nearest / maxf(distance, _rules.body_radius)
		var high := 1.0
		if highest - lowest > _rules.step_height:
			high = (pose.world_height(entry["pos"]) - lowest) / (highest - lowest)
		var base := (1.0 - bias) * near + bias * high
		var bound := base
		if _profile.exposure_weight > 0.0 and distance < carry * 2.0:
			bound += _profile.exposure_weight
			looks.append(bases.size())
		var crowded := _profile.crowd_aversion > 0.0 and _fought(seen, entry, distance)
		fought.append(1 if crowded else 0)
		if crowded:
			bound -= _profile.crowd_aversion
		bases.append(base)
		scores.append(bound)
	var best_score := -INF
	for index in scores.size():
		if not index in looks:
			best_score = maxf(best_score, scores[index])
	var bounds := scores.duplicate()
	looks.sort_custom(func(a: int, b: int) -> bool: return bounds[a] > bounds[b])
	for index: int in looks:
		var entry := candidates[index]
		if bounds[index] < best_score and entry["seat"] != kept:
			scores[index] = -INF
			continue
		var score := bases[index] + _profile.exposure_weight * _exposure(entry, pose)
		if fought[index] == 1:
			score -= _profile.crowd_aversion
		scores[index] = score
		best_score = maxf(best_score, score)
	return scores


## The way from [param mark] to the water or unrailed drop within a shove's carry of
## it — every probe that meets one, the nearer the more — and how far the nearest is,
## into drop_way and drop_distance; zero and INF for none.
func find_drop(mark: Dictionary, pose: ShipPose) -> void:
	drop_way = Vector2.ZERO
	drop_distance = INF
	if mark.is_empty():
		return
	var edges := _look_round(mark, pose)
	var way := Vector2.ZERO
	for index in BotFooting.PROBES:
		if edges[index] < INF:
			way += BotFooting.probe(index) * (1.0 - edges[index] / carry)
			drop_distance = minf(drop_distance, edges[index])
	drop_way = way.normalized()


## How far over a shove would put the seat [param entry] describes: 1 with the water or
## an open drop right behind it, down to 0 at the carry or past a railing; braced, the
## profile's braced_exposure of that.
func _exposure(entry: Dictionary, pose: ShipPose) -> float:
	var behind := INF
	for distance: float in _look_round(entry, pose):
		behind = minf(behind, distance)
	if behind == INF:
		return 0.0
	return (1.0 - behind / carry) * (_profile.braced_exposure if entry["bracing"] else 1.0)


## How far the water or an open drop is along each probe direction from the seat
## [param entry] describes, within the carry and not past a railing — looked once a
## think for each place.
func _look_round(entry: Dictionary, pose: ShipPose) -> PackedFloat64Array:
	var seat: int = entry["seat"]
	if _looked.has(seat) and _looked_from[seat] == entry["pos"]:
		return _looked[seat]
	var edges := PackedFloat64Array()
	for index in BotFooting.PROBES:
		edges.append(
			_footing.edge_toward(
				entry["pos"], entry["surface"], BotFooting.probe(index), carry, pose, false
			)
		)
	_looked_from[seat] = entry["pos"]
	_looked[seat] = edges
	return edges


## Whether another seat stands nearer the seat [param entry] describes than the bot,
## [param distance] off it, does: someone better placed is at it already.
func _fought(seen: Dictionary, entry: Dictionary, distance: float) -> bool:
	for other: Dictionary in seen["seats"]:
		if (
			other["seat"] != _seat
			and other["seat"] != entry["seat"]
			and not other["out"]
			and other["state"] != PlayerState.Body.SWIMMING
			and other["pos"].distance_to(entry["pos"]) < distance
		):
			return true
	return false


func _zone_of(entry: Dictionary) -> int:
	return _walk_graph.zone_at(entry["pos"], entry["surface"])
