extends GutTest
## What a box on an open deck is drawn as (DeckFurniture): a casing where a deck rests on
## it; a hatch's coaming over one of her structure's hatch openings in the deck it stands
## on — every box of a ship with no structure —; else a skylight, a seat locker or a
## towing post by its shape; and each piece drawn inside its box, its sides on the box's
## and its top the box's, but for a skylight's guard rods and a towing hook just over it.

## How far past its box a piece's faces may stand: the furniture's FLUSH and float noise.
const OUTSIDE := 0.005
## The Small Titanic's boat deck's height (tools/gen_small_titanic.py's BOAT), her other
## open decks' (A_DECK, B_DECK, her wells', POOP and the forecastle's FCSL), and the
## ferry's passenger and bridge decks' (tools/gen_ferry.py's PASS and BRIDGE). The liner's
## furniture is checked on her: the Titanic's traced decks (#360) are held by the lints.
const BOAT_DECK := 8.375
const A_DECK := 5.5
const TITANIC_OPEN_DECKS: Array[float] = [8.375, 5.5, 2.75, 0.0, 3.3125, 4.3125]
const FERRY_PASSENGER_DECK := 4.8
const FERRY_BRIDGE_DECK := 7.6

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


func _layout(ship: String) -> ShipLayout:
	return Fleet.layout(StringName(ship))


## What [param blocker] of [param layout] is drawn as.
func _piece(layout: ShipLayout, blocker: ShipBlocker) -> DeckFurniture.Piece:
	return DeckFurniture.piece_of(ShipSpace.new(layout), blocker)


## [param layout]'s box blocker over [param area], or null.
func _box(layout: ShipLayout, area: Rect2) -> ShipBlocker:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.BOX and blocker.area.is_equal_approx(area):
			return blocker
	return null


func _blocker(area: Rect2, bottom: float, top: float) -> ShipBlocker:
	var blocker := ShipBlocker.new()
	blocker.shape = ShipBlocker.Shape.BOX
	blocker.area = area
	blocker.bottom = bottom
	blocker.top = top
	return blocker


## Every face [param blocker] is drawn with, as DeckFurniture.build draws it to
## [param top]: its own top, or as ShipArt draws a box a deck rests on, a plank short.
func _drawn(layout: ShipLayout, blocker: ShipBlocker, top := INF) -> PackedVector3Array:
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
	DeckFurniture.build(mesh, ShipSpace.new(layout), blocker, minf(top, blocker.top))
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	var holder := Node3D.new()
	mesh.commit(holder, materials)
	var faces := PackedVector3Array()
	for child: Node in holder.get_children():
		faces.append_array((child as MeshInstance3D).mesh.get_faces())
	holder.free()
	return faces


func test_the_steamer_s_well_hatch_stays_a_hatch() -> void:
	var steamer := _layout("steamer")
	var hatch := _box(steamer, Rect2(4.0, -1.0, 4.0, 2.0))
	assert_not_null(hatch, "her well deck's hatch")
	assert_eq(_piece(steamer, hatch), DeckFurniture.Piece.HATCH)


func test_every_hatch_of_the_fleet_stays_a_hatch() -> void:
	var hatches := 0
	for ship: String in Fleet.names():
		var layout := _layout(ship)
		for opening: ShipOpening in layout.structure.openings:
			if opening.kind != ShipOpening.Kind.HATCH:
				continue
			var under := Vector2(opening.centre.x, opening.centre.z)
			for blocker: ShipBlocker in _on_deck(layout, opening.centre.y):
				if blocker.area.has_point(under):
					var named := "%s's %s" % [ship, opening.name]
					assert_eq(_piece(layout, blocker), DeckFurniture.Piece.HATCH, named)
					hatches += 1
	assert_gt(hatches, 20, "the fleet's cargo hatches")


func test_the_liner_s_casings_under_her_boat_deck_are_casings() -> void:
	var titanic := _layout("small_titanic")
	var space := ShipSpace.new(titanic)
	var casings := 0
	for blocker: ShipBlocker in _on_deck(titanic, A_DECK):
		if not space.deck_on(blocker):
			continue
		assert_eq(_piece(titanic, blocker), DeckFurniture.Piece.CASING, "%s" % blocker.area)
		casings += 1
	assert_eq(casings, 3, "funnel 2's and 3's casings, and the cabins round funnel 1")


