extends GutTest
## The clock a crew of games keeps together (CrewClock, make crew): who may run their
## next frame, where a member joining starts, and what its file says.

var _dir: String


func before_each() -> void:
	_dir = OS.get_user_data_dir().path_join("test_crew_clock_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	for file: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file))
	DirAccess.remove_absolute(_dir)


func test_a_member_steps_once_nobody_has_run_fewer_frames() -> void:
	assert_true(CrewClock.may_step(5, [5, 6]), "level with the slowest")
	assert_false(CrewClock.may_step(6, [5, 6]), "one ahead of a member held")
	assert_true(CrewClock.may_step(0, []), "alone")


func test_a_member_joins_at_the_crews_frame() -> void:
	assert_eq(CrewClock.joining_frame([120, 121]), 121, "never pulling the crew back")
	assert_eq(CrewClock.joining_frame([]), 0, "the first")


func test_a_members_file_says_its_process_and_frames() -> void:
	assert_eq(CrewClock.parse("4242 17\n"), [4242, 17])
	assert_eq(CrewClock.parse(""), [], "caught being written")
	assert_eq(CrewClock.parse("4242"), [], "half written")


func test_a_file_long_unwritten_is_a_member_gone() -> void:
	assert_false(CrewClock.is_stale(1000, 1000.0 + CrewClock.STALE_SECONDS), "just in time")
	assert_true(CrewClock.is_stale(1000, 1001.0 + CrewClock.STALE_SECONDS))
	assert_false(CrewClock.is_stale(0, 1.0e9), "no time known is no verdict")


func test_members_tick_in_turn_and_one_left_holds_nobody() -> void:
	var server := CrewClock.new(_dir, "server", false)
	var seat := CrewClock.new(_dir, "seat1", false)
	server.tick()
	assert_eq(server.frames(), 1, "alone, it runs")
	seat.tick()
	assert_eq(seat.frames(), 2, "joined at the server's frame, then run one")
	server.tick()
	assert_eq(server.frames(), 2, "level with the seat")
	seat.leave()
	server.tick()
	server.tick()
	assert_eq(server.frames(), 4, "the seat gone, nobody holds it back")
	assert_eq(
		FileAccess.get_file_as_string(_dir.path_join("server.clock")),
		"%d 4\n" % OS.get_process_id()
	)
	server.leave()
