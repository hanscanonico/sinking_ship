extends GutTest
## Every hole a flight of the Titanic's leaves in the deck over its foot has an opening under
## it (#483): wherever her deck is cut over a flight and her cells part at that deck, an
## opening joins the cell under the hole to the cell over it, there. A flight rising across
## her, one the open decks' skip list once caught by a name's start, and one whose foot
## stands over two cells each once left a hole no water, air or walk passed through.

const SHIP := "res://data/ships/titanic.tres"
## How finely a flight's footprint is sampled, in metres, and how far in from its edges.
const STEP := 0.25
const INSET := 0.05
## How near a deck's height a platform stands to be that deck.
const DECK := 0.01
## The least a flight climbs, a deck: her forecastle's step up onto her head is no flight.
const FLIGHT_RISE := 1.5
## Under her F deck her spaces' flights (#148): her hatchways and holds' open tops stand for
## their wells, the generator laying no opening of theirs.
const UNDER_F_DECK := -8.6
## Her stokeholds' flights up to F deck, each boiler room's fiddley standing for its shafts.
const FIDDLEY := "fiddley_%s"

var _layout: ShipLayout


func before_all() -> void:
	_layout = load(SHIP) as ShipLayout


func _overlaps(area: Rect2, x0: float, x1: float, z0: float, z1: float) -> bool:
	return x0 < area.end.x and x1 > area.position.x and z0 < area.end.y and z1 > area.position.y


func _cell_at(cells: Array[FloodCell], point: Vector3) -> StringName:
	for cell: FloodCell in cells:
		var inside := true
		for axis in 3:
			inside = inside and cell.low[axis] < point[axis] and point[axis] < cell.high[axis]
		if inside:
			return cell.name
	return &""


func _covered(
	openings: Array[ShipOpening], below: StringName, above: StringName, at: Vector2
) -> bool:
	for opening: ShipOpening in openings:
		if not (opening.joins.has(below) and opening.joins.has(above)):
			continue
		if opening.name == StringName(FIDDLEY % below):
			return true
		var half := Vector2(opening.size.x, opening.size.z) * 0.5 + Vector2(DECK, DECK)
		var centre := Vector2(opening.centre.x, opening.centre.z)
		if absf(at.x - centre.x) <= half.x and absf(at.y - centre.y) <= half.y:
			return true
	return false


## The (below, above) pairs over ramp's footprint where her deck at its top is cut and no
## opening joins the two cells there.
func _uncovered(ramp: ShipRamp) -> PackedStringArray:
	var top := maxf(ramp.start_height, ramp.end_height)
	var missing := PackedStringArray()
	if top - ramp.base() < FLIGHT_RISE or top < UNDER_F_DECK:
		return missing
	var area := ramp.area
	var decks: Array[ShipPlatform] = []
	for platform: ShipPlatform in _layout.platforms:
		if absf(platform.height - top) < DECK and platform.area.intersects(area, true):
			decks.append(platform)
	var cells: Array[FloodCell] = []
	for cell: FloodCell in _layout.structure.cells:
		if cell.low.y < top + DECK and cell.high.y > top - DECK:
			if _overlaps(area, cell.low.x, cell.high.x, cell.low.z, cell.high.z):
				cells.append(cell)
	var sky := ShipOpening.SKY
	var x := area.position.x + INSET
	while x <= area.end.x - INSET:
		var z := area.position.y + INSET
		while z <= area.end.y - INSET:
			var cut := true
			for deck: ShipPlatform in decks:
				cut = cut and not deck.contains(x, z)
			var below := _cell_at(cells, Vector3(x, top - DECK, z))
			var above := _cell_at(cells, Vector3(x, top + DECK, z))
			above = sky if above == &"" else above
			if cut and below != &"" and below != above:
				var openings := _layout.structure.openings
				var pair := "%s into %s" % [below, above]
				if not _covered(openings, below, above, Vector2(x, z)) and not missing.has(pair):
					missing.append(pair)
			z += STEP
		x += STEP
	return missing


func test_every_flight_s_hole_in_a_deck_opens_between_the_cells_it_parts() -> void:
	var flights := 0
	for ramp: ShipRamp in _layout.ramps:
		var missing := _uncovered(ramp)
		var where := (
			"the flight at x %.2f..%.2f z %.2f..%.2f up to %.3f"
			% [
				ramp.area.position.x,
				ramp.area.end.x,
				ramp.area.position.y,
				ramp.area.end.y,
				maxf(ramp.start_height, ramp.end_height)
			]
		)
		assert_eq(missing, PackedStringArray(), "%s: its hole opens no way" % where)
		flights += 1
	assert_gt(flights, 0, "her flights sampled")


func test_the_open_decks_skip_list_catches_only_the_flights_it_names() -> void:
	# Her after grand staircase's flights up to A and B decks, their names starting as the
	# open decks' flights' once did.
	for opening_name: StringName in [
		&"stair_a_after_grand_staircase_3", &"stair_b_after_grand_staircase_5"
	]:
		var found := false
		for opening: ShipOpening in _layout.structure.openings:
			found = found or opening.name == opening_name
		assert_true(found, "%s laid" % opening_name)
