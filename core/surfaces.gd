class_name Surfaces
extends RefCounted
## The only door to spatial questions about the ship (D6, D13): what a body stands
## on within a step, how high a surface is under a point, where a falling body
## lands, what holds a body back in the deck plane, whether a shove's line is
## blocked, whether one body's eyes see another's, whether a walk ends in a drop,
## whether a point is wet, and where a swimmer climbs out of the sea. Surfaces are
## numbered platforms first, then ramps, then blocker tops, each in layout order. A
## blocker's top is stood on and landed on like a platform's; a wall is a blocker
## and its doorways are the gaps between walls. Nothing here assumes a size or a deck
## count, and nothing reads the layout's rooms. What still stands is the pose's to say
## (D7): a collapsed platform, its ladders and a failed railing are gone from every
## answer once honour() has been handed a pose that says so. The match's own state
## comes in the same way (SH10): the railings it has broken are gone like failed
## ones, and its crates stand where it says — each an upright circle that holds a
## body back as a round blocker does, and whose lid, surface count() + its index, is
## stood on and landed on like a blocker's top.

const NONE := -1
## The side of a cell of the spatial index, in metres. Rooms made the steamer's
## surfaces six times as many as SH3's, so every query looks only at the surfaces
## whose areas reach the cells it touches — the first of SH18's index, behind this
## same door.
const CELL := 1.0
## How far under a step's reach a body slammed up a ramp is held, so that its feet
## still find the ramp within a step.
const CLIMB_MARGIN := 0.001
## How much of a floor's clearance under() leaves unused: a ramp's height between
## its ends may round past them.
const CLEARANCE_SLACK := 0.000001


## A body's circle overlapping something that holds it back.
class Contact:
	## Unit vector in the ship plane (x, z), from what was touched toward the body.
	var normal: Vector2
	## How far the circle reaches into it.
	var depth: float
	## The layout's railing it is, by index, or -1 for anything else.
	var railing: int

	func _init(outward: Vector2, overlap: float, span: int = -1) -> void:
		normal = outward
		depth = overlap
		railing = span


## A way out of the sea: where the climb puts a swimmer's feet, standing, and on
## which surface.
class Climb:
	var stand: Vector3
	var surface: int

	func _init(feet: Vector3, onto: int) -> void:
		stand = feet
		surface = onto


var _platforms: Array[ShipPlatform] = []
var _ramps: Array[ShipRamp] = []
var _blockers: Array[ShipBlocker] = []
var _railings: Array[ShipRailing] = []
## Per railing, the unit normal pointing onto its platform.
var _rail_normals := PackedVector2Array()
## Per platform, its railings in layout order: a body on a deck meets no other.
var _platform_rails: Array[PackedInt32Array] = []
var _ladders: Array[ShipLadder] = []
## Per crate, its radius and height, and where its underside stands as the last
## honour() was told.
var _prop_radii := PackedFloat64Array()
var _prop_heights := PackedFloat64Array()
var _prop_feet := PackedVector3Array()
## The numbers of the first ramp, the first blocker top and the first crate's lid:
## every surface before the lids is the ship's own.
var _first_ramp: int
var _first_top: int
var _first_lid: int
## Per ladder, the unit normal pointing onto its platform.
var _ladder_normals := PackedVector2Array()
## The index: the ship plane cut into CELL squares from [member _grid_origin], each
## listing, in ascending number, the surfaces whose areas reach into it — so a query
## meets its candidates in the order the full list would.
var _grid_origin := Vector2.ZERO
var _grid_size := Vector2i.ONE
var _cells: Array[PackedInt32Array] = []
## The surfaces of each block of cells a query has touched, by its corner cells: the
## index never changes, so a block is gathered once.
var _blocks: Dictionary[Vector4i, PackedInt32Array] = {}
## Per surface, 1 while it is gone: a collapsed platform, and the tops of the blockers
## standing flush under it — the roof's edge goes with the roof; and, after them, per
## crate, 1 while honour() has not been told where it stands, or it is lost.
var _gone := PackedByteArray()
## Per railing, 1 while it has failed, or its platform is gone.
var _rail_gone := PackedByteArray()
## What the last pose honoured said, so an unchanged one costs nothing.
var _honoured_collapsed: Array[StringName] = []
var _honoured_broken := PackedInt32Array()
## The last pose honour() was handed, and the railings the match had broken with it.
var _honoured_pose: ShipPose
var _honoured_by_match := PackedInt32Array()
## Per surface, its area, and how low its sides reach and how high it stands — what
## holds a body back and hides what is behind it: a blocker from its bottom to its
## top, a ramp from its base to its high end, a deck at its height — a deck over a
## lower one is a slab, and a deck over none the top of the hull, solid all the way
## down.
var _areas: Array[Rect2] = []
var _bottoms := PackedFloat64Array()
var _tops := PackedFloat64Array()
## 1 for a level rectangle — a platform, a box's top — whose area and top are all there
## is to standing on it.
var _level_rects := PackedByteArray()
## Per cell of the index: its platforms, and for each the nearest the height of any
## other surface of the cell comes to it — a body on it with a step short of that
## stands on it and nothing else there, but for a crate.
var _floors: Array[PackedInt32Array] = []
var _floor_clearances: Array[PackedFloat64Array] = []
## The watertight doors, as far shut as the last pose honoured has them; and her
## funnels, lying where the last one has them fallen.
var _doors: DoorLeaves
var _fallen: FallenFunnels


