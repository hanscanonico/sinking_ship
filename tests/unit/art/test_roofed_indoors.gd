extends GutTest
## Roofed space inside her that no room holds, under her lowest weather deck, is painted
## as indoors (RoofedIndoors, #357): her art once lit it as weather — the sun and the
## sky, and the sea's lap and tint on its dry walls once her bow was down. Over her
## lowest weather deck her covered promenades stay weather (the owner's ruling, "below C
## deck only"), and so does the sea outside her shell.

const TITANIC := "res://data/ships/titanic.tres"
const NO_BOXES: Array[AABB] = []

var _space: ShipSpace
var _roofed: RoofedIndoors


func before_all() -> void:
	_space = ShipSpace.new(load(TITANIC))
	_roofed = RoofedIndoors.new(_space)


func test_her_lowest_weather_deck_is_her_after_well_deck_on_c_deck() -> void:
	assert_eq(_roofed.weather_floor(), 0.0, "her after well deck, C deck's height")


func test_roofed_space_no_room_holds_under_c_deck_is_painted_indoors() -> void:
	# (where, ship point): each in no room of hers, as ShipSpace.outdoors says.
	var points := [
		["E deck's ladder well forward of its passage", Vector3(79.5, -4.94, 6.0)],
		["a strip by her shell past the second-class stewards' door", Vector3(37.02, -4.94, -6.52)],
		["a door's recess in bulkhead J on E deck", Vector3(-28.31, -4.94, -3.16)],
		["a door's recess in bulkhead J on F deck", Vector3(-28.31, -7.56, 3.94)],
	]
	for at: Array in points:
		var point: Vector3 = at[1]
		assert_true(_space.outdoors(point, NO_BOXES), "%s: in no room" % at[0])
		assert_false(_roofed.outdoors(point, NO_BOXES), "%s: painted indoors" % at[0])


func test_her_covered_promenades_and_the_sea_stay_weather() -> void:
	var points := [
		["A deck's promenade under her boat deck", Vector3(5.0, 6.5, 9.5)],
		["B deck's second-class promenade under A deck", Vector3(-60.125, 3.75, -13.6)],
		["C deck's second-class promenade by the library", Vector3(-85.0, 1.0, 11.0)],
		["the sea by her side, under her waterline", Vector3(0.0, -5.0, 15.0)],
	]
	for at: Array in points:
		var point: Vector3 = at[1]
		assert_true(_space.outdoors(point, NO_BOXES), "%s: in no room" % at[0])
		assert_true(_roofed.outdoors(point, NO_BOXES), "%s: still weather" % at[0])


func test_a_ship_with_no_structure_is_painted_as_her_rooms_say() -> void:
	var flat := ShipSpace.new(load(SimFixtures.FLAT_DECK))
	var roofed := RoofedIndoors.new(flat)
	assert_eq(roofed.weather_floor(), -INF, "no weather deck to stand under")
	assert_false(roofed.holds(Vector3(0.0, -2.0, 0.0)), "nothing roofed in her")
