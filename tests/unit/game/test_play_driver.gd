extends GutTest
## The played session's driver (PlayDriver, make play): how a batch's lines become
## commands, and what an answer says of the match and of its events.


func test_a_line_is_its_words_and_a_quoted_one_stays_whole() -> void:
	assert_eq(
		PlayDriver.split_words('click "Play online" right'),
		PackedStringArray(["click", "Play online", "right"])
	)
	assert_eq(PlayDriver.split_words("  wait   30 "), PackedStringArray(["wait", "30"]))
	assert_eq(PlayDriver.split_words(""), PackedStringArray(), "a blank line is no command")


func test_the_flags_name_the_session() -> void:
	var args := MatchArgs.parse(PackedStringArray(["--play=/tmp/play", "--play-idle=30"]))
	assert_eq(args.play_dir, "/tmp/play")
	assert_eq(args.play_idle, 30.0)
	assert_eq(MatchArgs.parse(PackedStringArray()).play_dir, "", "a person plays")


func test_an_event_line_keeps_the_local_seat_and_drops_what_nobody_named() -> void:
	var landed := SimEvent.new(SimEvent.Kind.SHOVE_LANDED, 45, 0)
	landed.target = 3
	assert_eq(PlayDriver.event_line(landed.to_dict()), "00:01.5 SHOVE_LANDED seat=0 target=3")


func test_a_ghost_line_says_where_the_ghost_walks_and_looks() -> void:
	var body := PlayerState.new(0)
	body.pos = Vector3(4.5, -2.6, 2.0)
	body.piece = 1
	body.body = PlayerState.Body.GROUNDED
	body.surface = 56
	assert_eq(
		PlayDriver.ghost_line(body, deg_to_rad(450.0)),
		"ghost: GROUNDED at (4.5, -2.6, 2.0) piece 1 surface 56, facing 90°"
	)


func test_the_match_lines_say_the_seat_and_who_is_near() -> void:
	var sim := SimFixtures.sim(3)
	var lines := PlayDriver.match_lines(sim.snapshot())
	assert_string_contains(lines[0], "3 of 3 in")
	assert_string_contains(lines[1], "me: GROUNDED")
	assert_eq(lines.size(), 5, "the clock, the seat's two lines, and the two others")
	assert_eq(PlayDriver.match_lines({}), PackedStringArray(), "no match, nothing to say")


func test_online_the_match_lines_say_the_seat_the_server_gave() -> void:
	var sim := SimFixtures.sim(3)
	var snapshot := sim.snapshot()
	var seats: Array = snapshot["seats"]
	var pos: Vector3 = seats[2]["pos"]
	assert_ne(pos, seats[0]["pos"], "the fixture's seats stand apart")
	var lines := PlayDriver.match_lines(snapshot, 2)
	assert_string_contains(lines[1], "(%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	var others := " | ".join(lines.slice(3))
	assert_string_contains(others, "seat 0 ", "the first seat is one of the others")
	assert_false(others.contains("seat 2 "), "the seat played is not")


func test_online_an_answer_tells_of_the_seat_the_server_gave() -> void:
	var landed := SimEvent.new(SimEvent.Kind.SHOVE_LANDED, 45, 4)
	landed.target = 2
	assert_true(PlayDriver.tells(landed.to_dict(), 2), "a shove on the seat played")
	assert_false(PlayDriver.tells(landed.to_dict(), 0), "a shove on someone else's seat")


func test_a_watcher_is_told_of_the_seat_it_watches() -> void:
	assert_eq(PlayDriver.told_seat(2, 5), 2, "a player, of the seat played")
	assert_eq(PlayDriver.told_seat(-1, 5), 5, "a watcher, of the seat whose eyes it has")
	assert_eq(PlayDriver.told_seat(-1, -1), MatchScene.LOCAL_SEAT, "else of the first")


func test_an_answer_leaves_the_bots_own_brawl_out() -> void:
	var theirs := SimEvent.new(SimEvent.Kind.SHOVE_LANDED, 45, 2)
	theirs.target = 3
	assert_false(PlayDriver.tells(theirs.to_dict()), "one bot shoving another")
	theirs.target = MatchScene.LOCAL_SEAT
	assert_true(PlayDriver.tells(theirs.to_dict()), "a shove on the local seat")
	var out := SimEvent.new(SimEvent.Kind.SEAT_OUT, 45, 2)
	assert_true(PlayDriver.tells(out.to_dict()), "anyone going out")
	var flooding := SimEvent.new(SimEvent.Kind.CELL_FLOODING, 45, -1)
	assert_true(PlayDriver.tells(flooding.to_dict()), "her sinking")


func test_the_flags_put_a_session_on_a_crews_clock() -> void:
	var args := MatchArgs.parse(
		PackedStringArray(["--play=/tmp/crew/seat1", "--crew=/tmp/crew/clock"])
	)
	assert_eq(args.crew_dir, "/tmp/crew/clock")
	assert_eq(MatchArgs.parse(PackedStringArray()).crew_dir, "", "its frames its own")