func _init(layout: ShipLayout) -> void:
	_platforms = layout.platforms.duplicate()
	_ramps = layout.ramps.duplicate()
	_blockers = layout.blockers.duplicate()
	_railings = layout.railings.duplicate()
	_ladders = layout.ladders.duplicate()
	for prop: ShipProp in layout.props:
		_prop_radii.append(prop.radius)
		_prop_heights.append(prop.height)
	for platform in _platforms.size():
		_platform_rails.append(PackedInt32Array())
	for index in _railings.size():
		var railing := _railings[index]
		_rail_normals.append(_onto(railing.platform, railing.from, railing.to))
		_platform_rails[railing.platform].append(index)
	for ladder: ShipLadder in _ladders:
		_ladder_normals.append(_onto(ladder.platform, ladder.from, ladder.to))
	_first_ramp = _platforms.size()
	_first_top = _first_ramp + _ramps.size()
	_first_lid = count()
	_index()
	_gone.resize(_first_lid + _prop_radii.size())
	_prop_feet.resize(_prop_radii.size())
	_rail_gone.resize(_railings.size())
	for surface in count():
		_areas.append(_area(surface))
		if is_ramp(surface):
			var ramp := _ramps[surface - _first_ramp]
			_bottoms.append(ramp.base())
			_tops.append(maxf(ramp.start_height, ramp.end_height))
		elif _is_blocker_top(surface):
			_bottoms.append(_blocker_of(surface).bottom)
			_tops.append(_blocker_of(surface).top)
		else:
			_bottoms.append(_platform_bottom(surface))
			_tops.append(_platforms[surface].height)
		_level_rects.append(0 if is_ramp(surface) or _is_round_top(surface) else 1)
	_index_floors()
	_stand_props([])
	_doors = DoorLeaves.new(layout.structure)
	_fallen = FallenFunnels.new(layout)


## Takes [param pose]'s collapsed platforms, failed railings and shut watertight
## doors as the ship's until the next pose, with the railings [param broken] by the
## match and its crates where [param props] has them: whoever asks about a tick hands
## its pose here first. Holds nothing it is not handed, so a match resumed from a
## snapshot stands on the same ship.
func honour(pose: ShipPose, broken := PackedInt32Array(), props: Array[PropState] = []) -> void:
	# A pose is a value, never changed once handed in: the same one with the same
	# broken spans masks what it last masked. The cargo honours many times a tick. A
	# copy, so a caller's list edited in place is not the one compared.
	if pose != _honoured_pose or broken != _honoured_by_match:
		_honoured_pose = pose
		_doors.honour(pose)
		if _fallen.honour(pose):
			for surface in range(_first_top, _first_lid):
				_tops[surface] = _fallen.top_of(surface - _first_top, _blocker_of(surface).top)
		_honoured_by_match = broken.duplicate()
		var failed := pose.broken_railings.duplicate()
		failed.append_array(broken)
		_mask(pose.collapsed, failed)
	_stand_props(props)


## Stands each crate of [param props] where it has it, and none of the others.
func _stand_props(props: Array[PropState]) -> void:
	for prop in _prop_radii.size():
		_gone[_first_lid + prop] = 1
	for crate: PropState in props:
		if not crate.is_lost():
			_prop_feet[crate.prop] = crate.pos
			_gone[_first_lid + crate.prop] = 0


