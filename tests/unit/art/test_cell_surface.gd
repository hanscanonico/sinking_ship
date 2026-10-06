extends GutTest
## A cell's water drawn level with the world (CellSurface): on a ship drawn listing and
## trimmed, the sheet's up is the world's and it stands at the level the pose gives over
## the box's middle; a box's reach is its lowest and highest corners' world heights.

const BOX := AABB(Vector3(-3.0, -2.6, 0.7), Vector3(4.0, 2.6, 4.1))


## A ship drawn trimmed [param trim_deg] by the head and listed [param heel_deg] to
## starboard, her origin [param height] over the sea.
func _drawn(trim_deg: float, heel_deg: float, height: float) -> Transform3D:
	var basis := (
		Basis(Vector3.BACK, deg_to_rad(-trim_deg)) * Basis(Vector3.RIGHT, deg_to_rad(heel_deg))
	)
	return Transform3D(basis, Vector3(0.0, height, 0.0))


func test_the_sheet_lies_level_with_the_world_at_its_level() -> void:
	for lean: Vector2 in [
		Vector2.ZERO, Vector2(4.0, 0.0), Vector2(0.0, -18.0), Vector2(-7.0, 25.0)
	]:
		var drawn := _drawn(lean.x, lean.y, 2.8)
		var level_basis := drawn.basis.inverse().orthonormalized()
		var placed := CellSurface.placed(drawn, level_basis, BOX, 1.2)
		var world := drawn * placed
		var up := world.basis.y.dot(Vector3.UP)
		assert_almost_eq(up, 1.0, 1e-5, "up is the world's at %s" % lean)
		assert_almost_eq(world.origin.y, 1.2, 1e-5, "at its level at %s" % lean)
		# Over the box's middle: along the world's up from it, no further.
		var middle := drawn * BOX.get_center()
		var across := Vector2(world.origin.x - middle.x, world.origin.z - middle.z)
		assert_almost_eq(across.length(), 0.0, 1e-5, "over the middle at %s" % lean)


func test_reach_is_the_lowest_and_highest_corner() -> void:
	for lean: Vector2 in [Vector2.ZERO, Vector2(9.0, -3.0), Vector2(-30.0, 40.0)]:
		var drawn := _drawn(lean.x, lean.y, -1.5)
		var low := INF
		var high := -INF
		for corner in 8:
			var height := (drawn * BOX.get_endpoint(corner)).y
			low = minf(low, height)
			high = maxf(high, height)
		var reach := CellSurface.reach(drawn, BOX)
		assert_almost_eq(reach.x, low, 1e-5, "lowest corner at %s" % lean)
		assert_almost_eq(reach.y, high, 1e-5, "highest corner at %s" % lean)


func test_the_sheet_covers_the_box_at_any_lean() -> void:
	# Every corner of the box lies over or under the unit sheet as placed: within its
	# half-metre either way along its own two ways, which the placing stretches.
	for lean: Vector2 in [
		Vector2.ZERO, Vector2(12.0, 0.0), Vector2(0.0, 30.0), Vector2(-9.0, -40.0)
	]:
		var drawn := _drawn(lean.x, lean.y, 1.0)
		var level_basis := drawn.basis.inverse().orthonormalized()
		var placed := CellSurface.placed(drawn, level_basis, BOX, 0.5).affine_inverse()
		var widest := Vector2.ZERO
		for corner in 8:
			var local := placed * BOX.get_endpoint(corner)
			widest = widest.max(Vector2(absf(local.x), absf(local.z)))
		assert_almost_eq(widest.x, 0.5, 1e-4, "just as wide as the box at %s" % lean)
		assert_almost_eq(widest.y, 0.5, 1e-4, "just as deep as the box at %s" % lean)
