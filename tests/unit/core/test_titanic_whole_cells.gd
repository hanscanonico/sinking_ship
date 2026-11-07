extends GutTest
## A cell of the Titanic's her sections fill but for their outlines' simplifying is
## whole (#365): tools/gen_titanic.py writes a fill at or over SHAPE_WHOLE, read to the
## four decimals it is written to, as shape 1, so no cell pokes out of her (CellMap
## asking her hull of every point of it) by the luck of the fourth decimal. Once her
## boiler room 2 was such a cell, a hair under whole, and the room behind its watertight
## door stood sealed from the walk graph; her sisters' C deck cell over x 19.18–36.46
## (c_deck_3) was still written 0.9999, its fill a hair under SHAPE_WHOLE before rounding.

## gen_titanic.py's SHAPE_WHOLE.
const SHAPE_WHOLE := 0.9999
const SHIPS: Array[String] = [
	"res://data/ships/titanic.tres",
	"res://tests/fixtures/ships/titanic_olympic_1913.tres",
	"res://tests/fixtures/ships/titanic_britannic.tres",
]


func test_no_cell_of_hers_is_a_hair_under_whole() -> void:
	for path: String in SHIPS:
		var layout: ShipLayout = load(path)
		var near := []
		for cell: FloodCell in layout.structure.cells:
			if cell.shape >= SHAPE_WHOLE and cell.shape < 1.0:
				near.append("%s %s" % [cell.name, cell.shape])
		assert_eq(near, [], "%s: cells a hair under whole, not written whole" % path)


## Her deck chair store's box her sections fill but for the fourth decimal: whole.
func test_her_deck_chair_store_is_whole() -> void:
	var layout: ShipLayout = load(SHIPS[0])
	var found := false
	for cell: FloodCell in layout.structure.cells:
		if cell.name == &"deck_chair_store":
			found = true
			assert_eq(cell.shape, 1.0, "her deck chair store is whole")
	assert_true(found, "her deck chair store is a cell of hers")
