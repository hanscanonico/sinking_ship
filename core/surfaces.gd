class_name Surfaces
extends RefCounted
## The only door to spatial questions about the ship (D6, D13): what a body stands
## on within a step, how high a surface is under a point, where a falling body
## lands, what holds a body back in the deck plane, whether a shove's line is
## blocked, whether a walk ends in a drop, and whether a point is wet. Surfaces are
## numbered platforms first, then ramps, then blocker tops, each in layout order. A
## blocker's top is stood on and landed on like a platform's; a wall is a blocker
## and its doorways are the gaps between walls. Nothing here assumes a size or a deck
## count, and nothing reads the layout's rooms.

const NONE := -1
## The side of a cell of the spatial index, in metres. Rooms made the steamer's
## surfaces six times as many as SH3's, so every query looks only at the surfaces
## whose areas reach the cells it touches — the first of SH18's index, behind this
## same door.
const CELL := 1.0
## How far under a step's reach a body slammed up a ramp is held, so that its feet
## still find the ramp within a step.
const CLIMB_MARGIN := 0.001


## A body's circle overlapping something that holds it back.
class Contact:
	## Unit vector in the ship plane (x, z), from what was touched toward the body.
	var normal: Vector2
	## How far the circle reaches into it.
	var depth: float

	func _init(outward: Vector2, overlap: float) -> void:
		normal = outward
		depth = overlap


var _platforms: Array[ShipPlatform] = []
var _ramps: Array[ShipRamp] = []
var _blockers: Array[ShipBlocker] = []
var _railings: Array[ShipRailing] = []
## Per railing, the unit normal pointing onto its platform.
var _rail_normals := PackedVector2Array()
## Per platform, how low its sides reach: a deck over a lower one is a slab, and a
## deck over none is the top of the hull, solid all the way down.
var _platform_bottoms := PackedFloat64Array()
## The index: the ship plane cut into CELL squares from [member _grid_origin], each
## listing, in ascending number, the surfaces whose areas reach into it — so a query
## meets its candidates in the order the full list would.
var _grid_origin := Vector2.ZERO
var _grid_size := Vector2i.ONE
var _cells: Array[PackedInt32Array] = []


func _init(layout: ShipLayout) -> void:
	_platforms = layout.platforms.duplicate()
	_ramps = layout.ramps.duplicate()
	_blockers = layout.blockers.duplicate()
	_railings = layout.railings.duplicate()
	for platform: ShipPlatform in _platforms:
		var bottom := -INF
		for other: ShipPlatform in _platforms:
			if other.height < platform.height and other.area.intersects(platform.area):
				bottom = platform.height
				break
		_platform_bottoms.append(bottom)
	for railing: ShipRailing in _railings:
		var normal := (railing.to - railing.from).normalized().orthogonal()
		var centre := _platforms[railing.platform].area.get_center()
		if (centre - railing.from).dot(normal) < 0.0:
			normal = -normal
		_rail_normals.append(normal)
	_index()


## How many surfaces there are, platforms, ramps and blocker tops together.
func count() -> int:
	return _platforms.size() + _ramps.size() + _blockers.size()


func platform_count() -> int:
	return _platforms.size()


func is_ramp(surface: int) -> bool:
	return surface >= _platforms.size() and surface < _platforms.size() + _ramps.size()


func _is_blocker_top(surface: int) -> bool:
	return surface >= _platforms.size() + _ramps.size()


## The surface number of the layout's ramp at [param ramp].
func ramp_surface(ramp: int) -> int:
	return _platforms.size() + ramp


## How high [param surface] stands under [param ship_point]'s x/z.
func height_at(surface: int, ship_point: Vector3) -> float:
	if is_ramp(surface):
		return _ramps[surface - _platforms.size()].height_at(ship_point.x, ship_point.z)
	if _is_blocker_top(surface):
		return _blocker_of(surface).top
	return _platforms[surface].height


## The surface a body with its feet at [param ship_point] stands on: the highest
## one under it whose height there is within [param step] of the feet, up or down.
## NONE when every surface under it is farther below than that — it falls — or there
## is none at all.
func under(ship_point: Vector3, step: float) -> int:
	var best := NONE
	var best_height := -INF
	for surface: int in _near(Rect2(Vector2(ship_point.x, ship_point.z), Vector2.ZERO)):
		if not _contains(surface, ship_point):
			continue
		var height := height_at(surface, ship_point)
		if absf(height - ship_point.y) <= step and height > best_height:
			best = surface
			best_height = height
	return best