## A casing a deck rests on over only part of its top stands up to its own top where the
## deck stops short of its edge, as a wall under a deck does: the Titanic's No. 4 hatch
## trunks, under the end of A deck's step, were drawn open-topped.
func test_a_casing_a_deck_half_covers_is_topped_where_the_deck_is_not() -> void:
	var tug: ShipLayout = _layout("tug").duplicate()
	var deck := ShipPlatform.new()
	deck.area = Rect2(10.0, -2.0, 1.0, 4.0)
	deck.height = 3.0
	var platforms := tug.platforms.duplicate()
	platforms.append(deck)
	tug.platforms = platforms
	var trunk := _blocker(Rect2(9.0, -1.0, 2.0, 2.0), 0.0, 3.0)
	assert_eq(_piece(tug, trunk), DeckFurniture.Piece.CASING, "the deck rests on half of it")
	var topped := false
	var faces := _drawn(tug, trunk, trunk.top - ShipArt.PLANK)
	var bare := Rect2(9.0, -1.0, 1.0, 2.0)
	for index in range(0, faces.size(), 3):
		var corners := faces.slice(index, index + 3)
		var flat := true
		for corner: Vector3 in corners:
			flat = flat and is_equal_approx(corner.y, 3.0)
		var middle := (corners[0] + corners[1] + corners[2]) / 3.0
		topped = topped or (flat and bare.has_point(Vector2(middle.x, middle.z)))
	assert_true(topped, "its top drawn aft of the deck")


func test_the_small_craft_s_skylights_are_skylights() -> void:
	var trawler := _layout("trawler")
	var trawler_s := _box(trawler, Rect2(-13.6, -0.5, 1.0, 1.0))
	assert_not_null(trawler_s, "the trawler's engine room skylight")
	assert_eq(_piece(trawler, trawler_s), DeckFurniture.Piece.SKYLIGHT)
	var tug := _layout("tug")
	var tug_s := _box(tug, Rect2(-4.6, -0.5, 0.8, 1.0))
	assert_not_null(tug_s, "the tug's casing skylight")
	assert_eq(_piece(tug, tug_s), DeckFurniture.Piece.SKYLIGHT)


func test_the_tug_s_towing_hook_stands_on_a_post() -> void:
	var tug := _layout("tug")
	var post := _box(tug, Rect2(-9.0, -0.3, 0.6, 0.6))
	assert_not_null(post, "her towing hook's post")
	assert_eq(_piece(tug, post), DeckFurniture.Piece.POST)


## The boxes ShipArt hands DeckFurniture on [param layout]'s open deck at
## [param height]: neither walls nor slabs nor indoors.
func _on_deck(layout: ShipLayout, height: float) -> Array[ShipBlocker]:
	var space := ShipSpace.new(layout)
	var found: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or not is_equal_approx(blocker.bottom, height):
			continue
		if space.is_wall(blocker) or blocker.top - blocker.bottom <= ShipSpace.WALL_MAX:
			continue
		var middle := blocker.area.get_center()
		if space.outdoors(Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)):
			found.append(blocker)
	return found


func test_the_liner_s_boat_deck_is_furnished() -> void:
	var titanic := _layout("small_titanic")
	var pieces := {}
	for blocker: ShipBlocker in _on_deck(titanic, BOAT_DECK):
		var piece := _piece(titanic, blocker)
		pieces[piece] = pieces.get(piece, 0) + 1
	var skylights: int = pieces.get(DeckFurniture.Piece.SKYLIGHT, 0)
	assert_eq(skylights, 3, "the lounge's, the engine room's and the after staircase's")
	var lockers: int = pieces.get(DeckFurniture.Piece.LOCKER, 0)
	assert_eq(lockers, 8, "two either side of each of her boat deck's two houses")
	assert_eq(pieces.get(DeckFurniture.Piece.BOAT, 0), 16, "her sixteen boats on chocks")
	assert_eq(pieces.get(DeckFurniture.Piece.BENCH, 0), 10, "benches along her skylights")


