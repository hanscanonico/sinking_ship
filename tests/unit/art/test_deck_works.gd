extends GutTest
## Which of her cylinders the dressed ship draws as a funnel — smoke, whistle and pipes,
## falling where the sinking fells it — and which as a mast with its crosstree and
## masthead light (ShipArt.is_funnel, DeckWorks): her structure's FUNNEL fittings say,
## never the cylinder's girth alone.


## [param ship]'s cylinders by name: the generator's names are gone from the layout,
## so each is found by where it stands.
func _cylinder(layout: ShipLayout, at: Vector2) -> ShipBlocker:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.CYLINDER and blocker.centre.is_equal_approx(at):
			return blocker
	return null


func _layout(ship: String) -> ShipLayout:
	return load("res://data/ships/%s.tres" % ship)


func test_the_liner_s_masts_are_masts_however_stout() -> void:
	var titanic := _layout("titanic")
	for at: Vector2 in [Vector2(96.0, 0.0), Vector2(-92.5, 0.0)]:
		var mast := _cylinder(titanic, at)
		assert_not_null(mast, "a mast at %s" % at)
		assert_gte(mast.radius, ShipArt.FUNNEL_FROM, "as stout as a small funnel")
		assert_false(ShipArt.is_funnel(titanic, mast), "the mast at %s is a mast" % at)


func test_the_liner_s_four_funnels_are_funnels() -> void:
	var titanic := _layout("titanic")
	for x: float in [50.2, 13.9, -22.4, -57.9]:
		assert_true(ShipArt.is_funnel(titanic, _cylinder(titanic, Vector2(x, 0.0))), "%.1f" % x)


func test_the_trawler_s_mast_is_a_mast() -> void:
	var trawler := _layout("trawler")
	assert_false(ShipArt.is_funnel(trawler, _cylinder(trawler, Vector2(9.8, 0.0))), "mast")


func test_the_steamer_s_funnel_and_mast() -> void:
	var steamer := _layout("steamer")
	assert_true(ShipArt.is_funnel(steamer, _cylinder(steamer, Vector2(-6.0, 0.0))), "funnel")
	assert_false(ShipArt.is_funnel(steamer, _cylinder(steamer, Vector2(16.0, 0.0))), "mast")


func test_a_ship_with_no_structure_goes_by_girth() -> void:
	var layout := ShipLayout.new()
	var stout := ShipBlocker.new()
	stout.shape = ShipBlocker.Shape.CYLINDER
	stout.radius = ShipArt.FUNNEL_FROM
	var slim: ShipBlocker = stout.duplicate()
	slim.radius = ShipArt.FUNNEL_FROM * 0.5
	assert_true(ShipArt.is_funnel(layout, stout), "stout: a funnel")
	assert_false(ShipArt.is_funnel(layout, slim), "slim: a mast")


func test_every_size_of_funnel_fittings_has_its_scale() -> void:
	for size: String in DeckWorks.FUNNEL_FITTINGS.values():
		assert_has(DeckWorks.FUNNEL_FITTING_SCALE, size, "%s has a scale" % size)
