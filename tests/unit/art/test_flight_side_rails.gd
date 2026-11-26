extends GutTest
## A flight's side rail on an open deck (ShipArt.FLIGHT_SIDE_RAIL), as the dressed
## steamer draws it: in teak boards of a piece with its stair, never as a white house's
## plated wall, whose trim band over a pale face read as a slab with no paint on it
## beside every one of her stairs.

const RunMatch := preload("res://tools/run_match.gd")


func test_her_open_decks_flight_side_rails_are_teak_boards_not_house_walls() -> void:
	var config := RunMatch.default_config(1701)
	var layout := config.ship
	var space := ShipSpace.new(layout)
	var rails: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		var middle := blocker.area.get_center()
		var at := Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)
		if (
			blocker.resource_scene_unique_id.begins_with(ShipArt.FLIGHT_SIDE_RAIL)
			and space.outdoors(at)
		):
			rails.append(blocker)
	assert_gt(rails.size(), 10, "her open decks' flights railed")
	var art: ShipArt = autofree(ShipArt.new())
	art.build(layout, config.rules.railing_height, config.rules.body_radius)
	var finishes := {}
	for part: Node in art.find_children("*", "MeshInstance3D", true, false):
		var instance := part as MeshInstance3D
		# Up to the art: nothing is in the tree, so no global transform.
		var place := Transform3D.IDENTITY
		var node: Node = instance
		while node != art and node is Node3D:
			place = (node as Node3D).transform * place
			node = node.get_parent()
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface) as ShaderMaterial
			if material == null:
				continue
			# Unset, the shader's own: PLAIN.
			var given: Variant = material.get_shader_parameter("finish")
			var finish: int = ShipMesh.Finish.PLAIN if given == null else given
			var arrays := instance.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index in range(0, order.size(), 3):
				var a := place * points[order[index]]
				var b := place * points[order[index + 1]]
				var c := place * points[order[index + 2]]
				var normal := (b - a).cross(c - a).normalized()
				if absf(normal.y) > 0.5:
					continue
				var middle := (a + b + c) / 3.0
				for rail: ShipBlocker in rails:
					if _on_a_side(rail, middle):
						finishes[finish] = finishes.get(finish, 0) + 1
						break
	assert_eq(finishes.get(ShipMesh.Finish.HOUSE, 0), 0, "no side rail plated as a house")
	assert_gt(finishes.get(ShipMesh.Finish.ROUGH, 0), 0, "her side rails in teak boards")


## Whether [param point] lies on one of [param rail]'s long sides, inside its height.
static func _on_a_side(rail: ShipBlocker, point: Vector3) -> bool:
	if point.y < rail.bottom + 0.05 or point.y > rail.top - 0.05:
		return false
	var area := rail.area
	var inner := area.grow(-0.005)
	var outer := area.grow(0.005)
	var flat := Vector2(point.x, point.z)
	return outer.has_point(flat) and not inner.has_point(flat)