func test_her_boats_stand_one_at_each_of_her_boat_stations() -> void:
	var titanic := _layout("small_titanic")
	var stations := {}
	for fitting: ShipFitting in titanic.structure.fittings:
		var named := String(fitting.name)
		if fitting.kind == ShipFitting.Kind.LIFEBOAT and named.begins_with("boat_"):
			stations[named] = fitting
	assert_eq(stations.size(), 16, "her boats' stations")
	for blocker: ShipBlocker in _on_deck(titanic, BOAT_DECK):
		if _piece(titanic, blocker) != DeckFurniture.Piece.BOAT:
			continue
		var side := int(signf(blocker.area.get_center().y))
		var found := ""
		for named: String in stations:
			var fitting: ShipFitting = stations[named]
			var x := fitting.x
			if fitting.side == side and blocker.area.position.x <= x and x <= blocker.area.end.x:
				found = named
		assert_ne(found, "", "the boat at %s stands at a station" % blocker.area)
		stations.erase(found)
		var size := Vector3(blocker.area.size.x, blocker.top - blocker.bottom, blocker.area.size.y)
		assert_almost_eq(size, DeckFurniture.STOWED_BOAT, Vector3.ONE * 0.001, "%s" % found)
	assert_eq(stations.size(), 0, "a boat at every station: %s" % [stations.keys()])


func test_a_box_at_a_boat_station_short_of_the_deck_s_edge_is_no_boat() -> void:
	var titanic := _layout("small_titanic")
	var inboard := _blocker(Rect2(56.0, 6.5, 9.0, 3.15), BOAT_DECK, BOAT_DECK + 1.5)
	assert_ne(_piece(titanic, inboard), DeckFurniture.Piece.BOAT, "clear of her edge")
	var at_edge := _blocker(Rect2(56.0, 10.4, 9.0, 3.15), BOAT_DECK, BOAT_DECK + 1.5)
	assert_eq(_piece(titanic, at_edge), DeckFurniture.Piece.BOAT, "out to her edge at boat 1's")


func test_her_open_decks_are_furnished_with_benches() -> void:
	var titanic := _layout("small_titanic")
	var benches := {}
	for height: float in TITANIC_OPEN_DECKS:
		for blocker: ShipBlocker in _on_deck(titanic, height):
			if _piece(titanic, blocker) != DeckFurniture.Piece.BENCH:
				continue
			benches[height] = benches.get(height, 0) + 1
			var size := Vector3(
				blocker.area.size.x, blocker.top - blocker.bottom, blocker.area.size.y
			)
			if size.x < size.z:
				size = Vector3(size.z, size.y, size.x)
			assert_almost_eq(size, DeckFurniture.BENCH, Vector3.ONE * 0.001, "%s" % blocker.area)
			assert_ne(
				DeckFurniture.back_of(titanic, blocker),
				Vector2.ZERO,
				"the bench at %s backs onto what stands behind it" % blocker.area
			)
	assert_eq(benches.get(BOAT_DECK, 0), 10, "along her boat deck's skylights")
	assert_eq(benches.get(A_DECK, 0), 22, "along A deck's house, between its doors")
	assert_eq(benches.get(2.75, 0), 4, "against the restaurant's after face")


func test_a_short_box_seat_is_a_bench_and_a_long_one_a_locker() -> void:
	var tug := _layout("tug")
	var bench := _blocker(Rect2(0.0, 0.0, 1.8, 0.55), 0.0, 0.45)
	assert_eq(_piece(tug, bench), DeckFurniture.Piece.BENCH)
	var across := _blocker(Rect2(0.0, 0.0, 0.55, 1.8), 0.0, 0.45)
	assert_eq(_piece(tug, across), DeckFurniture.Piece.BENCH, "laid across her")
	var locker := _blocker(Rect2(0.0, 0.0, 2.4, 0.55), 0.0, 0.45)
	assert_eq(_piece(tug, locker), DeckFurniture.Piece.LOCKER, "longer than a bench")