## Takes the platforms [param collapsed] and the railings [param failed] as gone, and
## the railings of a platform gone with it.
func _mask(collapsed: Array[StringName], failed: PackedInt32Array) -> void:
	if collapsed == _honoured_collapsed and failed == _honoured_broken:
		return
	_honoured_collapsed = collapsed.duplicate()
	_honoured_broken = failed
	for surface in count():
		_gone[surface] = 0
	_rail_gone.fill(0)
	var first_top := _platforms.size() + _ramps.size()
	for platform in _platforms.size():
		if not _platforms[platform].name in collapsed:
			continue
		_gone[platform] = 1
		var under_it := _platforms[platform].area.grow(ShipPlatform.EDGE)
		for surface in range(first_top, count()):
			if (
				is_equal_approx(_blocker_of(surface).top, _platforms[platform].height)
				and under_it.encloses(_area(surface))
			):
				_gone[surface] = 1
	for index in _railings.size():
		if index in failed or _gone[_railings[index].platform] == 1:
			_rail_gone[index] = 1


## How many surfaces there are, platforms, ramps and blocker tops together; the
## crates' lids are numbered after them.
func count() -> int:
	return _platforms.size() + _ramps.size() + _blockers.size()


func platform_count() -> int:
	return _platforms.size()


func is_ramp(surface: int) -> bool:
	return surface >= _first_ramp and surface < _first_top


func _is_blocker_top(surface: int) -> bool:
	return surface >= _first_top and surface < _first_lid


func _is_prop_top(surface: int) -> bool:
	return surface >= _first_lid


## The surface number of the layout's ramp at [param ramp].
func ramp_surface(ramp: int) -> int:
	return _platforms.size() + ramp


## How high [param surface] stands under [param ship_point]'s x/z.
func height_at(surface: int, ship_point: Vector3) -> float:
	if surface >= _first_lid:
		return _prop_feet[surface - _first_lid].y + _prop_heights[surface - _first_lid]
	if surface >= _first_top:
		return _tops[surface]
	if surface >= _first_ramp:
		return _ramps[surface - _first_ramp].height_at(ship_point.x, ship_point.z)
	return _platforms[surface].height


## The surface a body with its feet at [param ship_point] stands on: the highest
## one under it whose height there is within [param step] of the feet, up or down —
## never the lid of the crate [param except_prop]. NONE when every surface under it
## is farther below than that — it falls — or there is none at all.
func under(ship_point: Vector3, step: float, except_prop: int = NONE) -> int:
	var best := NONE
	var best_height := -INF
	var x := ship_point.x
	var z := ship_point.z
	# _contains and height_at written out for a level rectangle, and the crates' lids
	# after the cell's surfaces as _with_lids has them: the bots ask this at every step
	# they probe. Feet level with a floor clear of the rest of its cell stand on it.
	var near := PackedInt32Array()
	var cell := _cell_index(ship_point)
	if cell != NONE:
		near = _cells[cell]
		var floors := _floors[cell]
		for index in floors.size():
			var floor_surface := floors[index]
			var area := _areas[floor_surface]
			if (
				_tops[floor_surface] == ship_point.y
				and step < _floor_clearances[cell][index]
				and _gone[floor_surface] == 0
				and x >= area.position.x
				and x <= area.end.x
				and z >= area.position.y
				and z <= area.end.y
			):
				best = floor_surface
				best_height = ship_point.y
				near = PackedInt32Array()
				break
	for surface: int in near:
		if _gone[surface] == 1:
			continue
		var height: float
		if _level_rects[surface] == 1:
			var area := _areas[surface]
			if not (
				x >= area.position.x
				and x <= area.end.x
				and z >= area.position.y
				and z <= area.end.y
			):
				continue
			height = _tops[surface]
		elif _contains(surface, ship_point):
			height = height_at(surface, ship_point)
		else:
			continue
		if absf(height - ship_point.y) <= step and height > best_height:
			best = surface
			best_height = height
	for prop in _prop_radii.size():
		var feet := _prop_feet[prop]
		if prop == except_prop or _gone[_first_lid + prop] == 1:
			continue
		if not (Vector2(x - feet.x, z - feet.z).length() <= _prop_radii[prop]):
			continue
		var height := feet.y + _prop_heights[prop]
		if absf(height - ship_point.y) <= step and height > best_height:
			best = _first_lid + prop
			best_height = height
	return best


## Where a body falling straight down from [param ship_point] lands: the highest
## surface under it at or below its height — never the lid of the crate
## [param except_prop] — or NONE when nothing is: the sea.
func landing(ship_point: Vector3, except_prop: int = NONE) -> int:
	return _highest_at_or_below(ship_point, _gone.size(), except_prop)


