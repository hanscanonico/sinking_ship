extends GutTest
## Wreckage on the sea (Flotsam) goes under over every deck the sea hardly covers,
## whichever of her decks it is, and stays afloat off them all.


func test_wreckage_goes_under_over_every_deck_shallow_under_it_and_stays_off_them() -> void:
	var layout := SimFixtures.steamer()
	var wade := 0.3
	for index in layout.platforms.size():
		var deck := layout.platforms[index]
		var flotsam: Flotsam = add_child_autofree(Flotsam.new())
		flotsam.setup(layout, wade)
		# The deck a hair under the sea: a piece landing over any point of it goes under.
		var ship := Transform3D(Basis(), Vector3.DOWN * (deck.height + 0.05))
		var corner := deck.area.position + deck.area.size * 0.01
		var over := ship * Vector3(corner.x, deck.height, corner.y)
		flotsam.throw(FxCue.Piece.CRATE, over + Vector3.UP * 2.0, over, Vector2.DOWN)
		for _frame in 60:
			flotsam.advance(1.0 / 30.0)
			flotsam.go_under_shallows(ship)
		assert_eq(flotsam.afloat().size(), 0, "nothing afloat over %s" % deck.name)
	var outboard: Flotsam = add_child_autofree(Flotsam.new())
	outboard.setup(layout, wade)
	var sea := SpatialIndex.bounds_of(layout).end + Vector2(5.0, 5.0)
	var off := Vector3(sea.x, 0.0, sea.y)
	outboard.throw(FxCue.Piece.CRATE, off + Vector3.UP * 2.0, off, Vector2.DOWN)
	for _frame in 60:
		outboard.advance(1.0 / 30.0)
		outboard.go_under_shallows(Transform3D.IDENTITY)
	assert_eq(outboard.afloat().size(), 1, "off every deck, a piece stays afloat")
