extends GutTest
## Once she has broken (SH33), the sinking is seen on the piece of her each effect lies on
## (#466): a cue plays, and what lasts goes on, where its own piece carries its point; the
## wet decks soak and are drawn as their own piece stands, a deck across the cut on both;
## wreckage lands on the decks of its own piece; and a piece of flotsam goes under over a
## deck as the deck's own piece stands — not as her aft piece, which the ship's own node
## follows, would have them.

const MATCH := preload("res://scenes/match/match.tscn")
const CLEAR := 2.0
## Her aft piece has gone under by now, her fore piece still afloat: the wet decks and the
## flotsam read the sea off whichever piece they take a deck to stand on.
const AFT_UNDER := 180.0
const NEAR := 1e-3


## The weak hull's match [param seconds] after she parts in two, its view and effects
## drawn at that tick.
func _broken_match(seconds := 20.0) -> MatchScene:
	var config := SimFixtures.breaking(1, null)
	var at := SimFixtures.after_parting(config.schedule(), seconds)
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(config, true, false, MatchScene.LOCAL_SEAT, INF, true, null, at)
	scene.get_node("MatchView")._process(0.0)
	scene._fx._process(0.0)
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


func _leaves(scene: MatchScene) -> PackedInt32Array:
	return ShipPieces.leaves_of(scene._driver.sim().schedule)


func _cut(scene: MatchScene) -> float:
	var leaves := _leaves(scene)
	return scene._driver.sim().schedule.span_of(leaves[leaves.size() - 1]).x


## A point of her ship space on her fore piece, CLEAR or more fore of its cut: a bonus
## spot's, on her decks.
func _fore_point(scene: MatchScene) -> Vector3:
	var config: MatchConfig = scene._driver.config()
	var spot := SimFixtures.fore_spot(config.ship, scene._driver.sim().schedule, CLEAR)
	assert_ne(spot, -1, "a spot on her fore piece")
	return config.ship.bonus_spots[maxi(spot, 0)].point


## The point [param point] on her fore piece, and on her aft one, in the world now:
## apart, so a test tells which piece carries it.
func _on_each(scene: MatchScene, point: Vector3) -> PackedVector3Array:
	var leaves := _leaves(scene)
	var on_fore := _world(scene, leaves[leaves.size() - 1], point)
	var on_aft := _world(scene, leaves[0], point)
	assert_gt(on_fore.distance_to(on_aft), 1.0, "her pieces apart")
	return PackedVector3Array([on_fore, on_aft])


func _ship(scene: MatchScene) -> Transform3D:
	return scene.get_node("MatchView").ship_to_world()


func test_a_cue_plays_where_its_own_piece_carries_it() -> void:
	var scene := _broken_match()
	var point := _fore_point(scene)
	var on_fore := _on_each(scene, point)[0]
	var fx := scene._fx
	var dust := fx._dusts[fx._next_dust]
	var cue := FxCue.new(FxCue.Kind.DUST, scene._driver.current["tick"], point)
	cue.radius = 1.0
	cue.strength = 0.5
	fx.play([cue], _ship(scene), null)
	assert_almost_eq(dust.global_position, on_fore, Vector3.ONE * NEAR, "on its own piece")


func test_steam_goes_on_rising_from_its_own_piece() -> void:
	var scene := _broken_match()
	var point := _fore_point(scene)
	var on_fore := _on_each(scene, point)[0]
	var fx := scene._fx
	var steam := FxCue.new(FxCue.Kind.STEAM, scene._driver.current["tick"], point)
	steam.seconds = 3.0
	steam.strength = 0.5
	fx.play([steam], _ship(scene), null)
	fx._process(0.0)
	var rising := fx._plumes.filter(func(plume: CPUParticles3D) -> bool: return plume.emitting)
	assert_eq(rising.size(), 1, "a plume")
	if rising.size() == 1:
		var plume: CPUParticles3D = rising[0]
		assert_almost_eq(plume.global_position, on_fore, Vector3.ONE * NEAR, "on its own piece")