## How high a head rising from [param ship_point] may go: the lowest underside over
## it — a deck's, a ramp's, a blocker's, one still standing — more than
## [param clearance] above the feet, or INF when nothing is. Anything nearer the
## feet than that is underfoot.
func ceiling(ship_point: Vector3, clearance: float) -> float:
	var lowest := INF
	for surface: int in _at(ship_point):
		if _gone[surface] == 1 or not _contains(surface, ship_point):
			continue
		var underside := _underside(surface)
		if underside > ship_point.y + clearance:
			lowest = minf(lowest, underside)
	return lowest


## The platform or ramp a body on [param surface] walks on: a blocker top's is
## where a body stepping off its middle comes down, past any other blocker top, or
## NONE when that is the sea; any other surface is its own.
func footing(surface: int) -> int:
	if _is_prop_top(surface):
		if _gone[surface] == 1:
			return NONE
		return _highest_at_or_below(
			_prop_feet[surface - _first_lid], _platforms.size() + _ramps.size()
		)
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
## [param ship_point], a circle of [param radius]: every blocker and crate — but the
## crate [param except_prop] — its height overlaps, and every surface's edge too high
## above its feet to step onto but not clear overhead — a deck over another is a
## slab, a deck over none the top of a solid hull, a ramp a solid wedge. One contact
## per direction, the deepest.
func obstacle_contacts(
	ship_point: Vector3, radius: float, body_height: float, step: float, except_prop: int = NONE
) -> Array[Contact]:
	var contacts: Array[Contact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	var feet := ship_point.y
	# _overlaps' two heights, once: what the body can step onto stands under the first,
	# and its head is at the second.
	var reach_up := feet + step
	var head := feet + body_height
	var near := _near(Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	for surface: int in near:
		if surface < _first_top:
			continue
		if not (reach_up < _tops[surface] and head > _bottoms[surface]):
			continue
		var blocker := _blocker_of(surface)
		var contact: Contact
		if blocker.shape == ShipBlocker.Shape.BOX:
			contact = PlaneShapes.rect_contact(blocker.area, point, radius)
		else:
			contact = PlaneShapes.circle_contact(blocker.centre, blocker.radius, point, radius)
		if contact != null:
			contacts.append(contact)
	for surface: int in near:
		if surface >= _first_top:
			break
		if _gone[surface] == 1:
			continue
		var area := _areas[surface]
		var closest := point.clamp(area.position, area.end)
		var top := height_at(surface, Vector3(closest.x, 0.0, closest.y))
		if not (reach_up < top and head > _bottoms[surface]):
			continue
		var contact := (
			_climb_contact(_ramps[surface - _first_ramp], point, radius, reach_up)
			if surface >= _first_ramp and closest == point
			else PlaneShapes.rect_contact(area, point, radius)
		)
		if contact != null:
			contacts.append(contact)
	for prop in _prop_radii.size():
		var under_it := _prop_feet[prop]
		if prop == except_prop or _gone[_first_lid + prop] == 1:
			continue
		# A crate a reach away along either axis is farther than that: clear of the circle.
		var offset := point - Vector2(under_it.x, under_it.z)
		var reach := _prop_radii[prop] + radius
		if absf(offset.x) >= reach or absf(offset.y) >= reach:
			continue
		if not (reach_up < under_it.y + _prop_heights[prop] and head > under_it.y):
			continue
		var centre := Vector2(under_it.x, under_it.z)
		var contact := PlaneShapes.circle_contact(centre, _prop_radii[prop], point, radius)
		if contact != null:
			contacts.append(contact)
	contacts.append_array(_doors.contacts(point, reach_up, head, radius))
	contacts.append_array(_fallen.contacts(point, reach_up, head, radius))
	return PlaneShapes.deepest_per_direction(contacts)


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
	if surface < 0 or surface >= _platforms.size():
		return contacts
	var point := Vector2(ship_point.x, ship_point.z)
	for index: int in _platform_rails[surface]:
		if _rail_gone[index] == 1:
			continue
		var contact := _rail_contact(index, point, radius)
		if contact != null:
			contacts.append(contact)
	return PlaneShapes.deepest_per_direction(contacts)


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
		if _rail_gone[index] == 1:
			continue
		var railing := _railings[index]
		var deck := _platforms[railing.platform].height
		if ship_point.y >= deck + railing_height or ship_point.y + body_height <= deck:
			continue
		if (came_from - railing.from).dot(_rail_normals[index]) < 0.0:
			continue
		var contact := _rail_contact(index, point, radius)
		if contact != null:
			contacts.append(contact)
	return PlaneShapes.deepest_per_direction(contacts)


## Whether the straight path from [param from_point] to [param to_point] (x/z)
## crosses a railing span of [param surface] — the only railings a body standing
## on it can meet.
func railed(from_point: Vector3, to_point: Vector3, surface: int) -> bool:
	if surface < 0 or surface >= _platforms.size():
		return false
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	for index: int in _platform_rails[surface]:
		var railing := _railings[index]
		if _rail_gone[index] == 1:
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
	var feet := minf(from_point.y, to_point.y) + step
	var head := maxf(from_point.y, to_point.y) + body_height
	if _doors.crossed(start, end, feet, head) or _fallen.crossed(start, end, feet, head):
		return true
	for surface: int in _near(Rect2(start, Vector2.ZERO).expand(end)):
		if not _is_blocker_top(surface):
			continue
		var blocker := _blocker_of(surface)
		if not PlaneShapes.overlaps(from_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		if not PlaneShapes.overlaps(to_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			var nearest := Geometry2D.get_closest_point_to_segment(blocker.centre, start, end)
			if nearest.distance_to(blocker.centre) < blocker.radius:
				return true
		elif PlaneShapes.segment_meets_rect(start, end, blocker.area):
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
		if not PlaneShapes.overlaps(from_point.y, body_height, step, blocker.bottom, blocker.top):
			continue
		var span := (
			PlaneShapes.segment_in_circle(start, end, blocker.centre, blocker.radius)
			if blocker.shape == ShipBlocker.Shape.CYLINDER
			else PlaneShapes.segment_in_rect(start, end, blocker.area)
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


## Whether nothing stands between the eyes at [param from_point] and
## [param to_point] (ship space) to hide one from the other under [param pose]: no
## blocker — a wall, a funnel — no deck or stair still standing, and not the hull, a
## deck over none being solid all the way down. The gaps between walls and the
## openings a deck leaves over a stair hide nothing, so doorways and companionways are
## seen through; nor does a crate or a railing, as neither stops a shove's line. The
## one answer to who sees whom (D13): the bots' view and the
## first-person HUD's marks both ask it.
func line_of_sight(from_point: Vector3, to_point: Vector3, pose: ShipPose) -> bool:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	var low := minf(from_point.y, to_point.y)
	var high := maxf(from_point.y, to_point.y)
	if _doors.crossed(start, end, low, high) or _fallen.crossed(start, end, low, high):
		return false
	var reach := Rect2(start, Vector2.ZERO).expand(end)
	for surface in count():
		if _tops[surface] <= low or _bottoms[surface] >= high:
			continue
		var area := _areas[surface]
		if not area.intersects(reach, true):
			continue
		if surface < _platforms.size():
			if _platforms[surface].name in pose.collapsed:
				continue
			if _bottoms[surface] == _tops[surface]:
				# A deck over another is a slab: the line is hidden where it crosses it.
				var share := (_tops[surface] - from_point.y) / (to_point.y - from_point.y)
				if area.has_point(start.lerp(end, share)):
					return false
				continue
		var span := (
			PlaneShapes.segment_in_circle(
				start, end, _blocker_of(surface).centre, _blocker_of(surface).radius
			)
			if _is_round_top(surface)
			else PlaneShapes.segment_in_rect(start, end, area)
		)
		if span.x > span.y:
			continue
		var first := from_point.lerp(to_point, span.x)
		var last := from_point.lerp(to_point, span.y)
		if is_ramp(surface):
			# A stair is a solid wedge: hidden where the line runs under its slope.
			for at: Vector3 in [first, last]:
				if at.y < height_at(surface, at) and at.y > _bottoms[surface]:
					return false
		elif minf(first.y, last.y) < _tops[surface] and maxf(first.y, last.y) > _bottoms[surface]:
			return false
	return true


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


## Flooded is geometry (D7): below the water [param ship_point] is in under the
## schedule's pose — its cell's, found by the pose's CellMap, or the sea's outside her.
func wet(ship_point: Vector3, pose: ShipPose) -> bool:
	var height := pose.world_height(ship_point)
	return height < pose.highest_water() and height < pose.water_level(ship_point)


## Whether [param surface] is under the water at its middle.
func flooded(surface: int, pose: ShipPose) -> bool:
	return wet(_centre(surface), pose)


## How high the middle of [param surface] stands in the world under [param pose].
func world_height(surface: int, pose: ShipPose) -> float:
	return pose.world_height(_centre(surface))


## The platform still standing whose middle stands highest in the world under
## [param pose]; ties go to the lower number.
func highest_platform(pose: ShipPose) -> int:
	var best := NONE
	var best_height := -INF
	for platform in _platforms.size():
		if _platforms[platform].name in pose.collapsed:
			continue
		var height := world_height(platform, pose)
		if height > best_height:
			best = platform
			best_height = height
	return best


## Whether every surface still standing is more than [param depth] under the sea
## under [param pose], all over: the ship is gone.
func sunk(pose: ShipPose, depth: float) -> bool:
	for surface in count():
		if _gone[surface] == 1:
			continue
		var area := _area(surface)
		for corner: Vector2 in [
			area.position,
			Vector2(area.end.x, area.position.y),
			area.end,
			Vector2(area.position.x, area.end.y)
		]:
			var at := Vector3(corner.x, 0.0, corner.y)
			at.y = height_at(surface, at)
			if pose.world_height(at) > -depth:
				return false
	return true


## Where a swimmer with its feet at [param feet] gets out of the sea under
## [param pose] pressing along [param toward] (a unit vector, x/z), a body as
## [param rules] size it: up a standing ladder it is at, however high; else onto the surface
## past an edge within a radius of its circle that holds it back and stands no more
## than climb_reach above the water it swims in — a railing never stops it, a deck over
## its head too low to stand up under does: in a pocket it climbs onto a dry face inside
## it (Q22), never up through the ceiling or out over a wall under it. Either way the
## climb
## ends with the circle on a surface a radius past that edge — a deck, a stair or a
## box's top, never a round blocker's — under less than wade_depth of the sea, clear
## of everything that would hold it back, with no wall across the way at that height.
## Null when there is no way out there.
func climb_out(feet: Vector3, toward: Vector2, pose: ShipPose, rules: BrawlRules) -> Climb:
	var radius := rules.body_radius
	var step := rules.step_height
	var point := Vector2(feet.x, feet.z)
	for index in _ladders.size():
		var normal := _ladder_normals[index]
		var ladder := _ladders[index]
		if _gone[ladder.platform] == 1 or toward.dot(normal) <= 0.0:
			continue
		var at := Geometry2D.get_closest_point_to_segment(point, ladder.from, ladder.to)
		if (at - point).dot(normal) <= 0.0 or point.distance_to(at) > radius * 2.0:
			continue
		var top := _platforms[ladder.platform].height
		if top <= feet.y + step:
			continue
		var climb := _standing(feet, at + normal * radius * 2.0, top, pose, rules)
		if climb != null:
			return climb
	var probe := point + toward * radius * 2.0
	var limit := pose.water_height(feet) + rules.climb_reach
	var ledge := landing(Vector3(probe.x, limit, probe.y))
	if ledge == NONE or _contains(ledge, feet):
		return null
	var top := height_at(ledge, Vector3(probe.x, 0.0, probe.y))
	if top <= feet.y + step or top + rules.body_height > ceiling(feet, step):
		return null
	return _standing(feet, point + toward * radius * 3.0, top, pose, rules)


## The way out of the sea nearest a swimmer with its feet at [param feet], within
## [param within] across the water and with no wall across the swim: a ladder, or
## the point of a surface nearest the swimmer — a ramp's, moved along it to the
## waterline — when that point stands within climb_reach above the sea and no deeper
## than wade_depth under it, and climb_out finds a way up there. A surface whose
## nearest point is out of reach is passed over, even where another part of it is
## not. Null when there is none.
func nearest_climb(feet: Vector3, pose: ShipPose, rules: BrawlRules, within: float) -> Climb:
	var point := Vector2(feet.x, feet.z)
	var edges := PackedVector2Array()
	var towards := PackedVector2Array()
	for index in _ladders.size():
		var ladder := _ladders[index]
		if _gone[ladder.platform] == 1:
			continue
		var at := Geometry2D.get_closest_point_to_segment(point, ladder.from, ladder.to)
		if (at - point).dot(_ladder_normals[index]) > 0.0:
			edges.append(at)
			towards.append(_ladder_normals[index])
	var box := Rect2(point - Vector2(within, within), Vector2(within, within) * 2.0)
	var water := pose.water_height(feet)
	for surface: int in _near(box):
		if _gone[surface] == 1 or _is_round_top(surface):
			continue
		var at := _waterline_point(surface, point, water)
		var above := height_at(surface, Vector3(at.x, 0.0, at.y)) - water
		if above < -rules.wade_depth or above > rules.climb_reach or at.is_equal_approx(point):
			continue
		edges.append(at)
		towards.append((at - point).normalized())
	var best: Climb = null
	var best_distance := within
	for index in edges.size():
		var distance := point.distance_to(edges[index])
		if distance >= best_distance:
			continue
		var touching := edges[index] - towards[index] * rules.body_radius
		var from := Vector3(touching.x, feet.y, touching.y)
		if blocked(feet, from, rules.body_height, rules.step_height):
			continue
		var climb := climb_out(from, towards[index], pose, rules)
		if climb != null:
			best = climb
			best_distance = distance
	return best


## The highest of the first [param surfaces] surfaces — crates' lids last, but
## [param except_prop]'s — under [param ship_point] at or below its height; ties go
## to the lower number.
func _highest_at_or_below(ship_point: Vector3, surfaces: int, except_prop: int = NONE) -> int:
	var best := NONE
	var best_height := -INF
	for surface: int in _with_lids(_at(ship_point), ship_point, except_prop):
		if surface >= surfaces:
			break
		if _gone[surface] == 1 or not _contains(surface, ship_point):
			continue
		var height := height_at(surface, ship_point)
		if height <= ship_point.y and height > best_height:
			best = surface
			best_height = height
	return best


## The unit normal of the segment [param from]–[param to] along [param platform]'s
## edge that points onto the platform.
func _onto(platform: int, from: Vector2, to: Vector2) -> Vector2:
	var normal := (to - from).normalized().orthogonal()
	if (_platforms[platform].area.get_center() - from).dot(normal) < 0.0:
		normal = -normal
	return normal


## A swimmer at [param feet] climbing up onto [param top] to stand at [param stand]
## (x/z): on the surface there within a step, out of the sea under [param pose] as
## far as wading, with nothing holding it back and no wall across the way at that
## height; null when it cannot.
func _standing(
	feet: Vector3, stand: Vector2, top: float, pose: ShipPose, rules: BrawlRules
) -> Climb:
	var step := rules.step_height
	var at := Vector3(stand.x, top, stand.y)
	var surface := under(at, step)
	if surface == NONE or _is_round_top(surface):
		return null
	at.y = height_at(surface, at)
	if pose.water_height(at) - at.y >= rules.wade_depth:
		return null
	if not obstacle_contacts(at, rules.body_radius, rules.body_height, step).is_empty():
		return null
	if blocked(Vector3(feet.x, at.y, feet.z), at, rules.body_height, step):
		return null
	return Climb.new(at, surface)


## The point of [param surface] nearest [param point] (x/z) — on a ramp, moved along
## it to where it meets the water at [param water], when it can.
func _waterline_point(surface: int, point: Vector2, water: float) -> Vector2:
	var area := _area(surface)
	var at := point.clamp(area.position, area.end)
	if not is_ramp(surface):
		return at
	var ramp := _ramps[surface - _platforms.size()]
	var axis := 0 if ramp.axis == ShipRamp.Axis.X else 1
	var share := (water - ramp.start_height) / (ramp.end_height - ramp.start_height)
	at[axis] = area.position[axis] + area.size[axis] * clampf(share, 0.0, 1.0)
	return at


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
	var offset := point - railing.from
	# Clear of its line first: most railings a body is asked about are.
	var inside := offset.dot(_rail_normals[index])
	if absf(inside) >= radius:
		return null
	var span := railing.to - railing.from
	var along := offset.dot(span) / span.length_squared()
	if along < 0.0 or along > 1.0:
		return null
	return Contact.new(_rail_normals[index], radius - inside, index)


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


## Each cell's platforms and their clearances, into _floors and _floor_clearances: the
## distance from a platform's height to the heights every other surface of the cell
## stands at — a ramp anywhere between its ends — less CLEARANCE_SLACK.
func _index_floors() -> void:
	for near: PackedInt32Array in _cells:
		var floors := PackedInt32Array()
		var clearances := PackedFloat64Array()
		for surface: int in near:
			if surface >= _first_ramp:
				continue
			var height := _tops[surface]
			var clearance := INF
			for other: int in near:
				if other == surface:
					continue
				var low := _bottoms[other] if is_ramp(other) else _tops[other]
				clearance = minf(clearance, maxf(low - height, height - _tops[other]))
			floors.append(surface)
			clearances.append(clearance - CLEARANCE_SLACK)
		_floors.append(floors)
		_floor_clearances.append(clearances)


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
	var block := Vector4i(low.x, low.y, high.x, high.y)
	if block in _blocks:
		return _blocks[block]
	var gathered := PackedInt32Array()
	for row in range(low.y, high.y + 1):
		for column in range(low.x, high.x + 1):
			gathered.append_array(_cells[row * _grid_size.x + column])
	gathered.sort()
	var found := PackedInt32Array()
	for surface: int in gathered:
		if found.is_empty() or found[found.size() - 1] != surface:
			found.append(surface)
	_blocks[block] = found
	return found


## The surfaces whose areas reach the cell under [param ship_point]'s x/z, as _near
## answers a box that is that one point.
func _at(ship_point: Vector3) -> PackedInt32Array:
	var cell := _cell_index(ship_point)
	return PackedInt32Array() if cell == NONE else _cells[cell]


## The index in _cells of the cell under [param ship_point]'s x/z, as _cell_of finds it;
## NONE with no cells.
func _cell_index(ship_point: Vector3) -> int:
	if _cells.is_empty():
		return NONE
	var at := (Vector2(ship_point.x, ship_point.z) - _grid_origin) / CELL
	var column := clampi(floori(at.x), 0, _grid_size.x - 1)
	return clampi(floori(at.y), 0, _grid_size.y - 1) * _grid_size.x + column


## [param near] and after it, in number order, the lid of every crate standing over
## [param ship_point]'s x/z but [param except_prop]; [param near] itself when there is
## none, as there mostly is not.
func _with_lids(near: PackedInt32Array, ship_point: Vector3, except_prop: int) -> PackedInt32Array:
	var found := near
	var copied := false
	for prop in _prop_radii.size():
		var lid := _first_lid + prop
		if prop == except_prop or _gone[lid] == 1:
			continue
		# _contains(lid, ship_point), written out: every point query asks it of every crate.
		var feet := _prop_feet[prop]
		if not (
			Vector2(ship_point.x - feet.x, ship_point.z - feet.z).length() <= _prop_radii[prop]
		):
			continue
		if not copied:
			# near may be a cell of the index itself: never add to it.
			found = near.duplicate()
			copied = true
		found.append(lid)
	return found


## Whether [param surface] is the top of a round blocker — a funnel, a mast: nothing
## a swimmer climbs onto.
func _is_round_top(surface: int) -> bool:
	return _is_blocker_top(surface) and _blocker_of(surface).shape != ShipBlocker.Shape.BOX


func _blocker_of(surface: int) -> ShipBlocker:
	return _blockers[surface - _first_top]


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
	if surface >= _first_lid:
		var feet := _prop_feet[surface - _first_lid]
		var reach := _prop_radii[surface - _first_lid]
		return Vector2(ship_point.x - feet.x, ship_point.z - feet.z).length() <= reach
	if surface >= _first_top and _blocker_of(surface).shape == ShipBlocker.Shape.CYLINDER:
		var blocker := _blocker_of(surface)
		return Vector2(ship_point.x, ship_point.z).distance_to(blocker.centre) <= blocker.radius
	var area := _areas[surface]
	return (
		ship_point.x >= area.position.x
		and ship_point.x <= area.end.x
		and ship_point.z >= area.position.y
		and ship_point.z <= area.end.y
	)


## How low [param surface] reaches: a deck is a slab at its height, a ramp a solid
## wedge down to its base, a blocker stands on its bottom.
func _underside(surface: int) -> float:
	if surface >= _first_ramp:
		return _bottoms[surface]
	return _platforms[surface].height


## How low [param platform]'s sides reach: a deck over a lower one is a slab at its
## height, and a deck over none is the top of the hull, solid all the way down.
func _platform_bottom(platform: int) -> float:
	var deck := _platforms[platform]
	for other: ShipPlatform in _platforms:
		if other.height < deck.height and other.area.intersects(deck.area):
			return deck.height
	return -INF


## The middle of [param surface], at its height there.
func _centre(surface: int) -> Vector3:
	var middle := _area(surface).get_center()
	var point := Vector3(middle.x, 0.0, middle.y)
	point.y = height_at(surface, point)
	return point