## Where a body falling straight down from [param ship_point] lands: the highest
## surface under it at or below its height, or NONE when nothing is — the sea.
func landing(ship_point: Vector3) -> int:
	return _highest_at_or_below(ship_point, count())


## The platform or ramp a body on [param surface] walks on: a blocker top's is
## where a body stepping off its middle comes down, past any other blocker top, or
## NONE when that is the sea; any other surface is its own.
func footing(surface: int) -> int:
	if not _is_blocker_top(surface):
		return surface
	var middle := _area(surface).get_center()
	var below := Vector3(middle.x, _blocker_of(surface).bottom, middle.y)
	return _highest_at_or_below(below, _platforms.size() + _ramps.size())


## The platforms a ramp joins: at its start end, then at its end end — the platform
## at that end's height under the middle of that end's edge, or NONE, and NONE too
## when either corner of the edge stands over no platform at that height. A deck may
## be several platforms that touch, so an edge may run from one onto the next.
func joins(ramp_surface_id: int) -> PackedInt32Array:
	var ramp := _ramps[ramp_surface_id - _platforms.size()]
	var joined := PackedInt32Array()
	for end in 2:
		var edge := ramp.end_edge(end)
		var height := ramp.start_height if end == 0 else ramp.end_height
		var found := _platform_at(edge[0].lerp(edge[1], 0.5), height)
		if _platform_at(edge[0], height) == NONE or _platform_at(edge[1], height) == NONE:
			found = NONE
		joined.append(found)
	return joined