func test_her_ventilators_stand_their_cowls_heights() -> void:
	var titanic := _layout("small_titanic")
	var vents := 0
	for blocker: ShipBlocker in titanic.blockers:
		if not DeckFurniture.is_vent(titanic, blocker):
			continue
		vents += 1
		assert_has(DeckFurniture.VENTS, blocker.radius, "a trunk a cowl is made for")
		var height: float = DeckFurniture.VENT_HEIGHTS.get(blocker.radius, NAN)
		assert_almost_eq(blocker.top - blocker.bottom, height, 0.001, "%s" % blocker.centre)
	assert_eq(vents, 24, "her boat deck's, her forecastle's, her wells' and her poop's")


func test_no_funnel_or_mast_of_the_fleet_is_a_ventilator() -> void:
	for ship: String in Fleet.names():
		var layout := _layout(ship)
		for blocker: ShipBlocker in layout.blockers:
			if blocker.shape != ShipBlocker.Shape.CYLINDER:
				continue
			var tall := blocker.top - blocker.bottom > DeckFurniture.VENT_TALLEST
			if ShipArt.is_funnel(layout, blocker) or tall:
				var named := "%s's at %s" % [ship, blocker.centre]
				assert_false(DeckFurniture.is_vent(layout, blocker), named)
			else:
				assert_has(["titanic", "small_titanic"], ship, "only the liners carry ventilators")


func test_no_seat_starts_by_a_ventilator() -> void:
	var titanic := _layout("small_titanic")
	for blocker: ShipBlocker in titanic.blockers:
		if not DeckFurniture.is_vent(titanic, blocker):
			continue
		for spawn: Vector3 in titanic.spawns:
			var on_its_deck := is_equal_approx(spawn.y, blocker.bottom)
			var apart := Vector2(spawn.x, spawn.z).distance_to(blocker.centre)
			var by := apart < blocker.radius + _rules.body_radius
			assert_false(on_its_deck and by, "a seat at %s by %s" % [spawn, blocker.centre])


func test_her_seat_lockers_stand_back_to_their_houses() -> void:
	var titanic := _layout("small_titanic")
	for blocker: ShipBlocker in _on_deck(titanic, BOAT_DECK):
		if _piece(titanic, blocker) != DeckFurniture.Piece.LOCKER:
			continue
		var out := signf(blocker.area.get_center().y)
		assert_eq(
			DeckFurniture.back_of(titanic, blocker),
			Vector2(0.0, -out),
			"the locker at %s backs onto its house's wall" % blocker.area
		)


func test_the_ferry_s_decks_are_furnished() -> void:
	var ferry := _layout("ferry")
	var pieces := {}
	var backed := 0
	for height: float in [FERRY_PASSENGER_DECK, FERRY_BRIDGE_DECK]:
		for blocker: ShipBlocker in _on_deck(ferry, height):
			var piece := _piece(ferry, blocker)
			pieces[piece] = pieces.get(piece, 0) + 1
			if (
				piece == DeckFurniture.Piece.LOCKER
				and DeckFurniture.back_of(ferry, blocker) != Vector2.ZERO
			):
				backed += 1
	assert_eq(pieces.get(DeckFurniture.Piece.SKYLIGHT, 0), 1, "the engine room's, abaft the funnel")
	assert_eq(pieces.get(DeckFurniture.Piece.LOCKER, 0), 4, "two against walls, two across aft")
	assert_eq(backed, 2, "the wheelhouse's and the house's back onto their walls")


func test_no_seat_starts_on_the_new_furniture() -> void:
	var decks := {
		"small_titanic": TITANIC_OPEN_DECKS, "ferry": [FERRY_PASSENGER_DECK, FERRY_BRIDGE_DECK]
	}
	for ship: String in decks:
		var layout := _layout(ship)
		for height: float in decks[ship]:
			for blocker: ShipBlocker in _on_deck(layout, height):
				if _piece(layout, blocker) == DeckFurniture.Piece.HATCH:
					continue
				var about := blocker.area.grow(_rules.body_radius)
				for spawn: Vector3 in layout.spawns:
					var on_it := is_equal_approx(spawn.y, height)
					var start := Vector2(spawn.x, spawn.z)
					assert_false(on_it and about.has_point(start), "%s: %s" % [ship, spawn])


