extends GutTest
## Once she has broken (SH33), the match is heard from the piece of her each sound lies on
## (#460): the listener's own cell is the one its ears are in on the piece they are on, and
## a cue with no seat sounds where its own piece carries its point — not where her aft
## piece, which the ship's own node follows, would.

const MATCH := preload("res://scenes/match/match.tscn")
const CLEAR := 2.0


## The weak hull's match 20 s after she parts in two, its view and audio drawn at that tick.
func _broken_match() -> MatchScene:
	var config := SimFixtures.breaking(1, null)
	var at := SimFixtures.after_parting(config.schedule(), 20.0)
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


func test_the_listener_s_cell_is_the_one_its_ears_are_in_on_its_piece() -> void:
	var scene := _broken_match()
	var schedule := scene._driver.sim().schedule
	var leaves := ShipPieces.leaves_of(schedule)
	var fore := leaves[leaves.size() - 1]
	var cut := schedule.span_of(fore).x
	var tick: int = scene._driver.current["tick"]
	var pose := schedule.pose_at(tick).of_piece(fore)
	var cell := -1
	for each in pose.cells.count():
		var middle := pose.cells.box_of(each).get_center()
		if middle.x >= cut + CLEAR and pose.cells.cell_at(middle) == each:
			cell = each
			break
	assert_ne(cell, -1, "a cell on her fore piece")
	if cell == -1:
		return
	var ears := pose.cells.box_of(cell).get_center()
	var on_fore := _world(scene, fore, ears)
	assert_gt(on_fore.distance_to(_world(scene, leaves[0], ears)), 1.0, "her pieces apart")
	var audio: MatchAudio = scene.get_node("Audio")
	audio._read_sinking(tick, on_fore)
	var floor_point := Vector3(ears.x, pose.cells.floor_of(cell), ears.z)
	var depth := pose.levels[cell] - pose.world_height(floor_point)
	assert_almost_eq(audio._cell_depth, depth, 1e-4, "the depth in the cell its ears are in")


func test_a_cue_with_no_seat_sounds_where_its_own_piece_carries_it() -> void:
	var scene := _broken_match()
	var config: MatchConfig = scene._driver.config()
	var schedule := scene._driver.sim().schedule
	var leaves := ShipPieces.leaves_of(schedule)
	var spot := SimFixtures.fore_spot(config.ship, schedule, CLEAR)
	assert_ne(spot, -1, "a spot on her fore piece")
	if spot == -1:
		return
	var cue := AudioCue.new(AudioCue.Kind.CREAK, scene._driver.current["tick"])
	cue.positional = true
	cue.position = config.ship.bonus_spots[spot].point
	var on_fore := _world(scene, leaves[leaves.size() - 1], cue.position)
	var on_aft := _world(scene, leaves[0], cue.position)
	assert_gt(on_fore.distance_to(on_aft), 1.0, "her pieces apart")
	var audio: MatchAudio = scene.get_node("Audio")
	var voice := audio._placed[audio._next_placed]
	audio._play(cue)
	assert_almost_eq(voice.global_position, on_fore, Vector3.ONE * 1e-4, "on its own piece")
