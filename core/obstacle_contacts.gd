class_name ObstacleContacts
extends RefCounted
## Surfaces' working of what holds a body back in the deck plane (Surfaces.obstacle_contacts,
## D6): its GDScript, and its mirror in the game's extension (ContactsNative,
## NativeSurfaces, #410) — made the first time it is asked for, then told of every change
## Surfaces.honour() makes. Surfaces stays the only door: it alone makes one of these and
## asks it, handing itself in, and this reads Surfaces' own lists as Surfaces keeps them,
## holding nothing of its own but the mirror.

## Whether the mirror is asked, as Surfaces' stands ask theirs; the mirror, or null.
var _asks_native := false
var _native: Object


## Contacts for a Surfaces whose stands ask the extension where [param asks_native].
func _init(asks_native: bool) -> void:
	_asks_native = asks_native


## The NativeSurfaces mirroring [param surfaces], made now if not yet; null without the
## extension.
func native(surfaces: Surfaces) -> Object:
	if _native != null or not _asks_native:
		return _native
	var s := surfaces
	_native = ContactsNative.made(&"NativeSurfaces")
	var areas := PackedVector2Array()
	for area: Rect2 in s._areas:
		areas.append(area.position)
		areas.append(area.size)
	var round := PackedByteArray()
	var centres := PackedVector2Array()
	var radii := PackedFloat64Array()
	for blocker: ShipBlocker in s._blockers:
		round.append(0 if blocker.shape == ShipBlocker.Shape.BOX else 1)
		centres.append(blocker.centre)
		radii.append(blocker.radius)
	var ramp_x := PackedByteArray()
	var ramp_heights := PackedFloat64Array()
	for ramp: ShipRamp in s._ramps:
		ramp_x.append(1 if ramp.axis == ShipRamp.Axis.X else 0)
		ramp_heights.append(ramp.start_height)
		ramp_heights.append(ramp.end_height)
	_native.setup(
		PackedInt32Array([s._first_ramp, s._first_top, s._first_lid]),
		areas,
		s._bottoms,
		s._tops,
		s._gone,
		round,
		centres,
		radii,
		ramp_x,
		ramp_heights,
		s._grid.native_layout(),
		s.stands.native()
	)
	var ends := PackedVector2Array()
	var platforms := PackedInt32Array()
	for railing: ShipRailing in s._railings:
		ends.append(railing.from)
		ends.append(railing.to)
		platforms.append(railing.platform)
	var rails := SpatialIndex.flattened(s._platform_rails)
	_native.railings(
		ends,
		s._rail_normals,
		platforms,
		rails[0],
		rails[1],
		s._rail_gone,
		s._rail_grid.native_layout()
	)
	var leaves := s.doors.native_layout()
	_native.doors(leaves[0], leaves[1], leaves[2], leaves[3], leaves[4], leaves[5])
	_native.shut(s.doors.shut_all())
	var down := s._fallen.native_down()
	_native.felled(down[0], down[1], down[2])
	_native.lidded(s.stands.lids)
	# Her floors and their clearances, for Surfaces.under's own (BotFloorWay's search).
	var floors := SpatialIndex.flattened(s._floors)
	var clearances := PackedFloat64Array()
	for cell: PackedFloat64Array in s._floor_clearances:
		clearances.append_array(cell)
	_native.floors(floors[0], floors[1], clearances)
	# Her platforms' names, for line_of_sight's collapsed decks.
	var names: Array[StringName] = []
	for platform: ShipPlatform in s._platforms:
		names.append(platform.name)
	_native.named(names)
	return _native


## Tells the mirror, if made, of [param surfaces] honouring a new pose: its doors' leaves;
## its funnels down and its tops, where [param fell]; what is gone, where [param masked].
func honoured(surfaces: Surfaces, fell: bool, masked: bool) -> void:
	if _native == null:
		return
	_native.shut(surfaces.doors.shut_all())
	if fell:
		var down := surfaces._fallen.native_down()
		_native.felled(down[0], down[1], down[2])
		_native.topped(surfaces._tops)
	if masked:
		_native.masked(surfaces._gone, surfaces._rail_gone)


