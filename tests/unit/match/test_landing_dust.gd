extends GutTest
## Once she has broken (SH33), dust and splinters fly from the piece of her they come from
## (#460): a span breaking on her fore piece splinters where that piece carries it, and a
## seat landing there kicks up dust at its feet on it — not where her aft piece, which the
## ship's own node follows, would carry them.

const MATCH := preload("res://scenes/match/match.tscn")
const CLEAR := 2.0


## The weak hull's match of two seats 20 s after she parts in two, drawn at that tick.
func _broken_match() -> MatchScene:
	var config := SimFixtures.breaking(2, null)
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


## The puff [param scene]'s dust kicked up last.
func _last_puff(scene: MatchScene) -> CPUParticles3D:
	var puffs := scene._dust.find_children("*", "CPUParticles3D", false, false)
	return puffs[puffs.size() - 1] if not puffs.is_empty() else null


func test_a_span_breaking_on_a_piece_splinters_where_that_piece_is() -> void:
	var scene := _broken_match()
	var config: MatchConfig = scene._driver.config()
	var schedule := scene._driver.sim().schedule
	var leaves := ShipPieces.leaves_of(schedule)
	var cut := schedule.span_of(leaves[leaves.size() - 1]).x
	var above := config.rules.railing_height * 0.5
	var railing := -1
	for each in config.ship.railings.size():
		if config.ship.railing_middle(each, above).x >= cut + CLEAR:
			railing = each
			break
	assert_ne(railing, -1, "a span on her fore piece")
	if railing == -1:
		return
	var middle := config.ship.railing_middle(railing, above)
	var on_fore := _world(scene, leaves[leaves.size() - 1], middle)
	assert_gt(on_fore.distance_to(_world(scene, leaves[0], middle)), 1.0, "her pieces apart")
	var tick: int = scene._driver.current["tick"]
	scene._dust._on_stepped([SimEvent.railing_broke(tick, railing, 0, -1)])
	var puff := _last_puff(scene)
	assert_not_null(puff, "splinters")
	if puff == null:
		return
	assert_almost_eq(puff.global_position, on_fore, Vector3.ONE * 1e-4, "on its own piece")


func test_a_seat_landing_on_a_piece_kicks_up_dust_where_that_piece_is() -> void:
	var scene := _broken_match()
	var config: MatchConfig = scene._driver.config()
	var schedule := scene._driver.sim().schedule
	var leaves := ShipPieces.leaves_of(schedule)
	var fore := leaves[leaves.size() - 1]
	var spot := SimFixtures.fore_spot(config.ship, schedule, CLEAR)
	assert_ne(spot, -1, "a spot on her fore piece")
	if spot == -1:
		return
	var feet := config.ship.bonus_spots[spot].point
	var lander: Dictionary = scene._driver.current["seats"][1]
	lander["pos"] = feet
	lander["piece"] = fore
	scene._driver.previous["seats"][1]["piece"] = fore
	scene.get_node("MatchView")._process(0.0)
	var on_fore := _world(scene, fore, feet)
	assert_gt(on_fore.distance_to(_world(scene, leaves[0], feet)), 1.0, "her pieces apart")
	var tick: int = scene._driver.current["tick"]
	scene._dust._on_stepped([SimEvent.landed(tick, 1, Surfaces.NONE, 4)])
	var puff := _last_puff(scene)
	assert_not_null(puff, "dust")
	if puff == null:
		return
	assert_almost_eq(puff.global_position, on_fore, Vector3.ONE * 1e-4, "on its own piece")
