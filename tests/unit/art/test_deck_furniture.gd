extends GutTest
## What a box on an open deck is drawn as (DeckFurniture): a casing where a deck rests on
## it; a hatch's coaming over one of her structure's hatch openings in the deck it stands
## on — every box of a ship with no structure —; else a skylight, a seat locker or a
## towing post by its shape; and each piece drawn inside its box, its sides on the box's
## and its top the box's, but for a skylight's guard rods and a towing hook just over it.

## How far past its box a piece's faces may stand: the furniture's FLUSH and float noise.
const OUTSIDE := 0.005
## The Titanic's boat deck's height (tools/gen_titanic.py's BOAT), and the ferry's
## passenger and bridge decks' (tools/gen_ferry.py's PASS and BRIDGE).
const BOAT_DECK := 8.375
const FERRY_PASSENGER_DECK := 4.8
const FERRY_BRIDGE_DECK := 7.6


func _layout(ship: String) -> ShipLayout:
	return load("res://data/ships/%s.tres" % ship)


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


## Every face [param blocker] is drawn with, as DeckFurniture.build draws it.
func _drawn(layout: ShipLayout, blocker: ShipBlocker) -> PackedVector3Array:
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
	DeckFurniture.build(mesh, ShipSpace.new(layout), blocker, blocker.top)
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
	var titanic := _layout("titanic")
	var casings := 0
	for blocker: ShipBlocker in _on_deck(titanic, 5.5):
		assert_eq(_piece(titanic, blocker), DeckFurniture.Piece.CASING, "%s" % blocker.area)
		casings += 1
	assert_eq(casings, 3, "funnel 2's and 3's casings, and the cabins round funnel 1")


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
	var titanic := _layout("titanic")
	var skylights := 0
	var lockers := 0
	for blocker: ShipBlocker in _on_deck(titanic, BOAT_DECK):
		match _piece(titanic, blocker):
			DeckFurniture.Piece.SKYLIGHT:
				skylights += 1
			DeckFurniture.Piece.LOCKER:
				lockers += 1
	assert_eq(skylights, 3, "the lounge's, the engine room's and the after staircase's")
	assert_eq(lockers, 8, "two either side of each of her boat deck's two houses")


func test_her_seat_lockers_stand_back_to_their_houses() -> void:
	var titanic := _layout("titanic")
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
	var rules: BrawlRules = load("res://data/rules/brawl.tres")
	var decks := {"titanic": [BOAT_DECK], "ferry": [FERRY_PASSENGER_DECK, FERRY_BRIDGE_DECK]}
	for ship: String in decks:
		var layout := _layout(ship)
		for height: float in decks[ship]:
			for blocker: ShipBlocker in _on_deck(layout, height):
				if _piece(layout, blocker) == DeckFurniture.Piece.HATCH:
					continue
				var about := blocker.area.grow(rules.body_radius)
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
	]
	var over := maxf(DeckFurniture.HOOK_RISE, DeckFurniture.GUARD_RISE + DeckFurniture.GUARD * 0.5)
	for blocker: ShipBlocker in pieces:
		var faces := _drawn(tug, blocker)
		var piece := _piece(tug, blocker)
		assert_gt(faces.size(), 0, "%s drawn" % piece)
		var area := blocker.area.grow(OUTSIDE)
		for corner: Vector3 in faces:
			if not area.has_point(Vector2(corner.x, corner.z)):
				fail_test("%s at %s: a face out of its footprint at %s" % [piece, area, corner])
				break
			if corner.y < blocker.bottom - OUTSIDE or corner.y > blocker.top + over + OUTSIDE:
				fail_test("%s: a face out of its heights at %s" % [piece, corner])
				break
