class_name ShipGreybox
extends Node3D
## Meshes generated from the ShipLayout (D6): a plank top on every platform and a
## hull block under each one that stands over no other, a wedge for every ramp, a
## box or cylinder for every blocker, and a top rail on posts along every railing
## span. Drawn only — the sim never reads a mesh — and nothing is placed by hand.

## How far the hull block reaches below the waterline of a level, unsunk ship.
const HULL_DRAFT := 2.0
const PLANK_THICKNESS := 0.06
const DECK_COLOUR := Color(0.62, 0.5, 0.36)
const HULL_COLOUR := Color(0.32, 0.3, 0.3)
## The forward edge of each platform, so which end is the bow reads at a glance.
const BOW_COLOUR := Color(0.75, 0.2, 0.15)
const BOW_STRIP := 0.6
const RAMP_COLOUR := Color(0.5, 0.36, 0.22)
## Boxes read as houses and hatches, cylinders as funnels and masts.
const BOX_COLOUR := Color(0.86, 0.84, 0.76)
const CYLINDER_COLOUR := Color(0.2, 0.18, 0.18)
const RAIL_COLOUR := Color(0.85, 0.83, 0.78)
const RAIL_THICKNESS := 0.08
const POST_THICKNESS := 0.07
## Posts stand at both ends of a span and no farther apart than this.
const POST_SPACING := 1.5


## [param railing_height] is the rules' — how high every railing stands.
func build(layout: ShipLayout, railing_height: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	var hull_depth := layout.freeboard + HULL_DRAFT
	for platform: ShipPlatform in layout.platforms:
		var area := platform.area
		var centre := area.get_center()
		_box(
			Vector3(area.size.x, PLANK_THICKNESS, area.size.y),
			Vector3(centre.x, platform.height - PLANK_THICKNESS * 0.5, centre.y),
			DECK_COLOUR
		)
		_box(
			Vector3(BOW_STRIP, PLANK_THICKNESS, area.size.y),
			Vector3(
				area.end.x - BOW_STRIP * 0.5, platform.height - PLANK_THICKNESS * 0.4, centre.y
			),
			BOW_COLOUR
		)
		if not _stands_over_a_platform(platform, layout):
			_box(
				Vector3(area.size.x, hull_depth, area.size.y),
				Vector3(centre.x, platform.height - PLANK_THICKNESS - hull_depth * 0.5, centre.y),
				HULL_COLOUR
			)
	for ramp: ShipRamp in layout.ramps:
		_ramp(ramp)
	for blocker: ShipBlocker in layout.blockers:
		_blocker(blocker)
	for railing: ShipRailing in layout.railings:
		_railing(railing, layout.platforms[railing.platform].height, railing_height)


## Whether some lower platform lies under [param platform] — a deck on a house
## stands on that house, not on a hull of its own.
func _stands_over_a_platform(platform: ShipPlatform, layout: ShipLayout) -> bool:
	for other: ShipPlatform in layout.platforms:
		if other.height < platform.height and other.area.intersects(platform.area):
			return true
	return false


## A solid wedge from the ramp's lower end height up to its slope.
func _ramp(ramp: ShipRamp) -> void:
	var rise := absf(ramp.end_height - ramp.start_height)
	var along_x := ramp.axis == ShipRamp.Axis.X
	var run := ramp.area.size.x if along_x else ramp.area.size.y
	var width := ramp.area.size.y if along_x else ramp.area.size.x
	var wedge := PrismMesh.new()
	wedge.size = Vector3(run, rise, width)
	# The prism's apex stands over its +x edge at 1, its -x edge at 0.
	wedge.left_to_right = 1.0 if ramp.end_height > ramp.start_height else 0.0
	wedge.material = _material(RAMP_COLOUR)
	var instance := MeshInstance3D.new()
	instance.mesh = wedge
	var centre := ramp.area.get_center()
	instance.position = Vector3(centre.x, ramp.base() + rise * 0.5, centre.y)
	if not along_x:
		instance.rotation.y = -PI * 0.5
	add_child(instance)


## A blocker stops a plank short of its top, so a deck standing on it shows.
func _blocker(blocker: ShipBlocker) -> void:
	var height := blocker.top - blocker.bottom - PLANK_THICKNESS
	var middle := blocker.bottom + height * 0.5
	if blocker.shape == ShipBlocker.Shape.BOX:
		var centre := blocker.area.get_center()
		_box(
			Vector3(blocker.area.size.x, height, blocker.area.size.y),
			Vector3(centre.x, middle, centre.y),
			BOX_COLOUR
		)
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = blocker.radius
	cylinder.bottom_radius = blocker.radius
	cylinder.height = height
	cylinder.material = _material(CYLINDER_COLOUR)
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.position = Vector3(blocker.centre.x, middle, blocker.centre.y)
	add_child(instance)


## The top rail along [param railing]'s span and posts under it, standing on a
## deck at [param deck_height].
func _railing(railing: ShipRailing, deck_height: float, railing_height: float) -> void:
	var span := railing.to - railing.from
	var turn := Basis(Vector3.UP, -span.angle())
	var top := deck_height + railing_height - RAIL_THICKNESS * 0.5
	var middle := (railing.from + railing.to) * 0.5
	var bar := _box(
		Vector3(span.length(), RAIL_THICKNESS, RAIL_THICKNESS),
		Vector3(middle.x, top, middle.y),
		RAIL_COLOUR
	)
	bar.basis = turn
	var posts := ceili(span.length() / POST_SPACING)
	for index in posts + 1:
		var at := railing.from + span * (float(index) / posts)
		_box(
			Vector3(POST_THICKNESS, railing_height, POST_THICKNESS),
			Vector3(at.x, deck_height + railing_height * 0.5, at.y),
			RAIL_COLOUR
		)


func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(colour)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
