extends GutTest
## Her ground tackle and her mooring gear (ShipFittings, MooringGear) stand on the open
## deck at her ends, whole (EndDeck): every bow of the fleet lays its hawse pipes and
## cables — the steamer's forecastle, cut into pieces round its stair openings, among
## them; the Titanic's led from her cable holders forward to the hawse pipes her plate
## draws — and the steamer is moored by a pair of bitts and a coil either side at both
## ends; every piece lies wholly on its deck with nothing standing there, outdoors, under
## a step, and clear of the tackle, of the other pieces, of where a seat starts and of
## where a swimmer comes aboard.

## The Titanic's hawse pipes' mouths on her forecastle as Plate IV draws them, from their
## after ends to their forward ends along her (tools/titanic_plates/forecastle.py's px
## 10336-10457).
const HAWSE_MOUTHS := Vector2(121.55, 124.79)

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


## [param ship]'s fittings, built as ShipArt builds them, into a mesh nobody draws.
func _fitted(ship: StringName) -> ShipFittings:
	var space := ShipSpace.new(Fleet.layout(ship))
	var hull := SectionHull.of(space, _rules.railing_height)
	var fittings := ShipFittings.new(space, hull, _rules.body_radius)
	fittings.build(ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines()))
	return fittings


## A deck of one platform 10 m square at [param height], for EndDeck's own rules.
func _square_deck(height: float) -> EndDeck:
	var platform := ShipPlatform.new()
	platform.area = Rect2(0.0, 0.0, 10.0, 10.0)
	platform.height = height
	var deck := EndDeck.new()
	deck.height = height
	deck.pieces.append(platform)
	deck.spread = platform.area
	return deck


func _stair(area: Rect2, from: float, to: float) -> ShipRamp:
	var ramp := ShipRamp.new()
	ramp.area = area
	ramp.axis = ShipRamp.Axis.X
	ramp.start_height = from
	ramp.end_height = to
	return ramp


func test_the_steamer_s_fore_deck_is_her_whole_forecastle() -> void:
	var fore := EndDeck.of(ShipSpace.new(Fleet.layout(&"steamer")), 1.0)
	assert_almost_eq(fore.height, 1.8, 0.001, "her forecastle's deck")
	assert_eq(fore.spread, Rect2(12.0, -4.0, 8.0, 8.0), "the whole of it, round its openings")
	assert_gt(fore.pieces.size(), 1, "cut into pieces round its stair openings")


func test_the_steamer_s_after_deck_is_her_poop() -> void:
	var aft := EndDeck.of(ShipSpace.new(Fleet.layout(&"steamer")), -1.0)
	assert_almost_eq(aft.height, 1.2, 0.001, "her poop deck")
	assert_almost_eq(aft.spread.position.x, -20.0, 0.001, "out to her stern")


func test_the_titanic_s_fore_deck_is_her_forecastle_head_not_c_deck_under_it() -> void:
	# Her C deck runs on under the forecastle to 0.1 m past its head's end, out of every
	# room: her ground tackle and her forward mooring gear lay there, inside her bow and
	# in her forward well, before #381.
	var fore := EndDeck.of(ShipSpace.new(Fleet.layout(&"titanic")), 1.0)
	assert_eq(fore.pieces[0].name, &"forecastle")
	assert_almost_eq(fore.height, 4.9375, 0.001, "her forecastle head's deck")


func test_a_deck_with_a_deck_over_it_is_no_end_deck() -> void:
	var layout := ShipLayout.new()
	for deck: Array in [[Rect2(0.0, 0.0, 10.1, 10.0), 0.0], [Rect2(0.0, 0.0, 10.0, 10.0), 3.0]]:
		var platform := ShipPlatform.new()
		platform.area = deck[0]
		platform.height = deck[1]
		layout.platforms.append(platform)
	var fore := EndDeck.of(ShipSpace.new(layout), 1.0)
	assert_almost_eq(fore.height, 3.0, 0.001, "the deck over it, though it reaches a hair less")
	assert_true(EndDeck.roofed(layout, layout.platforms[0]))
	assert_false(EndDeck.roofed(layout, layout.platforms[1]))


func test_every_bow_lays_its_ground_tackle_both_sides() -> void:
	for ship: String in Fleet.names():
		var laid := _fitted(StringName(ship)).tackle.size()
		assert_eq(laid, 2, "%s: a hawse pipe and its cable either side of her bow" % ship)


func test_the_titanic_s_cables_lead_from_her_cable_holders_forward_to_their_hawse_pipes() -> void:
	var holders: Array[ShipBlocker] = []
	for blocker: ShipBlocker in Fleet.layout(&"titanic").blockers:
		if blocker.name == ShipFittings.CABLE_HOLDER:
			holders.append(blocker)
	assert_eq(holders.size(), 2, "her two cable holders, on her forecastle")
	var tackle := _fitted(&"titanic").tackle
	for holder in holders:
		var line := holder.area.get_center().y
		var led: Array[Rect2] = []
		for kept: Rect2 in tackle:
			if absf(kept.get_center().y - line) < 0.001:
				led.append(kept)
		assert_eq(led.size(), 1, "a cable from the holder at z %.2f" % line)
		if led.is_empty():
			continue
		var laid := led[0].grow(-ShipFittings.LAID)
		assert_almost_eq(laid.position.x, holder.area.end.x, 0.001, "from its forward face")
		var hawse := laid.end.x
		assert_between(
			hawse, HAWSE_MOUTHS.x, HAWSE_MOUTHS.y, "its hawse pipe where her plate draws it"
		)


