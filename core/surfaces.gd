class_name Surfaces
extends RefCounted
## The only door to spatial questions about the ship (D6, D13): what a body stands
## on within a step, how high a surface is under a point, where a falling body
## lands, what holds a body back in the deck plane, whether a shove's line is
## blocked, whether a walk ends in a drop, and whether a point is wet. Surfaces are
## numbered platforms first, then ramps, then blocker tops, each in layout order. A
## blocker's top is stood on and landed on like a platform's. Nothing here assumes
## a size or a deck count, so a spatial index can arrive behind it (SH18).

const NONE := -1


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


## How many surfaces there are, platforms, ramps and blocker tops together.
func count() -> int:
	return _platforms.size() + _ramps.size() + _blockers.size()


func platform_count() -> int:
	return _platforms.size()


func is_ramp(surface: int) -> bool:
	return surface >= _platforms.size() and surface < _platforms.size() + _ramps.size()


func is_blocker_top(surface: int) -> bool:
	return surface >= _platforms.size() + _ramps.size()


## The surface number of the layout's ramp at [param ramp].
func ramp_surface(ramp: int) -> int:
	return _platforms.size() + ramp


## How high [param surface] stands under [param ship_point]'s x/z.
func height_at(surface: int, ship_point: Vector3) -> float:
	if is_ramp(surface):
		return _ramps[surface - _platforms.size()].height_at(ship_point.x, ship_point.z)
	if is_blocker_top(surface):
		return _blocker_of(surface).top
	return _platforms[surface].height


## The surface a body with its feet at [param ship_point] stands on: the highest
## one under it whose height there is within [param step] of the feet, up or down.
## NONE when every surface under it is farther below than that — it falls — or there
## is none at all.
func under(ship_point: Vector3, step: float) -> int:
	var best := NONE
	var best_height := -INF
	for surface in count():
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
	if not is_blocker_top(surface):
		return surface
	var middle := _area(surface).get_center()
	var below := Vector3(middle.x, _blocker_of(surface).bottom, middle.y)
	return _highest_at_or_below(below, _platforms.size() + _ramps.size())


## The platforms a ramp joins: at its start end, then at its end end — the
## platform at that end's height whose area holds that end's whole edge, or NONE.
func joins(ramp_surface_id: int) -> PackedInt32Array:
	var ramp := _ramps[ramp_surface_id - _platforms.size()]
	var joined := PackedInt32Array()
	for end in 2:
		var edge := ramp.end_edge(end)
		var height := ramp.start_height if end == 0 else ramp.end_height
		var found := NONE
		for index in _platforms.size():
			var platform := _platforms[index]
			if (
				is_equal_approx(platform.height, height)
				and platform.contains(edge[0].x, edge[0].y)
				and platform.contains(edge[1].x, edge[1].y)
			):
				found = index
				break
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
	for blocker: ShipBlocker in _blockers:
		if not _overlaps(feet, body_height, step, blocker.bottom, blocker.top):
			continue
		var contact: Contact
		if blocker.shape == ShipBlocker.Shape.BOX:
			contact = _rect_contact(blocker.area, point, radius)
		else:
			contact = _circle_contact(blocker.centre, blocker.radius, point, radius)
		if contact != null:
			contacts.append(contact)
	for surface in _platforms.size() + _ramps.size():
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
		var contact := _rect_contact(area, point, radius)
		if contact != null:
			contacts.append(contact)
	return _deepest_per_direction(contacts)


## Every railing of [param surface] that a circle of [param radius] centred on
## [param ship_point] overlaps, one per direction. A railing holds only along its
## span: a centre level with a gap is touching nothing.
func rail_contacts(ship_point: Vector3, radius: float, surface: int) -> Array[Contact]:
	var contacts: Array[Contact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	for index in _railings.size():
		var railing := _railings[index]
		if railing.platform != surface:
			continue
		var span := railing.to - railing.from
		var along := (point - railing.from).dot(span) / span.length_squared()
		if along < 0.0 or along > 1.0:
			continue
		var inside := (point - railing.from).dot(_rail_normals[index])
		if absf(inside) < radius:
			contacts.append(Contact.new(_rail_normals[index], radius - inside))
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
## [param to_point] (x/z) at the height of a body [param body_height] tall with its
## feet at [param from_point] — what a shove cannot pass through.
func blocked(from_point: Vector3, to_point: Vector3, body_height: float, step: float) -> bool:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	for blocker: ShipBlocker in _blockers:
		if not _overlaps(from_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			var nearest := Geometry2D.get_closest_point_to_segment(blocker.centre, start, end)
			if nearest.distance_to(blocker.centre) < blocker.radius:
				return true
		elif _segment_meets_rect(start, end, blocker.area):
			return true
	return false


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
	for surface in surfaces:
		if not _contains(surface, ship_point):
			continue
		var height := height_at(surface, ship_point)
		if height <= ship_point.y and height > best_height:
			best = surface
			best_height = height
	return best


func _blocker_of(surface: int) -> ShipBlocker:
	return _blockers[surface - _platforms.size() - _ramps.size()]


func _area(surface: int) -> Rect2:
	if is_ramp(surface):
		return _ramps[surface - _platforms.size()].area
	if is_blocker_top(surface):
		var blocker := _blocker_of(surface)
		if blocker.shape == ShipBlocker.Shape.BOX:
			return blocker.area
		var corner := blocker.centre - Vector2(blocker.radius, blocker.radius)
		return Rect2(corner, Vector2(blocker.radius, blocker.radius) * 2.0)
	return _platforms[surface].area


func _contains(surface: int, ship_point: Vector3) -> bool:
	if is_ramp(surface):
		return _ramps[surface - _platforms.size()].contains(ship_point.x, ship_point.z)
	if is_blocker_top(surface):
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
