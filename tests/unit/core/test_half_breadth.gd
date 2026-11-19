extends GutTest
## ShipStructure.half_breadth() bisects her sections' middles (#411): it answers exactly
## what walking them in order answers, for every ship, at every middle and the float
## either side of it, and for sections out of order or changed.

const SHIPS: Array[ShipLayout] = [
	preload("res://data/ships/titanic.tres"),
	preload("res://data/ships/small_titanic.tres"),
	preload("res://data/ships/steamer.tres"),
	preload("res://data/ships/trawler.tres"),
	preload("res://data/ships/tug.tres"),
	preload("res://data/ships/barque.tres"),
]
## How finely x is swept, in metres, and how far past her ends.
const STEP := 0.37
const PAST := 3.0


func test_every_ship_answers_as_the_scan_does() -> void:
	for ship: ShipLayout in SHIPS:
		var structure := ship.structure
		var ys: Array[float] = [
			structure.keel_y,
			lerpf(structure.keel_y, structure.waterline_y, 0.5),
			structure.waterline_y,
			structure.waterline_y + 4.0,
		]
		var aft := structure.sections[0].x - structure.sections[0].length * 0.5
		var to := aft + structure.length() + PAST
		assert_eq(_first_wrong(structure, aft - PAST, to, STEP, ys), "", ship.resource_path)
		var wrong := ""
		for section: HullSection in structure.sections:
			for at: float in [section.x, _next_down(section.x), _next_up(section.x)]:
				wrong = _wrong_at(structure, at, ys)
				if wrong != "":
					break
			if wrong != "":
				break
		assert_eq(wrong, "", "%s at a middle" % ship.resource_path)


func test_sections_out_of_order_fall_back_to_the_scan() -> void:
	var structure := ShipStructure.new()
	var sections: Array[HullSection] = [
		_section(0.0, 2.0), _section(3.0, 2.0), _section(2.5, 1.0), _section(5.0, 2.0)
	]
	structure.sections = sections
	assert_eq(_first_wrong(structure, -2.0, 7.0, 0.01, [0.0, 0.5]), "")


func test_a_change_to_her_sections_is_never_answered_stale() -> void:
	var structure := ShipStructure.new()
	var first := _section(0.0, 2.0)
	var sections: Array[HullSection] = [first, _section(2.0, 2.0), _section(4.0, 2.0)]
	structure.sections = sections
	assert_eq(_first_wrong(structure, -2.0, 6.0, 0.01, [0.0, 0.5]), "")
	first.x = 1.0
	assert_eq(_first_wrong(structure, -2.0, 6.0, 0.01, [0.0, 0.5]), "", "a section moved")
	structure.sections.append(_section(6.0, 2.0, 2.0))
	assert_eq(_first_wrong(structure, -2.0, 8.0, 0.01, [0.0, 0.5]), "", "one appended")


## The first (x, y, way) from [param from] to [param to] where bisection and the scan
## differ, as text; empty where they never do.
func _first_wrong(
	structure: ShipStructure, from: float, to: float, step: float, ys: Array[float]
) -> String:
	var count := int(ceilf((to - from) / step))
	for index in count + 1:
		var wrong := _wrong_at(structure, from + index * step, ys)
		if wrong != "":
			return wrong
	return ""


func _wrong_at(structure: ShipStructure, x: float, ys: Array[float]) -> String:
	for y: float in ys:
		for way: int in [1, -1]:
			var found := structure.half_breadth(x, y, way)
			var scanned := structure.half_breadth_by_scan(x, y, way)
			if not is_same(found, scanned):
				return "x %s y %s way %d: %s, the scan %s" % [x, y, way, found, scanned]
	return ""


static func _section(x: float, length: float, half_width := 1.0) -> HullSection:
	var section := HullSection.new()
	section.x = x
	section.length = length
	section.outline = PackedVector2Array(
		[
			Vector2(-half_width * 0.5, -1.0),
			Vector2(half_width * 0.5, -1.0),
			Vector2(half_width, 1.0),
			Vector2(-half_width, 1.0),
		]
	)
	return section


static func _next_up(value: float) -> float:
	return _step(value, 1)


static func _next_down(value: float) -> float:
	return _step(value, -1)


## The double next to [param value] towards [param way]'s sign.
static func _step(value: float, way: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var bits := bytes.decode_s64(0)
	if value == 0.0:
		bytes.encode_s64(0, 1)
		return bytes.decode_double(0) * way
	bits += way if value > 0.0 else -way
	bytes.encode_s64(0, bits)
	return bytes.decode_double(0)
