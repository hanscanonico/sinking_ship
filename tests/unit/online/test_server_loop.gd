extends GutTest
## How `--server` is wired (SH12, R9): its room codes come from the system's CSPRNG
## with or without --seed — never from a seeded source — its match seeds too unless
## --seed asks for runs that repeat; and its log reaches a pipe line by line.


func test_room_codes_never_come_from_a_seeded_source() -> void:
	for seed_value: int in [-1, 0, 1701]:
		var codes: Draws = ServerLoop.draws_for(seed_value)[1]
		assert_true(codes is SecureDraws, "codes from the CSPRNG with seed %d" % seed_value)


func test_seeds_repeat_only_when_asked() -> void:
	var unseeded := ServerLoop.draws_for(-1)
	assert_true(unseeded[0] is SecureDraws, "no --seed: seeds from the CSPRNG too")
	var seeded := ServerLoop.draws_for(1701)
	var again := ServerLoop.draws_for(1701)
	assert_true(seeded[0] is SeededDraws)
	assert_ne(seeded[0], seeded[1], "a seeded source never draws the codes")
	assert_eq(seeded[0].u32(), again[0].u32(), "a --seed run's seeds repeat")


## A containerised server's stdout is a pipe, which a release build fills a buffer at
## a time unless told to flush: the log would come minutes late, or die with it. Read
## from the file, as a debug build's own override says true whatever it holds.
func test_the_log_is_flushed_line_by_line() -> void:
	var project := ConfigFile.new()
	assert_eq(project.load("res://project.godot"), OK)
	assert_true(project.get_value("application", "run/flush_stdout_on_print", false))
