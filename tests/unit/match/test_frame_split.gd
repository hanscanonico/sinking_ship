extends GutTest
## FrameSplit sums up where each kept frame's time went (make fps SPLIT=1): every part
## averaged over the frames kept, each part's rest — what its own parts leave of it —
## reported under its own name, so the parts always add up to the frame, and the
## frame's own rest reported as unaccounted.


func _frame(split: FrameSplit, frame_us: int, parts: Dictionary) -> void:
	for part: StringName in parts:
		split.add(part, parts[part])
	split.close(frame_us)


func test_a_part_is_its_mean_over_the_frames_kept() -> void:
	var split := FrameSplit.new()
	_frame(split, 30000, {&"bots": 4000, &"match": 10000})
	_frame(split, 40000, {&"bots": 2000, &"match": 6000})
	assert_eq(split.frames(), 2)
	assert_almost_eq(split.mean(&"frame"), 35.0, 0.0001, "in milliseconds")
	assert_almost_eq(split.mean(&"bots"), 3.0, 0.0001)
	assert_almost_eq(split.mean(&"match"), 8.0, 0.0001)


func test_a_part_measured_twice_in_a_frame_counts_both_times() -> void:
	var split := FrameSplit.new()
	split.add(&"host_sim", 1500)
	split.add(&"host_sim", 2500)
	split.close(20000)
	assert_almost_eq(split.mean(&"host_sim"), 4.0, 0.0001, "two steps in one frame")


func test_a_dropped_frame_counts_for_nothing() -> void:
	var split := FrameSplit.new()
	split.add(&"bots", 90000)
	split.drop()
	_frame(split, 20000, {&"bots": 1000})
	assert_eq(split.frames(), 1)
	assert_almost_eq(split.mean(&"bots"), 1.0, 0.0001, "the dropped frame's time left out")


func test_what_a_part_leaves_of_its_parent_is_its_rest() -> void:
	var split := FrameSplit.new()
	_frame(
		split,
		40000,
		{
			&"process": 20000,
			&"match": 12000,
			&"bots": 5000,
			&"host_sim": 4000,
			&"render": 15000,
		}
	)
	assert_almost_eq(split.rest(&"match"), 3.0, 0.0001, "the step less its measured parts")
	assert_almost_eq(split.rest(&"process"), 8.0, 0.0001, "the display scripts' share")
	assert_almost_eq(split.rest(&"frame"), 5.0, 0.0001, "unaccounted")


func test_the_frames_parts_and_their_rest_add_up_to_the_frame() -> void:
	var split := FrameSplit.new()
	_frame(split, 38000, {&"process": 21000, &"match": 9000, &"render": 12500})
	_frame(split, 41000, {&"process": 19000, &"match": 11000, &"render": 13500})
	var top := 0.0
	for part: StringName in split.parts_of(&"frame"):
		top += split.mean(part)
	assert_almost_eq(top + split.rest(&"frame"), split.mean(&"frame"), 0.0001)
	assert_almost_eq(split.rest(&"frame"), 6.5, 0.0001)


func test_the_report_names_every_part_and_the_unaccounted_rest() -> void:
	var split := FrameSplit.new()
	_frame(
		split,
		40000,
		{
			&"process": 20000,
			&"match": 12000,
			&"bots": 5000,
			&"render": 15000,
			&"poses": 21,
			&"pose_time": 3000,
			&"steps": 1,
		}
	)
	var report := "\n".join(split.report())
	assert_string_contains(report, "over 1 frames")
	assert_string_contains(report, "bots' decisions")
	assert_string_contains(report, "display scripts")
	assert_string_contains(report, "render CPU")
	assert_string_contains(report, "unaccounted")
	var unaccounted := Array(split.report()).filter(
		func(line: String) -> bool: return line.contains("unaccounted")
	)
	assert_eq(unaccounted.size(), 1)
	assert_string_contains(unaccounted[0], "5.00 ms", "the frame's rest, in milliseconds")
	assert_string_contains(report, "sinking poses")
	assert_string_contains(report, "21.0", "poses built per frame")


func test_a_report_of_no_frames_says_so() -> void:
	var report := FrameSplit.new().report()
	assert_eq(report.size(), 1)
	assert_string_contains(report[0], "no frames kept")
