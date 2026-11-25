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
var _windup_ticks: int
var _profile: BotProfile
var _rules: BrawlRules
var _footing: BotFooting
var _walk_graph: WalkGraph
var _plays_for: MatchRules.Goal
## The zones a survival bot fights over, as the last think found them: its refuge and
## its highest ground. Empty under the battle royale, where it fights anywhere.
var _fights: Array[int] = []
## Whether a survival bot fights nobody yet: until it sees refuge_from of the ship
## under water, nothing is worth a fight while she still holds them all.
var _holds := false
## Sparring, the seat it has held its shove at, the snapshot tick it began to and the last
## it did: -1 for none (spares). And by seat, the snapshot tick until which it lets
## that seat be (#776).
var _sparing := PackedInt32Array([-1, 0, 0])
var _let_be: Dictionary[int, int] = {}
## This think's looks round seats, by seat: where it stood, and how far the water or an
## open drop is along each probe direction.
var _looked_from := {}
var _looked := {}


## [param plays_for] is what the match is played for (MatchRules.Goal).
func _init(
	seat: int,
	profile: BotProfile,
	rules: BrawlRules,
	footing: BotFooting,
	walk_graph: WalkGraph,
	plays_for := MatchRules.Goal.LAST_STANDING
) -> void:
	_seat = seat
	_windup_ticks = Ticks.from_seconds(rules.shove_windup)
	_plays_for = plays_for
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
## to the lower seat. -1 for none. Under survival, once it sees the share [param under]
## of her deck area reach refuge_from, it fights over [param refuge] and
## [param perch]: while anyone stands in them, only those are weighed — before that,
## nobody is fought (off_perch). A seat it lets be (spares) is none of them.
func choose(
	seen: Dictionary,
	me: Dictionary,
	found: WalkSearch,
	pose: ShipPose,
	perch: int,
	kept: int,
	refuge := WalkGraph.NONE,
	under := 0.0
) -> int:
	_fights.clear()
	_holds = _plays_for == MatchRules.Goal.SURVIVAL and under < _profile.refuge_from
	if _plays_for == MatchRules.Goal.SURVIVAL and not _holds:
		_fights.assign([refuge, perch])
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
		if _let_be.get(entry["seat"], -1) > seen["tick"]:
			continue
		var zone := _zone_of(entry)
		if zone != WalkGraph.NONE and not found.reaches(zone):
			continue
		# Not down into a room the sea is about to take: the bot would climb out of it.
		if (
			_walk_graph.room_of(zone) != WalkGraph.NONE
			and _walk_graph.floor_height(zone, entry["pos"], pose) < _profile.climb_margin_m
		):
			continue
		candidates.append(entry)
	if not _fights.is_empty():
		var on_perch := candidates.filter(
			func(entry: Dictionary) -> bool: return not off_perch(entry)
		)
		if not on_perch.is_empty():
			candidates.assign(on_perch)
	for entry: Dictionary in candidates:
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


## Sparring with a spar margin of [param spar], whether a shove from [param my_pos] would
## land on a seat in [param seen] — one [param lands] says it lands on — with the water, an
## open drop or a railing it could go over within that margin the way the shove sends it,
## straight away from the bot: from where it was seen, or from where its seen velocity
## carries it by the time the shove lands. Held at [param victim] for spar_patience_s
## running, no break of more than two thinks, it lets that seat be for spar_release_s
## (#776): choose() passes it over.
func spares(
	seen: Dictionary,
	my_pos: Vector3,
	victim: Dictionary,
	lands: Callable,
	spar: float,
	pose: ShipPose
) -> bool:
	var lag := (_profile.reaction_ticks + _windup_ticks) * Ticks.SECONDS_PER_TICK
	for entry: Dictionary in seen["seats"]:
		if entry["seat"] == _seat or not lands.call(entry):
			continue
		var seen_at: Vector3 = entry["pos"]
		var vel: Vector3 = entry["vel"]
		for at: Vector3 in [seen_at, seen_at + Vector3(vel.x, 0.0, vel.z) * lag]:
			var way := Vector2(at.x - my_pos.x, at.z - my_pos.z).normalized()
			if _footing.edge_toward(at, entry["surface"], way, spar, pose, true) < INF:
				_held_fire(victim["seat"], seen["tick"])
				return true
	return false


func _held_fire(at_seat: int, tick: int) -> void:
	if _sparing[0] != at_seat or tick - _sparing[2] > _profile.think_period * 2:
		_sparing = PackedInt32Array([at_seat, tick, tick])
		return
	_sparing[2] = tick
	if tick - _sparing[1] >= Ticks.from_seconds(_profile.spar_patience_s):
		_let_be[at_seat] = tick + Ticks.from_seconds(_profile.spar_release_s)
		_sparing[0] = -1


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


## Whether a survival bot would be going at [param entry] — a seat of the snapshot, or
## none — off the zones it fights over, or before it fights at all (choose); never
## under the battle royale.
func off_perch(entry: Dictionary) -> bool:
	if _holds:
		return true
	return not _fights.is_empty() and (entry.is_empty() or not _zone_of(entry) in _fights)


func _zone_of(entry: Dictionary) -> int:
	return _walk_graph.zone_at(entry["pos"], entry["surface"])


## The nearest seat seen in the sea within guard_range_m of [param my_pos], or -1:
## one there may climb out at the bot's feet.
func swimmer_near(seen: Dictionary, my_pos: Vector3) -> int:
	var nearest := -1
	var best := _profile.guard_range_m
	for entry: Dictionary in seen["seats"]:
		if (
			entry["seat"] == _seat
			or entry["state"] != PlayerState.Body.SWIMMING
			or entry.has(BotView.REMEMBERED)
		):
			continue
		var distance := my_pos.distance_to(entry["pos"])
		if distance < best:
			best = distance
			nearest = entry["seat"]
	return nearest


## The nearest seat whose shove would land on the bot as things stand and that
## could be winding one up: seen in a windup or a charge, or idle and able to
## start one. The view is reaction_ticks old, so this is a read, never a reaction
## to a quick windup — that has landed before the bot could see it. Empty when
## there is none.
func threat(seen: Dictionary, me: Dictionary) -> Dictionary:
	var nearest := {}
	var best := INF
	var my_pos: Vector3 = me["pos"]
	var mine := ShoveResolver.Candidate.new(
		_seat, my_pos, _rules.body_radius, _rules.height_at(_walk_graph.surfaces(), my_pos)
	)
	for entry: Dictionary in seen["seats"]:
		if (
			entry["seat"] == _seat
			or entry["state"] != PlayerState.Body.GROUNDED
			or entry.has(BotView.REMEMBERED)
		):
			continue
		var action: PlayerState.Action = entry["action"]
		if action == PlayerState.Action.ACTIVE or action == PlayerState.Action.RECOVERY:
			continue
		if entry["stagger"] > 0:
			continue
		if not ShoveResolver.lands(
			entry["pos"],
			_rules.body_radius,
			Vector2.from_angle(entry["facing"]),
			mine,
			_rules.shove_reach,
			_rules.shove_cone_deg,
			_walk_graph.surfaces(),
			_rules.step_height
		):
			continue
		var distance := my_pos.distance_squared_to(entry["pos"])
		if distance < best:
			best = distance
			nearest = entry
	return nearest