## Surfaces.obstacle_contacts of [param surfaces].
func contacts(
	surfaces: Surfaces,
	ship_point: Vector3,
	radius: float,
	body_height: float,
	step: float,
	except_prop: int,
	crawl_height: float,
	crawl_reach: float
) -> Array[Surfaces.Contact]:
	if _asks_native:
		var asked := _native if _native != null else native(surfaces)
		return ContactsNative.contacts_of(
			asked.obstacle_contacts(
				ship_point, radius, body_height, step, except_prop, crawl_height, crawl_reach
			)
		)
	var s := surfaces
	var tops := s._tops
	var bottoms := s._bottoms
	var first_top := s._first_top
	var first_ramp := s._first_ramp
	var contacts_found: Array[Surfaces.Contact] = []
	# Every flat piece that holds the body — a box blocker, a deck — and the contacts with
	# their corners, each with its corner and its piece, for _unseam.
	var flats: Array[Rect2] = []
	var cornered: Array[Surfaces.Contact] = []
	var cornered_at := PackedVector2Array()
	var cornered_of := PackedInt32Array()
	var point := Vector2(ship_point.x, ship_point.z)
	var feet := ship_point.y
	# _overlaps' two heights, once: what the body can step onto stands under the first,
	# and its head is at the second.
	var reach_up := feet + step
	var head := feet + body_height
	var reach_in := radius if crawl_reach < 0.0 else crawl_reach
	var box := Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	var near := s._grid.near(box, reach_up, head)
	var stair := Surfaces.UNASKED
	for surface: int in near:
		if surface < first_top:
			continue
		if not (reach_up < tops[surface] and head > bottoms[surface]):
			continue
		if stair == Surfaces.UNASKED:
			stair = _stair_under(s, point, feet, step)
		if _crawls_under(s, surface, point, reach_in, feet, step, crawl_height, stair):
			continue
		var blocker := s._blocker_of(surface)
		var contact: Surfaces.Contact
		if blocker.shape == ShipBlocker.Shape.BOX:
			var nearest := point.clamp(blocker.area.position, blocker.area.end)
			if tops[surface] <= _along(s, stair, nearest, feet) + step:
				continue
			contact = PlaneShapes.rect_contact(blocker.area, point, radius)
			if contact != null:
				flats.append(blocker.area)
				if nearest.x != point.x and nearest.y != point.y:
					cornered.append(contact)
					cornered_at.append(nearest)
					cornered_of.append(flats.size() - 1)
		else:
			contact = PlaneShapes.circle_contact(blocker.centre, blocker.radius, point, radius)
		if contact != null:
			contacts_found.append(contact)
	var gone := s._gone
	var areas := s._areas
	for surface: int in near:
		if surface >= first_top:
			break
		if gone[surface] == 1:
			continue
		var area := areas[surface]
		var closest := point.clamp(area.position, area.end)
		var top := s.height_at(surface, Vector3(closest.x, 0.0, closest.y))
		if not (reach_up < top and head > bottoms[surface]):
			continue
		if stair == Surfaces.UNASKED:
			stair = _stair_under(s, point, feet, step)
		if surface < first_ramp and top <= _along(s, stair, closest, feet) + step:
			continue
		if _crawls_under(s, surface, point, reach_in, feet, step, crawl_height, stair):
			continue
		var contact := (
			PlaneShapes.climb_contact(s._ramps[surface - first_ramp], point, radius, reach_up)
			if surface >= first_ramp and closest == point
			else PlaneShapes.rect_contact(area, point, radius)
		)
		if contact != null:
			contacts_found.append(contact)
			if surface < first_ramp:
				flats.append(area)
				if closest.x != point.x and closest.y != point.y:
					cornered.append(contact)
					cornered_at.append(closest)
					cornered_of.append(flats.size() - 1)
	if not cornered.is_empty():
		_unseam(contacts_found, flats, cornered, cornered_at, cornered_of, point)
	var stands := s.stands
	for prop: int in stands.near(point.x, point.y, radius, except_prop):
		var under_it := stands.feet[prop]
		if not (reach_up < under_it.y + stands.heights[prop] and head > under_it.y):
			continue
		var centre := Vector2(under_it.x, under_it.z)
		var contact := PlaneShapes.circle_contact(centre, stands.radii[prop], point, radius)
		if contact != null:
			contact.prop = prop
			contacts_found.append(contact)
	contacts_found.append_array(s.doors.contacts(point, reach_up, head, radius))
	contacts_found.append_array(s._fallen.contacts(point, reach_up, head, radius))
	return PlaneShapes.deepest_per_direction(contacts_found)


