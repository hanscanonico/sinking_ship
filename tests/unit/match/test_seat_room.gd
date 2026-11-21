extends GutTest
## The room a seat is in (SeatRoom): the one whose floor it stands on, and afloat the
## one round it while it is inside her — never a room for a body in the open sea or over
## her decks.

const RunMatch := preload("res://tools/run_match.gd")


func test_a_swimmer_inside_her_is_in_the_room_round_it() -> void:
	var layout := SimFixtures.steamer()
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var schedule := SimFixtures.config(1, scenario, 1701, layout).schedule()
	var pose := schedule.pose_at(schedule.hit_tick())
	var step := SimFixtures.rules().step_height
	var rooms := SeatRoom.new()
	var hold := layout.room_at(Vector3(9.0, -2.6, 0.0), step)
	assert_eq(layout.rooms[hold].name, &"forward hold")
	assert_eq(rooms.of(layout, pose, Vector3(9.0, -2.6, 0.0), step), hold, "on its floor")
	assert_eq(rooms.of(layout, pose, Vector3(9.0, -1.2, 0.0), step), hold, "afloat in it")
	assert_eq(rooms.of(layout, pose, Vector3(9.0, -1.2, 8.0), step), -1, "in the sea alongside")
	assert_eq(rooms.of(layout, pose, Vector3(9.0, 6.0, 0.0), step), -1, "afloat over her decks")


## The trawler's deck over her fish hold lies in the hold's cell: a body standing on it
## is on deck, as it was before a swimmer's room was asked for (#749).
func test_a_body_on_the_deck_over_a_hold_is_in_no_room() -> void:
	var config := RunMatch.default_config(5)
	config.ship = preload("res://data/ships/trawler.tres")
	var sim := MatchSim.new(config)
	var pose := sim.schedule.pose_at(0).of_piece(0)
	var step := config.rules.step_height
	var rooms := SeatRoom.new()
	var on_deck := Vector3(2.0, 0.0, 0.0)
	assert_ne(pose.cell_at(on_deck), CellMap.NONE, "the deck there is inside her hull")
	assert_eq(rooms.of(config.ship, pose, on_deck, step, false), -1, "on its feet: on deck")
	var me := {"pos": on_deck, "state": PlayerState.Body.GROUNDED}
	assert_eq(rooms.of_seat(config.ship, pose, me, step), -1, "as the plate asks it")
	me["state"] = PlayerState.Body.AIRBORNE
	assert_eq(rooms.of_seat(config.ship, pose, me, step), -1, "nor jumping on it")
	var hold := config.ship.room_at(Vector3(2.0, -2.2, 0.0), step)
	assert_eq(config.ship.rooms[hold].name, &"fish hold")
	me = {"pos": Vector3(2.0, -1.0, 0.0), "state": PlayerState.Body.SWIMMING}
	assert_eq(rooms.of_seat(config.ship, pose, me, step), hold, "afloat in the hold: in it")


func test_a_pose_with_no_cells_names_only_the_room_stood_in() -> void:
	var layout := SimFixtures.below_decks()
	var pose := SimFixtures.sim(1, null, layout).pose()
	var step := SimFixtures.rules().step_height
	var rooms := SeatRoom.new()
	assert_ne(rooms.of(layout, pose, SimFixtures.hold_spot(0), step), -1, "on the hold's floor")
	var afloat := SimFixtures.hold_spot(0) + Vector3.UP * 1.2
	assert_eq(rooms.of(layout, pose, afloat, step), -1, "nothing says it is inside her")


## A seat the cold put out afloat in her hold went out aboard; one in the sea alongside,
## overboard; one still in, neither — and the answer is kept until the next match.
func test_a_seat_out_in_a_room_went_out_aboard() -> void:
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var sim := MatchSim.create(SimFixtures.config(3, scenario, 1701, SimFixtures.steamer()))
	sim.state.tick = sim.schedule.hit_tick()
	var spots: Array[Vector3] = [Vector3(9.0, -1.2, 0.0), Vector3(9.0, -1.2, 8.0)]
	for seat in spots.size():
		var player := sim.state.seats[seat]
		player.pos = spots[seat]
		player.body = PlayerState.Body.OUT
		player.out_cause = PlayerState.Cause.COLD
	sim.state.seats[2].pos = spots[0]
	var rooms := SeatRoom.new()
	var snapshot := sim.snapshot()
	assert_true(rooms.out_aboard(sim, snapshot, 0), "out in the hold")
	assert_false(rooms.out_aboard(sim, snapshot, 1), "out in the sea")
	assert_false(rooms.out_aboard(sim, snapshot, 2), "in the hold, still in")
	assert_false(rooms.out_aboard(sim, snapshot, -1), "a watcher has no seat")
	sim.state.seats[0].pos = spots[1]
	assert_true(rooms.out_aboard(sim, sim.snapshot(), 0), "kept: asked once a match")
	rooms.forget()
	assert_false(rooms.out_aboard(sim, sim.snapshot(), 0), "asked again for the next")


## The ghost is in the room it walks, as a seat is, and on an open deck on its platform;
## nowhere while the view is not its.
func test_the_ghost_stands_in_the_room_it_walks() -> void:
	var sim := SimFixtures.sim(1, null, SimFixtures.steamer())
	var step := sim.config.rules.step_height
	var snapshot := sim.snapshot()
	var rooms := SeatRoom.new()
	var ghost := GhostWalk.new(sim.config, sim.schedule)
	assert_eq(rooms.ghost_place(null, sim.schedule, snapshot, step), "", "no ghost")
	assert_eq(rooms.ghost_place(ghost, sim.schedule, snapshot, step), "", "not walking")
	assert_true(ghost.start(snapshot, Vector3(9.0, -2.6, 0.0), 0, Vector3.RIGHT))
	assert_eq(rooms.ghost_place(ghost, sim.schedule, snapshot, step), "forward hold")
	# From high over the hold it is stood on the highest floor under it: her open deck.
	assert_true(ghost.start(snapshot, Vector3(9.0, 30.0, 0.0), 0, Vector3.RIGHT))
	assert_eq(sim.config.ship.room_at(ghost.body.pos, step), -1, "in no room")
	var deck := String(sim.config.ship.platforms[ghost.body.surface].name)
	assert_ne(deck, "")
	assert_eq(rooms.ghost_place(ghost, sim.schedule, snapshot, step), deck, "its platform")
	ghost.leave()
	assert_eq(rooms.ghost_place(ghost, sim.schedule, snapshot, step), "", "the view left")
