extends GutTest
## Which of a structure's windows a pane the art draws is (ShipFittings.openings_of): the
## one in its own wall, never the window of a house across an open deck facing it.


func _window(name: StringName, x: float) -> ShipOpening:
	var window := ShipOpening.new()
	window.name = name
	window.kind = ShipOpening.Kind.WINDOW
	window.centre = Vector3(x, 9.825, 0.0)
	window.size = Vector3(0.0, 0.6, 0.55)
	return window


func test_a_pane_is_the_window_in_its_own_wall_not_the_one_facing_it() -> void:
	# A house's after wall at x 40, its window in the wall's outer face; another house's
	# forward wall 7 m aft, its window facing it across the deck.
	var glass: Array[ShipOpening] = [_window(&"across_the_deck", 33.0), _window(&"own", 39.9)]
	var pane := [null, Vector3(40.1, 9.825, 0.0), Vector3.RIGHT, false, Vector2(0.275, 0.3)]
	var found := ShipFittings.openings_of(pane, glass, 0.05)
	assert_eq(found.size(), 1, "one window")
	assert_eq(glass[found[0]].name, &"own", "the window in its own wall")
