extends GutTest
## FloodedDecks says of each platform under each pose what Surfaces.flooded says — its
## middle under the water there — whichever of the two latest poses it is asked of, in
## whatever order, and for a pose it reads again.


## The steamer sunk [param sea] m over her main deck and heeled [param heel_deg], every
## other cell holding water to its middle.
static func _pose(layout: ShipLayout, sea: float, heel_deg: float) -> ShipPose:
	var waters := {}
	var cells := layout.structure.cells
	for index in cells.size():
		if index % 2 == 0:
			waters[cells[index].name] = [lerpf(cells[index].low.y, cells[index].high.y, 0.5)]
	var held := HeldPose.flooded(layout, sea, waters)
	var pose := ShipPose.new(
		held.sink,
		0.0,
		heel_deg,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(heel_deg)), held.transform.origin)
	)
	pose.cells = held.cells
	pose.levels = held.levels
	pose.pockets = held.pockets
	return pose


func test_each_platform_is_flooded_as_surfaces_says() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var decks := FloodedDecks.new(layout)
	var poses: Array[ShipPose] = [
		_pose(layout, -3.0, 0.0), _pose(layout, -1.0, 6.0), _pose(layout, 0.5, -10.0)
	]
	var flooded := 0
	# Each pose after the one before it, as a planner steps, and back to an older one.
	for pose: ShipPose in [poses[0], poses[1], poses[0], poses[2], poses[1], poses[2]]:
		for platform in layout.platforms.size():
			var expected := surfaces.flooded(platform, pose)
			assert_eq(decks.flooded(platform, pose), expected, "platform %d" % platform)
			flooded += 1 if expected else 0
	assert_gt(flooded, 0, "some of her platforms under")
