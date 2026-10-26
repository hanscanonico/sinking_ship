extends GutTest
## The boxes the water inside her is drawn in, and the sea is masked out of
## (CellBoxes.boxes, SeaAndSky): none of any ship of the fleet reaches past her shell —
## a cell drawn for its rooms whose box pokes out of her, as the trawler's fore does at
## her bow, is drawn round its rooms only, each in its own box where one round them all
## would poke out (the steamer's aft peak), and out to the bulkheads it shares — and a
## ship whose room cells stand inside her, the steamer, keeps each cell's whole box, but
## for her engine room's, which runs out to her shell round the stokehold (#74), and her
## old voids', people's places now (#148); a void a room under it stands up into is drawn
## over that room (her poop's space).

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
		var boxes := CellBoxes.boxes(structure, layout.rooms)
		var drawn: Array = []
		for index in boxes.size():
			drawn.append([index, boxes[index]])
		drawn.append_array(CellBoxes.stacked(structure, layout.rooms))
		for each: Array in drawn:
			var box: AABB = each[1]
			if box.size == Vector3.ZERO:
				continue
			var cell := "%s's %s" % [ship_name, structure.cells[each[0]].name]
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
	assert_lt(fore.shape, CellBoxes.WHOLE, "her fore pokes out past her stem")
	var box := CellBoxes.boxes(structure, layout.rooms)[structure.cell_named(&"fore")]
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


## A cell drawn round its rooms is drawn out to the bulkheads it shares, as a whole
## cell is: the Titanic's No. 3 hold's tween deck, whose rooms stop short of bulkheads
## D and C by the bulkheads' thickness, out to both, so its water meets boiler room 6's
## inside bulkhead D and the sea is never drawn across the watertight door there. But a
## box never takes on what another of its cell's boxes holds: No. 1 hold's, stacked
## down her narrowing bow, keep to their own rooms short of the bulkhead forward of it.
func test_a_cell_drawn_round_its_rooms_reaches_the_bulkheads_it_shares() -> void:
	var layout := Fleet.layout(&"titanic")
	var structure := layout.structure
	var drawn := CellBoxes.boxes(structure, layout.rooms)
	var index := structure.cell_named(&"hold_3_tween")
	var hold_3 := structure.cells[index]
	assert_lt(hold_3.shape, CellBoxes.WHOLE, "No. 3 hold's tween deck pokes past her shell")
	var berths := _room(layout, &"third-class berths")
	assert_gt(berths.area.position.x, hold_3.low.x + 0.1, "its rooms stop short of bulkhead D")
	assert_almost_eq(drawn[index].position.x, hold_3.low.x, 1e-5, "out to bulkhead D")
	assert_almost_eq(drawn[index].end.x, hold_3.high.x, 1e-5, "out to bulkhead C")
	var boiler_room := drawn[structure.cell_named(&"boiler_room_6_tween")]
	assert_almost_eq(boiler_room.end.x, hold_3.low.x, 1e-5, "meeting boiler room 6's")
	var hold_1 := structure.cells[structure.cell_named(&"hold_1")]
	var orlop := _room(layout, &"No. 1 hold, orlop")
	var top := drawn[structure.cell_named(&"hold_1")]
	assert_almost_eq(top.end.x, orlop.area.end.x, 1e-5, "No. 1 hold's keeps to its orlop")
	assert_lt(top.end.x, hold_1.high.x - 1.0, "short of the bulkhead forward of it")
	for stack: Array in CellBoxes.stacked(structure, layout.rooms):
		var box: AABB = stack[1]
		if structure.cells[stack[0]] == hold_1:
			assert_false(box.intersects(top), "its stack keeps off its top box at %s" % box)


## [param layout]'s room named [param name].
func _room(layout: ShipLayout, name: StringName) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.name == name:
			return room
	return null


## The space under the steamer's poop has no room of its own, but her steering gear
## stands up into it through its floor with nothing between them (ShipOpening.Kind.OPEN):
## its water is drawn over that opening, from its floor to the poop deck, so the sea is
## left out there as it is under the main deck. Her voids no room sees into stay undrawn.
func test_a_void_a_room_stands_up_into_is_drawn_over_the_room() -> void:
	var layout := Fleet.layout(&"steamer")
	var structure := layout.structure
	var index := structure.cell_named(&"poop_space")
	var poop := structure.cells[index]
	assert_true(poop.rooms.is_empty(), "the poop's space has no room of its own")
	var into: ShipOpening
	for opening: ShipOpening in structure.openings:
		if opening.name == &"open_aft_peak":
			into = opening
	assert_eq(into.kind, ShipOpening.Kind.OPEN, "nothing between the steering gear and it")
	var drawn := CellBoxes.boxes(structure, layout.rooms)
	var box := drawn[index]
	assert_almost_eq(box.position.y, poop.low.y, 1e-5, "from its floor")
	assert_almost_eq(box.end.y, poop.high.y, 1e-5, "to the poop deck")
	assert_almost_eq(
		box.position.x, into.centre.x - into.size.x * 0.5, 1e-5, "over the opening: aft"
	)
	assert_almost_eq(box.end.x, into.centre.x + into.size.x * 0.5, 1e-5, "forward")
	assert_almost_eq(box.position.z, into.centre.z - into.size.z * 0.5, 1e-5, "port")
	assert_almost_eq(box.end.z, into.centre.z + into.size.z * 0.5, 1e-5, "starboard")
	var trawler := Fleet.layout(&"trawler")
	var wing := trawler.structure.cell_named(&"engine_wing_p")
	assert_eq(
		CellBoxes.boxes(trawler.structure, trawler.rooms)[wing],
		AABB(),
		"the trawler's engine room wing, a void nobody sees into, is undrawn"
	)


func test_the_steamer_keeps_each_cells_whole_box_but_those_round_her_shell() -> void:
	var layout := Fleet.layout(&"steamer")
	var structure := layout.structure
	var drawn := CellBoxes.boxes(structure, layout.rooms)
	# Her engine room's cell runs from her tank top out to her shell, round the turn of
	# her bilge (#74): drawn round its rooms, the stokehold and its galleries, from the
	# stokehold's floor, within its lining.
	var engine := structure.cell_named(&"engine_room")
	var engine_cell := structure.cells[engine]
	assert_lt(engine_cell.shape, CellBoxes.WHOLE, "her engine room pokes past her bilge's turn")
	var stokehold: ShipRoom
	for room: ShipRoom in layout.rooms:
		if room.name == &"stokehold":
			stokehold = room
	var round := drawn[engine]
	assert_almost_eq(round.position.y, stokehold.floor_height, 1e-5, "from the stokehold's floor")
	assert_almost_eq(round.end.y, engine_cell.high.y, 1e-5, "to the engine room's top")
	assert_almost_eq(round.position.z, stokehold.area.position.y, 1e-5, "within its lining")
	assert_almost_eq(round.end.z, stokehold.area.end.y, 1e-5)
	var whole := 0
	for index in drawn.size():
		var box := drawn[index]
		# Her old voids' boxes are their rooms', as her engine room's is (#148).
		if box.size == Vector3.ZERO or structure.cells[index].shape < CellBoxes.WHOLE:
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
					is_zero_approx(gap) or is_equal_approx(gap, CellBoxes.INSET),
					"%s's box is its own on axis %s" % [cell.name, axis]
				)
	assert_eq(whole, 7, "her rooms' cells, the deckhouse's and the hold's top")