func test_a_low_narrow_box_is_a_seat_locker() -> void:
	var tug := _layout("tug")
	var locker := _blocker(Rect2(0.0, 0.0, 2.4, 0.5), 0.0, 0.45)
	assert_eq(_piece(tug, locker), DeckFurniture.Piece.LOCKER)
	var deep := _blocker(Rect2(0.0, 0.0, 2.4, 0.8), 0.0, 0.45)
	assert_eq(_piece(tug, deep), DeckFurniture.Piece.SKYLIGHT, "too deep to sit on")


func test_with_no_structure_to_say_every_box_is_a_hatch() -> void:
	var bare := ShipLayout.new()
	var post := _blocker(Rect2(0.0, 0.0, 0.5, 0.5), 0.0, 1.0)
	assert_eq(_piece(bare, post), DeckFurniture.Piece.HATCH)


func test_every_piece_is_drawn_inside_its_box() -> void:
	var tug := _layout("tug")
	var pieces: Array[ShipBlocker] = [
		_box(tug, Rect2(-9.0, -0.3, 0.6, 0.6)),
		_box(tug, Rect2(-4.6, -0.5, 0.8, 1.0)),
		_blocker(Rect2(2.0, 1.0, 2.4, 0.5), 0.0, 0.45),
		_blocker(Rect2(2.0, 1.0, 0.5, 2.4), 0.0, 0.45),
		_blocker(Rect2(-2.0, -1.5, 4.0, 3.0), 0.0, 0.9),
		_blocker(Rect2(2.0, 1.0, 1.8, 0.55), 0.0, 0.45),
		_blocker(Rect2(2.0, 1.0, 0.55, 1.8), 0.0, 0.45),
	]
	var over := maxf(DeckFurniture.HOOK_RISE, DeckFurniture.GUARD_RISE + DeckFurniture.GUARD * 0.5)
	over = maxf(over, DeckFurniture.BENCH_RISE)
	for blocker: ShipBlocker in pieces:
		_assert_drawn_inside(tug, blocker, over)


func test_a_boat_and_its_davits_are_drawn_inside_its_box() -> void:
	var titanic := _layout("small_titanic")
	for blocker: ShipBlocker in _on_deck(titanic, BOAT_DECK):
		if _piece(titanic, blocker) == DeckFurniture.Piece.BOAT:
			var over := DeckFurniture.DAVIT_BOX.end.y - DeckFurniture.STOWED_BOAT.y
			_assert_drawn_inside(titanic, blocker, over)


func test_a_ventilator_is_drawn_in_its_trunk_s_footprint_under_head_height() -> void:
	var titanic := _layout("small_titanic")
	var drawn := {}
	for blocker: ShipBlocker in titanic.blockers:
		if not DeckFurniture.is_vent(titanic, blocker) or drawn.has(blocker.radius):
			continue
		drawn[blocker.radius] = true
		var faces := _drawn(titanic, blocker)
		assert_gt(faces.size(), 0, "the ventilator at %s drawn" % blocker.centre)
		for corner: Vector3 in faces:
			var out := Vector2(corner.x, corner.z).distance_to(blocker.centre) - blocker.radius
			var head := corner.y - blocker.bottom >= DeckFurniture.HEAD_ROOM
			if out > (DeckFurniture.COWL_REACH if head else 0.0) + OUTSIDE:
				fail_test("the ventilator at %s: a face out at %s" % [blocker.centre, corner])
				break
	assert_eq(drawn.size(), DeckFurniture.VENTS.size(), "every ventilator she carries")


## Whether every face [param blocker] of [param layout] is drawn with stands in its
## footprint, from its bottom to [param over] over its top.
func _assert_drawn_inside(layout: ShipLayout, blocker: ShipBlocker, over: float) -> void:
	var faces := _drawn(layout, blocker)
	var piece := _piece(layout, blocker)
	assert_gt(faces.size(), 0, "%s drawn" % piece)
	var area := blocker.area.grow(OUTSIDE)
	for corner: Vector3 in faces:
		if not area.has_point(Vector2(corner.x, corner.z)):
			fail_test("%s at %s: a face out of its footprint at %s" % [piece, area, corner])
			return
		if corner.y < blocker.bottom - OUTSIDE or corner.y > blocker.top + over + OUTSIDE:
			fail_test("%s: a face out of its heights at %s" % [piece, corner])
			return
