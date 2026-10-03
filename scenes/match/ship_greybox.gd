class_name ShipGreybox
extends Node3D
## Boxes generated from the ShipLayout (D6): a plank top on every platform, a hull
## block under it, and a top rail on posts along every railing span. Drawn only —
## the sim never reads a mesh.

## How far the hull block reaches below the waterline of a level, unsunk ship.
const HULL_DRAFT := 2.0
const PLANK_THICKNESS := 0.06
const DECK_COLOUR := Color(0.62, 0.5, 0.36)
const HULL_COLOUR := Color(0.32, 0.3, 0.3)
## The forward edge of each platform, so which end is the bow reads at a glance.
const BOW_COLOUR := Color(0.75, 0.2, 0.15)
const BOW_STRIP := 0.6
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
		_box(
			Vector3(area.size.x, hull_depth, area.size.y),
			Vector3(centre.x, platform.height - PLANK_THICKNESS - hull_depth * 0.5, centre.y),
			HULL_COLOUR
		)
	for railing: ShipRailing in layout.railings:
		_railing(railing, layout.platforms[railing.platform].height, railing_height)


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
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance
