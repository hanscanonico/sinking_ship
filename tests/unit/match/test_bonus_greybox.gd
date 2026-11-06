extends GutTest
## The bonuses aboard, drawn in greybox (#310) from the snapshot: each at its bonus spot, a
## shape of its kind's size in its kind's colour standing on the spot's floor, lit from
## within (#313) — none once it is no longer aboard, and none at all in a match without
## bonuses. Once she has broken (SH33), each lies on the piece of her its spot is on (#335).

const MATCH := preload("res://scenes/match/match.tscn")


## The shapes [param drawn] shows, in the order the snapshot lists its bonuses.
func _shown(drawn: BonusGreybox) -> Array[MeshInstance3D]:
	var shown: Array[MeshInstance3D] = []
	for child: Node in drawn.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			shown.append(child)
	return shown


func test_each_bonus_aboard_is_drawn_at_its_spot() -> void:
	var layout := SimFixtures.below_decks(3)
	var bonuses := SimFixtures.bonus_rules()
	var drawn: BonusGreybox = add_child_autofree(BonusGreybox.new())
	drawn.setup(layout, bonuses)
	var sim := SimFixtures.bonus_sim(bonuses, 1, layout)
	SimFixtures.bring_aboard(sim, 2)
	SimFixtures.bring_aboard(sim, 0)
	drawn.show_bonuses(sim.snapshot())
	var shown := _shown(drawn)
	assert_eq(shown.size(), 2, "both aboard")
	var kind := SimFixtures.double_life()
	for index in mini(shown.size(), 2):
		var point := layout.bonus_spots[[2, 0][index]].point
		var middle := point + Vector3.UP * kind.height * 0.5
		assert_almost_eq(shown[index].position, middle, Vector3.ONE * 1e-6, "on its spot")
		var mesh := shown[index].mesh as CylinderMesh
		assert_not_null(mesh, "a greybox shape")
		if mesh != null:
			assert_almost_eq(mesh.top_radius, kind.radius, 1e-6, "its kind's size")
			assert_almost_eq(mesh.height, kind.height, 1e-6)
			var material := mesh.material as StandardMaterial3D
			assert_eq(material.albedo_color, kind.mark, "in its kind's colour")
	sim.state.bonuses.remove_at(0)
	drawn.show_bonuses(sim.snapshot())
	assert_eq(_shown(drawn).size(), 1, "one taken: one drawn")
	sim.state.bonuses.clear()
	drawn.show_bonuses(sim.snapshot())
	assert_eq(_shown(drawn).size(), 0, "none aboard: none drawn")


## A bonus aboard is lit from within (#313), so that it shows in a dark room: its kind's
## colour given off as well as lit, at no less than the colour itself. Yet it is
## depth-tested as any mesh, and casts no lamp's light, which would reach through a wall:
## nothing of it shows through one (§13).
func test_a_bonus_aboard_glows_but_never_through_a_wall() -> void:
	var layout := SimFixtures.below_decks()
	var bonuses := SimFixtures.bonus_rules()
	var drawn: BonusGreybox = add_child_autofree(BonusGreybox.new())
	drawn.setup(layout, bonuses)
	var sim := SimFixtures.bonus_sim(bonuses, 1, layout)
	SimFixtures.bring_aboard(sim, 0)
	drawn.show_bonuses(sim.snapshot())
	var shown := _shown(drawn)
	assert_eq(shown.size(), 1)
	if shown.size() == 1:
		var material := (shown[0].mesh as PrimitiveMesh).material as StandardMaterial3D
		assert_true(material.emission_enabled, "lit from within")
		assert_eq(material.emission, SimFixtures.double_life().mark, "in its kind's colour")
		assert_gte(material.emission_energy_multiplier, 1.0, "as bright as its colour, unlit")
		assert_false(material.no_depth_test, "hidden behind a wall as any mesh is")
	assert_eq(drawn.find_children("*", "Light3D", true, false), [], "no lamp")


## A bonus the sea takes (#311) leaves the snapshot, and its drawing goes with it.
func test_a_bonus_lost_to_the_sea_is_drawn_no_more() -> void:
	var layout := SimFixtures.below_decks()
	var bonuses := SimFixtures.bonus_rules(600.0)
	var drawn: BonusGreybox = add_child_autofree(BonusGreybox.new())
	drawn.setup(layout, bonuses)
	var sim := SimFixtures.bonus_sim(bonuses, 1, layout, SimFixtures.flooding(1.0))
	SimFixtures.bring_aboard(sim, 0)
	drawn.show_bonuses(sim.snapshot())
	assert_eq(_shown(drawn).size(), 1, "drawn while it lies dry")
	SimFixtures.step(sim, {}, Ticks.RATE + 2)
	drawn.show_bonuses(sim.snapshot())
	assert_eq(_shown(drawn).size(), 0, "lost to the sea: drawn no more")


func test_a_match_without_bonuses_draws_none() -> void:
	var drawn: BonusGreybox = add_child_autofree(BonusGreybox.new())
	drawn.setup(SimFixtures.below_decks(), null)
	drawn.show_bonuses(SimFixtures.sim(1, null, SimFixtures.below_decks()).snapshot())
	assert_eq(_shown(drawn).size(), 0)


## Once she has broken (SH33), a bonus is drawn on the piece of her its spot lies on, wherever
## that piece goes (#335): on the weak hull 20 s after she parts, a bonus on her fore piece
## stands where that piece's pose has its spot — not where her aft piece, which the ship's
## own node follows, would carry it.
func test_a_bonus_on_a_piece_she_broke_into_is_drawn_where_that_piece_is() -> void:
	var config := SimFixtures.breaking(1, SimFixtures.bonus_rules(600.0))
	var schedule := config.schedule()
	var at := SimFixtures.after_parting(schedule, 20.0)
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(config, true, false, MatchScene.LOCAL_SEAT, INF, true, null, at)
	var spot := SimFixtures.fore_spot(config.ship, schedule, 2.0)
	assert_ne(spot, -1, "a spot on her fore piece")
	if spot == -1:
		return
	var aboard: Array = scene._driver.current["bonuses"]
	aboard.append(BonusState.new(-1, 0, spot).to_dict())
	var view: MatchView = scene.get_node("MatchView")
	view._process(0.0)
	var shown := _shown(view.get_node("Ship/Bonuses"))
	assert_eq(shown.size(), 1, "drawn")
	if shown.size() != 1:
		return
	var leaves := ShipPieces.leaves_of(schedule)
	var middle := (
		config.ship.bonus_spots[spot].point + Vector3.UP * SimFixtures.double_life().height * 0.5
	)
	var on_fore := view.global_transform * _drawn(scene, leaves[leaves.size() - 1]) * middle
	var on_aft := view.global_transform * _drawn(scene, leaves[0]) * middle
	assert_gt(on_fore.distance_to(on_aft), 1.0, "her pieces apart by then")
	assert_almost_eq(shown[0].global_position, on_fore, Vector3.ONE * 1e-4, "on its own piece")


## Where [param scene]'s view draws piece [param piece] of her now, in its own space: its
## pose interpolated between the two snapshots drawn.
func _drawn(scene: MatchScene, piece: int) -> Transform3D:
	var driver := scene._driver
	var schedule := driver.sim().schedule
	var then := schedule.pose_at(driver.previous["tick"]).of_piece(piece).transform
	var now := schedule.pose_at(driver.current["tick"]).of_piece(piece).transform
	return then.interpolate_with(now, driver.alpha)
