extends GutTest
## MachineryWater answers as reading every floor corner and machine afresh each pose:
## its kept reading of the pose before and its cells found once change no answer.


func _went_by_hand(
	surfaces: Surfaces, layout: ShipLayout, rooms: PackedInt32Array, then: ShipPose, now: ShipPose
) -> PackedByteArray:
	var went := PackedByteArray()
	for index: int in rooms:
		var room := layout.rooms[index]
		var middle := room.area.get_center()
		var machine := Vector3(middle.x, room.floor_height + 1.0, middle.y)
		went.append(
			1 if _floor_wet(surfaces, room, now) and not _floor_wet(surfaces, room, then) else 0
		)
		went.append(1 if surfaces.wet(machine, now) and not surfaces.wet(machine, then) else 0)
	return went


func _floor_wet(surfaces: Surfaces, room: ShipRoom, pose: ShipPose) -> bool:
	var area := room.area
	for corner: Vector2 in [
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y)
	]:
		if surfaces.wet(Vector3(corner.x, room.floor_height, corner.y), pose):
			return true
	return false


func test_it_answers_as_reading_every_pose_afresh() -> void:
	var layout := SimFixtures.steamer()
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	sinking.explicit_hit = SimFixtures.explicit_hit(1, -2.0, 19.0, 1.0, 0.05, 1.5)
	var sim := SimFixtures.sim(1, sinking, layout)
	var machines := PackedVector3Array()
	for room: ShipRoom in layout.rooms:
		var middle := room.area.get_center()
		machines.append(Vector3(middle.x, room.floor_height + 1.0, middle.y))
	machines[0] = Vector3(NAN, NAN, NAN)
	var water := MachineryWater.new(layout, machines, sim.surfaces)
	assert_eq(water.rooms.size(), layout.rooms.size() - 1, "the room with no machine left out")
	var went_any := 0
	var tick := 0
	var stride := Ticks.RATE
	while tick + stride < sim.schedule.end_tick():
		# Every few steps a jump, as a seek makes: the pose before read again.
		var from := tick if tick % (stride * 7) != 0 else tick - 1
		var then := sim.schedule.pose_at(from)
		var now := sim.schedule.pose_at(tick + stride)
		var went := water.went_under(then, now, from, tick + stride)
		assert_eq(went, _went_by_hand(sim.surfaces, layout, water.rooms, then, now), "at %d" % tick)
		went_any += went.count(1)
		tick += stride
	assert_gt(went_any, 0, "some floor or machine goes under")
