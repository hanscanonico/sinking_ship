extends GutTest
## A ShipStructure read as data (§5b.2): a malformed one tells its problems, and never
## stops on them.


func test_a_missing_cell_is_a_problem_not_a_stop() -> void:
	var structure: ShipStructure = SimFixtures.steamer().structure.duplicate()
	var cells := structure.cells.duplicate()
	cells[0] = null
	structure.cells = cells
	assert_has(structure.problems(), "structure: a cell is missing")
	assert_eq(structure.cell_named(cells[1].name), 1, "the cells after it are still found")
	assert_eq(structure.cell_named(&"nowhere"), -1)
