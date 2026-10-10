extends GutTest
## The Titanic's flooding, standing still (SH34): her compartments opened to the sea,
## each flooded cell's water up to the sea's plane at whatever attitude she settles
## at, and she floated on them until her lift and her weight agree. The assertions are
## the 1912 inquiry's evidence and the research's numbers (§SH34), each at the draught
## its source took — the night's, as her data floats her, or the design's load
## waterline Wilding's flooding plans were drawn at ("The intended load waterline of the
## ship"); her watertight compartment is every cell between two of her bulkheads under
## their tops, her double bottom left intact.

const SHIP := "res://data/ships/titanic.tres"
const NIGHT := "res://tests/fixtures/sinking/hits/titanic_night.tres"
## Her compartments from her bow, as her bulkheads A–P part her (BOT).
const COMPARTMENTS: Array[StringName] = [
	&"forepeak",
	&"hold_1",
	&"hold_2",
	&"hold_3",
	&"boiler_room_6",
	&"boiler_room_5",
	&"boiler_room_4",
	&"boiler_room_3",
	&"boiler_room_2",
	&"boiler_room_1",
	&"engine_room",
	&"turbine_room",
	&"electric_room",
	&"after_hold_fwd",
	&"after_hold_aft",
	&"after_peak",
]
const LONG_TON := 1016.0469
## Her displacement at her load waterline, 34 ft 7 in: the inquiry's 52 310 tons.
const LOAD := 52310.0 * LONG_TON
## How near two settlings must come for her to have come to rest, in metres and slopes.
const SETTLED := 1e-4
const STEPS := 80
## The research's: two adjacent compartments leave half a metre to her bulkhead deck;
## 0.19° of trim for each 1 000 long tons she takes in forward, ± 30 %, about a point
## 176–180 m from her bow — read with the night's six damaged compartments open.
const SPARE := 0.5
const TRIM_PER_THOUSAND := 0.19
const TRIM_SHARE := 0.3
const PIVOT := Vector2(176.0, 180.0)
## Her bow, where her stem meets her waterline: her forward perpendicular, read off The
## Shipbuilder's Plate III as her generator does (tools/gen_titanic.py, X_FP).
const BOW := 129.5

var _structure: ShipStructure
var _sea: SeaPhysics
## Her bulkheads from her bow: x and top, each.
var _walls: Array[ShipWall] = []
## The sea she displaces herself, in m³: the night's, or her load's.
var _own := 0.0


## How she floats with some compartments open to the sea.
class Floated:
	var sea: Hydrostatics.Sea
	## The sea she took in, in m³.
	var water := 0.0
	## Whether she came to rest at all.
	var rests := false
	## The least height of a bulkhead's top over the sea: every one of hers, and those
	## at the ends of what is flooded.
	var spare := INF
	var spare_ends := INF


func before_all() -> void:
	var layout: ShipLayout = load(SHIP)
	_structure = layout.structure
	_sea = SeaPhysics.load_default()
	for wall: ShipWall in _structure.walls:
		if wall.axis == ShipWall.Axis.ACROSS:
			_walls.append(wall)
	_walls.sort_custom(func(a: ShipWall, b: ShipWall) -> bool: return a.at > b.at)
	assert_eq(_walls.size(), COMPARTMENTS.size() - 1, "fifteen bulkheads part her into sixteen")


func before_each() -> void:
	_own = _structure.total_mass() / _sea.sea_density


## Loads her to her load waterline: what she carries more than the night, over her
## centre of mass, so she stays level.
func _at_load() -> void:
	_own = LOAD / _sea.sea_density


## From her bow, compartment [param index] runs from bulkhead index to bulkhead index -
## 1: its x from aft to fore.
func _span(index: int) -> Vector2:
	var aft := -INF if index == _walls.size() else _walls[index].at
	var fore := INF if index == 0 else _walls[index - 1].at
	return Vector2(aft, fore)


## The cells of compartments [param flooded], by index from her bow: every cell between
## its bulkheads under the lower of their tops, her double bottom kept.
func _cells_of(flooded: Array[int]) -> Array[FloodCell]:
	var found: Array[FloodCell] = []
	for index: int in flooded:
		var span := _span(index)
		var top := INF
		for wall in [index - 1, index]:
			if wall >= 0 and wall < _walls.size():
				top = minf(top, _walls[wall].top)
		for cell: FloodCell in _structure.cells:
			var middle := (float(cell.low.x) + cell.high.x) * 0.5
			if middle <= span.x or middle >= span.y or cell.low.y >= top:
				continue
			if String(cell.name).begins_with("db_"):
				continue
			found.append(cell)
	return found


