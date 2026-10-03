class_name ShipGreybox
extends Node3D
## Boxes generated from the ShipLayout (D6): a plank top on every platform and a
## hull block under it. Drawn only — the sim never reads a mesh.

## How far the hull block reaches below the waterline of a level, unsunk ship.
const HULL_DRAFT := 2.0
const PLANK_THICKNESS := 0.06
const DECK_COLOUR := Color(0.62, 0.5, 0.36)
const HULL_COLOUR := Color(0.32, 0.3, 0.3)
## The forward edge of each platform, so which end is the bow reads at a glance.
const BOW_COLOUR := Color(0.75, 0.2, 0.15)
const BOW_STRIP := 0.6


func build(layout: ShipLayout) -> void:
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


func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
