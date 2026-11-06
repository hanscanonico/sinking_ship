extends GutTest
## Once she has broken (SH33), the planners work out where the sea and her water are as
## the piece of her each thing lies on stands (#478): the waterlines of her fore piece's
## decks where they cross the sea, a deck flooding, a machine going under, the funnel
## coming down to the sea and her cells heard flooding — each judged against its own
## piece's pose and its own cells' water, never as her aft piece, which the whole ship's
## pose follows, would have it.

## Points this far or more from her cut are on one piece of her alone.
const CLEAR := 2.0
## Her fore piece's main deck is crossing the sea by now.
const FORE_AWASH := 120.0
const WINDOW := 10.0
const NEAR := 1e-3
## When the deck and cell answers are read, after she parts, in seconds.
const READ_AT: Array[float] = [5.0, 20.0, 60.0, 120.0, 180.0, 300.0]


func _sim() -> MatchSim:
	return MatchSim.create(SimFixtures.breaking(1, null))


func _cut(schedule: SinkSchedule) -> float:
	var leaves := ShipPieces.leaves_of(schedule)
	return schedule.span_of(leaves[leaves.size() - 1]).x


## The piece she ends in that ship point x [param x] lies on.
func _leaf(schedule: SinkSchedule, x: float) -> int:
	return ShipPieces.leaves_of(schedule)[ShipPieces.leaf_at(schedule, x)]


## Whether ship point [param point] is under the water of [param pose] — a piece's own,
## its cells its own (Surfaces.wet).
func _wet(pose: ShipPose, point: Vector3) -> bool:
	var height := pose.world_height(point)
	return pose.wet_at(point, height, pose.cell_at(point))


func _steps(sim: MatchSim, from: int, to: int, planner: FxPlanner) -> Array[FxCue]:
	var snapshot := sim.snapshot()
	snapshot["events"] = []
	var found: Array[FxCue] = []
	for tick in range(from, to):
		var previous := snapshot.duplicate()
		previous["tick"] = tick
		var current := snapshot.duplicate()
		current["tick"] = tick + 1
		found.append_array(planner.plan(previous, current))
	return found


func test_her_fore_piece_s_decks_wash_where_they_cross_the_sea() -> void:
	var sim := _sim()
	var schedule := sim.schedule
	var cut := _cut(schedule)
	var planner := FxPlanner.new(sim.config, sim.surfaces, schedule)
	var from := SimFixtures.after_parting(schedule, FORE_AWASH)
	var cues := _steps(sim, from, from + Ticks.from_seconds(WINDOW), planner)
	var fore := 0
	var off_its_sea := 0
	for cue: FxCue in FxProbe.of(cues, FxCue.Kind.WASH):
		if cue.position.x >= cut:
			fore += 1
		# On the sea of the pose of the piece it lies on, at the tick it plays.
		var own := schedule.pose_at(cue.tick).of_piece(_leaf(schedule, cue.position.x))
		if absf(own.world_height(cue.position)) > NEAR:
			off_its_sea += 1
	assert_gt(fore, 0, "white water along her fore piece's decks")
	assert_eq(off_its_sea, 0, "each on the sea as its own piece stands")


func test_a_deck_floods_as_its_own_piece_stands() -> void:
	var sim := _sim()
	var schedule := sim.schedule
	var layout := sim.config.ship
	var cut := _cut(schedule)
	var planner := FxPlanner.new(sim.config, sim.surfaces, schedule)
	var heard := CuePlanner.new(sim.config, sim.surfaces, schedule, 0)
	var parted := SimFixtures.after_parting(schedule, 0.0)
	var wrong := 0
	var unlike_whole := 0
	for seconds: float in READ_AT:
		var pose := schedule.pose_at(parted + Ticks.from_seconds(seconds))
		var seen := planner._decks.of(pose)
		var sounded := heard._decks.of(pose)
		for index in layout.platforms.size():
			var deck := layout.platforms[index]
			var middle := Vector3(deck.area.get_center().x, deck.height, deck.area.get_center().y)
			if absf(middle.x - cut) < CLEAR:
				continue
			var own := _wet(pose.of_piece(_leaf(schedule, middle.x)), middle)
			if (seen[index] == 1) != own or (sounded[index] == 1) != own:
				wrong += 1
			if own != sim.surfaces.wet(middle, pose):
				unlike_whole += 1
	assert_gt(unlike_whole, 0, "decks the whole ship's pose would flood wrong")
	assert_eq(wrong, 0, "every deck flooded as its own piece stands")


func test_her_cells_are_heard_flooding_as_their_own_piece_stands() -> void:
	var sim := _sim()
	var schedule := sim.schedule
	var structure := sim.config.ship.structure
	var cut := _cut(schedule)
	var heard := CuePlanner.new(sim.config, sim.surfaces, schedule, 0)
	var parted := SimFixtures.after_parting(schedule, 0.0)
	var wrong := 0
	var unlike_whole := 0
	for seconds: float in READ_AT:
		var pose := schedule.pose_at(parted + Ticks.from_seconds(seconds))
		var over := heard._reading(pose).over
		for cell in structure.cells.size():
			var box := structure.cells[cell]
			var middle := (box.low + box.high) * 0.5
			if box.low.x < cut + CLEAR and box.high.x > cut - CLEAR:
				continue
			var leaf := _leaf(schedule, middle.x)
			var own := pose.of_piece(leaf)
			var place := schedule.structure_of(leaf).cell_named(box.name)
			var lowest := INF
			var whole_lowest := INF
			for corner: Vector3 in [
				box.low,
				Vector3(box.high.x, box.low.y, box.low.z),
				Vector3(box.low.x, box.low.y, box.high.z),
				Vector3(box.high.x, box.low.y, box.high.z),
			]:
				lowest = minf(lowest, own.world_height(corner))
				whole_lowest = minf(whole_lowest, pose.world_height(corner))
			var level := own.levels[place]
			if absf(level - lowest - CuePlanner.SHOWS) < NEAR:
				continue
			if (over[cell] == 1) != (level > lowest + CuePlanner.SHOWS):
				wrong += 1
			if (
				(pose.levels[cell] > whole_lowest + CuePlanner.SHOWS)
				!= (level > lowest + CuePlanner.SHOWS)
			):
				unlike_whole += 1
	assert_gt(unlike_whole, 0, "cells the whole ship's pose would hear wrong")
	assert_eq(wrong, 0, "every cell heard as its own piece stands")


