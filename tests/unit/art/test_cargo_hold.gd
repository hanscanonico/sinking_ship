extends GutTest
## A hold too low for it stows nothing over head height: the Titanic's orlop forward of D,
## under 2 m to its deck, its racks' sacks once through the deck into the rooms over it.

const SHIP := "res://data/ships/titanic.tres"
const LOW_HOLD := &"first- and second-class baggage room"


func test_a_hold_no_taller_than_head_height_has_no_racks_through_its_deck() -> void:
	var ship: ShipLayout = load(SHIP)
	var space := ShipSpace.new(ship)
	var hold := CargoHold.new(space)
	var checked := 0
	for room: ShipRoom in ship.rooms:
		if room.name != LOW_HOLD:
			continue
		checked += 1
		var middle := room.area.get_center()
		var head := space.ceiling(room, middle.x, middle.y)
		assert_lt(head - room.floor_height, RoomDressing.HEADROOM + 0.2, "she is that low there")
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, space.room_lines())
		hold.build(mesh, room)
		var parent := Node3D.new()
		var materials := {}
		for finish: int in ShipMesh.Finish.values():
			materials[finish] = StandardMaterial3D.new()
		mesh.commit(parent, materials)
		var highest := -INF
		for node: Node in parent.get_children():
			for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
				highest = maxf(highest, corner.y)
		parent.free()
		assert_lte(highest, head + 0.001, "nothing of it through its deck")
	assert_gt(checked, 0, "she has the room")


func test_a_hold_too_low_for_them_has_no_door_signs_or_hatch_beams_at_a_body_s_height() -> void:
	var ship: ShipLayout = load(SHIP)
	var space := ShipSpace.new(ship)
	var dressing := RoomDressing.new(space, INF)
	var hold := CargoHold.new(space)
	var checked := 0
	for room: ShipRoom in ship.rooms:
		if room.name != LOW_HOLD:
			continue
		checked += 1
		var head := CargoHold.headroom(space, room)
		var beams := head - ShipArt.PLANK - ShipArt.BEAM_DEPTH - 0.06
		var signs := Node3D.new()
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, space.room_lines())
		dressing._signs(mesh, signs, room)
		assert_eq(signs.get_child_count(), 0, "no sign over a door in a room under its height")
		signs.free()
		mesh = ShipMesh.new(func(_point: Vector3) -> bool: return false, space.room_lines())
		hold._hatch_beams(mesh, room)
		var parent := Node3D.new()
		var materials := {}
		for finish: int in ShipMesh.Finish.values():
			materials[finish] = StandardMaterial3D.new()
		mesh.commit(parent, materials)
		assert_lt(beams, RoomDressing.HEADROOM, "it is that low")
		assert_eq(parent.get_child_count(), 0, "no hatch's timbers")
		parent.free()
	assert_gt(checked, 0, "she has the room")


func test_a_stringer_along_a_hold_s_side_stays_under_a_deck_over_part_of_it() -> void:
	var ship: ShipLayout = load(SHIP)
	var space := ShipSpace.new(ship)
	var hold := CargoHold.new(space)
	var checked := 0
	for room: ShipRoom in ship.rooms:
		if room.name != &"No. 2 hold, tank top, port" or room.area.position.x < 90.0:
			continue
		checked += 1
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, space.room_lines())
		hold.build(mesh, room)
		var parent := Node3D.new()
		var materials := {}
		for finish: int in ShipMesh.Finish.values():
			materials[finish] = StandardMaterial3D.new()
		mesh.commit(parent, materials)
		var deck := space.ceiling(room, 97.0, room.area.position.y + 0.2)
		for node: Node in parent.get_children():
			for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
				if corner.x > 96.0 and corner.x < 98.0:
					assert_lte(corner.y, deck + 0.001, "under the deck over it")
		parent.free()
	assert_gt(checked, 0, "she has the room")


func test_nothing_of_a_hold_s_side_stands_in_a_flight_climbing_beside_it() -> void:
	var ship: ShipLayout = load(SHIP)
	var space := ShipSpace.new(ship)
	var hold := CargoHold.new(space)
	var mesh_of := func(room: ShipRoom) -> Array:
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, space.room_lines())
		hold.build(mesh, room)
		var parent := Node3D.new()
		var materials := {}
		for finish: int in ShipMesh.Finish.values():
			materials[finish] = StandardMaterial3D.new()
		mesh.commit(parent, materials)
		var corners := []
		for node: Node in parent.get_children():
			corners.append_array((node as MeshInstance3D).mesh.get_faces())
		parent.free()
		return corners
	var checked := 0
	for room: ShipRoom in ship.rooms:
		if room.name != &"No. 2 hold, tank top, port" or room.area.position.x < 90.0:
			continue
		for ramp: ShipRamp in ship.ramps:
			if ramp.base() > room.floor_height + 0.1 or not ramp.area.intersects(room.area):
				continue
			checked += 1
			for corner: Vector3 in mesh_of.call(room):
				var at := Vector2(corner.x, corner.z)
				assert_false(
					ramp.area.grow(-0.01).has_point(at) and corner.y > ramp.base() + 2.0,
					"nothing of it at %s over the flight" % corner
				)
	assert_gt(checked, 0, "a flight climbs in the room")


func test_a_tween_deck_stands_a_body_s_reach_off_a_flight_through_its_hold() -> void:
	var ship: ShipLayout = load(SHIP)
	var space := ShipSpace.new(ship)
	var hold := CargoHold.new(space)
	var checked := 0
	for room: ShipRoom in ship.rooms:
		if room.name != &"No. 2 hold, tank top, port":
			continue
		checked += 1
		var tween := hold._tween_area(room)
		if not tween.has_area():
			continue
		for ramp: ShipRamp in ship.ramps:
			if ramp.base() < room.floor_height + CargoHold.TWEEN + 0.5:
				var near := ramp.area.grow(CargoHold.RACK_CLEAR - 0.01)
				assert_false(near.intersects(tween), "clear of the flight at %s" % ramp.area)
	assert_gt(checked, 0, "she has the room")