func test_the_breach_s_water_and_rents_go_on_on_their_own_piece() -> void:
	var scene := _broken_match()
	var point := _fore_point(scene)
	var fx := scene._fx
	var tick: int = scene._driver.current["tick"]
	var jet := FxCue.new(FxCue.Kind.JET, tick, point)
	jet.end = point + Vector3(0.0, 0.0, 1.0)
	jet.toward = Vector3.BACK
	jet.rise = 1.0
	jet.strength = 0.5
	jet.source = 0
	var rent := FxCue.new(FxCue.Kind.RENT, tick, point)
	rent.end = point + Vector3(1.0, 0.0, 0.0)
	rent.toward = Vector3.BACK
	rent.radius = 0.5
	fx.play([jet, rent], _ship(scene), null)
	fx._process(0.0)
	var middle := (jet.position + jet.end) * 0.5
	var on_fore := _on_each(scene, middle)[0]
	var going := fx._breach._jets.filter(func(each: CPUParticles3D) -> bool: return each.emitting)
	assert_eq(going.size(), 1, "a jet")
	if going.size() == 1:
		var at: Vector3 = (going[0] as CPUParticles3D).global_position
		assert_almost_eq(at, on_fore, Vector3.ONE * NEAR, "the jet on its own piece")
	var torn: MeshInstance3D = fx._breach._rents[0]
	var lying := _on_each(scene, (rent.position + rent.end) * 0.5)[0]
	assert_almost_eq(torn.global_position, lying, Vector3.ONE * NEAR, "the rent in its own piece")


func test_froth_lies_on_the_sea_off_its_own_piece() -> void:
	var scene := _broken_match()
	var point := _fore_point(scene)
	var fx := scene._fx
	var froth := FxCue.new(FxCue.Kind.FROTH, scene._driver.current["tick"], point)
	froth.end = point + Vector3(1.0, 0.0, 0.0)
	froth.toward = Vector3.BACK
	froth.strength = 0.5
	froth.seconds = 5.0
	fx.play([froth], _ship(scene), null)
	fx._process(0.0)
	_on_each(scene, point)
	var foam: CPUParticles3D = fx._gash._froths[0]
	var laid := foam.global_position
	var leaves := _leaves(scene)
	var fore := _drawn(scene, leaves[leaves.size() - 1])
	fx._gash._lay_froth(0, scene.get_node("MatchView").global_transform * fore)
	assert_almost_eq(laid, foam.global_position, Vector3.ONE * NEAR, "off its own piece")


func test_wreckage_lands_on_the_decks_of_its_own_piece() -> void:
	var scene := _broken_match()
	var layout: ShipLayout = scene._driver.config().ship
	# Over the middle of an open deck of her fore piece.
	var point := Vector3(NAN, NAN, NAN)
	for index: int in scene._fx._wetness.platforms:
		var deck := layout.platforms[index]
		if deck.area.position.x >= _cut(scene) + CLEAR:
			point = Vector3(deck.area.get_center().x, deck.height + 1.0, deck.area.get_center().y)
			break
	assert_false(is_nan(point.x), "an open deck on her fore piece")
	if is_nan(point.x):
		return
	var on_fore := _on_each(scene, point)[0]
	var fx := scene._fx
	var debris := FxCue.new(FxCue.Kind.DEBRIS, scene._driver.current["tick"], point)
	debris.radius = 3.0
	fx.play([debris], _ship(scene), null)
	var landing: Array[DeckDebris] = []
	for found: Node in fx.find_children("Debris", "", true, false):
		if found is DeckDebris and (found as DeckDebris).count() > 0:
			landing.append(found)
	assert_eq(landing.size(), 1, "its bits on one piece's decks")
	for on: DeckDebris in landing:
		assert_almost_eq(on.global_transform * point, on_fore, Vector3.ONE * NEAR, "its own")


