extends GutTest
## Once she has broken (SH33), eyes in no seat — the free camera's, the ghost's — read the
## water round them on the piece of her they are inside as it is drawn: a cell of her fore
## piece is that cell where the fore piece stands, not where her aft piece, which the
## ship's own node follows, would carry it.

const MATCH := preload("res://scenes/match/match.tscn")
const CLEAR := 2.0
## Her aft piece has gone under by now, her fore piece still afloat, the two well apart.
const AFT_UNDER := 180.0
## How far a point stands from the sea's surface and its cell's water to be read plainly.
const PLAIN := 0.3


## The weak hull's match [param seconds] after she parts in two, only watched, its view
## drawn at that tick.
func _broken_match(seconds := AFT_UNDER) -> MatchScene:
	var config := SimFixtures.breaking(1, null)
	var at := SimFixtures.after_parting(config.schedule(), seconds)
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(config, true, false, MatchScene.LOCAL_SEAT, INF, true, null, at)
	scene.get_node("MatchView")._process(0.0)
	return scene


## Where [param scene]'s view draws piece [param piece] of her now, in its own space: its
## pose interpolated between the two snapshots drawn.
func _drawn(scene: MatchScene, piece: int) -> Transform3D:
	var driver := scene._driver
	var schedule := driver.sim().schedule
	var then := schedule.pose_at(driver.previous["tick"]).of_piece(piece).transform
	var now := schedule.pose_at(driver.current["tick"]).of_piece(piece).transform
	return then.interpolate_with(now, driver.alpha)


## Where [param point] of her ship space is drawn in the world on piece [param piece].
func _world(scene: MatchScene, piece: int, point: Vector3) -> Vector3:
	return scene.get_node("MatchView").global_transform * _drawn(scene, piece) * point


## Her fore piece — the last she ends in, which the ship's own node does not follow — and
## its pose at the tick drawn.
func _fore(scene: MatchScene) -> int:
	var leaves := ShipPieces.leaves_of(scene._driver.sim().schedule)
	return leaves[leaves.size() - 1]


func _fore_pose(scene: MatchScene) -> ShipPose:
	var schedule := scene._driver.sim().schedule
	return schedule.pose_at(scene._driver.current["tick"]).of_piece(_fore(scene))


## A cell of her fore piece, CLEAR or more fore of its cut, whose middle stands under the
## sea's surface and over the cell's own water — dry air under the waterline — or -1.
func _dry_cell_under_the_sea(scene: MatchScene) -> int:
	var fore := _fore(scene)
	var pose := _fore_pose(scene)
	var cut := scene._driver.sim().schedule.span_of(fore).x
	for cell in pose.cells.count():
		var middle := pose.cells.box_of(cell).get_center()
		if middle.x < cut + CLEAR or pose.cells.cell_at(middle) != cell:
			continue
		var height := _world(scene, fore, middle).y
		if height < -PLAIN and height > pose.levels[cell] + PLAIN:
			return cell
	return -1


func test_a_free_eye_in_a_cell_of_her_fore_piece_reads_that_cell() -> void:
	var scene := _broken_match()
	var view: MatchView = scene.get_node("MatchView")
	var cell := _dry_cell_under_the_sea(scene)
	assert_ne(cell, -1, "a dry cell of her fore piece under the sea's surface")
	if cell == -1:
		return
	var fore := _fore(scene)
	var pose := _fore_pose(scene)
	var middle := pose.cells.box_of(cell).get_center()
	var eye := _world(scene, fore, middle)
	var aft := ShipPieces.leaves_of(scene._driver.sim().schedule)[0]
	assert_gt(eye.distance_to(_world(scene, aft, middle)), 1.0, "her pieces apart")
	view.look_out_of(-1)
	assert_true(view.indoors(eye), "inside her")
	assert_almost_eq(view.above_water(eye), eye.y - pose.levels[cell], 1e-4, "over its water")
	assert_gt(view.above_water(eye), 0.0, "in its air, under the sea's surface")
	assert_eq(view.lit_at(eye), pose.lit[cell], "lit as its cell is")


func test_a_free_eye_where_her_aft_piece_would_carry_that_cell_is_in_the_sea() -> void:
	var scene := _broken_match()
	var view: MatchView = scene.get_node("MatchView")
	var cell := _dry_cell_under_the_sea(scene)
	assert_ne(cell, -1, "a dry cell of her fore piece under the sea's surface")
	if cell == -1:
		return
	var pose := _fore_pose(scene)
	var middle := pose.cells.box_of(cell).get_center()
	# Where the cell would be drawn were her fore piece still one with her aft piece:
	# open sea, or air over it, now that the fore piece has gone its own way.
	var aft := ShipPieces.leaves_of(scene._driver.sim().schedule)[0]
	var eye := _world(scene, aft, middle)
	assert_ne(
		pose.cells.cell_at(_drawn(scene, _fore(scene)).affine_inverse() * eye),
		cell,
		"the cell is not there"
	)
	view.look_out_of(-1)
	assert_false(view.indoors(eye), "outside her")
	assert_almost_eq(view.above_water(eye), eye.y, 1e-4, "the sea's water")
	assert_eq(view.lit_at(eye), ShipPower.Power.MAIN, "the sky's light")


func test_the_free_camera_in_dry_air_under_the_waterline_is_not_under_water() -> void:
	var scene := _broken_match()
	var cell := _dry_cell_under_the_sea(scene)
	assert_ne(cell, -1, "a dry cell of her fore piece under the sea's surface")
	if cell == -1:
		return
	var eye := _world(scene, _fore(scene), _fore_pose(scene).cells.box_of(cell).get_center())
	_fly_to(scene, eye)
	assert_true(scene._free.active, "a watcher flies the free camera")
	assert_almost_eq(scene._eyes.global_position, eye, Vector3.ONE * 1e-4, "the view is its own")
	assert_false(scene._underwater.is_under(), "in the cell's air")


## Stands [param scene]'s free camera at [param eye] in the world, the match only watched,
## and draws a frame from it.
func _fly_to(scene: MatchScene, eye: Vector3) -> void:
	scene._watcher = true
	scene._free.active = true
	scene._free.following = false
	scene._free.position = eye
	scene._process(0.0)
