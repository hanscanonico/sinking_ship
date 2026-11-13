extends GutTest
## ShipStructure.section_at() bisects her sections (#635): it answers exactly what
## walking them in order answers, for every ship, past her ends, across a missing
## section, and after her sections change.

const SHIPS: Array[ShipLayout] = [
	preload("res://data/ships/titanic.tres"),
	preload("res://data/ships/small_titanic.tres"),
	preload("res://data/ships/steamer.tres"),
	preload("res://data/ships/trawler.tres"),
	preload("res://data/ships/tug.tres"),
	preload("res://data/ships/barque.tres"),
]
## How finely x is swept, in metres, and how far past her ends.
const STEP := 0.037
const PAST := 6.0


func test_every_ship_answers_as_the_scan_does() -> void:
	for ship: ShipLayout in SHIPS:
		var structure := ship.structure
		var aft := structure.sections[0].x - structure.sections[0].length * 0.5
		var x := aft - PAST
		var wrong := _first_wrong(structure, x, aft + structure.length() + PAST, STEP)
		assert_eq(wrong, "", ship.resource_path)
		# Every end exactly, and the float either side of it.
		for section: HullSection in structure.sections:
			for end: float in [section.x - section.length * 0.5, section.x + section.length * 0.5]:
				for at: float in [end, _next_down(end), _next_up(end)]:
					assert_same(structure.section_at(at), structure.section_at_by_scan(at))


func test_a_missing_section_and_touching_ends() -> void:
	var structure := ShipStructure.new()
	var sections: Array[HullSection] = [
		_section(0.0, 2.0), null, _section(2.0, 2.0), _section(4.0, 2.0), null
	]
	structure.sections = sections
	assert_eq(_first_wrong(structure, -3.0, 8.0, 0.01), "")
	assert_same(structure.section_at(1.0), sections[2], "the fore end is out, the after in")
	assert_same(structure.section_at(-1.0), sections[0])
	assert_null(structure.section_at(5.0), "her fore end is past her")
	assert_null(structure.section_at(NAN))


func test_overlaps_and_gaps_answer_as_the_scan_does() -> void:
	var structure := ShipStructure.new()
	var sections: Array[HullSection] = [
		_section(0.0, 2.0), _section(1.9, 2.0), _section(4.5, 2.0), _section(5.5, 2.0)
	]
	structure.sections = sections
	assert_eq(_first_wrong(structure, -2.0, 8.0, 0.01), "")


func test_sections_out_of_order_fall_back_to_the_scan() -> void:
	var structure := ShipStructure.new()
	var sections: Array[HullSection] = [_section(4.0, 2.0), _section(0.0, 2.0), _section(2.0, 6.0)]
	structure.sections = sections
	assert_eq(_first_wrong(structure, -2.0, 7.0, 0.01), "")
	assert_same(structure.section_at(0.5), sections[1])
	assert_same(structure.section_at(1.0), sections[2])


func test_a_change_to_her_sections_is_never_answered_stale() -> void:
	var structure := ShipStructure.new()
	var first := _section(0.0, 2.0)
	var sections: Array[HullSection] = [first, _section(2.0, 2.0)]
	structure.sections = sections
	assert_same(structure.section_at(2.5), sections[1])
	structure.sections.append(_section(4.0, 2.0))
	assert_same(structure.section_at(4.5), structure.sections[2], "one appended")
	first.length = 6.0
	assert_same(structure.section_at(2.5), first, "a section lengthened")
	first.x = -10.0
	assert_same(structure.section_at(2.5), structure.sections[1], "a section moved")
	structure.sections[1] = _section(2.0, 0.5)
	assert_null(structure.section_at(2.5), "a section replaced")
	structure.sections[1] = null
	assert_eq(_first_wrong(structure, -14.0, 7.0, 0.01), "", "a section dropped")


## The first x from [param from] to [param to] where bisection and the scan differ,
## as text; empty where they never do.
func _first_wrong(structure: ShipStructure, from: float, to: float, step: float) -> String:
	var count := int(ceilf((to - from) / step))
	for index in count + 1:
		var x := from + index * step
		var found := structure.section_at(x)
		var scanned := structure.section_at_by_scan(x)
		if found != scanned:
			return "x %s: %s, the scan %s" % [x, _named(found), _named(scanned)]
	return ""


static func _named(section: HullSection) -> String:
	return "none" if section == null else "the section at %s" % section.x


static func _section(x: float, length: float) -> HullSection:
	var section := HullSection.new()
	section.x = x
	section.length = length
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