## Her rest with compartments [param flooded] open to the sea: their cells filled to its
## plane, her lift found again, until the two agree.
func _float(flooded: Array[int]) -> Floated:
	var made := Floated.new()
	var cells := _cells_of(flooded)
	var own := _own
	var centre := _structure.mass_centre()
	var whole := Hydrostatics.cut_hull(_structure.sections, Hydrostatics.level(INF)).volume
	var sea := Hydrostatics.rest(_structure.sections, own, centre)
	for _step in STEPS:
		var water := 0.0
		var moment := PackedFloat64Array([own * centre[0], own * centre[1], own * centre[2]])
		for cell: FloodCell in cells:
			var cut := Hydrostatics.cut_box(
				cell.low.x, cell.high.x, cell.low.y, cell.high.y, cell.low.z, cell.high.z, sea
			)
			var held := cut.volume * cell.shape * cell.permeability_in(_sea)
			water += held
			moment[0] += held * cut.x
			moment[1] += held * cut.y
			moment[2] += held * cut.z
		var total := own + water
		if total >= whole:
			return made
		var weight := PackedFloat64Array([moment[0] / total, moment[1] / total, moment[2] / total])
		var next := Hydrostatics.rest(_structure.sections, total, weight)
		var settled := (
			absf(next.height - sea.height) < SETTLED and absf(next.trim() - sea.trim()) < SETTLED
		)
		sea = next
		made.water = water
		if settled:
			made.rests = true
			break
	made.sea = sea
	for index in _walls.size():
		var wall := _walls[index]
		var over := -sea.depth(wall.at, wall.top, 0.0)
		made.spare = minf(made.spare, over)
		var aft_flooded := (index + 1) in flooded
		var fore_flooded := index in flooded
		if aft_flooded != fore_flooded:
			made.spare_ends = minf(made.spare_ends, over)
	return made


## Whether she floats with [param flooded] open: at rest, and the sea under the top of
## every bulkhead closing what is flooded, so none spills into the next.
func _floats(flooded: Array[int]) -> bool:
	var made := _float(flooded)
	return made.rests and made.spare_ends > 0.0


func _named(flooded: Array[int]) -> String:
	var names := PackedStringArray()
	for index: int in flooded:
		names.append(COMPARTMENTS[index])
	return " + ".join(names)


func test_any_two_adjacent_compartments_float_with_half_a_metre_to_spare() -> void:
	# BOT: "so placed that the ship would remain afloat in the event of any two adjoining
	# compartments being flooded"; Wilding, on his plan at her load waterline: "The
	# lowest case ... was 2 feet 7 inches".
	_at_load()
	for first in COMPARTMENTS.size() - 1:
		var pair: Array[int] = [first, first + 1]
		var made := _float(pair)
		gut.p("%s: spare %.2f m, trim %.2f°" % [_named(pair), made.spare, _trim_deg(made)])
		assert_true(made.rests, "%s: she comes to rest" % _named(pair))
		assert_gte(made.spare, SPARE, "%s: half a metre to her bulkhead deck" % _named(pair))


func test_the_first_four_float_and_the_first_five_founder() -> void:
	# BOT: "the ship, even with these four compartments flooded would have remained
	# afloat. But she could not remain afloat with the four forward compartments and the
	# forward boiler room (No. 6) also flooded."
	var four: Array[int] = [0, 1, 2, 3]
	var five: Array[int] = [0, 1, 2, 3, 4]
	var floated := _float(four)
	gut.p(
		(
			"the first four: spare at bulkhead D %.2f m, trim %.2f°"
			% [floated.spare_ends, _trim_deg(floated)]
		)
	)
	assert_true(_floats(four), "the first four float")
	var foundered := _float(five)
	gut.p("the first five: spare at bulkhead E %.2f m" % foundered.spare_ends)
	assert_false(_floats(five), "the first five founder")


func test_any_three_of_the_first_four_float() -> void:
	# Wilding, 20364: "the ship would have floated at the time of the accident if any
	# three of these forward compartments had been flooded".
	for left_out in 4:
		var three: Array[int] = []
		for index in 4:
			if index != left_out:
				three.append(index)
		assert_true(_floats(three), "%s float" % _named(three))


func test_the_three_compartment_exceptions_founder() -> void:
	# She was built for two (BOT); at her design's load waterline some three adjacent
	# compartments sink her. The inquiry names none but the forward four, which float
	# at the night's waterline (above); the exception asserted is the one its evidence
	# brackets — No. 3 hold with boiler rooms 6 and 5, the two whose flooding "sealed
	# the doom of the ship" (BOT) — and the rest are printed: the model's, not a source's.
	_at_load()
	var foundering := PackedStringArray()
	for first in COMPARTMENTS.size() - 2:
		var three: Array[int] = [first, first + 1, first + 2]
		if not _floats(three):
			foundering.append(_named(three))
	gut.p("at load, three adjacent compartments that founder: %s" % ", ".join(foundering))
	assert_has(
		foundering, "hold_3 + boiler_room_6 + boiler_room_5", "No. 3 hold and boiler rooms 6 and 5"
	)


