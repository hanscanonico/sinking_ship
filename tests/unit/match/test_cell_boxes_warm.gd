extends GutTest
## Her water's boxes made ahead on a worker (CellBoxes.warm, #634): asked for as her
## match's water is first drawn, they are found made — waited for while still being made,
## never made a second time beside — and the same boxes and stacks a cold ask makes.

const SMALL_TITANIC := "res://data/ships/small_titanic.tres"


## [param layout]'s lists as her water reads them: [boxes, stacks].
func _asked(layout: ShipLayout) -> Array:
	return [
		CellBoxes.boxes(layout.structure, layout.rooms),
		CellBoxes.stacked(layout.structure, layout.rooms, layout),
	]


func _forget(structure: ShipStructure) -> void:
	CellBoxes._made_guard.lock()
	CellBoxes._made.erase(structure)
	CellBoxes._made_guard.unlock()


func test_warmed_lists_are_asked_for_without_being_made_again() -> void:
	var layout: ShipLayout = load(SMALL_TITANIC)
	_forget(layout.structure)
	var makes := CellBoxes._makes
	# Asked at once: the warm-up is likely still under way, and is waited for.
	CellBoxes.warm(layout.structure, layout.rooms, layout)
	_asked(layout)
	assert_eq(CellBoxes._makes - makes, 1, "made once, by the warm-up")
	CellBoxes.warm(layout.structure, layout.rooms, layout)
	_asked(layout)
	assert_eq(CellBoxes._makes - makes, 1, "a second warm-up of made lists makes none")


func test_warmed_lists_are_those_a_cold_ask_makes() -> void:
	for ship_name: StringName in [&"steamer", &"trawler"]:
		var layout := Fleet.layout(ship_name)
		_forget(layout.structure)
		CellBoxes.warm(layout.structure, layout.rooms, layout)
		var warm := _asked(layout)
		_forget(layout.structure)
		var cold := _asked(layout)
		assert_eq(warm[0], cold[0], "%s's boxes" % ship_name)
		assert_eq(warm[1], cold[1], "%s's stacks" % ship_name)
		assert_false((cold[0] as Array).is_empty(), "%s has boxes" % ship_name)