## Takes out of [param found] each of [param cornered] — a contact with the corner
## [param at] of the [param of]th of [param flats], nearest a body's middle at
## [param point] — where another of [param flats] carries one of that corner's faces on
## toward the body (PlaneShapes.carries_on): two abutting pieces' edges are one edge, and a
## seam in it holds nothing back that the edge does not (#566). What carries the face on
## holds the body itself, nearer than the corner.
static func _unseam(
	found: Array[Surfaces.Contact],
	flats: Array[Rect2],
	cornered: Array[Surfaces.Contact],
	at: PackedVector2Array,
	of: PackedInt32Array,
	point: Vector2
) -> void:
	for index in cornered.size():
		for other in flats.size():
			if other != of[index] and PlaneShapes.carries_on(flats[other], at[index], point):
				found.erase(cornered[index])
				break


## Whether a body with its feet at [param feet] and its middle at [param point] ducks
## under [param surface] of [param s] to crawl: under it — [param reach] in from its edge
## nearest the body, where its middle would be once its circle is under it — a deck or a
## stair stands within [param step] of the feet, or of [param stair] going on down to
## there, with crawl_height or more of headroom up to it, and its underside is
## [param crawl_height] or more over the feet, or over that stair there.
static func _crawls_under(
	s: Surfaces,
	surface: int,
	point: Vector2,
	reach: float,
	feet: float,
	step: float,
	crawl_height: float,
	stair: int
) -> bool:
	var underside := s._bottoms[surface]
	if underside < feet + crawl_height and stair == Surfaces.NONE:
		return false
	var area := s._areas[surface]
	var closest := point.clamp(area.position, area.end)
	var under_it := closest
	if closest != point:
		under_it += (closest - point).normalized() * reach
	var low := minf(_along(s, stair, under_it, feet), feet)
	if underside < low + crawl_height:
		return false
	var at := Vector3(under_it.x, feet + step, under_it.y)
	var ground := s._highest_at_or_below(at, s._first_top)
	if ground == Surfaces.NONE:
		return false
	var height := s.height_at(ground, at)
	return height >= low - step and underside - height >= crawl_height


## The ramp of [param s] a body with its feet at [param feet] and its middle at
## [param point] stands on — the highest surface within [param step] under them, if a
## ramp — or NONE.
static func _stair_under(s: Surfaces, point: Vector2, feet: float, step: float) -> int:
	var at := Vector3(point.x, feet + step, point.y)
	var stand := s._highest_at_or_below(at, s._first_top)
	if stand < s._first_ramp or s.height_at(stand, at) < feet - step:
		return Surfaces.NONE
	return stand


## The height [param stair] of [param s] stands at at [param at], carried on level past
## its ends; off a stair (NONE), the feet's [param feet].
static func _along(s: Surfaces, stair: int, at: Vector2, feet: float) -> float:
	if stair == Surfaces.NONE:
		return feet
	return s._ramps[stair - s._first_ramp].height_at(at.x, at.y)
