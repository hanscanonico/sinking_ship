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


func test_her_shell_outside_her_skin_stays_weather_where_she_narrows() -> void:
	# Each face of her shell is judged at a probe just off its outside (ShipMesh.PROBE):
	# where she narrows to her stem a section's outline stands wider than her skin, and
	# her starboard bow went black where it was read instead (#475).
	var structure := _space.layout.structure
	var held := PackedStringArray()
	for x in range(-130, 131):
		for y in range(-12, 0):
			for side: int in [1, -1]:
				var breadth := structure.half_breadth(x, y, side)
				if breadth <= 0.0:
					continue
				var probe := Vector3(x, y, (breadth + ShipMesh.PROBE) * side)
				if _roofed.holds(probe):
					held.append(str(probe))
	assert_eq(held, PackedStringArray(), "no probe off her shell painted indoors")


func test_a_ship_with_no_structure_is_painted_as_her_rooms_say() -> void:
	var flat := ShipSpace.new(load(SimFixtures.FLAT_DECK))
	var roofed := RoofedIndoors.new(flat)
	assert_eq(roofed.weather_floor(), -INF, "no weather deck to stand under")
	assert_false(roofed.holds(Vector3(0.0, -2.0, 0.0)), "nothing roofed in her")


func test_holds_answers_as_her_half_breadth_reads_asked_again_or_not() -> void:
	# holds() remembers half_breadth() per x, height and side (#411): the same answers as
	# reading it each time, on her first asking and on every one after, and for any z.
	var roofed := RoofedIndoors.new(_space)
	var structure := _space.layout.structure
	var lowest := roofed.weather_floor()
	var wrong := PackedStringArray()
	var held := 0
	for asking in 2:
		for x in range(-130, 131, 3):
			for y: float in [-12.0, -7.56, -4.94, -1.25, 0.0, 2.5]:
				for z: float in [-14.0, -6.52, -0.5, 0.0, 3.94, 9.0, 14.0]:
					var point := Vector3(x + 0.37, y, z)
					var side := 1 if z >= 0.0 else -1
					var breadth := structure.half_breadth(point.x, point.y, side)
					var expected := (
						point.y < lowest
						and breadth > 0.0
						and point.z * side <= breadth
						and roofed._under_a_deck(point)
					)
					if expected:
						held += 1
					if roofed.holds(point) != expected:
						wrong.append("%s on asking %d" % [point, asking])
	assert_eq(wrong, PackedStringArray(), "holds() as half_breadth() reads, every time")
	assert_gt(held, 0, "some of them roofed")
	assert_gt(roofed._breadths.size(), 0, "her breadths remembered")
