class_name PlaneShapes
extends RefCounted
## The flat shapes Surfaces' questions are made of, in the ship's x/z plane: where a
## circle meets a rectangle, another circle or a stair too steep for it, where a
## segment crosses one, and how contacts facing one way merge. Pure functions, nothing
## kept.

## How far under a step's reach a body slammed up a ramp is held, so that its feet
## still find the ramp within a step.
const CLIMB_MARGIN := 0.001


## Whether a body [param body_height] tall with its feet at [param feet] meets
## something between [param bottom] and [param top] — it cannot step up onto it, and
## it is not clear overhead.
static func overlaps(
	feet: float, body_height: float, step: float, bottom: float, top: float
) -> bool:
	return feet + step < top and feet + body_height > bottom


static func rect_contact(rect: Rect2, point: Vector2, radius: float) -> Surfaces.Contact:
	var closest := point.clamp(rect.position, rect.end)
	var offset := point - closest
	var distance := offset.length()
	if distance > 0.0:
		return (
			Surfaces.Contact.new(offset / distance, radius - distance)
			if distance < radius
			else null
		)
	# The centre is inside: out through the nearest side.
	var sides := [
		[point.x - rect.position.x, Vector2.LEFT],
		[rect.end.x - point.x, Vector2.RIGHT],
		[point.y - rect.position.y, Vector2.UP],
		[rect.end.y - point.y, Vector2.DOWN],
	]
	var nearest: Array = sides[0]
	for side: Array in sides:
		if side[0] < nearest[0]:
			nearest = side
	return Surfaces.Contact.new(nearest[1], nearest[0] + radius)


static func circle_contact(
	centre: Vector2, circle_radius: float, point: Vector2, radius: float
) -> Surfaces.Contact:
	var offset := point - centre
	var distance := offset.length()
	if distance >= circle_radius + radius:
		return null
	var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
	return Surfaces.Contact.new(normal, circle_radius + radius - distance)


## What holds back a circle of [param radius] whose centre at [param point] stands on
## [param ramp] where it rises above [param reach], the highest its feet can step this
## tick — carried up a steep stair faster than a step a tick, or onto its side: the
## least move of back down the ramp to where the rise runs out, or out through a side
## or the low end. Never out through the high end: past a stair's head is the deck it
## climbs to, standing over a wall or the hull.
static func climb_contact(
	ramp: ShipRamp, point: Vector2, radius: float, reach: float
) -> Surfaces.Contact:
	var x_axis := ramp.axis == ShipRamp.Axis.X
	var axis := 0 if x_axis else 1
	var length := ramp.area.size[axis]
	var along := point[axis] - ramp.area.position[axis]
	var rise := (ramp.end_height - ramp.start_height) / length
	var outward := Vector2.RIGHT if x_axis else Vector2.DOWN
	var high_end := outward if rise > 0.0 else -outward
	# A hair under the reach, so the feet find the ramp within a step when grounded.
	var limit := clampf((reach - CLIMB_MARGIN - ramp.start_height) / rise, 0.0, length)
	var best := Surfaces.Contact.new(-high_end, absf(along - limit) + CLIMB_MARGIN / absf(rise))
	var area := ramp.area
	for side: Array in [
		[point.x - area.position.x, Vector2.LEFT],
		[area.end.x - point.x, Vector2.RIGHT],
		[point.y - area.position.y, Vector2.UP],
		[area.end.y - point.y, Vector2.DOWN],
	]:
		if side[1] == high_end:
			continue
		if side[0] + radius < best.depth:
			best = Surfaces.Contact.new(side[1], side[0] + radius)
	return best


static func segment_meets_rect(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	if rect.has_point(start) or rect.has_point(end):
		return true
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for index in 4:
		var side_start: Vector2 = corners[index]
		var side_end: Vector2 = corners[(index + 1) % 4]
		if Geometry2D.segment_intersects_segment(start, end, side_start, side_end) != null:
			return true
	return false


## The part of the segment from [param start] to [param end] inside [param rect],
## as (from, to) fractions along it; empty (from > to) when it misses.
static func segment_in_rect(start: Vector2, end: Vector2, rect: Rect2) -> Vector2:
	var low := 0.0
	var high := 1.0
	var delta := end - start
	for axis in 2:
		var lower := rect.position[axis]
		var upper := rect.end[axis]
		if is_zero_approx(delta[axis]):
			if start[axis] < lower or start[axis] > upper:
				return Vector2(INF, -INF)
			continue
		var first := (lower - start[axis]) / delta[axis]
		var second := (upper - start[axis]) / delta[axis]
		low = maxf(low, minf(first, second))
		high = minf(high, maxf(first, second))
	return Vector2(low, high) if low <= high else Vector2(INF, -INF)


## The part of the segment from [param start] to [param end] inside the circle of
## [param radius] round [param centre], as (from, to) fractions along it; empty
## (from > to) when it misses.
static func segment_in_circle(
	start: Vector2, end: Vector2, centre: Vector2, radius: float
) -> Vector2:
	var delta := end - start
	var a := delta.length_squared()
	var offset := start - centre
	var b := offset.dot(delta)
	var discriminant := b * b - a * (offset.length_squared() - radius * radius)
	if a == 0.0 or discriminant < 0.0:
		return Vector2(INF, -INF)
	var root := sqrt(discriminant)
	var low := maxf(0.0, (-b - root) / a)
	var high := minf(1.0, (-b + root) / a)
	return Vector2(low, high) if low <= high else Vector2(INF, -INF)


## Touching shapes facing the same way — two railing spans end to end, a deck over
## the house it stands on — hold a body back once, not twice.
static func deepest_per_direction(contacts: Array[Surfaces.Contact]) -> Array[Surfaces.Contact]:
	if contacts.size() < 2:
		return contacts
	var kept: Array[Surfaces.Contact] = []
	for contact: Surfaces.Contact in contacts:
		var merged := false
		for other: Surfaces.Contact in kept:
			if other.normal.is_equal_approx(contact.normal):
				if contact.depth > other.depth:
					other.depth = contact.depth
					other.railing = contact.railing
				merged = true
				break
		if not merged:
			kept.append(contact)
	return kept
