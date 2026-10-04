extends RefCounted
## art-lint's check of the rooms' furnishings (RoomDressing): none stands more than
## TOLERANCE into the space a body fills — within a body's radius of anywhere Surfaces
## lets its centre stand, from a step over what it stands on to its height over it — so
## nothing drawn at body height is something a body walks through: a table in the
## middle of a cabin fails, a lifebelt on its wall does not.

## How far into the space a body fills a furnishing may stand: a wall fitting's
## depth, clear of the mannequin's shoulders. The furnishings' faces are sampled STEP
## apart, and round each sample the centres tried stand on rings of RINGS shares of a
## body's reach, SPOKES to a ring, on a grid of GRID.
const TOLERANCE := 0.12
const STEP := 0.08
const RINGS: Array[float] = [0.0, 0.6, 0.95]
const SPOKES := 10
const GRID := 0.05
## The squares of the ship plane the heights a body may stand at are filed under.
const CELL := 1.0


## Every face of the rooms' furnishings (RoomDressing) [param art] draws, under its
## Dressing node, in the ship's space: their meshes and their signs' letters.
static func furnishings(art: ShipArt) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for node: Node in art.get_node("Dressing").get_children():
		var place := (node as Node3D).transform
		if node is MeshInstance3D:
			for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
				faces.append(place * corner)
		elif node is Label3D:
			var box := (node as Label3D).get_aabb()
			var corners: Array[Vector3] = [
				box.position,
				box.position + Vector3(box.size.x, 0.0, 0.0),
				box.position + Vector3(box.size.x, box.size.y, 0.0),
				box.position + Vector3(0.0, box.size.y, 0.0),
			]
			for index: int in [0, 1, 2, 0, 2, 3]:
				faces.append(place * corners[index])
	return faces


## Where [param faces] stand more than TOLERANCE into the space a body of
## [param rules] fills on [param layout]: a point of them within a body's radius, less
## the tolerance, of a centre Surfaces lets a body stand at, between a step over what
## that body stands on and its height over it. A face inside a blocker, or wholly over
## or under every body that could stand within reach of it, is passed over unsampled.
## One line per face found so, at most a few.
static func intrusions(
	layout: ShipLayout, rules: BrawlRules, faces: PackedVector3Array
) -> PackedStringArray:
	var surfaces := Surfaces.new(layout)
	var reach := rules.body_radius - TOLERANCE
	var bands := _standing_bands(layout, reach)
	var standing := {}
	var found := PackedStringArray()
	for index in range(0, faces.size(), 3):
		var triangle := faces.slice(index, index + 3)
		if _inside_a_blocker(layout, triangle) or not _in_a_band(bands, triangle, rules):
			continue
		for point in _spread(triangle):
			var feet := _body_round(surfaces, rules, standing, point, reach)
			if feet.x == INF:
				continue
			var into := rules.body_radius - Vector2(point.x - feet.x, point.z - feet.z).length()
			found.append(
				"furnishing at %s stands %.2f m into a body standing at %s" % [point, into, feet]
			)
			break
		if found.size() >= 5:
			break
	return found


## Per CELL square of the ship plane, the heights (low, high) a body's feet
## may stand at within [param reach] of it: every platform, ramp and blocker top of
## [param layout] whose area comes that near.
static func _standing_bands(layout: ShipLayout, reach: float) -> Dictionary:
	var bands := {}
	var tops: Array[Array] = []
	for platform: ShipPlatform in layout.platforms:
		tops.append([platform.area, Vector2(platform.height, platform.height)])
	for ramp: ShipRamp in layout.ramps:
		var high := maxf(ramp.start_height, ramp.end_height)
		tops.append([ramp.area, Vector2(ramp.base(), high)])
	for blocker: ShipBlocker in layout.blockers:
		var area := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			area = Rect2(
				blocker.centre - Vector2.ONE * blocker.radius, Vector2.ONE * blocker.radius * 2.0
			)
		tops.append([area, Vector2(blocker.top, blocker.top)])
	for top: Array in tops:
		var area := (top[0] as Rect2).grow(reach)
		var low := Vector2i((area.position / CELL).floor())
		var high := Vector2i((area.end / CELL).floor())
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				var cell := Vector2i(x, z)
				var heights: PackedVector2Array = bands.get(cell, PackedVector2Array())
				heights.append(top[1])
				bands[cell] = heights
	return bands


