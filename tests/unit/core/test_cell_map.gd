extends GutTest
## CellMap answers in slots along her and takes a point well inside her shell on trust
## (SH26): the same cell, everywhere in and round her, as trying every box in her cells'
## order and every poking box against her shell.


## The cell [param ship_point] lies in, found the long way: every box in order, one
## that pokes outside her hull only where the point is inside her shell.
static func _the_long_way(structure: ShipStructure, ship_point: Vector3) -> int:
	for index in structure.cells.size():
		var cell := structure.cells[index]
		var low := cell.low
		var high := cell.high
		if ship_point.x < low.x or ship_point.x >= high.x:
			continue
		if ship_point.y < low.y or ship_point.y >= high.y:
			continue
		if ship_point.z < low.z or ship_point.z >= high.z:
			continue
		if cell.shape < 1.0:
			var section := structure.section_at(ship_point.x)
			if section == null:
				continue
			var side := 1 if ship_point.z >= 0.0 else -1
			var shell := section.shell_at(ship_point.y, side)
			if is_nan(shell) or ship_point.z * side > shell * side:
				continue
		return index
	return CellMap.NONE


func test_slots_and_the_shell_shortcut_find_the_cell_the_long_way_does() -> void:
	var structure: ShipStructure = SimFixtures.steamer().structure
	var cells := CellMap.new(structure)
	var differing := 0
	var inside := 0
	var tried := 0
	# Half a metre along, on every whole and half metre her boxes start and end on; a
	# fifth of a metre across and up, through her shell and her boxes' faces.
	for along in 85:
		var x := -21.0 + along * 0.5
		for up in 70:
			var y := -6.0 + up * 0.2
			for across in 61:
				var point := Vector3(x, y, -6.0 + across * 0.2)
				var found := cells.cell_at(point)
				tried += 1
				if found != CellMap.NONE:
					inside += 1
				if found != _the_long_way(structure, point):
					differing += 1
	assert_gt(inside, tried / 10, "a fair share of the points are in her cells")
	assert_eq(differing, 0, "the same cell as the long way, at all %d points" % tried)