func test_a_deck_s_wetness_is_drawn_on_its_own_piece_and_one_across_the_cut_on_both() -> void:
	var scene := _broken_match()
	var layout: ShipLayout = scene._driver.config().ship
	var cut := _cut(scene)
	var fx := scene._fx
	var wholly := -1
	var across := -1
	for slot in fx._wetness.platforms.size():
		var area := layout.platforms[fx._wetness.platforms[slot]].area
		if wholly == -1 and area.position.x >= cut + CLEAR:
			wholly = fx._wetness.platforms[slot]
		if across == -1 and area.position.x < cut - CLEAR and area.end.x > cut + CLEAR:
			across = fx._wetness.platforms[slot]
	assert_ne(wholly, -1, "a wet deck on her fore piece")
	assert_ne(across, -1, "a wet deck across her cut")
	if wholly == -1 or across == -1:
		return
	var deck := layout.platforms[wholly]
	var middle := Vector3(deck.area.get_center().x, deck.height, deck.area.get_center().y)
	var on_fore := _on_each(scene, middle)[0]
	var drawn := _overlays_of(fx, wholly)
	assert_eq(drawn.size(), 1, "one overlay")
	for overlay: MeshInstance3D in drawn:
		assert_almost_eq(overlay.global_transform * middle, on_fore, Vector3.ONE * NEAR, "fore")
	var long := layout.platforms[across]
	var fore_end := Vector3(cut + CLEAR, long.height, long.area.get_center().y)
	var aft_end := Vector3(cut - CLEAR, long.height, long.area.get_center().y)
	var fore_world := _on_each(scene, fore_end)[0]
	var aft_world := _on_each(scene, aft_end)[1]
	var on_both := _overlays_of(fx, across)
	assert_eq(on_both.size(), 2, "an overlay on each piece")
	var fore_drawn := false
	var aft_drawn := false
	for overlay: MeshInstance3D in on_both:
		var holds := _holds(overlay, fore_end)
		if holds:
			fore_drawn = (overlay.global_transform * fore_end).distance_to(fore_world) < NEAR
		if _holds(overlay, aft_end):
			aft_drawn = (overlay.global_transform * aft_end).distance_to(aft_world) < NEAR
	assert_true(fore_drawn, "its fore end drawn on her fore piece")
	assert_true(aft_drawn, "its aft end drawn on her aft piece")


func test_a_deck_soaks_as_its_own_piece_stands_in_the_sea() -> void:
	var scene := _broken_match(AFT_UNDER)
	var layout: ShipLayout = scene._driver.config().ship
	var cut := _cut(scene)
	var leaves := _leaves(scene)
	var schedule := scene._driver.sim().schedule
	var pose := schedule.pose_at(scene._driver.current["tick"])
	var fore := pose.of_piece(leaves[leaves.size() - 1])
	var aft := pose.of_piece(leaves[0])
	var fx := scene._fx
	var outs := DeckWetness.out_on_deck(layout)
	# Patches out on deck CLEAR either side of the cut: one aft the sea stands over, on
	# her aft piece, and one fore it stands under, on her fore piece — dry, though her aft
	# piece, carrying it, would have it under the sea.
	var fore_dry := Vector3(NAN, NAN, NAN)
	var aft_wet := Vector3(NAN, NAN, NAN)
	for index: int in fx._wetness.platforms:
		var deck := layout.platforms[index]
		var size := Vector2i((deck.area.size / DeckWetness.CELL).ceil())
		for patch in outs[index].size():
			if outs[index][patch] == 0:
				continue
			var middle := (
				deck.area.position
				+ (Vector2(patch % size.x, patch / size.x) + Vector2(0.5, 0.5)) * DeckWetness.CELL
			)
			var at := Vector3(middle.x, deck.height, middle.y)
			if not deck.area.has_point(middle):
				continue
			if at.x >= cut + CLEAR and fore.world_height(at) > 1.0 and aft.world_height(at) < -1.0:
				fore_dry = at
			if at.x <= cut - CLEAR and aft.world_height(at) < -1.0:
				aft_wet = at
	assert_false(is_nan(fore_dry.x), "a patch on her fore piece over the sea")
	assert_false(is_nan(aft_wet.x), "a patch on her aft piece under it")
	if is_nan(fore_dry.x) or is_nan(aft_wet.x):
		return
	# Round every deck, a deck a step.
	for step in fx._wetness.platforms.size():
		fx._on_stepped([])
	assert_eq(_wetness_at(fx, layout, fore_dry), 0.0, "dry on her fore piece")
	assert_eq(_wetness_at(fx, layout, aft_wet), 1.0, "soaked on her aft piece")


