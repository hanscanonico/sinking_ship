extends GutTest
## The Titanic's seats along her houses (tools/gen_titanic.py), each drawn as its shape
## says (DeckFurniture): her boat deck's seat lockers along the officers' house and the
## staircase house, A deck's benches along its house on both promenades. Since her decks
## were laid off her plates (#364) none stood: each seat's lane was kept clear of the
## house it backs onto as of all else.

## Her boat deck and A deck (tools/gen_titanic.py's BOAT and A_DECK).
const BOAT_DECK := 8.375
const A_DECK := 5.5


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


func test_the_titanic_s_houses_are_lined_with_seats() -> void:
	var titanic := Fleet.layout(&"titanic")
	var space := ShipSpace.new(titanic)
	var seats := {}
	for height: float in [BOAT_DECK, A_DECK]:
		for blocker: ShipBlocker in _on_deck(titanic, height):
			var piece := DeckFurniture.piece_of(space, blocker)
			if piece != DeckFurniture.Piece.BENCH and piece != DeckFurniture.Piece.LOCKER:
				continue
			var key := "%s %s" % [height, DeckFurniture.Piece.keys()[piece]]
			seats[key] = seats.get(key, 0) + 1
			assert_ne(
				DeckFurniture.back_of(titanic, blocker),
				Vector2.ZERO,
				"the seat at %s backs onto what stands behind it" % blocker.area
			)
	var boat := "%s %s" % [BOAT_DECK, "LOCKER"]
	var benches := "%s %s" % [A_DECK, "BENCH"]
	assert_eq(seats.get(boat, 0), 6, "seat lockers along her boat deck's houses: %s" % seats)
	assert_eq(seats.get(benches, 0), 19, "benches along A deck's house, between its doors")