## How many of [param placed] (MooringGear.placed) are [param model] on the deck at
## [param height], toward [param toward] (1 her bow, -1 her stern) on [param side].
func _count(placed: Array[Array], model: String, height: float, toward: float, side: float) -> int:
	var count := 0
	for piece: Array in placed:
		var at := (piece[1] as Transform3D).origin
		if piece[0] != model or not is_equal_approx(at.y, height):
			continue
		if signf(at.x) == toward and signf(at.z) == side:
			count += 1
	return count


## Whether [param area], [param top] tall, lies bare on one of [param ends] at
## [param height].
func _on_an_end(
	ends: Array[EndDeck], layout: ShipLayout, area: Rect2, height: float, top: float
) -> bool:
	for deck: EndDeck in ends:
		if is_equal_approx(deck.height, height) and deck.bare(layout, area, top):
			return true
	return false


func test_the_steamer_is_moored_either_side_at_both_ends() -> void:
	var placed := _fitted(&"steamer").mooring.placed
	for end: Vector2 in [Vector2(1.8, 1.0), Vector2(1.2, -1.0)]:
		for side: float in [-1.0, 1.0]:
			for model: String in [MooringGear.BITTS_MODEL, MooringGear.COIL_MODEL]:
				var found := _count(placed, model, end.x, end.y, side)
				assert_eq(found, 1, "%s on the deck at %.1f, side %d" % [model, end.x, side])


func test_every_piece_lies_bare_on_an_end_deck_clear_of_all_else() -> void:
	for ship: String in Fleet.names():
		var fittings := _fitted(StringName(ship))
		var layout := Fleet.layout(StringName(ship))
		var space := ShipSpace.new(layout)
		var ends: Array[EndDeck] = [EndDeck.of(space, 1.0), EndDeck.of(space, -1.0)]
		var areas: Array[Rect2] = []
		for piece: Array in fittings.mooring.placed:
			var place: Transform3D = piece[1]
			var bitts: bool = piece[0] == MooringGear.BITTS_MODEL
			var box := MooringGear.BITTS_BOX if bitts else MooringGear.COIL_BOX
			var area := MooringGear.footprint(place, box)
			var named := "%s's %s at %s" % [ship, piece[0], place.origin]
			assert_lt(box.end.y, _rules.step_height, named + ": under a step")
			var bare := _on_an_end(ends, layout, area, place.origin.y, box.end.y)
			assert_true(bare, named + ": bare on an end deck")
			var middle := area.get_center()
			var top := Vector3(middle.x, place.origin.y + box.end.y, middle.y)
			assert_true(space.outdoors(top), named + ": outdoors")
			for kept: Rect2 in fittings.tackle:
				assert_false(kept.intersects(area), named + ": clear of the ground tackle")
			for other: Rect2 in areas:
				assert_false(other.intersects(area), named + ": clear of the others")
			areas.append(area)
			var room := area.grow(MooringGear.CLEAR_OF)
			for spawn: Vector3 in layout.spawns:
				var near := is_equal_approx(spawn.y, place.origin.y)
				assert_false(near and room.has_point(Vector2(spawn.x, spawn.z)), named + ": spawn")


func test_a_stair_up_from_the_deck_stands_on_it() -> void:
	var deck := _square_deck(0.0)
	var layout := ShipLayout.new()
	layout.ramps.append(_stair(Rect2(4.0, 4.0, 3.0, 1.0), 0.0, 2.4))
	assert_false(deck.bare(layout, Rect2(5.0, 4.2, 0.4, 0.4), 0.3), "on the stair's treads")
	assert_true(deck.bare(layout, Rect2(1.0, 1.0, 0.4, 0.4), 0.3), "clear of it")


func test_a_stair_under_the_planking_is_no_matter() -> void:
	var deck := _square_deck(0.0)
	var layout := ShipLayout.new()
	layout.ramps.append(_stair(Rect2(4.0, 4.0, 3.0, 1.0), -3.0, -1.0))
	assert_true(deck.bare(layout, Rect2(5.0, 4.2, 0.4, 0.4), 0.3), "over the stair below")


func test_off_the_deck_is_not_bare() -> void:
	var deck := _square_deck(0.0)
	assert_false(deck.bare(ShipLayout.new(), Rect2(9.8, 5.0, 0.4, 0.4), 0.3), "over its edge")


func test_a_blocker_on_the_deck_stands_in_the_way() -> void:
	var deck := _square_deck(0.0)
	var layout := ShipLayout.new()
	var hatch := ShipBlocker.new()
	hatch.shape = ShipBlocker.Shape.BOX
	hatch.area = Rect2(2.0, 2.0, 2.0, 2.0)
	hatch.top = 0.8
	layout.blockers.append(hatch)
	assert_false(deck.bare(layout, Rect2(3.5, 3.5, 1.0, 1.0), 0.3), "on the hatch")
	assert_true(deck.bare(layout, Rect2(6.0, 6.0, 1.0, 1.0), 0.3), "clear of it")