func test_trim_per_thousand_tons_forward_about_her_pivot() -> void:
	# The research's: 0.19° a 1 000 long tons taken in forward, pivoting 176–180 m from
	# her bow — read with the six compartments the night opened flooded to the sea (BOT:
	# "the forepeak, No. 1 hold, No. 2 hold, No. 3 hold, No. 6 boiler room, No. 5 boiler
	# room").
	var intact := _float([] as Array[int])
	var floated := _float([0, 1, 2, 3, 4, 5] as Array[int])
	var tons := floated.water * _sea.sea_density / LONG_TON
	var trim := _trim_deg(floated)
	var per_thousand := trim / tons * 1000.0
	# Where her draught is the same as intact: the two seas' depths meet.
	var keel := _structure.keel_y
	var a := floated.sea.depth(0.0, keel, 0.0) - intact.sea.depth(0.0, keel, 0.0)
	var b := floated.sea.depth(1.0, keel, 0.0) - intact.sea.depth(1.0, keel, 0.0)
	var pivot_x := -a / (b - a)
	var told := (
		"the night's six: %.0f long tons in, trim %.2f° — %.3f° a 1 000 tons"
		% [tons, trim, per_thousand]
	)
	gut.p("%s; pivot x %.1f m, %.1f m from her bow" % [told, pivot_x, BOW - pivot_x])
	assert_almost_eq(
		per_thousand, TRIM_PER_THOUSAND, TRIM_PER_THOUSAND * TRIM_SHARE, "0.19° a 1 000 tons"
	)
	assert_between(BOW - pivot_x, PIVOT.x, PIVOT.y, "pivoting 176–180 m from her bow")


func test_the_nights_damage_is_the_inquirys() -> void:
	# BOT: damage "at about 10 feet above the level of the keel", from the forepeak to
	# No. 5 boiler room "at 2 feet from the watertight bulkhead between Nos. 5 and 6";
	# Wilding, 20422: the holes' aggregate area "somewhere about 12 square feet". Its
	# total area is part 2's calibration value: as a discharge area (× 0.6) 0.67 m², in
	# the research's 0.5–1.1 m².
	var hit: IcebergHit = load(NIGHT)
	var bulkhead_e := _walls[4]
	assert_eq(hit.side, 1, "her starboard side")
	assert_almost_eq(hit.start_x, bulkhead_e.at - 2.0 * 0.3048, 0.01, "2 ft abaft bulkhead E")
	assert_gt(hit.end_x(), _walls[0].at, "into her forepeak")
	var over_keel := _structure.waterline_y - hit.depth_start - _structure.keel_y
	assert_almost_eq(over_keel, 10.0 * 0.3048, 0.1, "about 10 ft over her keel")
	var area := hit.width * hit.length
	assert_almost_eq(area, 12.0 * 0.3048 * 0.3048, 0.01, "about 12 square feet")
	assert_between(area * _sea.discharge, 0.5, 1.1, "a discharge area in the research's band")


func _trim_deg(made: Floated) -> float:
	return rad_to_deg(atan(made.sea.trim())) if made.sea != null else NAN


func test_her_sisters_carry_their_bulkheads() -> void:
	# The Shipbuilder, 1914: Britannic's "sixteen transverse bulkheads, five of which
	# extend to a height of over 40 feet above the deepest load-line", and "a complete
	# inner skin" along her boiler and engine rooms; the Olympic altered "by the
	# introduction of an inner skin". Test-only hulls, never in the fleet.
	for sister: String in ["olympic_1913", "britannic"]:
		var layout: ShipLayout = load("res://tests/fixtures/ships/%s.tres" % sister)
		var structure := layout.structure
		assert_eq(structure.problems(), PackedStringArray(), "%s's structure loads" % sister)
		var bulkheads := 0
		var raised := 0
		var skin := 0
		for wall: ShipWall in structure.walls:
			if wall.axis == ShipWall.Axis.ALONG:
				skin += 1
				continue
			bulkheads += 1
			if wall.top > 0.0:
				raised += 1
		assert_eq(bulkheads, 16 if sister == "britannic" else 15, "%s's bulkheads" % sister)
		assert_eq(raised, 5, "%s: five carried over C deck" % sister)
		assert_gt(skin, 0, "%s: an inner skin" % sister)
		assert_false(Fleet.names().has(sister), "the fleet never lists %s" % sister)
