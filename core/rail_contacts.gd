class_name RailContacts
extends RefCounted
## Surfaces' working of the railings that hold back a body on its feet
## (Surfaces.rail_contacts, D6): standing on a surface, and walking there this tick from
## where it stood. Surfaces stays the only door: it alone asks these, handing itself in,
## and they read Surfaces' own lists as Surfaces keeps them, as ObstacleContacts does.
##
## A railing holds a body whatever surface it stepped from, on the side it came from
## (#592). A body reads the railings of the surface it stands on; one that walked onto
## another this tick reads that one's too, and any railing whose span its centre crossed
## holds it back on the side its centre came from. On main a body stepping from a
## landing past a stair's side railing onto the deck the railing belongs to met it there,
## from the deck's side, and was pushed on out through it.


## Into [param contacts], every railing that holds back a circle of [param radius] on its
## feet on [param surface] of [param s], centred on [param ship_point], as
## Surfaces.rail_contacts reads them before taking them one per direction.
static func standing(
	s: Surfaces,
	surface: int,
	ship_point: Vector3,
	radius: float,
	step: float,
	railing_height: float,
	contacts: Array[Surfaces.Contact]
) -> void:
	var point := Vector2(ship_point.x, ship_point.z)
	if s.is_ramp(surface):
		var box := Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		var feet := ship_point.y
		var middle := s._areas[surface].get_center()
		for index: int in s._rail_grid.near(box, feet - railing_height, feet + step):
			if s._rail_gone[index] == 1:
				continue
			var deck := s._platforms[s._railings[index].platform].height
			if deck > feet + step or feet >= deck + railing_height:
				continue
			var side := (middle - s._railings[index].from).dot(s._rail_normals[index])
			var contact := s._rail_contact(index, point, radius, side < 0.0)
			if contact != null:
				contacts.append(contact)
		return
	if surface < 0 or surface >= s.platform_count():
		return
	for index: int in s._platform_rails[surface]:
		if s._rail_gone[index] == 1:
			continue
		var contact := s._rail_contact(index, point, radius)
		if contact != null:
			contacts.append(contact)


## Every railing of [param s] that holds back a circle of [param radius] on its feet that
## has walked this tick from [param came_from] (x/z) to [param ship_point], off
## [param surface]: those it meets standing on [param surface] and on the surface it stands
## over now, within [param step] — that one's, where both hold it by one railing — and every
## railing whose span its centre crossed on the way (_crossed), in their stead. One per
## direction.
static func walked(
	s: Surfaces,
	ship_point: Vector3,
	came_from: Vector2,
	radius: float,
	surface: int,
	step: float,
	railing_height: float
) -> Array[Surfaces.Contact]:
	var contacts := _crossed(s, came_from, ship_point, radius, step, railing_height)
	var held := PackedInt32Array()
	for contact: Surfaces.Contact in contacts:
		held.append(contact.railing)
	var now := s.under(ship_point, step)
	for on: int in [now, surface] if now != surface else [surface]:
		var met: Array[Surfaces.Contact] = []
		standing(s, on, ship_point, radius, step, railing_height, met)
		for contact: Surfaces.Contact in met:
			if not contact.railing in held:
				contacts.append(contact)
		for contact: Surfaces.Contact in met:
			held.append(contact.railing)
	return PlaneShapes.deepest_per_direction(contacts)


## Every railing of [param s] whose span a centre walking straight from
## [param came_from] (x/z) to [param ship_point] crosses, its deck no more than
## [param step] over the feet nor railing_height or more under them, as on a stair beside
## it: each holding a circle of [param radius] back on the side of its line the centre came
## from, however far past the line the centre is.
static func _crossed(
	s: Surfaces,
	came_from: Vector2,
	ship_point: Vector3,
	radius: float,
	step: float,
	railing_height: float
) -> Array[Surfaces.Contact]:
	var contacts: Array[Surfaces.Contact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	if point == came_from:
		return contacts
	var feet := ship_point.y
	var met := PackedInt32Array()
	for index: int in s._rail_grid.along(came_from, point, feet - railing_height, feet + step):
		if s._rail_gone[index] == 1 or index in met:
			continue
		met.append(index)
		var railing := s._railings[index]
		var deck := s._platforms[railing.platform].height
		if deck > feet + step or feet >= deck + railing_height:
			continue
		var was := (came_from - railing.from).dot(s._rail_normals[index])
		if was == 0.0:
			continue
		if (
			Geometry2D.segment_intersects_segment(came_from, point, railing.from, railing.to)
			== null
		):
			continue
		var normal := s._rail_normals[index] if was > 0.0 else -s._rail_normals[index]
		var depth := radius - (point - railing.from).dot(normal)
		contacts.append(Surfaces.Contact.new(normal, depth, index))
	return contacts