## Whether [param triangle] reaches the heights a body of [param rules] standing
## within reach of it fills — over a step above its feet, under its head — on any of
## [param bands] (_standing_bands).
static func _in_a_band(bands: Dictionary, triangle: PackedVector3Array, rules: BrawlRules) -> bool:
	var low := Vector3.INF
	var high := -Vector3.INF
	for corner: Vector3 in triangle:
		low = low.min(corner)
		high = high.max(corner)
	var from := Vector2i((Vector2(low.x, low.z) / CELL).floor())
	var to := Vector2i((Vector2(high.x, high.z) / CELL).floor())
	for x in range(from.x, to.x + 1):
		for z in range(from.y, to.y + 1):
			for feet: Vector2 in bands.get(Vector2i(x, z), PackedVector2Array()):
				if high.y >= feet.x + rules.step_height and low.y <= feet.y + rules.body_height:
					return true
	return false


## Whether [param triangle] stands wholly inside one of [param layout]'s box
## blockers, which hold every body a radius off: an engine's own faces.
static func _inside_a_blocker(layout: ShipLayout, triangle: PackedVector3Array) -> bool:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX:
			continue
		var area := blocker.area.grow(0.002)
		var inside := true
		for corner: Vector3 in triangle:
			if (
				not area.has_point(Vector2(corner.x, corner.z))
				or corner.y < blocker.bottom - 0.002
				or corner.y > blocker.top + 0.002
			):
				inside = false
				break
		if inside:
			return true
	return false


## Points spread over [param triangle] no more than STEP apart, its
## corners among them.
static func _spread(triangle: PackedVector3Array) -> PackedVector3Array:
	var a := triangle[0]
	var u := triangle[1] - a
	var v := triangle[2] - a
	var longest := maxf(u.length(), maxf(v.length(), (v - u).length()))
	var steps := maxi(1, ceili(longest / STEP))
	var points := PackedVector3Array()
	for i in steps + 1:
		for j in steps + 1 - i:
			points.append(a + u * (float(i) / steps) + v * (float(j) / steps))
	return points


## The feet of a body of [param rules] that Surfaces lets stand within [param reach]
## of [param point] across the ship plane and whose height takes it in — over a step
## above its feet and under its head — or Vector3.INF when none of the centres tried
## does. [param standing] keeps, per grid centre, what stands under it (_stood_on).
static func _body_round(
	surfaces: Surfaces, rules: BrawlRules, standing: Dictionary, point: Vector3, reach: float
) -> Vector3:
	for ring: float in RINGS:
		var spokes := 1 if ring == 0.0 else SPOKES
		for spoke in spokes:
			var turn := TAU * spoke / spokes
			var at := Vector2(point.x, point.z) + Vector2(cos(turn), sin(turn)) * reach * ring
			var cell := Vector2i(roundi(at.x / GRID), roundi(at.y / GRID))
			var centre := Vector2(cell) * GRID
			if centre.distance_to(Vector2(point.x, point.z)) >= reach:
				continue
			if not standing.has(cell):
				standing[cell] = _stood_on(surfaces, rules, centre)
			for under: Vector2 in standing[cell]:
				if point.y - under.x < rules.step_height:
					continue
				if point.y - under.x <= rules.body_height and under.y == 1.0:
					return Vector3(centre.x, under.x, centre.y)
				break
	return Vector3.INF


## Every surface Surfaces has under ship-plane point [param centre], from the top
## down, as (its height there, 1 when a body of [param rules] stands on it there with
## nothing holding it back, else 0).
static func _stood_on(surfaces: Surfaces, rules: BrawlRules, centre: Vector2) -> PackedVector2Array:
	var found := PackedVector2Array()
	var probe := Vector3(centre.x, 1e4, centre.y)
	while found.size() < 8:
		var surface := surfaces.landing(probe)
		if surface == Surfaces.NONE:
			break
		var feet := Vector3(centre.x, surfaces.height_at(surface, probe), centre.y)
		var contacts := surfaces.obstacle_contacts(
			feet, rules.body_radius, rules.body_height, rules.step_height
		)
		found.append(Vector2(feet.y, 1.0 if contacts.is_empty() else 0.0))
		probe.y = feet.y - 0.01
	return found
