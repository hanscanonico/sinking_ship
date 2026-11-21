extends GutTest
## A plain room's pendants light the whole of it (PendantGrid): found playing the
## ferry, whose saloon and car deck stood near black between their lamps.


func test_a_cabins_pendant_keeps_its_own_reach() -> void:
	var cabin := Rect2(0.0, 0.0, 4.0, 3.0)
	assert_eq(PendantGrid.across(cabin), Vector2i.ONE)
	assert_eq(PendantGrid.reach(cabin, 2.0), ShipLamp.RANGE)


func test_a_great_rooms_pendant_reaches_the_corner_of_its_square() -> void:
	# The ferry's car deck: 47.5 m by 12.8 m, its lamps some 4 m up.
	var deck := Rect2(-29.5, -6.4, 47.5, 12.8)
	var squares := PendantGrid.across(deck)
	assert_eq(squares, Vector2i(4, 2))
	var half := deck.size / Vector2(squares) * 0.5
	var corner := Vector3(half.x, 4.0, half.y).length()
	assert_gt(corner, ShipLamp.RANGE, "further than a lamp's own reach: it stood dark")
	assert_almost_eq(PendantGrid.reach(deck, 4.0), corner, 0.001)


func test_no_pendant_is_asked_further_than_the_most() -> void:
	var hall := Rect2(0.0, 0.0, 12.0, 12.0)
	assert_eq(PendantGrid.reach(hall, 8.0), PendantGrid.REACH_MOST)


func test_every_ships_plain_rooms_are_lit_to_their_corners() -> void:
	for ship: String in ["steamer", "trawler", "tug", "ferry", "freighter", "barque"]:
		var layout: ShipLayout = load("res://data/ships/%s.tres" % ship)
		var space := ShipSpace.new(layout)
		for room in layout.rooms:
			var lights := PendantGrid.lights(space, room)
			var squares := PendantGrid.across(room.area)
			assert_eq(lights.size(), squares.x * squares.y, "%s %s" % [ship, room.name])
			for light in lights:
				var half := room.area.size / Vector2(squares) * 0.5
				var corner := Vector3(half.x, light.at.y - room.floor_height, half.y).length()
				assert_gte(
					light.reach, minf(corner, PendantGrid.REACH_MOST), "%s %s" % [ship, room.name]
				)
