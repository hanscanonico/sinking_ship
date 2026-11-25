extends GutTest
## ShapeStock (#563): what every reader of a match builds of her alike — a piece's cut
## layout, its decks' Surfaces, a frame she turns onto — built once and shared, each
## reader still standing on a Surfaces of its own; and what a ShapeWarmer foresees her by
## (SinkSchedule.placed_at) is where pose_at has her.


func _config() -> MatchConfig:
	return SimFixtures.breaking(1, null)


func _pieces(config: MatchConfig, sim: MatchSim) -> Pieces:
	return Pieces.new(
		config.ship, sim.schedule, sim.faces, config.rules.brace_holds_to, true, config.shapes()
	)


## The heights under a grid of points over [param surfaces]' piece, as a body would ask.
func _heights(surfaces: Surfaces, layout: ShipLayout) -> PackedFloat64Array:
	var bounds := SpatialIndex.bounds_of(layout)
	var found := PackedFloat64Array()
	for i in 12:
		for j in 6:
			var at := bounds.position + bounds.size * Vector2((i + 0.5) / 12.0, (j + 0.5) / 6.0)
			for y: float in [-6.0, -2.0, 0.0, 2.0, 6.0]:
				var point := Vector3(at.x, y, at.y)
				var surface := surfaces.under(point, 0.5)
				found.append(surface)
				if surface != Surfaces.NONE:
					found.append(surfaces.height_at(surface, point))
	return found


func test_a_second_reader_of_a_piece_shares_the_firsts_shape_and_stands_apart() -> void:
	var config := _config()
	var sim := MatchSim.create(config)
	assert_gt(sim.schedule.piece_count(), 1, "the fixture breaks")
	var first := _pieces(config, sim).faces(1)
	var second := _pieces(config, sim).faces(1)
	assert_same(first.layout(Faces.Up.DECK), second.layout(Faces.Up.DECK), "one cut layout")
	var a := first.surfaces(Faces.Up.DECK)
	var b := second.surfaces(Faces.Up.DECK)
	assert_ne(a, b, "each reader stands on its own Surfaces")
	var fresh := Surfaces.new(first.layout(Faces.Up.DECK))
	var layout := first.layout(Faces.Up.DECK)
	assert_eq(_heights(b, layout), _heights(fresh, layout), "answers as one built afresh")
	a._gone[0] = 1
	a._tops[a._first_top] = -99.0
	assert_eq(b._gone[0], 0, "what a pose takes away from one stays on the other")
	assert_ne(b._tops[b._first_top], -99.0)


func test_a_frame_she_turns_onto_is_built_once_for_every_reader() -> void:
	var config := _config()
	var sim := MatchSim.create(config)
	var first := _pieces(config, sim).faces(1)
	var second := _pieces(config, sim).faces(1)
	var up := Faces.Up.STARBOARD
	var a := first.surfaces(up)
	var b := second.surfaces(up)
	assert_same(first.layout(up), second.layout(up), "one framed layout")
	assert_ne(a, b)
	var fresh := Surfaces.new(first.layout(up))
	assert_eq(_heights(b, first.layout(up)), _heights(fresh, first.layout(up)))
	assert_true(config.shapes().has([&"frame", 1, up, first.shut_of(null)]))


func test_a_sliding_door_keeps_no_frame() -> void:
	var config := _config()
	var sim := MatchSim.create(config)
	var faces := _pieces(config, sim).faces(1)
	var shut := faces.shut_of(null)
	if shut.is_empty():
		pass_test("no watertight door on the fixture")
		return
	shut[0] = 0.5
	faces.stock_frame(Faces.Up.PORT, shut)
	assert_false(config.shapes().has([&"frame", 1, Faces.Up.PORT, shut]))


func test_placed_at_places_her_and_her_pieces_as_pose_at_does() -> void:
	var config := _config()
	var schedule := MatchSim.create(config).schedule
	var parted := SimFixtures.after_parting(schedule, 0.0)
	for tick: int in [
		0, schedule.hit_tick(), parted - 1, parted, parted + 300, schedule.end_tick()
	]:
		var placed := schedule.placed_at(tick)
		var pose := schedule.pose_at(tick)
		assert_eq(placed.standing, pose.standing, "tick %d" % tick)
		assert_eq(placed.doors_shut, pose.doors_shut)
		assert_eq(placed.opened, pose.opened)
		for piece: int in pose.standing:
			assert_eq(placed.of_piece(piece).transform, pose.of_piece(piece).transform)


func test_bots_take_the_floors_a_warmer_built_ahead() -> void:
	var config := _config()
	var sim := MatchSim.create(config)
	var built := _pieces(config, sim).faces(1)
	var graph := WalkGraph.new(
		built.layout(Faces.Up.DECK), built.surfaces(Faces.Up.DECK), config.rules
	)
	config.shapes().offer([&"walk", 1, Faces.Up.DECK], [built, graph])
	var floors := BotInputSource.floors_of(config)
	assert_same(floors.surfaces(1), built.surfaces(Faces.Up.DECK))
	assert_same(floors.graph(Faces.Up.size()), graph)
	assert_false(config.shapes().has([&"walk", 1, Faces.Up.DECK]), "claimed by one reader")
