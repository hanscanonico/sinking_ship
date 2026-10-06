extends GutTest
## The boxes the water inside her is drawn in, and the sea is masked out of
## (InnerWater.boxes, SeaAndSky): none of any ship of the fleet reaches past her shell —
## a cell drawn for its rooms whose box pokes out of her, as the trawler's fore does at
## her bow, is drawn round its rooms only — and a ship whose room cells stand inside her,
## the steamer, keeps each cell's whole box.

## How far a drawn box may stand past her shell, in metres.
const NEAR := 0.01
## How far inside a box's top and bottom her shell is read: a box's top on her sheer
## stands where her outline ends.
const IN := 1e-3


## Whether [param box]'s side [param side] — 1 for starboard, -1 for port — stands
## inside [param section]'s shell at every height the box spans: her shell is straight
## between its outline's points, so its narrowest there is at one of them or at an end.
func _inside(section: HullSection, box: AABB, side: int) -> bool:
	var heights := PackedFloat32Array([box.position.y + IN, box.end.y - IN])
	for point: Vector2 in section.outline:
		if point.y > box.position.y and point.y < box.end.y:
			heights.append(point.y)
	var reach := box.end.z if side == 1 else -box.position.z
	for height: float in heights:
		var shell := section.shell_at(height, side)
		if is_nan(shell) or reach > shell * side + NEAR:
			return false
	return true


func test_no_drawn_box_reaches_past_her_shell() -> void:
	for ship_name: String in Fleet.names():
		var layout := Fleet.layout(ship_name)
		var structure := layout.structure
		var sections := structure.sections
		var stern := sections[0].x - sections[0].length * 0.5
		var stem := sections[-1].x + sections[-1].length * 0.5
		var drawn := InnerWater.boxes(structure, layout.rooms)
		for index in drawn.size():
			var box := drawn[index]
			if box.size == Vector3.ZERO:
				continue
			var cell := "%s's %s" % [ship_name, structure.cells[index].name]
			assert_true(box.position.x >= stern - NEAR and box.end.x <= stem + NEAR, cell)
			for section: HullSection in sections:
				var half := section.length * 0.5
				var aft := section.x - half
				if section.x + half <= box.position.x + NEAR or aft >= box.end.x - NEAR:
					continue
				for side: int in [1, -1]:
					assert_true(_inside(section, box, side), "%s at x %s" % [cell, section.x])


func test_a_cell_poking_out_of_her_is_drawn_round_its_rooms() -> void:
	var layout := Fleet.layout(&"trawler")
	var structure := layout.structure
	var fore := structure.cells[structure.cell_named(&"fore")]
	assert_lt(fore.shape, InnerWater.WHOLE, "her fore pokes out past her stem")
	var box := InnerWater.boxes(structure, layout.rooms)[structure.cell_named(&"fore")]
	var mess: ShipRoom
	for room: ShipRoom in layout.rooms:
		if room.name == &"crew mess":
			mess = room
	assert_almost_eq(box.position.y, mess.floor_height, 1e-5, "from the crew mess's floor")
	assert_almost_eq(box.end.y, fore.high.y, 1e-5, "to the fore's top")
	assert_almost_eq(box.position.x, mess.area.position.x, 1e-5, "out to its walls: aft")
	assert_almost_eq(box.end.x, mess.area.end.x, 1e-5, "forward")
	assert_almost_eq(box.position.z, mess.area.position.y, 1e-5, "port")
	assert_almost_eq(box.end.z, mess.area.end.y, 1e-5, "starboard")


func test_the_steamer_keeps_each_cells_whole_box() -> void:
	var layout := Fleet.layout(&"steamer")
	var structure := layout.structure
	var drawn := InnerWater.boxes(structure, layout.rooms)
	var whole := 0
	for index in drawn.size():
		var box := drawn[index]
		if box.size == Vector3.ZERO:
			continue
		whole += 1
		var cell := structure.cells[index]
		assert_almost_eq(box.position.y, cell.low.y, 1e-5, "%s from its floor" % cell.name)
		assert_almost_eq(box.end.y, cell.high.y, 1e-5, "%s to its top" % cell.name)
		# Each face in from its cell's by INSET where no other cell's box shares it.
		for axis: int in [0, 2]:
			var low := box.position[axis] - cell.low[axis]
			var high := cell.high[axis] - box.end[axis]
			for gap: float in [low, high]:
				assert_true(
					is_zero_approx(gap) or is_equal_approx(gap, InnerWater.INSET),
					"%s's box is its own on axis %s" % [cell.name, axis]
				)
	assert_eq(whole, 8, "her rooms' cells, the deckhouse's and the hold's top")