func test_flotsam_goes_under_over_a_deck_as_its_own_piece_stands() -> void:
	var scene := _broken_match(AFT_UNDER)
	var layout: ShipLayout = scene._driver.config().ship
	var cut := _cut(scene)
	var leaves := _leaves(scene)
	var schedule := scene._driver.sim().schedule
	var view: MatchView = scene.get_node("MatchView")
	var pose := schedule.pose_at(scene._driver.current["tick"])
	var fore := view.global_transform * pose.of_piece(leaves[leaves.size() - 1]).transform
	var aft := view.global_transform * pose.of_piece(leaves[0]).transform
	# A point on the sea over a deck of her fore piece standing over it: no piece floats
	# there, though over her aft piece, carrying the deck, the sea would be deep.
	var over := Vector3(NAN, NAN, NAN)
	for deck: ShipPlatform in layout.platforms:
		var middle := Vector3(deck.area.get_center().x, deck.height, deck.area.get_center().y)
		if deck.area.position.x < cut + CLEAR or (fore * middle).y < 0.5:
			continue
		var sea := fore * middle
		sea.y = 0.0
		var under_aft := aft.affine_inverse() * sea
		if _deck_depth(layout, aft, under_aft) < -1.0:
			over = sea
			break
	assert_false(is_nan(over.x), "a fore deck over the sea that her aft piece would drown")
	if is_nan(over.x):
		return
	var flotsam := scene._fx._flotsam
	flotsam._state[0] = Flotsam.State.AFLOAT
	flotsam._pieces[0].position = over
	scene._fx._on_stepped([])
	assert_eq(flotsam._state[0], Flotsam.State.SINKING, "under: its deck stands over the sea")


## The world height of the highest deck of [param layout] over ship point [param point] on
## a piece drawn at [param ship]; -INF over none.
func _deck_depth(layout: ShipLayout, ship: Transform3D, point: Vector3) -> float:
	var highest := -INF
	for deck: ShipPlatform in layout.platforms:
		if deck.area.has_point(Vector2(point.x, point.z)):
			highest = maxf(highest, (ship * Vector3(point.x, deck.height, point.z)).y)
	return highest


## The wet decks' overlays of platform [param index].
func _overlays_of(fx: SinkingFx, index: int) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for each: Node in fx.find_children("Wet%d*" % index, "MeshInstance3D", true, false):
		var name := String(each.name)
		if name == "Wet%d" % index or name.begins_with("Wet%d_" % index):
			found.append(each)
	return found


## Whether [param overlay]'s quad lies over ship point [param point].
func _holds(overlay: MeshInstance3D, point: Vector3) -> bool:
	var box := overlay.mesh.get_aabb()
	return point.x >= box.position.x and point.x <= box.end.x


## How wet the patch over ship point [param point] is on the tracked deck it stands on.
func _wetness_at(fx: SinkingFx, layout: ShipLayout, point: Vector3) -> float:
	for slot in fx._wetness.platforms.size():
		var deck := layout.platforms[fx._wetness.platforms[slot]]
		if is_equal_approx(deck.height, point.y) and deck.area.has_point(Vector2(point.x, point.z)):
			return fx._wetness.wetness(slot, point.x, point.z)
	return NAN