func test_a_piece_s_view_answers_as_the_piece_itself() -> void:
	# What the planners ask of a point — how high it stands, whether it is wet, how deep
	# the water over it — asked of the view of the piece it lies on (PieceViews), answered
	# as the piece's own pose with its own cells answers it: vents over the sea, wells,
	# the funnel's top, a failing opening's sides.
	var sim := _sim()
	var schedule := sim.schedule
	var structure := sim.config.ship.structure
	var cut := _cut(schedule)
	var views := PieceViews.new(sim.config.ship, schedule)
	var parted := SimFixtures.after_parting(schedule, 0.0)
	var asked := 0
	var wrong: Array[String] = []
	for seconds: float in READ_AT:
		var pose := schedule.pose_at(parted + Ticks.from_seconds(seconds))
		for cell in structure.cells.size():
			var box := structure.cells[cell]
			for share: float in [0.1, 0.5, 0.9]:
				var point := box.low.lerp(box.high, share)
				if absf(point.x - cut) < CLEAR:
					continue
				var own := pose.of_piece(_leaf(schedule, point.x))
				var view := views.at(pose, point)
				asked += 1
				var alike := (
					is_equal_approx(view.world_height(point), own.world_height(point))
					and sim.surfaces.wet(point, view) == _wet(own, point)
					and is_equal_approx(view.water_level(point), own.water_level(point))
				)
				if not alike and wrong.size() < 4:
					wrong.append("%s at %.0f s" % [point, seconds])
	assert_gt(asked, 0, "points asked")
	assert_eq(wrong, [] as Array[String], "every point as its own piece answers it")


func test_her_funnel_dips_and_hisses_as_its_own_piece_brings_it_down() -> void:
	var sim := _sim()
	var schedule := sim.schedule
	var planner := FxPlanner.new(sim.config, sim.surfaces, schedule)
	var funnel := planner._funnel
	assert_false(is_nan(funnel.x), "she has a funnel")
	if is_nan(funnel.x):
		return
	var leaf := _leaf(schedule, funnel.x)
	var expected := PackedInt32Array()
	var found := PackedInt32Array()
	for tick in range(SimFixtures.after_parting(schedule, 1.0), schedule.end_tick()):
		var then := schedule.pose_at(tick - 1)
		var now := schedule.pose_at(tick)
		var was := then.of_piece(leaf).world_height(funnel)
		var is_now := now.of_piece(leaf).world_height(funnel)
		for edge: float in [FxPlanner.FUNNEL_DIP, 0.0]:
			if is_now < edge and was >= edge:
				expected.append(tick)
		var cues: Array[FxCue] = []
		planner._funnel_going(then, now, tick, cues)
		for cue: FxCue in cues:
			found.append(cue.tick)
	assert_false(expected.is_empty(), "her funnel goes under with its piece")
	assert_eq(found, expected, "belching and hissing as its own piece brings it down")


func test_her_machinery_goes_under_as_its_own_piece_stands() -> void:
	var sim := _sim()
	var schedule := sim.schedule
	var layout := sim.config.ship
	var planner := FxPlanner.new(sim.config, sim.surfaces, schedule)
	var water := planner._machinery_water
	assert_false(water.rooms.is_empty(), "she has machinery")
	var expected := PackedInt32Array()
	var found := PackedInt32Array()
	var from := SimFixtures.after_parting(schedule, 1.0)
	for slot in water.rooms.size():
		var room := layout.rooms[water.rooms[slot]]
		var leaf := _leaf(schedule, room.area.get_center().x)
		var points: Array[Vector3] = []
		for at in range(slot * 5, slot * 5 + 5):
			points.append(water._points.point(at))
		var was := PackedByteArray([0, 0])
		for tick in range(from - 1, schedule.end_tick()):
			var own := schedule.pose_at(tick).of_piece(leaf)
			var floor_wet := false
			for corner in 4:
				floor_wet = floor_wet or _wet(own, points[corner])
			var now := PackedByteArray([1 if floor_wet else 0, 1 if _wet(own, points[4]) else 0])
			if tick >= from:
				for edge in 2:
					if now[edge] == 1 and was[edge] == 0:
						expected.append_array([slot, edge, tick])
			was = now
	var by_room: Array[PackedInt32Array] = []
	by_room.resize(water.rooms.size())
	for tick in range(from, schedule.end_tick()):
		var went := water.went_under(
			schedule.pose_at(tick - 1), schedule.pose_at(tick), tick - 1, tick
		)
		for slot in water.rooms.size():
			for edge in 2:
				if went[slot * 2 + edge] == 1:
					by_room[slot].append_array([slot, edge, tick])
	for each: PackedInt32Array in by_room:
		found.append_array(each)
	assert_false(expected.is_empty(), "her machinery goes under with its piece")
	assert_eq(found, expected, "its floor and machine going under as its own piece stands")
