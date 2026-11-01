extends GutTest
## The Titanic's low hull off her plates (#395): Plate V's tank top reads her side some height
## over its floor (tools/gen_titanic.py, LOW_PLANS), Fig. 22 of The Shipbuilder's special
## number draws her bilge under it, and the reading holds her displacement to the inquiry's.

const SHIP := "res://data/ships/titanic.tres"
const FT := 0.3048
## Her keel and tank top, as her generator lays them; the tank top's plan is true this far
## over its floor.
const KEEL := -19.8125
const TANK_TOP := KEEL + 5.25 * FT
const TANK_TOP_CUT := 3.75
const LOAD_WATERLINE := -30.5 * FT
## Each space's x and half breadth off the tank top's trace (tools/titanic_plates/tanktop.py),
## a room's middle, both sides' mean.
const TANK_TOP_TRACE: Dictionary[StringName, Vector2] = {
	&"shaft tunnel, O to N": Vector2(-98.9, 5.56),
	&"boiler room 5": Vector2(45.6, 13.22),
	&"boiler room 6": Vector2(62.3, 11.72),
	&"No. 3 hold": Vector2(81.0, 9.9),
	&"No. 2 hold": Vector2(89.8, 8.06),
	&"No. 1 hold": Vector2(104.1, 4.72),
}
## A section stands for up to its length: her side between them is read linearly.
const TRACE_MARGIN := 0.3
## Fig. 22's half breadth at her tank top's height.
const MIDSHIP_AT_TANK_TOP := 12.9
## The inquiry's 52 310 long tons at 34 ft 7 in (BOT), as cubic metres of her sea.
const LOAD_VOLUME := 53149e3 / 1025.0
const LOAD_SHARE := 0.015

var _structure: ShipStructure


func before_all() -> void:
	var layout: ShipLayout = load(SHIP)
	_structure = layout.structure


func test_her_side_is_the_tank_tops_trace_at_its_cut() -> void:
	var height := TANK_TOP + TANK_TOP_CUT
	for space: StringName in TANK_TOP_TRACE:
		var trace: Vector2 = TANK_TOP_TRACE[space]
		for way: int in [1, -1]:
			assert_almost_eq(
				_structure.half_breadth(trace.x, height, way), trace.y, TRACE_MARGIN, space
			)


func test_her_bilge_turns_as_her_midship_section_draws_it() -> void:
	assert_almost_eq(
		_structure.half_breadth(0.0, TANK_TOP, 1), MIDSHIP_AT_TANK_TOP, 0.2, "at her tank top"
	)
	assert_gt(_structure.half_breadth(0.0, KEEL + 5.8, 1), 13.9, "her full breadth over the turn")
	assert_lt(_structure.half_breadth(0.0, KEEL + 0.01, 1), 10.2, "her flat of bottom")


func test_her_side_never_turns_in_as_it_climbs() -> void:
	for x: float in [-110.0, -94.0, -60.0, 0.0, 62.0, 74.0, 86.0, 98.0, 110.0]:
		var below := 0.0
		for rise: int in range(1, 40):
			var here := _structure.half_breadth(x, KEEL + rise * 0.5, 1)
			assert_gte(here, below - 0.02, "at x %.0f, %.1f m over her keel" % [x, rise * 0.5])
			below = here


func test_she_displaces_the_inquirys_figure_at_her_load_waterline() -> void:
	var volume := 0.0
	var x := -130.0
	while x < 131.0:
		var y := KEEL + 0.05
		while y < LOAD_WATERLINE:
			volume += (
				(_structure.half_breadth(x, y, 1) + _structure.half_breadth(x, y, -1)) * 0.1 * 0.5
			)
			y += 0.1
		x += 0.5
	gut.p("%.0f m³ at her load waterline, the inquiry's %.0f" % [volume, LOAD_VOLUME])
	assert_almost_eq(volume, LOAD_VOLUME, LOAD_VOLUME * LOAD_SHARE)
