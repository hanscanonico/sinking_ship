extends GutTest
## The observer's cells (CellOverlay) are drawn from the layout's structure: a name per
## cell over the steamer's, and nothing at all over a ship the physics does not float.


func _labels(overlay: CellOverlay) -> int:
	var count := 0
	for child: Node in overlay.get_children():
		if child is Label3D:
			count += 1
	return count


func test_every_cell_of_the_steamer_is_named() -> void:
	var overlay: CellOverlay = add_child_autofree(CellOverlay.new())
	var structure := SimFixtures.steamer().structure
	overlay.build(structure)
	assert_eq(_labels(overlay), structure.cells.size())


func test_a_ship_with_no_structure_draws_no_cells() -> void:
	var layout := SimFixtures.deck()
	assert_null(layout.structure, "the flat deck does not float")
	var overlay: CellOverlay = add_child_autofree(CellOverlay.new())
	overlay.build(layout.structure)
	assert_eq(overlay.get_child_count(), 0)
