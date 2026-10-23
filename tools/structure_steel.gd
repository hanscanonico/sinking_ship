extends RefCounted
## art-lint's word on what is drawn where the rules have it stand (D6), so no false floor
## and nothing across a broken railing's opening: her structure's own steel — the
## plating and the bulwarks of her shell (SectionHull) and the faces closing her ends —
## and the blockers the rules hold every body out of.

## How near a section's outline, or a face closing her ends, a face stands to be her
## structure's own steel.
const TOLERANCE := 0.05


## Whether [param point] stands within TOLERANCE of [param layout]'s structure: on the
## outline of the section cut across her there or of either whose middle stands nearest
## aft or fore of it — her shell is lofted from one section's middle to the next — or on
## a face closing her ends, inside her first section's outline at its after end or her
## last's at its fore end, as a transom. Only on it: what stands inside her hull is held
## to the checks.
static func holds(layout: ShipLayout, point: Vector3) -> bool:
	if layout.structure == null:
		return false
	var across := Vector2(point.z, point.y)
	var sections := layout.structure.sections
	for end: int in [0, sections.size() - 1]:
		var closing := sections[end]
		var face := closing.x + closing.length * (-0.5 if end == 0 else 0.5)
		if absf(point.x - face) <= TOLERANCE:
			if Geometry2D.is_point_in_polygon(across, closing.outline):
				return true
	for at in sections.size():
		var section := sections[at]
		var within := absf(point.x - section.x) <= section.length * 0.5 + TOLERANCE
		var before := at > 0 and sections[at - 1].x <= point.x and point.x <= section.x
		var after := at < sections.size() - 1 and section.x <= point.x
		after = after and point.x <= sections[at + 1].x
		if not (within or before or after):
			continue
		var outline := section.outline
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			var nearest := Geometry2D.get_closest_point_to_segment(across, a, b)
			if nearest.distance_to(across) <= TOLERANCE:
				return true
	return false


## Whether [param point] stands in one of [param layout]'s blockers, its box or its
## round grown by [param tolerance]: drawn where the rules hold every body out.
static func in_a_blocker(layout: ShipLayout, point: Vector3, tolerance: float) -> bool:
	var at := Vector2(point.x, point.z)
	for blocker: ShipBlocker in layout.blockers:
		if point.y < blocker.bottom - tolerance or point.y > blocker.top + tolerance:
			continue
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			if at.distance_to(blocker.centre) <= blocker.radius + tolerance:
				return true
		elif blocker.area.grow(tolerance).has_point(at):
			return true
	return false
