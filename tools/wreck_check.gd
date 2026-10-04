class_name WreckCheck
extends RefCounted
## `make art-lint`'s check of a collapsed deck's wreck (DeckWreck), once it has fallen
## in the match scene: nothing drawn of it stands more than a step over where the
## rules now land a body under it — the floor beneath, a deck still standing — so a
## body walking there treads on wreckage, never through a deck; and nothing of it
## stands outside its own deck's area. What has gone under the floor (the lamp it
## carried, out) is out of sight.

## How far over a step, or out of its area, a piece of the wreck may stand.
const TOLERANCE := 0.02


## The wrecks [param art] draws of the platforms of [param layout] named in
## [param collapsed], against where [param surfaces] — honouring the pose they fell in
## — lands a body: [problems found, checks made].
static func check(
	art: ShipArt,
	layout: ShipLayout,
	rules: BrawlRules,
	surfaces: Surfaces,
	collapsed: Array[StringName]
) -> Array:
	var problems := PackedStringArray()
	var checks := 0
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		if not platform.name in collapsed:
			continue
		checks += 1
		var wreck := art.get_node_or_null("Deck%d" % index) as Node3D
		if wreck == null:
			problems.append(
				"art-lint: collapsed platform %d (%s) has no wreck" % [index, platform.name]
			)
			continue
		var reach := platform.area.grow(TOLERANCE)
		var beneath := ShipSpace.new(layout).floor_beneath(platform)
		for point in _drawn(art, wreck):
			# What has gone through the floor beneath is out of sight under it.
			if point.y < beneath - TOLERANCE:
				continue
			var under := surfaces.landing(point + Vector3.UP * TOLERANCE)
			var floor := -INF if under == Surfaces.NONE else surfaces.height_at(under, point)
			var over := point.y - floor - rules.step_height
			if over > TOLERANCE or not reach.has_point(Vector2(point.x, point.z)):
				problems.append(
					(
						"art-lint: the wreck of platform %d (%s) stands at %s, %.2f m over a step"
						% [index, platform.name, point, over]
					)
				)
				break
	return [problems, checks]


## Every corner of the faces drawn under [param wreck] that shows, in [param art]'s
## space (the ship's).
static func _drawn(art: ShipArt, wreck: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for node: Node in wreck.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var place := Transform3D.IDENTITY
		var at: Node = mesh
		while at != art:
			place = (at as Node3D).transform * place
			at = at.get_parent()
		for corner: Vector3 in mesh.mesh.get_faces():
			points.append(place * corner)
	return points
