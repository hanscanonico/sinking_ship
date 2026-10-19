extends GutTest
## DrawWatch tells a capture whose window has stopped being drawn — covered,
## minimised, on another Space, the display asleep — from one that is drawing, however
## slowly, so it fails rather than wait forever for a frame (#105).

const LIMIT_MS := 60000


func test_a_window_drawing_nothing_for_the_limit_has_stalled() -> void:
	var watch := DrawWatch.new(LIMIT_MS)
	assert_false(watch.stalled(5, 1000), "the first look starts the watch")
	assert_false(watch.stalled(5, 60999), "a moment short of the limit")
	assert_true(watch.stalled(5, 61000), "the limit with nothing drawn")


func test_a_window_drawing_slowly_never_stalls() -> void:
	var watch := DrawWatch.new(LIMIT_MS)
	var drawn := 0
	for second in 600:
		drawn += 1 if second % 50 == 0 else 0
		assert_false(watch.stalled(drawn, second * 1000), "a frame every fifty seconds")


func test_the_limit_runs_from_the_last_frame_drawn() -> void:
	var watch := DrawWatch.new(LIMIT_MS)
	watch.stalled(5, 0)
	assert_false(watch.stalled(6, 50000), "a frame drawn")
	assert_false(watch.stalled(6, 109999), "short of the limit since that frame")
	assert_true(watch.stalled(6, 110000), "the limit since that frame")


func test_one_long_frame_that_is_drawn_has_not_stalled() -> void:
	var watch := DrawWatch.new(LIMIT_MS)
	watch.stalled(5, 0)
	assert_false(watch.stalled(6, 90000), "a jump's bake in one frame, then drawn")


func test_its_message_names_the_limit_and_the_window() -> void:
	var message := DrawWatch.new(5000).stall_message()
	assert_string_contains(message, "for 5 s")
	assert_string_contains(message, "window is not being drawn")


func test_a_capture_waits_a_minute_by_default() -> void:
	var watch := DrawWatch.new()
	watch.stalled(5, 0)
	assert_false(watch.stalled(5, 59999), "short of a minute")
	assert_true(watch.stalled(5, 60000), "a minute with nothing drawn")
