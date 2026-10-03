class_name ShoveResolver
extends RefCounted
## Who a shove hits (D13). It reads bodies as data — never the live seats — so a
## caller may hand it positions from any moment (SH13 rewinds them for lag
## compensation) without the rule changing. Whether a blocker stands between two
## bodies it asks the ship's Surfaces.


## A body a shove could land on, as of the moment being resolved.
class Candidate:
	var seat: int
	var pos: Vector3
	var radius: float
	var height: float

	func _init(body_seat: int, body_pos: Vector3, body_radius: float, body_height: float) -> void:
		seat = body_seat
		pos = body_pos
		radius = body_radius
		height = body_height


## A shove in its active window: who throws it, from where, and which way.
class Attempt:
	var seat: int
	var origin: Vector3
	var radius: float
	## Unit vector in the ship plane (x, z).
	var direction: Vector2

	func _init(
		shover_seat: int, shover_pos: Vector3, shover_radius: float, shove_direction: Vector2
	) -> void:
		seat = shover_seat
		origin = shover_pos
		radius = shover_radius
		direction = shove_direction


class Hit:
	var shover: int
	var target: int
	## The shove's direction, which is where the target is sent.
	var direction: Vector2

	func _init(shover_seat: int, target_seat: int, shove_direction: Vector2) -> void:
		shover = shover_seat
		target = target_seat
		direction = shove_direction


## Every hit of every attempt, all against the same candidates: simultaneous
## shoves all land. Ordered by attempt, then by candidate. [param surfaces] is the
## ship's, and [param step] the rules' step_height.
static func resolve(
	attempts: Array[Attempt],
	candidates: Array[Candidate],
	reach: float,
	cone_deg: float,
	surfaces: Surfaces,
	step: float
) -> Array[Hit]:
	var hits: Array[Hit] = []
	for attempt: Attempt in attempts:
		for candidate: Candidate in candidates:
			if candidate.seat == attempt.seat:
				continue
			if lands(
				attempt.origin,
				attempt.radius,
				attempt.direction,
				candidate,
				reach,
				cone_deg,
				surfaces,
				step
			):
				hits.append(Hit.new(attempt.seat, candidate.seat, attempt.direction))
	return hits


## True when [param target] is within [param reach] beyond both bodies' edges,
## inside the half-angle [param cone_deg] of [param direction], level enough with
## the shover to touch, and no blocker stands between them.
static func lands(
	origin: Vector3,
	radius: float,
	direction: Vector2,
	target: Candidate,
	reach: float,
	cone_deg: float,
	surfaces: Surfaces,
	step: float
) -> bool:
	if absf(target.pos.y - origin.y) >= target.height:
		return false
	var offset := Vector2(target.pos.x - origin.x, target.pos.z - origin.z)
	var gap := offset.length() - radius - target.radius
	if gap > reach:
		return false
	if surfaces.blocked(origin, target.pos, target.height, step):
		return false
	if offset.is_zero_approx():
		return true
	return absf(direction.angle_to(offset)) <= deg_to_rad(cone_deg)


## The facing a shove starting now should take: toward the nearest candidate a
## shove could reach inside the half-angle [param cone_deg] of [param facing], or
## [param facing] unchanged when there is none. Ties go to the lower seat.
static func autoaim(
	shover: Candidate,
	facing: float,
	candidates: Array[Candidate],
	reach: float,
	cone_deg: float,
	surfaces: Surfaces,
	step: float
) -> float:
	var direction := Vector2.from_angle(facing)
	var best_gap := INF
	var best_facing := facing
	for candidate: Candidate in candidates:
		if candidate.seat == shover.seat:
			continue
		if not lands(
			shover.pos, shover.radius, direction, candidate, reach, cone_deg, surfaces, step
		):
			continue
		var offset := Vector2(candidate.pos.x - shover.pos.x, candidate.pos.z - shover.pos.z)
		if offset.is_zero_approx():
			continue
		var gap := offset.length()
		if gap < best_gap:
			best_gap = gap
			best_facing = offset.angle()
	return best_facing