## What holds back a body [param body_height] tall with its feet at
## [param ship_point], a circle of [param radius]: every blocker its height
## overlaps, and every surface's edge too high above its feet to step onto but not
## clear overhead — a deck over another is a slab, a deck over none the top of a
## solid hull, a ramp a solid wedge. One contact per direction, the deepest.
func obstacle_contacts(
	ship_point: Vector3, radius: float, body_height: float, step: float
) -> Array[Contact]:
	var contacts: Array[Contact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	var feet := ship_point.y
	var near := _near(Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	var first_top := _platforms.size() + _ramps.size()
	for surface: int in near:
		if surface < first_top:
			continue
		var blocker := _blocker_of(surface)
		if not _overlaps(feet, body_height, step, blocker.bottom, blocker.top):
			continue
		var contact: Contact
		if blocker.shape == ShipBlocker.Shape.BOX:
			contact = _rect_contact(blocker.area, point, radius)
		else:
			contact = _circle_contact(blocker.centre, blocker.radius, point, radius)
		if contact != null:
			contacts.append(contact)
	for surface: int in near:
		if surface >= first_top:
			break
		var area := _area(surface)
		var closest := point.clamp(area.position, area.end)
		var top := height_at(surface, Vector3(closest.x, 0.0, closest.y))
		var bottom := (
			_ramps[surface - _platforms.size()].base()
			if is_ramp(surface)
			else _platform_bottoms[surface]
		)
		if not _overlaps(feet, body_height, step, bottom, top):
			continue
		var contact := (
			_climb_contact(_ramps[surface - _platforms.size()], point, radius, feet + step)
			if is_ramp(surface) and closest == point
			else _rect_contact(area, point, radius)
		)
		if contact != null:
			contacts.append(contact)
	return _deepest_per_direction(contacts)


## What holds back a circle of [param radius] whose centre at [param point] stands on
## [param ramp] where it rises above [param reach], the highest its feet can step this
## tick — carried up a steep stair faster than a step a tick, or onto its side: the
## least move of back down the ramp to where the rise runs out, or out through a side
## or the low end. Never out through the high end: past a stair's head is the deck it
## climbs to, standing over a wall or the hull.
static func _climb_contact(ramp: ShipRamp, point: Vector2, radius: float, reach: float) -> Contact:
	var x_axis := ramp.axis == ShipRamp.Axis.X
	var axis := 0 if x_axis else 1
	var length := ramp.area.size[axis]
	var along := point[axis] - ramp.area.position[axis]
	var rise := (ramp.end_height - ramp.start_height) / length
	var outward := Vector2.RIGHT if x_axis else Vector2.DOWN
	var high_end := outward if rise > 0.0 else -outward
	# A hair under the reach, so the feet find the ramp within a step when grounded.
	var limit := clampf((reach - CLIMB_MARGIN - ramp.start_height) / rise, 0.0, length)
	var best := Contact.new(-high_end, absf(along - limit) + CLIMB_MARGIN / absf(rise))
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
			best = Contact.new(side[1], side[0] + radius)
	return best


## Every railing of [param surface] that a circle of [param radius] centred on
## [param ship_point] overlaps, one per direction. A railing holds only along its
## span: a centre level with a gap is touching nothing.
func rail_contacts(ship_point: Vector3, radius: float, surface: int) -> Array[Contact]:
	var contacts: Array[Contact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	for index in _railings.size():
		if _railings[index].platform != surface:
			continue
		var contact := _rail_contact(index, point, radius)
		if contact != null:
			contacts.append(contact)
	return _deepest_per_direction(contacts)


## Every railing that holds back a body in the air [param body_height] tall with its
## feet at [param ship_point], a circle of [param radius] whose centre stood at
## [param came_from] (x/z) before it moved: one standing [param railing_height] on a
## deck the body overlaps in height — feet below the rail's top, head above its deck
## — whose span the circle overlaps, met from its platform's side, where the body
## came from. One per direction.
func airborne_rail_contacts(
	ship_point: Vector3,
	came_from: Vector2,
	radius: float,
	body_height: float,
	railing_height: float
) -> Array[Contact]:
	var contacts: Array[Contact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	for index in _railings.size():
		var railing := _railings[index]
		var deck := _platforms[railing.platform].height
		if ship_point.y >= deck + railing_height or ship_point.y + body_height <= deck:
			continue
		if (came_from - railing.from).dot(_rail_normals[index]) < 0.0:
			continue
		var contact := _rail_contact(index, point, radius)
		if contact != null:
			contacts.append(contact)
	return _deepest_per_direction(contacts)


## Whether the straight path from [param from_point] to [param to_point] (x/z)
## crosses a railing span of [param surface] — the only railings a body standing
## on it can meet.
func railed(from_point: Vector3, to_point: Vector3, surface: int) -> bool:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	for railing: ShipRailing in _railings:
		if railing.platform != surface:
			continue
		if Geometry2D.segment_intersects_segment(start, end, railing.from, railing.to) != null:
			return true
	return false


## Whether a blocker stands across the straight line from [param from_point] to
## [param to_point] (x/z) at the height of bodies [param body_height] tall with
## their feet at either end — what a shove cannot pass through. A blocker stands
## between them only where it rises into both, so one a body stands on top of never
## shields it.
func blocked(from_point: Vector3, to_point: Vector3, body_height: float, step: float) -> bool:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	for surface: int in _near(Rect2(start, Vector2.ZERO).expand(end)):
		if not _is_blocker_top(surface):
			continue
		var blocker := _blocker_of(surface)
		if not _overlaps(from_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		if not _overlaps(to_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			var nearest := Geometry2D.get_closest_point_to_segment(blocker.centre, start, end)
			if nearest.distance_to(blocker.centre) < blocker.radius:
				return true
		elif _segment_meets_rect(start, end, blocker.area):
			return true
	return false


## The stretches of the straight line from [param from_point] to [param to_point]
## (x/z) that no blocker stands across at the height of a body [param body_height]
## tall with its feet at [param from_point]'s height — the gaps between walls: each a
## (start, end) in metres from [param from_point], in order.
func clear_stretches(
	from_point: Vector3, to_point: Vector3, body_height: float, step: float
) -> PackedVector2Array:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	var length := start.distance_to(end)
	var covered: Array[Vector2] = []
	for blocker: ShipBlocker in _blockers:
		if not _overlaps(from_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		var span := (
			_segment_in_circle(start, end, blocker.centre, blocker.radius)
			if blocker.shape == ShipBlocker.Shape.CYLINDER
			else _segment_in_rect(start, end, blocker.area)
		)
		if span.x <= span.y:
			covered.append(span * length)
	covered.sort()
	var clear := PackedVector2Array()
	var reached := 0.0
	for span: Vector2 in covered:
		if span.x > reached:
			clear.append(Vector2(reached, span.x))
		reached = maxf(reached, span.y)
	if reached < length:
		clear.append(Vector2(reached, length))
	return clear


## Whether walking straight from [param from_point] (the feet) toward
## [param to_point]'s x/z, stepping up or down at most [param step] at a time,
## walks off an edge before a wall stops it.
func drops(from_point: Vector3, to_point: Vector3, step: float) -> bool:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	var samples := maxi(1, ceili(start.distance_to(end) / step))
	var feet := from_point.y
	for index in range(1, samples + 1):
		var at := start.lerp(end, float(index) / samples)
		var point := Vector3(at.x, feet, at.y)
		var surface := under(point, step)
		if surface == NONE:
			var highest := landing(Vector3(at.x, INF, at.y))
			return highest == NONE or height_at(highest, point) < feet
		feet = height_at(surface, point)
	return false


## Flooded is geometry (D7): below the sea plane under the schedule's pose.
func wet(ship_point: Vector3, pose: ShipPose) -> bool:
	return pose.world_height(ship_point) < 0.0


## Whether [param surface] is under the water at its middle.
func flooded(surface: int, pose: ShipPose) -> bool:
	return wet(_centre(surface), pose)


## How high the middle of [param surface] stands in the world under [param pose].
func world_height(surface: int, pose: ShipPose) -> float:
	return pose.world_height(_centre(surface))


## The platform whose middle stands highest in the world under [param pose]; ties
## go to the lower number.
func highest_platform(pose: ShipPose) -> int:
	var best := NONE
	var best_height := -INF
	for platform in _platforms.size():
		var height := world_height(platform, pose)
		if height > best_height:
			best = platform
			best_height = height
	return best


## The highest of the first [param surfaces] surfaces under [param ship_point] at
## or below its height; ties go to the lower number.
func _highest_at_or_below(ship_point: Vector3, surfaces: int) -> int:
	var best := NONE
	var best_height := -INF
	for surface: int in _near(Rect2(Vector2(ship_point.x, ship_point.z), Vector2.ZERO)):
		if surface >= surfaces:
			break
		if not _contains(surface, ship_point):
			continue
		var height := height_at(surface, ship_point)
		if height <= ship_point.y and height > best_height:
			best = surface
			best_height = height
	return best


## The first platform at [param height] whose area holds [param point] (x/z), or NONE.
func _platform_at(point: Vector2, height: float) -> int:
	for index in _platforms.size():
		var platform := _platforms[index]
		if is_equal_approx(platform.height, height) and platform.contains(point.x, point.y):
			return index
	return NONE


## The layout's railing at [param index] holding back a circle of [param radius] at
## [param point], or null when the circle is clear of it or level with no part of
## its span.
func _rail_contact(index: int, point: Vector2, radius: float) -> Contact:
	var railing := _railings[index]
	var span := railing.to - railing.from
	var along := (point - railing.from).dot(span) / span.length_squared()
	if along < 0.0 or along > 1.0:
		return null
	var inside := (point - railing.from).dot(_rail_normals[index])
	if absf(inside) >= radius:
		return null
	return Contact.new(_rail_normals[index], radius - inside)


## Builds the index over every surface's area — a cylinder's by its square.
func _index() -> void:
	if count() == 0:
		return
	var bounds := _area(0)
	for surface in count():
		bounds = bounds.merge(_area(surface))
	_grid_origin = bounds.position
	_grid_size = Vector2i(floori(bounds.size.x / CELL) + 1, floori(bounds.size.y / CELL) + 1)
	_cells.resize(_grid_size.x * _grid_size.y)
	for cell in _cells.size():
		_cells[cell] = PackedInt32Array()
	for surface in count():
		var area := _area(surface)
		var low := _cell_of(area.position)
		var high := _cell_of(area.end)
		for row in range(low.y, high.y + 1):
			for column in range(low.x, high.x + 1):
				_cells[row * _grid_size.x + column].append(surface)


## The cell holding [param point] (x/z), the nearest one for a point off the grid.
func _cell_of(point: Vector2) -> Vector2i:
	var at := (point - _grid_origin) / CELL
	return Vector2i(
		clampi(floori(at.x), 0, _grid_size.x - 1), clampi(floori(at.y), 0, _grid_size.y - 1)
	)


## The surfaces whose areas reach the cells [param box] (x/z) touches, in ascending
## number, each once: every surface whose area meets the box is among them.
func _near(box: Rect2) -> PackedInt32Array:
	if _cells.is_empty():
		return PackedInt32Array()
	var low := _cell_of(box.position)
	var high := _cell_of(box.end)
	if low == high:
		return _cells[low.y * _grid_size.x + low.x]
	var gathered := PackedInt32Array()
	for row in range(low.y, high.y + 1):
		for column in range(low.x, high.x + 1):
			gathered.append_array(_cells[row * _grid_size.x + column])
	gathered.sort()
	var found := PackedInt32Array()
	for surface: int in gathered:
		if found.is_empty() or found[found.size() - 1] != surface:
			found.append(surface)
	return found


func _blocker_of(surface: int) -> ShipBlocker:
	return _blockers[surface - _platforms.size() - _ramps.size()]


func _area(surface: int) -> Rect2:
	if is_ramp(surface):
		return _ramps[surface - _platforms.size()].area
	if _is_blocker_top(surface):
		var blocker := _blocker_of(surface)
		if blocker.shape == ShipBlocker.Shape.BOX:
			return blocker.area
		var corner := blocker.centre - Vector2(blocker.radius, blocker.radius)
		return Rect2(corner, Vector2(blocker.radius, blocker.radius) * 2.0)
	return _platforms[surface].area


func _contains(surface: int, ship_point: Vector3) -> bool:
	if is_ramp(surface):
		return _ramps[surface - _platforms.size()].contains(ship_point.x, ship_point.z)
	if _is_blocker_top(surface):
		var blocker := _blocker_of(surface)
		var point := Vector2(ship_point.x, ship_point.z)
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			return point.distance_to(blocker.centre) <= blocker.radius
		var area := blocker.area
		return (
			point.x >= area.position.x
			and point.x <= area.end.x
			and point.y >= area.position.y
			and point.y <= area.end.y
		)
	return _platforms[surface].contains(ship_point.x, ship_point.z)


## The middle of [param surface], at its height there.
func _centre(surface: int) -> Vector3:
	var middle := _area(surface).get_center()
	var point := Vector3(middle.x, 0.0, middle.y)
	point.y = height_at(surface, point)
	return point


## Whether a body [param body_height] tall with its feet at [param feet] meets
## something between [param bottom] and [param top] — it cannot step up onto it, and
## it is not clear overhead.
static func _overlaps(
	feet: float, body_height: float, step: float, bottom: float, top: float
) -> bool:
	return feet + step < top and feet + body_height > bottom


static func _rect_contact(rect: Rect2, point: Vector2, radius: float) -> Contact:
	var closest := point.clamp(rect.position, rect.end)
	var offset := point - closest
	var distance := offset.length()
	if distance > 0.0:
		return Contact.new(offset / distance, radius - distance) if distance < radius else null
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
	return Contact.new(nearest[1], nearest[0] + radius)


static func _circle_contact(
	centre: Vector2, circle_radius: float, point: Vector2, radius: float
) -> Contact:
	var offset := point - centre
	var distance := offset.length()
	if distance >= circle_radius + radius:
		return null
	var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
	return Contact.new(normal, circle_radius + radius - distance)


static func _segment_meets_rect(start: Vector2, end: Vector2, rect: Rect2) -> bool:
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
static func _segment_in_rect(start: Vector2, end: Vector2, rect: Rect2) -> Vector2:
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
static func _segment_in_circle(
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
static func _deepest_per_direction(contacts: Array[Contact]) -> Array[Contact]:
	var kept: Array[Contact] = []
	for contact: Contact in contacts:
		var merged := false
		for other: Contact in kept:
			if other.normal.is_equal_approx(contact.normal):
				other.depth = maxf(other.depth, contact.depth)
				merged = true
				break
		if not merged:
			kept.append(contact)
	return kept
