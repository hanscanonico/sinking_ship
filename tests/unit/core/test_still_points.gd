extends GutTest
## StillPoints answers for every point of her what ShipPose and Surfaces answer for it
## (D7): its height in the world, whether it is wet and how far it stands above its
## water, pose after pose — level and heeled, dry, flooded and with no cells at all — and
## again for a pose it read before, or one with another CellMap.


## Points through the steamer and round her, a metre apart along, half a metre up and
## across: in her cells, on their floors and ceilings, and out in the sea.
static func _points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for along in 44:
		for up in 28:
			for across in 26:
				points.append(Vector3(-21.5 + along, -6.5 + up * 0.5, -6.5 + across * 0.5))
	return points


## The steamer's cells flooded in turn to their middles and a hand over their floors,
## the sea [param sea] m over her main deck, the pose turned by [param heel_deg] and
## [param trim_deg] about her middle.
static func _pose(layout: ShipLayout, sea: float, heel_deg: float, trim_deg: float) -> ShipPose:
	var waters := {}
	var structure := layout.structure
	for index in structure.cells.size():
		var cell := structure.cells[index]
		if index % 3 == 0:
			waters[cell.name] = [lerpf(cell.low.y, cell.high.y, 0.5)]
		elif index % 3 == 1:
			waters[cell.name] = [cell.low.y + 0.1]
	var held := HeldPose.flooded(layout, sea, waters)
	var turn := Basis.from_euler(Vector3(deg_to_rad(heel_deg), 0.0, deg_to_rad(trim_deg)))
	var pose := ShipPose.new(
		held.sink, trim_deg, heel_deg, Transform3D(turn, held.transform.origin)
	)
	pose.cells = held.cells
	pose.levels = held.levels
	pose.pockets = held.pockets
	return pose


## How many points of [param points] [param still] answers otherwise than [param pose]
## and [param surfaces] do, having read [param pose].
static func _differing(
	still: StillPoints, points: PackedVector3Array, pose: ShipPose, surfaces: Surfaces
) -> int:
	still.read(pose)
	var differing := 0
	for index in points.size():
		var point := points[index]
		if (
			still.world_height(index) != pose.world_height(point)
			or still.wet(index) != surfaces.wet(point, pose)
			or still.above_water(index) != pose.above_water(point)
		):
			differing += 1
	return differing


func test_every_point_answers_as_the_pose_and_its_surfaces_do() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var points := _points()
	var still := StillPoints.new(points)
	var poses: Array[ShipPose] = [
		HeldPose.flooded(layout, -layout.freeboard, {}),
		_pose(layout, -2.0, 0.0, 0.0),
		_pose(layout, -1.0, 7.0, -2.5),
		_pose(layout, 0.5, -12.0, 4.0),
	]
	var wet := 0
	for pose in poses:
		assert_eq(_differing(still, points, pose, surfaces), 0, "the same answers everywhere")
		for index in points.size():
			wet += 1 if still.wet(index) else 0
	assert_gt(wet, points.size() / 10, "a fair share of the points are wet")
	assert_eq(_differing(still, points, poses[1], surfaces), 0, "and for a pose read again")


func test_a_pose_with_no_cells_has_her_in_the_sea() -> void:
	var layout := SimFixtures.steamer()
	var points := _points()
	var still := StillPoints.new(points)
	var pose := ShipPose.new(0.0, 0.0, 3.0, Transform3D(Basis(Vector3.RIGHT, 0.05), Vector3.ZERO))
	assert_eq(
		_differing(still, points, pose, Surfaces.new(layout)), 0, "the sea's water, as theirs"
	)


func test_another_cell_map_is_looked_through_afresh() -> void:
	# A piece of her, or another frame, reads its own CellMap: the points' cells are
	# found again in it, not taken from the last.
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var points := _points()
	var still := StillPoints.new(points)
	var first := _pose(layout, -1.0, 3.0, 1.0)
	assert_eq(_differing(still, points, first, surfaces), 0, "in its own cells")
	var other := _pose(layout, -1.0, 3.0, 1.0)
	other.cells = CellMap.new(layout.structure, Basis(Vector3.UP, PI))
	assert_eq(_differing(still, points, other, surfaces), 0, "and in another's")


func test_every_point_read_at_once_is_wet_as_each_asked_alone() -> void:
	var layout := SimFixtures.steamer()
	var points := _points()
	var still := StillPoints.new(points)
	var wet := 0
	for pose: ShipPose in [_pose(layout, -2.0, 0.0, 0.0), _pose(layout, 0.5, -12.0, 4.0)]:
		still.read(pose)
		var all := still.wet_all()
		var differing := 0
		for index in points.size():
			differing += 1 if (all[index] == 1) != still.wet(index) else 0
			wet += all[index]
		assert_eq(differing, 0, "every point as asked alone")
	assert_gt(wet, 0, "some of them wet")
